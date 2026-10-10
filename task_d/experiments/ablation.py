"""Гипотеза D: в метках train есть систематическая примесь, связанная с частью признаков
(ridge лучше LGBM на CV, но сильно хуже на LB). Убираем по одной группе признаков из финального
ансамбля (CatBoost + LightGBM+FE, по 3 seed) и сравниваем на LB."""
import os
import sys
import warnings

import lightgbm as lgb
import numpy as np
import pandas as pd
from catboost import CatBoostRegressor

warnings.filterwarnings("ignore")
HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from common import CAT_FEATURES, TARGET, load  # noqa: E402
from train import prep  # noqa: E402

GROUPS = {
    "survey": ["customer_loyalty", "marketing_response", "health_index", "risk_tolerance"],
    "regional": ["regional_risk", "crime_rate", "natural_disaster_risk", "cyber_risk"],
    "claims": ["number_of_claims", "claim_frequency", "average_claim_cost", "fraud_flag"],
    "aggregates": ["digital_behavior_score", "insurance_products", "active_policies", "coverage_share",
                   "policy_ratio"],
}
tr = load(os.path.join(HERE, "data", "hard_train.csv"))
te = load(os.path.join(HERE, "data", "hard_test.csv"))
y = tr[TARGET].values
SEED, NS = 352773, 3
LP = dict(learning_rate=0.02, num_leaves=8, min_child_samples=40, subsample=0.8, subsample_freq=1,
          colsample_bytree=0.5, reg_lambda=5, verbose=-1)
Xc0, Xct0 = prep(tr, tr, False, "cat"), prep(te, tr, False, "cat")
Xl0, Xlt0 = prep(tr, tr, True, "lgbm"), prep(te, tr, True, "lgbm")
best = pd.read_csv(os.path.join(ROOT, "submissions_d/final/submission_seed_352773.csv")).protection_score.values
for g, cols in GROUPS.items():
    dc = [c for c in Xc0.columns if c not in cols]
    dl = [c for c in Xl0.columns if c not in cols]
    pc = np.mean([CatBoostRegressor(iterations=867, learning_rate=0.03, depth=6, verbose=0,
                                    cat_features=[c for c in CAT_FEATURES if c in dc], random_seed=SEED + k,
                                    allow_writing_files=False).fit(Xc0[dc], y).predict(Xct0[dc]) for k in range(NS)], 0)
    pl = np.mean([lgb.LGBMRegressor(n_estimators=1068, **LP, random_state=SEED + k).fit(Xl0[dl], y).predict(Xlt0[dl])
                  for k in range(NS)], 0)
    p = np.clip((pc + pl) / 2, 0, 100)
    out = os.path.join(ROOT, f"submissions_d/ablation/submission_seed_{SEED}_no_{g}.csv")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    pd.DataFrame({"customer_id": te.customer_id, "protection_score": p}).to_csv(out, index=False)
    print(f"без {g}: RMSE к сабмиту 76.27 = {np.sqrt(np.mean((p - best) ** 2)):.2f} -> {out}", flush=True)
