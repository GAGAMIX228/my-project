"""E3: ridge на logit -> перевод в среднее (Гаусс–Эрмит), CV; структура в логит-остатках ridge.
Сохраняет OOF/тест ridge в логитах (submissions_d/ridge_z.npz) и сабмит S0 (ridge-mean)."""
import os, sys, warnings
import lightgbm as lgb, numpy as np, pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.impute import SimpleImputer
from sklearn.linear_model import RidgeCV
from sklearn.model_selection import KFold, cross_val_predict, cross_val_score
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import OneHotEncoder, StandardScaler
warnings.filterwarnings("ignore")
HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__))); ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from common import CAT_FEATURES, ID, TARGET, load, make_features  # noqa
from train import prep  # noqa
tr = load(os.path.join(HERE, "data", "hard_train.csv")); te = load(os.path.join(HERE, "data", "hard_test.csv"))
y = tr[TARGET].values; z = np.log(y / (100 - y))
X, Xt = make_features(tr, False), make_features(te, False)
num = [c for c in X.columns if c not in CAT_FEATURES]
pre = ColumnTransformer([("num", make_pipeline(SimpleImputer(strategy="median", add_indicator=True), StandardScaler()), num),
                         ("cat", OneHotEncoder(handle_unknown="ignore"), CAT_FEATURES)])
ridge = lambda: make_pipeline(pre, RidgeCV(alphas=np.logspace(-3, 3, 13)))
kf = KFold(5, shuffle=True, random_state=0)
zo = cross_val_predict(ridge(), X, z, cv=kf); zt = ridge().fit(X, z).predict(Xt)
gx, gw = np.polynomial.hermite_e.hermegauss(40); gw = gw / gw.sum()
to_mean = lambda q, s: 100 * (gw / (1 + np.exp(-(q[:, None] + s * gx)))).sum(1)
rm = lambda p: np.sqrt(np.mean((p - y) ** 2))
r = z - zo
print("std логит-остатка ridge", r.std().round(4))
for s in [0, 0.4, 0.5, 0.6, 0.7, 0.8]:
    print(f"s={s}: CV RMSE ridge-mean {rm(to_mean(zo, s)):.4f}")
Xl = prep(tr, tr, True, "lgbm")
gb = lgb.LGBMRegressor(n_estimators=300, learning_rate=0.03, num_leaves=8, verbose=-1, n_jobs=1)
print("R2 бустинга на логит-остатках ridge:", np.round(cross_val_score(gb, Xl, r, cv=kf, scoring="r2"), 4))
gb2 = lgb.LGBMRegressor(n_estimators=300, learning_rate=0.03, num_leaves=8, verbose=-1, n_jobs=1)
print("R2 бустинга на y-остатках ridge-mean(0.6):", np.round(cross_val_score(gb2, Xl, y - to_mean(zo, 0.6), cv=kf, scoring="r2"), 4))
os.makedirs(os.path.join(ROOT, "submissions_d", "ridge_mean"), exist_ok=True)
np.savez(os.path.join(ROOT, "submissions_d", "ridge_z.npz"), zo=zo, zt=zt)
p = to_mean(zt, 0.6)
pd.DataFrame({ID: te[ID], TARGET: p}).to_csv(os.path.join(ROOT, "submissions_d", "ridge_mean", "submission_seed_352773_ridge_mean.csv"), index=False)
best = pd.read_csv(os.path.join(ROOT, "submissions_d", "sharp", "submission_seed_352773_base_mid_sharp.csv"))[TARGET].values
print("S0 ridge-mean test: mean", p.mean().round(2), "RMSE к лучшему", np.sqrt(np.mean((p - best) ** 2)).round(3))
