"""Задача B — обучение финальной модели: ансамбль 5 CatBoost (по фолдам) + порог под F1,
подобранный на OOF-вероятностях.

    python task_b/train.py                 # seed выбирается случайно и печатается
    python task_b/train.py --seed 12345    # воспроизведение

Результат: task_b/weights/fold{k}.cbm и task_b/weights/meta.json (seed, порог, признаки).
"""
import argparse
import json
import os
import sys

import numpy as np
from catboost import CatBoostClassifier
from sklearn.metrics import f1_score, roc_auc_score
from sklearn.model_selection import StratifiedKFold

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from common import CAT_FEATURES, TARGET, best_threshold, load, make_features, set_seed  # noqa: E402

# Конфиг финальной модели. Выбран по результатам task_b/results.csv.
CONFIG = dict(
    folds=5,
    extra_features=True,
    iterations=3000,
    learning_rate=0.03,
    depth=6,
    l2_leaf_reg=3,
    early_stopping_rounds=200,
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
    X = make_features(df, extra=CONFIG["extra_features"])
    cats = [c for c in CAT_FEATURES if c in X.columns]
    os.makedirs(args.out_dir, exist_ok=True)

    oof = np.zeros(len(df))
    skf = StratifiedKFold(CONFIG["folds"], shuffle=True, random_state=seed)
    trees = []
    for k, (tr, va) in enumerate(skf.split(X, y)):
        m = CatBoostClassifier(iterations=CONFIG["iterations"], learning_rate=CONFIG["learning_rate"],
                               depth=CONFIG["depth"], l2_leaf_reg=CONFIG["l2_leaf_reg"],
                               early_stopping_rounds=CONFIG["early_stopping_rounds"], eval_metric="AUC",
                               random_seed=seed + k, verbose=0, cat_features=cats)
        m.fit(X.iloc[tr], y[tr], eval_set=(X.iloc[va], y[va]))
        oof[va] = m.predict_proba(X.iloc[va])[:, 1]
        m.save_model(os.path.join(args.out_dir, f"fold{k}.cbm"))
        trees.append(m.tree_count_)
        print(f"fold {k}: деревьев {m.tree_count_}, AUC {roc_auc_score(y[va], oof[va]):.4f}")

    thr, f1 = best_threshold(y, oof)
    print(f"OOF AUC {roc_auc_score(y, oof):.4f}; F1@0.5 {f1_score(y, oof >= 0.5):.4f}; "
          f"F1@{thr:.3f} {f1:.4f}")
    meta = {"seed": seed, "threshold": thr, "oof_f1": f1, "oof_auc": roc_auc_score(y, oof),
            "folds": CONFIG["folds"], "trees": trees, "features": list(X.columns), "config": CONFIG}
    with open(os.path.join(args.out_dir, "meta.json"), "w") as f:
        json.dump(meta, f, ensure_ascii=False, indent=2)
    print(f"сохранено в {args.out_dir}")


if __name__ == "__main__":
    main()
