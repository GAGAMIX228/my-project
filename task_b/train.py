"""Задача B — обучение финальной модели: смесь (пополам) двух ансамблей по 5 фолдам:
  * GAM — сплайны по признакам + логистическая регрессия (≈146 параметров на модель);
  * CatBoost depth=4.
Порог под F1 подбирается на OOF-вероятностях смеси.

    python task_b/train.py                 # seed выбирается случайно и печатается
    python task_b/train.py --seed 12345    # воспроизведение

Результат: task_b/weights/{gam,cb}_fold{k}.* и task_b/weights/meta.json.
"""
import argparse
import json
import os
import sys

import joblib
import numpy as np
from catboost import CatBoostClassifier
from sklearn.metrics import f1_score, roc_auc_score
from sklearn.model_selection import StratifiedKFold

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from common import (CAT_FEATURES, TARGET, add_pairs, best_threshold, build_gam, load,  # noqa: E402
                    make_features, pair_stats, set_seed)

# Конфиг финальной модели. Выбран по результатам task_b/results.csv:
# GAM k=3 — F1 0.959, CatBoost d4 — 0.950, смесь 50/50 — 0.961 (5-fold CV ×3); LB 96.18.
CONFIG = dict(
    folds=5,
    gam=dict(n_knots=3, degree=3, C=1.0),
    catboost=dict(iterations=3000, learning_rate=0.03, depth=4, l2_leaf_reg=3, early_stopping_rounds=200),
    gam_weight=0.5,
    gam_pairs=True,  # GAM + 4 попарных взаимодействия (CV 0.9589 -> 0.9613)
)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data-dir", default=os.path.join(HERE, "data"))
    ap.add_argument("--out-dir", default=os.path.join(HERE, "weights"))
    ap.add_argument("--seed", type=int, default=None)
    args = ap.parse_args()

    seed = args.seed if args.seed is not None else int(np.random.SeedSequence().entropy % 1_000_000)
    print(f"SEED = {seed}")
    set_seed(seed)

    df = load(os.path.join(args.data_dir, "train.csv"))
    y = df[TARGET].values
    X = make_features(df, extra=False)
    cats = [c for c in CAT_FEATURES if c in X.columns]
    stats = pair_stats(X)
    Xg = add_pairs(X, stats) if CONFIG["gam_pairs"] else X
    os.makedirs(args.out_dir, exist_ok=True)
    for f in os.listdir(args.out_dir):  # убираем веса прошлых версий
        os.remove(os.path.join(args.out_dir, f))

    oof_gam, oof_cb = np.zeros(len(df)), np.zeros(len(df))
    skf = StratifiedKFold(CONFIG["folds"], shuffle=True, random_state=seed)
    n_params, trees = 0, []
    for k, (tr, va) in enumerate(skf.split(X, y)):
        gam = build_gam(list(Xg.columns), **CONFIG["gam"]).fit(Xg.iloc[tr], y[tr])
        oof_gam[va] = gam.predict_proba(Xg.iloc[va])[:, 1]
        joblib.dump(gam, os.path.join(args.out_dir, f"gam_fold{k}.joblib"))
        n_params += gam[-1].coef_.size + 1

        cb = CatBoostClassifier(**CONFIG["catboost"], eval_metric="AUC", random_seed=seed + k,
                                verbose=0, cat_features=cats, allow_writing_files=False)
        cb.fit(X.iloc[tr], y[tr], eval_set=(X.iloc[va], y[va]))
        oof_cb[va] = cb.predict_proba(X.iloc[va])[:, 1]
        cb.save_model(os.path.join(args.out_dir, f"cb_fold{k}.cbm"))
        trees.append(cb.tree_count_)
        print(f"fold {k}: F1@0.5 GAM {f1_score(y[va], oof_gam[va] >= .5):.4f}, "
              f"CatBoost {f1_score(y[va], oof_cb[va] >= .5):.4f} ({cb.tree_count_} деревьев)")

    w = CONFIG["gam_weight"]
    oof = w * oof_gam + (1 - w) * oof_cb
    thr, f1 = best_threshold(y, oof)
    print(f"OOF: GAM {f1_score(y, oof_gam >= .5):.4f}, CatBoost {f1_score(y, oof_cb >= .5):.4f}, "
          f"смесь F1@0.5 {f1_score(y, oof >= .5):.4f}, F1@{thr:.3f} {f1:.4f}, AUC {roc_auc_score(y, oof):.4f}")
    meta = {"seed": seed, "threshold": thr, "oof_f1": f1, "oof_f1_at_05": f1_score(y, oof >= .5),
            "oof_auc": roc_auc_score(y, oof), "gam_params_total": int(n_params), "cb_trees": trees,
            "features": list(X.columns), "pair_stats": stats, "config": CONFIG}
    with open(os.path.join(args.out_dir, "meta.json"), "w") as f:
        json.dump(meta, f, ensure_ascii=False, indent=2)
    print(f"сохранено в {args.out_dir}")


if __name__ == "__main__":
    main()
