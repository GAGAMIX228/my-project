"""S2-вариант: дистилляция бленда в аддитивную модель в шкале y (сплайны + one-hot, RidgeCV).
Мощность — по RMSE к отложенному blend_oof."""
import os, sys, warnings
import numpy as np, pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.impute import SimpleImputer
from sklearn.linear_model import RidgeCV
from sklearn.model_selection import KFold, cross_val_predict
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import OneHotEncoder, SplineTransformer, StandardScaler
warnings.filterwarnings("ignore")
HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__))); ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from common import CAT_FEATURES, ID, TARGET, load, make_features  # noqa
SD = os.path.join(ROOT, "submissions_d"); OUT = os.path.join(SD, "shrink")
tr = load(os.path.join(HERE, "data", "hard_train.csv")); te = load(os.path.join(HERE, "data", "hard_test.csv"))
blend = np.load(os.path.join(SD, "blend_oof.npz"))["blend"]
best = pd.read_csv(os.path.join(SD, "sharp", "submission_seed_352773_base_mid_sharp.csv"))[TARGET].values
X, Xt = make_features(tr, True), make_features(te, True)
num = [c for c in X.columns if c not in CAT_FEATURES]
rm = lambda a, b: np.sqrt(np.mean((a - b) ** 2))
def student(knots):
    st = [SimpleImputer(strategy="median", add_indicator=True)]
    if knots: st.append(SplineTransformer(n_knots=knots, degree=3, knots="quantile", extrapolation="linear"))
    pre = ColumnTransformer([("num", make_pipeline(*st, StandardScaler()), num),
                             ("cat", OneHotEncoder(handle_unknown="ignore"), CAT_FEATURES)])
    return make_pipeline(pre, RidgeCV(alphas=np.logspace(-3, 3, 13)))
kf = KFold(5, shuffle=True, random_state=0); res = {}
for k in [0, 3, 5, 8, 12]:
    res[k] = rm(cross_val_predict(student(k), X, blend, cv=kf), blend); print(f"knots={k}: RMSE к отложенному blend {res[k]:.3f}")
k = min(res, key=res.get); p = np.clip(student(k).fit(X, blend).predict(Xt), 0, 100)
print(f"выбран {k}: тест mean {p.mean():.2f}, RMSE к лучшему {rm(p, best):.3f}")
pd.DataFrame({ID: te[ID], TARGET: p}).to_csv(os.path.join(OUT, f"submission_seed_352773_S2y_distill_k{k}.csv"), index=False)
