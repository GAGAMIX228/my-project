"""Гипотезы C на спектральных признаках: LightGBM x5 seed; CatBoost; смесь рангов LGBM+CatBoost."""
import os
import sys

import lightgbm as lgb
import numpy as np
import pandas as pd
from catboost import CatBoostClassifier
from scipy.stats import rankdata

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.dirname(HERE)
s = np.load(os.path.join(HERE, "features", "train_spec.npz"))
t = np.load(os.path.join(HERE, "features", "public_test_spec.npz"))
SEED = 185065
LP = dict(n_estimators=400, learning_rate=0.05, num_leaves=31, subsample=0.8, subsample_freq=1,
          colsample_bytree=0.5, class_weight="balanced", verbose=-1)
pl = np.mean([lgb.LGBMClassifier(**LP, random_state=SEED + k).fit(s["X"], s["y"]).predict_proba(t["X"])[:, 1]
              for k in range(5)], 0)
w = np.where(s["y"] == 1, 1.0, (s["y"] == 1).sum() / (s["y"] == 0).sum())
pc = CatBoostClassifier(iterations=1500, learning_rate=0.05, depth=6, verbose=0, random_seed=SEED,
                        allow_writing_files=False, thread_count=4).fit(s["X"], s["y"], sample_weight=w).predict_proba(t["X"])[:, 1]
od = os.path.join(ROOT, "submissions_c/ens")
os.makedirs(od, exist_ok=True)
base = pd.read_csv(os.path.join(ROOT, "submissions_c/final/submission_seed_185065.csv")).score.values
for name, p in [("lgbm5", pl), ("catboost", pc), ("lgbm5_cat", (rankdata(pl) + rankdata(pc)) / (2 * len(pl)))]:
    pd.DataFrame({"idx": t["ids"], "score": p}).to_csv(f"{od}/submission_seed_{SEED}_{name}.csv", index=False)
    print(name, "корреляция рангов с 98.46-сабмитом:", round(float(np.corrcoef(rankdata(p), rankdata(base))[0, 1]), 3), flush=True)
