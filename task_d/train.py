"""Задача D — обучение финального ансамбля. Метки train сильно зашумлены (CV RMSE ~10.5, а на
чистом тесте ~2), поэтому главный резерв — снижение разброса моделей усреднением:
  * CatBoost depth=6 (исходные признаки и + признаки «покрытия»), несколько seed'ов;
  * LightGBM num_leaves=8 + признаки «покрытия», несколько seed'ов;
  * RandomForest (большой min_samples_leaf — сам усредняет шум).
Итог — среднее групп моделей. Число деревьев бустингов — по early stopping на 5-fold CV.

Public LB (проверенные гипотезы):
  LGBM 71.64 | LGBM на logit-цели 62.16 | ridge на logit 54.39 | константа 0
  LGBM8+FE (5 seed) 72.49 | CatBoost 72.55 | их среднее 75.62
  CatBoost x5 + CatBoost+FE x5 + LGBM+FE x5: 74.22; + RandomForest: 70.31 (RF вредит)
  CatBoost x5 + LGBM+FE x5 пополам: 76.27  <- финал

    python task_d/train.py [--seed N]
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
from sklearn.ensemble import RandomForestRegressor
from sklearn.model_selection import KFold

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from common import CAT_FEATURES, TARGET, load, make_features  # noqa: E402

CONFIG = dict(
    n_seeds=5,
    groups=["catboost", "lgbm_fe"],  # catboost_fe и rf_fe проверены и отключены (см. docstring)
    catboost=dict(learning_rate=0.03, depth=6),
    lgbm=dict(learning_rate=0.02, num_leaves=8, min_child_samples=40, subsample=0.8, subsample_freq=1,
              colsample_bytree=0.5, reg_lambda=5),
    rf=dict(n_estimators=500, min_samples_leaf=20, max_features=0.3),
)


def prep(df, ref, extra, kind):
    X = make_features(df, extra)
    if kind == "cat":
        for c in CAT_FEATURES:
            X[c] = X[c].astype(str)
    elif kind == "lgbm":
        for c in CAT_FEATURES:
            X[c] = pd.Categorical(X[c], categories=sorted(ref[c].dropna().unique()))
    else:  # rf: one-hot + заполнение пропусков
        X = pd.get_dummies(X, columns=CAT_FEATURES, dtype=float)
        X = X.fillna(-1)
    return X


def n_trees(make, X, y):
    its = []
    for a, b in KFold(5, shuffle=True, random_state=0).split(X):
        its.append(make(a, b))
    return int(np.mean(its) * 1.1)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data-dir", default=os.path.join(HERE, "data"))
    ap.add_argument("--out-dir", default=os.path.join(HERE, "weights"))
    ap.add_argument("--seed", type=int, default=None)
    args = ap.parse_args()
    seed = args.seed if args.seed is not None else int(np.random.SeedSequence().entropy % 1_000_000)
    print(f"SEED = {seed}", flush=True)
    os.makedirs(args.out_dir, exist_ok=True)
    for f in os.listdir(args.out_dir):
        os.remove(os.path.join(args.out_dir, f))
    tr = load(os.path.join(args.data_dir, "hard_train.csv"))
    y = tr[TARGET].values
    meta = dict(seed=seed, config=CONFIG, models={}, columns={})

    for g in CONFIG["groups"]:
        extra = g.endswith("_fe")
        if g.startswith("catboost"):
            X = prep(tr, tr, extra, "cat")
            n = n_trees(lambda a, b: CatBoostRegressor(iterations=5000, **CONFIG["catboost"], verbose=0,
                        cat_features=CAT_FEATURES, early_stopping_rounds=200, allow_writing_files=False)
                        .fit(X.iloc[a], y[a], eval_set=(X.iloc[b], y[b])).tree_count_, X, y)
            files = []
            for k in range(CONFIG["n_seeds"]):
                m = CatBoostRegressor(iterations=n, **CONFIG["catboost"], verbose=0, cat_features=CAT_FEATURES,
                                      random_seed=seed + k, allow_writing_files=False).fit(X, y)
                files.append(f"{g}_{k}.cbm")
                m.save_model(os.path.join(args.out_dir, files[-1]))
        elif g.startswith("lgbm"):
            X = prep(tr, tr, extra, "lgbm")
            n = n_trees(lambda a, b: lgb.LGBMRegressor(n_estimators=5000, **CONFIG["lgbm"], verbose=-1)
                        .fit(X.iloc[a], y[a], eval_set=[(X.iloc[b], y[b])],
                             callbacks=[lgb.early_stopping(200, verbose=False)]).best_iteration_, X, y)
            files = []
            for k in range(CONFIG["n_seeds"]):
                m = lgb.LGBMRegressor(n_estimators=n, **CONFIG["lgbm"], verbose=-1, random_state=seed + k).fit(X, y)
                files.append(f"{g}_{k}.txt")
                m.booster_.save_model(os.path.join(args.out_dir, files[-1]))
        else:
            X = prep(tr, tr, extra, "rf")
            n = CONFIG["rf"]["n_estimators"]
            m = RandomForestRegressor(**CONFIG["rf"], n_jobs=-1, random_state=seed).fit(X, y)
            files = [f"{g}.joblib"]
            joblib.dump(m, os.path.join(args.out_dir, files[0]), compress=3)
        meta["models"][g] = dict(files=files, trees=n, extra=extra)
        meta["columns"][g] = list(X.columns)
        print(f"{g}: {len(files)} моделей по {n} деревьев", flush=True)
    json.dump(meta, open(os.path.join(args.out_dir, "meta.json"), "w"), ensure_ascii=False, indent=2)


if __name__ == "__main__":
    main()
