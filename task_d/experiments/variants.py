"""Гипотезы D (снижение разброса): три кандидата для проверки на LB.
  v1: CatBoost x5 + LightGBM+FE x5 + XGBoost+FE x5, по трети;
  v2: «сглаженные»: CatBoost lr=0.015 (x2 деревьев) + LightGBM extra_trees;
  v3: финальная смесь (CatBoost + LightGBM), но только топ-30 признаков по важности."""
import os
import sys
import warnings

import lightgbm as lgb
import numpy as np
import pandas as pd
import xgboost as xgb
from catboost import CatBoostRegressor
from sklearn.model_selection import KFold

warnings.filterwarnings("ignore")
HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from common import CAT_FEATURES, TARGET, load  # noqa: E402
from train import prep  # noqa: E402

tr = load(os.path.join(HERE, "data", "hard_train.csv"))
te = load(os.path.join(HERE, "data", "hard_test.csv"))
y = tr[TARGET].values
SEED, NS = 352773, 5
Xc, Xct = prep(tr, tr, False, "cat"), prep(te, tr, False, "cat")
Xl, Xlt = prep(tr, tr, True, "lgbm"), prep(te, tr, True, "lgbm")
LP = dict(learning_rate=0.02, num_leaves=8, min_child_samples=40, subsample=0.8, subsample_freq=1,
          colsample_bytree=0.5, reg_lambda=5, verbose=-1)
kf = list(KFold(5, shuffle=True, random_state=0).split(tr))
best = pd.read_csv(os.path.join(ROOT, "submissions_d/final/submission_seed_352773.csv")).protection_score.values


def save(name, p):
    p = np.clip(p, 0, 100)
    out = os.path.join(ROOT, f"submissions_d/variants/submission_seed_{SEED}_{name}.csv")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    pd.DataFrame({"customer_id": te.customer_id, "protection_score": p}).to_csv(out, index=False)
    print(f"{name}: RMSE к сабмиту 76.27 = {np.sqrt(np.mean((p - best) ** 2)):.2f} -> {out}", flush=True)


def cat(X, Xt, lr=0.03, mult=1.0):
    its = [CatBoostRegressor(iterations=8000, learning_rate=lr, depth=6, verbose=0, cat_features=CAT_FEATURES,
                             early_stopping_rounds=300, allow_writing_files=False)
           .fit(X.iloc[a], y[a], eval_set=(X.iloc[b], y[b])).tree_count_ for a, b in kf]
    n = int(np.mean(its) * 1.1 * mult)
    return np.mean([CatBoostRegressor(iterations=n, learning_rate=lr, depth=6, verbose=0, cat_features=CAT_FEATURES,
                                      random_seed=SEED + k, allow_writing_files=False).fit(X, y).predict(Xt)
                    for k in range(NS)], 0), n


def lgbm(X, Xt, **kw):
    p = {**LP, **kw}
    its = [lgb.LGBMRegressor(n_estimators=8000, **p).fit(X.iloc[a], y[a], eval_set=[(X.iloc[b], y[b])],
           callbacks=[lgb.early_stopping(200, verbose=False)]).best_iteration_ for a, b in kf]
    n = int(np.mean(its) * 1.1)
    return np.mean([lgb.LGBMRegressor(n_estimators=n, **p, random_state=SEED + k).fit(X, y).predict(Xt)
                    for k in range(NS)], 0), n


# базовые компоненты (как в финале)
pc, nc = cat(Xc, Xct)
pl, nl = lgbm(Xl, Xlt)
print("база: catboost", nc, "lgbm", nl, flush=True)

# v1: + XGBoost
xp = dict(learning_rate=0.02, max_depth=4, min_child_weight=20, subsample=0.8, colsample_bytree=0.5,
          reg_lambda=5, tree_method="hist", enable_categorical=True)
its = [xgb.XGBRegressor(n_estimators=8000, **xp, early_stopping_rounds=200)
       .fit(Xl.iloc[a], y[a], eval_set=[(Xl.iloc[b], y[b])], verbose=False).best_iteration for a, b in kf]
nx = int(np.mean(its) * 1.1)
px = np.mean([xgb.XGBRegressor(n_estimators=nx, **xp, random_state=SEED + k).fit(Xl, y).predict(Xlt)
              for k in range(NS)], 0)
print("xgb деревьев", nx, flush=True)
save("v1_xgb", (pc + pl + px) / 3)

# v2: сглаженные версии
pc2, nc2 = cat(Xc, Xct, lr=0.015)
pl2, nl2 = lgbm(Xl, Xlt, extra_trees=True)
print("сглаженные: catboost", nc2, "lgbm extra_trees", nl2, flush=True)
save("v2_smooth", (pc2 + pl2) / 2)

# v3: топ-30 признаков по важности (gain LightGBM)
m = lgb.LGBMRegressor(n_estimators=nl, **LP, random_state=SEED).fit(Xl, y)
imp = pd.Series(m.booster_.feature_importance("gain"), index=Xl.columns).sort_values(ascending=False)
top = list(imp.index[:30])
print("топ-30:", top, flush=True)
topc = [c for c in top if c in Xc.columns]
cats_keep = [c for c in CAT_FEATURES if c in topc]
its = [CatBoostRegressor(iterations=8000, learning_rate=0.03, depth=6, verbose=0, cat_features=cats_keep,
                         early_stopping_rounds=300, allow_writing_files=False)
       .fit(Xc[topc].iloc[a], y[a], eval_set=(Xc[topc].iloc[b], y[b])).tree_count_ for a, b in kf]
n = int(np.mean(its) * 1.1)
pc3 = np.mean([CatBoostRegressor(iterations=n, learning_rate=0.03, depth=6, verbose=0, cat_features=cats_keep,
                                 random_seed=SEED + k, allow_writing_files=False).fit(Xc[topc], y).predict(Xct[topc])
               for k in range(NS)], 0)
pl3, _ = lgbm(Xl[top], Xlt[top])
save("v3_top30", (pc3 + pl3) / 2)
