"""Задача D — предсказание без обучения: среднее по уровням сложности (base, mid, sharp),
на каждом — среднее CatBoost x5 и LightGBM x5 пополам.

    python task_d/predict.py --test task_d/data/hard_test.csv
"""
import argparse
import json
import os
import sys

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
    ap.add_argument("--out-dir", default=".")
    args = ap.parse_args()
    meta = json.load(open(os.path.join(args.weights, "meta.json")))
    cats_path = os.path.join(args.weights, "categories.json")  # список категорий train (для LightGBM)
    if os.path.exists(cats_path):
        ref = pd.DataFrame({c: pd.Series(v) for c, v in json.load(open(cats_path)).items()})
    else:
        ref = load(os.path.join(args.data_dir, "hard_train.csv"))
    te = load(args.test)
    Xc = prep(te, ref, False, "cat")[meta["columns"]["cat"]]
    Xl = prep(te, ref, True, "lgbm")[meta["columns"]["lgbm"]]
    levels = []
    for lvl, info in meta["models"].items():
        pc = []
        for f in info["cat"]:
            m = CatBoostRegressor()
            m.load_model(os.path.join(args.weights, f))
            pc.append(m.predict(Xc))
        pl = [lgb.Booster(model_file=os.path.join(args.weights, f)).predict(Xl) for f in info["lgbm"]]
        levels.append(np.clip((np.mean(pc, 0) + np.mean(pl, 0)) / 2, 0, 100))
    p = np.mean(levels, 0)
    os.makedirs(args.out_dir, exist_ok=True)
    out = os.path.join(args.out_dir, f"submission_seed_{meta['seed']}.csv")
    pd.DataFrame({ID: te[ID], TARGET: p}).to_csv(out, index=False)
    print(out, "уровней:", len(levels))


if __name__ == "__main__":
    main()
