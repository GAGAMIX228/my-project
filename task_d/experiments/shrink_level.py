"""E4 + S1 + S2 (гипотеза: y_train = t + c + шум, тест = t, t ≈ «сжатое» условное среднее train).
E4: D = blend_oof − mu_oof (mu = ridge-logit, переведённый в среднее): доля D, объяснимая уровнем, и структура по признакам.
S1: h(mu_test), h — изотонная зависимость blend_oof от mu_oof.
S2: дистилляция бленда: сплайновый ridge на logit(blend_oof), мощность по CV против отложенного blend_oof."""
import os, sys, warnings
import lightgbm as lgb, numpy as np, pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.impute import SimpleImputer
from sklearn.isotonic import IsotonicRegression
from sklearn.linear_model import RidgeCV
from sklearn.model_selection import KFold, cross_val_predict, cross_val_score
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import OneHotEncoder, SplineTransformer, StandardScaler
warnings.filterwarnings("ignore")
HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__))); ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from common import CAT_FEATURES, ID, TARGET, load, make_features  # noqa
from train import prep  # noqa
SD = os.path.join(ROOT, "submissions_d"); OUT = os.path.join(SD, "shrink"); os.makedirs(OUT, exist_ok=True)
tr = load(os.path.join(HERE, "data", "hard_train.csv")); te = load(os.path.join(HERE, "data", "hard_test.csv"))
y = tr[TARGET].values
bo = np.load(os.path.join(SD, "blend_oof.npz")); blend = bo["blend"]
rz = np.load(os.path.join(SD, "ridge_z.npz")); zo, zt = rz["zo"], rz["zt"]
best = pd.read_csv(os.path.join(SD, "sharp", "submission_seed_352773_base_mid_sharp.csv"))[TARGET].values
gx, gw = np.polynomial.hermite_e.hermegauss(40); gw = gw / gw.sum()
to_mean = lambda q, s=0.6: 100 * (gw / (1 + np.exp(-(q[:, None] + s * gx)))).sum(1)
mu, mut = to_mean(zo), to_mean(zt)
rm = lambda a, b: np.sqrt(np.mean((a - b) ** 2))
kf = KFold(5, shuffle=True, random_state=0)
print(f"OOF RMSE по y: blend {rm(blend, y):.4f}, ridge-mean {rm(mu, y):.4f}, (blend+mu)/2 {rm((blend + mu) / 2, y):.4f}")
print(f"RMS(blend−mu): train {rm(blend, mu):.3f}, test (best−mu_test) {rm(best, mut):.3f}")

# E4
D = blend - mu
iso = IsotonicRegression(out_of_bounds="clip").fit(mu, blend)
lvl = iso.predict(mu) - mu
print(f"E4: доля var(D), объяснённая уровнем: {1 - np.var(D - lvl) / np.var(D):.3f}")
Xl, Xlt = prep(tr, tr, True, "lgbm"), prep(te, tr, True, "lgbm")
gb = lgb.LGBMRegressor(n_estimators=300, learning_rate=0.03, num_leaves=8, verbose=-1, n_jobs=1)
print("E4: R2 остатка D по признакам:", np.round(cross_val_score(gb, Xl, D - lvl, cv=kf, scoring="r2"), 3))
for q in [10, 30, 50, 70, 90]:
    v = np.percentile(mu, q); print(f"   уровень mu {v:5.1f}: h(mu)−mu = {iso.predict([v])[0] - v:+.2f}")

# S1: h(mu) — изотонная калибровка; честный CV h (h обучен вне фолда)
h_oof = np.zeros(len(y))
for a, b in kf.split(mu):
    h_oof[b] = IsotonicRegression(out_of_bounds="clip").fit(mu[a], blend[a]).predict(mu[b])
s1 = iso.predict(mut)
print(f"S1: OOF RMSE по y {rm(h_oof, y):.4f}; к отложенному blend {rm(h_oof, blend):.3f}; "
      f"тест: mean {s1.mean():.2f}, RMSE к лучшему {rm(s1, best):.3f}")
pd.DataFrame({ID: te[ID], TARGET: s1}).to_csv(os.path.join(OUT, "submission_seed_352773_S1_iso_mu.csv"), index=False)

# S2: дистилляция бленда в сплайновый ridge на логитах
X, Xt = make_features(tr, True), make_features(te, True)
num = [c for c in X.columns if c not in CAT_FEATURES]
eps = 0.2; zb = np.log(np.clip(blend, eps, 100 - eps) / (100 - np.clip(blend, eps, 100 - eps)))
def student(knots):
    numt = make_pipeline(SimpleImputer(strategy="median", add_indicator=True), StandardScaler()) if knots == 0 else \
        make_pipeline(SimpleImputer(strategy="median", add_indicator=True),
                      SplineTransformer(n_knots=knots, degree=3, knots="quantile", extrapolation="linear"), StandardScaler())
    pre = ColumnTransformer([("num", numt, num), ("cat", OneHotEncoder(handle_unknown="ignore"), CAT_FEATURES)])
    return make_pipeline(pre, RidgeCV(alphas=np.logspace(-3, 3, 13)))
inv = lambda q: 100 / (1 + np.exp(-q))
res = {}
for knots in [0, 3, 5, 8]:
    p = inv(cross_val_predict(student(knots), X, zb, cv=kf))
    res[knots] = rm(p, blend)
    print(f"S2 knots={knots}: RMSE к отложенному blend {res[knots]:.3f}, OOF RMSE по y {rm(p, y):.4f}")
k = min(res, key=res.get)
s2 = inv(student(k).fit(X, zb).predict(Xt))
print(f"S2 выбран knots={k}: тест mean {s2.mean():.2f}, RMSE к лучшему {rm(s2, best):.3f}")
pd.DataFrame({ID: te[ID], TARGET: s2}).to_csv(os.path.join(OUT, f"submission_seed_352773_S2_distill_k{k}.csv"), index=False)
print("RMSE S1 vs S2 на тесте", rm(s1, s2).round(3))
