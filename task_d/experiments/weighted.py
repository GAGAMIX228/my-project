"""Гипотеза D: взвешенный МНК. Шум зависит от уровня цели (std ~4 при высоком прогнозе, ~14 при
низком), поэтому строки с меньшим шумом получают больший вес 1/sigma^2. Ансамбль как в финале
(CatBoost x5 + LightGBM+FE x5), но с весами."""
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
sys.path.insert(0, HERE)
from common import CAT_FEATURES, TARGET, load  # noqa: E402
from train import prep  # noqa: E402

tr = load(os.path.join(HERE, "data", "hard_train.csv"))
te = load(os.path.join(HERE, "data", "hard_test.csv"))
y = tr[TARGET].values
Xc, Xct = prep(tr, tr, False, "cat"), prep(te, tr, False, "cat")
Xl, Xlt = prep(tr, tr, True, "lgbm"), prep(te, tr, True, "lgbm")
lp = dict(learning_rate=0.02, num_leaves=8, min_child_samples=40, subsample=0.8, subsample_freq=1,
          colsample_bytree=0.5, reg_lambda=5, verbose=-1)

oof = np.zeros(len(y))
for a, b in KFold(5, shuffle=True, random_state=0).split(Xl):
    oof[b] = lgb.LGBMRegressor(n_estimators=1000, **lp).fit(Xl.iloc[a], y[a]).predict(Xl.iloc[b])
var_m = lgb.LGBMRegressor(n_estimators=300, learning_rate=0.03, num_leaves=8, min_child_samples=100,
                          verbose=-1).fit(oof.reshape(-1, 1), (y - oof) ** 2)
sig2 = np.clip(var_m.predict(oof.reshape(-1, 1)), 4, None)
w = 1 / sig2
w = w / w.mean()
q = pd.qcut(oof, 5, labels=False)
print("std шума по квинтилям прогноза:", [round(float(np.sqrt(sig2[q == i].mean())), 1) for i in range(5)],
      "веса", round(w.min(), 2), "-", round(w.max(), 2), flush=True)

seed = 352773
pc = np.mean([CatBoostRegressor(iterations=867, learning_rate=0.03, depth=6, verbose=0, cat_features=CAT_FEATURES,
                                random_seed=seed + k, allow_writing_files=False)
              .fit(Xc, y, sample_weight=w).predict(Xct) for k in range(5)], 0)
pl = np.mean([lgb.LGBMRegressor(n_estimators=1068, **lp, random_state=seed + k)
              .fit(Xl, y, sample_weight=w).predict(Xlt) for k in range(5)], 0)
p = np.clip((pc + pl) / 2, 0, 100)
root = os.path.dirname(HERE)
best = pd.read_csv(os.path.join(root, "submissions_d/final/submission_seed_352773.csv")).protection_score.values
print("RMSE к сабмиту 76.27:", round(float(np.sqrt(np.mean((p - best) ** 2))), 2))
out = os.path.join(root, f"submissions_d/submission_seed_{seed}_weighted.csv")
pd.DataFrame({"customer_id": te.customer_id, "protection_score": p}).to_csv(out, index=False)
print(out)
