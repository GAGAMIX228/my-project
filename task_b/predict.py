"""Задача B — предсказание без обучения: читает task_b/weights и пишет submission_seed_{SEED}.csv.

    python task_b/predict.py --test task_b/data/public_test.csv
    python task_b/predict.py --test task_b/data/private_test.csv --out-dir submissions_b
"""
import argparse
import json
import os
import sys

import joblib
import numpy as np
import pandas as pd
from catboost import CatBoostClassifier

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from common import ID, TARGET, add_pairs, load, make_features  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--test", default=os.path.join(HERE, "data", "public_test.csv"))
    ap.add_argument("--weights", default=os.path.join(HERE, "weights"))
    ap.add_argument("--out-dir", default=".")
    args = ap.parse_args()

    with open(os.path.join(args.weights, "meta.json")) as f:
        meta = json.load(f)
    df = load(args.test)
    X = make_features(df, extra=False)[meta["features"]]
    cfg = meta["config"]

    p_gam, p_cb = np.zeros(len(df)), np.zeros(len(df))
    for k in range(cfg["folds"]):
        gam = joblib.load(os.path.join(args.weights, f"gam_fold{k}.joblib"))
        Xg = add_pairs(X, meta["pair_stats"]) if cfg.get("gam_pairs") else X
        p_gam += gam.predict_proba(Xg)[:, 1] / cfg["folds"]
        cb = CatBoostClassifier()
        cb.load_model(os.path.join(args.weights, f"cb_fold{k}.cbm"))
        p_cb += cb.predict_proba(X)[:, 1] / cfg["folds"]
    proba = cfg["gam_weight"] * p_gam + (1 - cfg["gam_weight"]) * p_cb

    pred = (proba >= meta["threshold"]).astype(int)
    os.makedirs(args.out_dir, exist_ok=True)
    out = os.path.join(args.out_dir, f"submission_seed_{meta['seed']}.csv")
    pd.DataFrame({ID: df[ID], TARGET: pred}).to_csv(out, index=False)
    print(f"{out}: {len(pred)} строк, доля 1 = {pred.mean():.3f}, порог {meta['threshold']:.3f}")


if __name__ == "__main__":
    main()
