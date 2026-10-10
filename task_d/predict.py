"""Задача D — предсказание без обучения: среднее групп моделей из task_d/weights.

    python task_d/predict.py --test task_d/data/hard_test.csv [--groups catboost,lgbm_fe]
"""
import argparse
import json
import os
import sys

import joblib
import lightgbm as lgb
import numpy as np
import pandas as pd
from catboost import CatBoostRegressor

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from common import ID, TARGET, load  # noqa: E402
from train import prep  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--test", default=os.path.join(HERE, "data", "hard_test.csv"))
    ap.add_argument("--data-dir", default=os.path.join(HERE, "data"))
    ap.add_argument("--weights", default=os.path.join(HERE, "weights"))
    ap.add_argument("--groups", default="", help="подмножество групп через запятую (по умолчанию все)")
    ap.add_argument("--out-dir", default=".")
    args = ap.parse_args()
    meta = json.load(open(os.path.join(args.weights, "meta.json")))
    ref = load(os.path.join(args.data_dir, "hard_train.csv"))  # только для списка категорий
    te = load(args.test)
    groups = [g for g in args.groups.split(",") if g] or list(meta["models"])
    preds = {}
    for g in groups:
        info = meta["models"][g]
        kind = "cat" if g.startswith("catboost") else "lgbm" if g.startswith("lgbm") else "rf"
        X = prep(te, ref, info["extra"], kind).reindex(columns=meta["columns"][g], fill_value=0)
        ps = []
        for f in info["files"]:
            path = os.path.join(args.weights, f)
            if kind == "cat":
                m = CatBoostRegressor()
                m.load_model(path)
                ps.append(m.predict(X))
            elif kind == "lgbm":
                ps.append(lgb.Booster(model_file=path).predict(X))
            else:
                ps.append(joblib.load(path).predict(X))
        preds[g] = np.mean(ps, 0)
    p = np.clip(np.mean(list(preds.values()), 0), 0, 100)
    os.makedirs(args.out_dir, exist_ok=True)
    tag = "" if not args.groups else "_" + "-".join(groups)
    out = os.path.join(args.out_dir, f"submission_seed_{meta['seed']}{tag}.csv")
    pd.DataFrame({ID: te[ID], TARGET: p}).to_csv(out, index=False)
    print(out, {g: round(float(v.mean()), 2) for g, v in preds.items()})


if __name__ == "__main__":
    main()
