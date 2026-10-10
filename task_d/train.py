"""Задача D — обучение финального ансамбля.

Метки train сильно зашумлены (CV RMSE ~10.5, на тесте ~1.6), поэтому главный резерв — снижение
разброса усреднением. Лучше всего на LB сработала смесь моделей РАЗНОЙ сложности:
три уровня, на каждом CatBoost x5 seed + LightGBM(+признаки «покрытия») x5 seed, всё усредняется.

  уровень   CatBoost depth   LightGBM num_leaves / min_child / lambda
  base      6                8  / 40 / 5
  mid       7                16 / 30 / 1
  sharp     8                31 / 20 / 1

Число деревьев каждой модели — по early stopping на 5-fold CV (KFold random_state=0), x1.1.

Проверенные гипотезы (public LB):
  LGBM 71.64 | LGBM на logit-цели 62.16 | ridge на logit 54.39 | константа 0
  LGBM8+FE (5 seed) 72.49 | CatBoost 72.55 | их среднее 75.62 | CatBoost x5 + LGBM x5 (base) 76.27
  + CatBoost+FE / + RandomForest: 74.22 / 70.31 | + XGBoost по трети: 76.22
  взвешенный МНК 1/sigma^2: 71.14 | «сглаженные» (lr 0.015, extra_trees): 74.46 | топ-30 признаков: 74.21
  без групп признаков: survey 70.13, regional 74.93, claims 76.03, aggregates 38.08
  sharp (d8/31): 76.48 | sharper (d10/63): 73.84 | base+sharp: 77.09 | base+mid+sharp: 77.25 <- финал

    python task_d/train.py [--seed N]
"""
import argparse
import json
import os
import sys

import lightgbm as lgb
import numpy as np
import pandas as pd
from catboost import CatBoostRegressor
from sklearn.model_selection import KFold

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from common import CAT_FEATURES, TARGET, load, make_features  # noqa: E402

LEVELS = {
    "base":  dict(cat=dict(depth=6), lgbm=dict(num_leaves=8, min_child_samples=40, reg_lambda=5)),
    "mid":   dict(cat=dict(depth=7), lgbm=dict(num_leaves=16, min_child_samples=30, reg_lambda=1)),
    "sharp": dict(cat=dict(depth=8), lgbm=dict(num_leaves=31, min_child_samples=20, reg_lambda=1)),
}
CONFIG = dict(n_seeds=5, levels=LEVELS, cat_lr=0.03, cat_es=dict(base=200, mid=300, sharp=300),
              lgbm_common=dict(learning_rate=0.02, subsample=0.8, subsample_freq=1, colsample_bytree=0.5))


def prep(df, ref, extra, kind):
    X = make_features(df, extra)
    if kind == "cat":
        for c in CAT_FEATURES:
            X[c] = X[c].astype(str)
    elif kind == "lgbm":
        for c in CAT_FEATURES:
            X[c] = pd.Categorical(X[c], categories=sorted(ref[c].dropna().unique()))
    else:  # rf/прочие: one-hot + заполнение пропусков
        X = pd.get_dummies(X, columns=CAT_FEATURES, dtype=float).fillna(-1)
    return X


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
    Xc, Xl = prep(tr, tr, False, "cat"), prep(tr, tr, True, "lgbm")
    kf = list(KFold(5, shuffle=True, random_state=0).split(tr))
    meta = dict(seed=seed, config=CONFIG, models={}, columns={"cat": list(Xc.columns), "lgbm": list(Xl.columns)})

    for lvl, p in LEVELS.items():
        cp = dict(learning_rate=CONFIG["cat_lr"], **p["cat"])
        es = CONFIG["cat_es"][lvl]
        its = [CatBoostRegressor(iterations=8000 if es == 300 else 5000, **cp, verbose=0, cat_features=CAT_FEATURES,
                                 early_stopping_rounds=es, allow_writing_files=False)
               .fit(Xc.iloc[a], y[a], eval_set=(Xc.iloc[b], y[b])).tree_count_ for a, b in kf]
        nc = int(np.mean(its) * 1.1)
        cat_files = []
        for k in range(CONFIG["n_seeds"]):
            m = CatBoostRegressor(iterations=nc, **cp, verbose=0, cat_features=CAT_FEATURES, random_seed=seed + k,
                                  allow_writing_files=False).fit(Xc, y)
            cat_files.append(f"{lvl}_cat_{k}.cbm")
            m.save_model(os.path.join(args.out_dir, cat_files[-1]))

        lp = dict(**CONFIG["lgbm_common"], **p["lgbm"], verbose=-1)
        its = [lgb.LGBMRegressor(n_estimators=8000 if lvl != "base" else 5000, **lp)
               .fit(Xl.iloc[a], y[a], eval_set=[(Xl.iloc[b], y[b])],
                    callbacks=[lgb.early_stopping(200, verbose=False)]).best_iteration_ for a, b in kf]
        nl = int(np.mean(its) * 1.1)
        lgbm_files = []
        for k in range(CONFIG["n_seeds"]):
            m = lgb.LGBMRegressor(n_estimators=nl, **lp, random_state=seed + k).fit(Xl, y)
            lgbm_files.append(f"{lvl}_lgbm_{k}.txt")
            m.booster_.save_model(os.path.join(args.out_dir, lgbm_files[-1]))
        meta["models"][lvl] = dict(cat=cat_files, lgbm=lgbm_files, cat_trees=nc, lgbm_trees=nl)
        print(f"{lvl}: CatBoost {nc} деревьев x{CONFIG['n_seeds']}, LightGBM {nl} деревьев x{CONFIG['n_seeds']}",
              flush=True)
    json.dump(meta, open(os.path.join(args.out_dir, "meta.json"), "w"), ensure_ascii=False, indent=2)


if __name__ == "__main__":
    main()
