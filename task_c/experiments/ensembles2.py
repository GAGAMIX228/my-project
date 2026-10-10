"""C: CatBoost x3 seed (depth 6 и 8) + LightGBM x5, смесь рангов."""
import os

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
r = lambda v: rankdata(v) / len(v)  # noqa: E731
od = os.path.join(ROOT, "submissions_c/ens")
for depth in (6, 8):
    pc = np.mean([CatBoostClassifier(iterations=1500, learning_rate=0.05, depth=depth, verbose=0, random_seed=SEED + k,
                                     allow_writing_files=False, thread_count=4)
                  .fit(s["X"], s["y"], sample_weight=w).predict_proba(t["X"])[:, 1] for k in range(3)], 0)
    np.save(f"{od}/cat_d{depth}_x3.npy", pc)
    for name, p in [(f"cat{depth}x3", pc), (f"lgbm5_cat{depth}x3", (r(pl) + r(pc)) / 2)]:
        pd.DataFrame({"idx": t["ids"], "score": p}).to_csv(f"{od}/submission_seed_{SEED}_{name}.csv", index=False)
    print("depth", depth, "готово", flush=True)
