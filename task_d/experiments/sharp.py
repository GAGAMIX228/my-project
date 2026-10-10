"""Гипотеза D: сглаживание вредит на LB (ridge 54, smooth 74.5, top30 74.2) -> пробуем менее
регуляризованные («резкие») модели: глубже деревья, меньше листовой минимум."""
import os
import sys
import warnings

import lightgbm as lgb
import numpy as np
import pandas as pd
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
kf = list(KFold(5, shuffle=True, random_state=0).split(tr))
best = pd.read_csv(os.path.join(ROOT, "submissions_d/final/submission_seed_352773.csv")).protection_score.values

import sys as _s
LEVELS = {"sharp": (8, 31, 20), "sharper": (10, 63, 10), "mid": (7, 16, 30)}
todo = _s.argv[1:] or ["sharp", "sharper"]
for name, (depth, leaves, mcs) in [(n, LEVELS[n]) for n in todo]:
    its = [CatBoostRegressor(iterations=8000, learning_rate=0.03, depth=depth, verbose=0, cat_features=CAT_FEATURES,
                             early_stopping_rounds=300, allow_writing_files=False)
           .fit(Xc.iloc[a], y[a], eval_set=(Xc.iloc[b], y[b])).tree_count_ for a, b in kf]
    nc = int(np.mean(its) * 1.1)
    pc = np.mean([CatBoostRegressor(iterations=nc, learning_rate=0.03, depth=depth, verbose=0,
                                    cat_features=CAT_FEATURES, random_seed=SEED + k, allow_writing_files=False)
                  .fit(Xc, y).predict(Xct) for k in range(NS)], 0)
    lp = dict(learning_rate=0.02, num_leaves=leaves, min_child_samples=mcs, subsample=0.8, subsample_freq=1,
              colsample_bytree=0.5, reg_lambda=1, verbose=-1)
    its = [lgb.LGBMRegressor(n_estimators=8000, **lp).fit(Xl.iloc[a], y[a], eval_set=[(Xl.iloc[b], y[b])],
           callbacks=[lgb.early_stopping(200, verbose=False)]).best_iteration_ for a, b in kf]
    nl = int(np.mean(its) * 1.1)
    pl = np.mean([lgb.LGBMRegressor(n_estimators=nl, **lp, random_state=SEED + k).fit(Xl, y).predict(Xlt)
                  for k in range(NS)], 0)
    p = np.clip((pc + pl) / 2, 0, 100)
    out = os.path.join(ROOT, f"submissions_d/sharp/submission_seed_{SEED}_{name}.csv")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    pd.DataFrame({"customer_id": te.customer_id, "protection_score": p}).to_csv(out, index=False)
    print(f"{name}: cat depth={depth} ({nc} дер.), lgbm leaves={leaves} ({nl} дер.); "
          f"RMSE к 76.27 = {np.sqrt(np.mean((p - best) ** 2)):.2f} -> {out}", flush=True)
