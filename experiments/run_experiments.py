"""Журнал гипотез: каждая гипотеза оценивается одинаковым stratified k-fold CV на train.

Запуск:
    python experiments/run_experiments.py --data-dir data
    python experiments/run_experiments.py --data-dir data --only mlp_base,mlp_cw05

Результаты дописываются в experiments/results.csv, OOF-вероятности — в experiments/oof/.
"""
import argparse
import csv
import os
import sys
import time

import numpy as np
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import StratifiedKFold

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)
from src.common import (CLASSES, Preprocessor, class_weights, count_params,  # noqa: E402
                        cross_fitted_scaled_f1, encode_targets, load_npz, macro_f1,
                        predict_proba_mlp, set_seed, train_mlp)


def run_logreg(X_tr, y_tr, X_va, seed, C=1.0, balanced=True):
    pre = Preprocessor().fit(X_tr)
    m = LogisticRegression(C=C, max_iter=2000, class_weight="balanced" if balanced else None,
                           random_state=seed)
    m.fit(pre.transform(X_tr), y_tr)
    n_params = m.coef_.size + m.intercept_.size
    return m.predict_proba(pre.transform(X_va)), n_params


def run_lgbm(X_tr, y_tr, X_va, seed, y_va=None):
    import lightgbm as lgb
    w = class_weights(y_tr, 0.5)[y_tr]
    m = lgb.LGBMClassifier(n_estimators=3000, learning_rate=0.05, num_leaves=63,
                           subsample=0.8, subsample_freq=1, colsample_bytree=0.3,
                           reg_lambda=1.0, random_state=seed, verbose=-1, n_jobs=-1)
    m.fit(X_tr, y_tr, sample_weight=w, eval_set=[(X_va, y_va)],
          callbacks=[lgb.early_stopping(100, verbose=False)])
    n_nodes = int(m.booster_.trees_to_dataframe().shape[0])
    return m.predict_proba(X_va), n_nodes


def run_mlp(X_tr, y_tr, X_va, seed, y_va=None, l2=False, **kw):
    pre = Preprocessor(l2=l2).fit(X_tr)
    model, ep, _ = train_mlp(pre.transform(X_tr), y_tr, pre.transform(X_va), y_va, seed=seed, **kw)
    return predict_proba_mlp(model, pre.transform(X_va)), count_params(model)


# Название -> (функция, kwargs, описание гипотезы)
EXPERIMENTS = {
    "logreg_plain":   (run_logreg, dict(balanced=False), "Линейная модель без учёта дисбаланса"),
    "logreg_bal":     (run_logreg, dict(balanced=True), "Логрег + class_weight=balanced"),
    "lgbm":           (run_lgbm, {}, "Градиентный бустинг на эмбеддингах"),
    "mlp_base":       (run_mlp, dict(cw_power=0.0, label_smoothing=0.0), "MLP 512-256 без весов классов"),
    "mlp_cw05":       (run_mlp, dict(cw_power=0.5), "MLP + веса sqrt(1/freq) + label smoothing"),
    "mlp_cw1":        (run_mlp, dict(cw_power=1.0), "MLP + веса 1/freq"),
    "mlp_l2":         (run_mlp, dict(cw_power=0.5, l2=True), "MLP + L2-нормализация эмбеддинга"),
    "mlp_small":      (run_mlp, dict(cw_power=0.5, hidden=(256,)), "Маленький MLP, 1 скрытый слой 256"),
    "mlp_wide":       (run_mlp, dict(cw_power=0.5, hidden=(1024, 512), dropout=0.4), "Широкий MLP 1024-512"),
    "mlp_mixup":      (run_mlp, dict(cw_power=0.5, mixup=0.4), "MLP + mixup(0.4)"),
    "mlp_drop05":     (run_mlp, dict(cw_power=0.5, dropout=0.5), "MLP + dropout 0.5"),
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data-dir", default=os.path.join(ROOT, "data"))
    ap.add_argument("--only", default="", help="через запятую; пусто = все")
    ap.add_argument("--folds", type=int, default=5)
    ap.add_argument("--seed", type=int, default=20261009)
    ap.add_argument("--max-rows", type=int, default=0, help="подвыборка для быстрых проверок")
    args = ap.parse_args()

    X, y = load_npz(os.path.join(args.data_dir, "train.npz"))
    y = encode_targets(y)
    if args.max_rows:
        set_seed(args.seed)
        idx = np.random.permutation(len(X))[:args.max_rows]
        X, y = X[idx], y[idx]
    print(f"train: {X.shape}, классы: {dict(zip(CLASSES, np.bincount(y)))}")

    names = [n for n in args.only.split(",") if n] or list(EXPERIMENTS)
    os.makedirs(os.path.join(ROOT, "experiments", "oof"), exist_ok=True)
    res_path = os.path.join(ROOT, "experiments", "results.csv")
    new_file = not os.path.exists(res_path)

    skf = StratifiedKFold(n_splits=args.folds, shuffle=True, random_state=args.seed)
    for name in names:
        fn, kw, desc = EXPERIMENTS[name]
        t0 = time.time()
        oof = np.zeros((len(X), len(CLASSES)), dtype=np.float32)
        fold_f1 = []
        for k, (tr, va) in enumerate(skf.split(X, y)):
            extra = {"y_va": y[va]} if fn is not run_logreg else {}
            proba, n_params = fn(X[tr], y[tr], X[va], args.seed + k, **extra, **kw)
            oof[va] = proba
            fold_f1.append(macro_f1(y[va], proba.argmax(1)))
        f1_raw = macro_f1(y, oof.argmax(1))
        f1_tuned = cross_fitted_scaled_f1(oof, y, seed=args.seed)
        np.save(os.path.join(ROOT, "experiments", "oof", f"{name}.npy"), oof)
        row = dict(name=name, description=desc, cv_f1=round(f1_raw, 4),
                   cv_f1_std=round(float(np.std(fold_f1)), 4), cv_f1_tuned=round(f1_tuned, 4),
                   params=n_params, minutes=round((time.time() - t0) / 60, 1), seed=args.seed,
                   rows=len(X))
        print(row)
        with open(res_path, "a", newline="") as f:
            wr = csv.DictWriter(f, fieldnames=list(row))
            if new_file:
                wr.writeheader()
                new_file = False
            wr.writerow(row)


if __name__ == "__main__":
    main()
