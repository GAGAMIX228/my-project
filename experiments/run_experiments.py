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


def run_knn(X_tr, y_tr, X_va, seed, k=50):
    """Косинусный kNN с весами по сходству; эмбеддинги уже L2-нормированы по половинам."""
    import torch
    Xt, Xv = torch.from_numpy(X_tr), torch.from_numpy(X_va)
    proba = np.zeros((len(X_va), len(CLASSES)), dtype=np.float32)
    prior = np.bincount(y_tr, minlength=len(CLASSES)) / len(y_tr)
    for i in range(0, len(Xv), 2048):
        s, idx = (Xv[i:i + 2048] @ Xt.T).topk(k, dim=1)
        w = torch.exp((s - 2.0) * 10).numpy()  # 2.0 — максимум (две единичные половины)
        lab = y_tr[idx.numpy()]
        for c in range(len(CLASSES)):
            proba[i:i + 2048, c] = (w * (lab == c)).sum(1)
    proba /= prior  # снимаем перекос частот train
    return proba / proba.sum(1, keepdims=True), 0


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


def run_mlp(X_tr, y_tr, X_va, seed, y_va=None, l2=False, half=None, **kw):
    if half is not None:  # гипотеза: какая из двух половин эмбеддинга информативнее
        sl = slice(0, 1024) if half == 0 else slice(1024, 2048)
        X_tr, X_va = X_tr[:, sl], X_va[:, sl]
    pre = Preprocessor(l2=l2).fit(X_tr)
    model, ep, _ = train_mlp(pre.transform(X_tr), y_tr, pre.transform(X_va), y_va, seed=seed, **kw)
    return predict_proba_mlp(model, pre.transform(X_va)), count_params(model)


# Название -> (функция, kwargs, описание гипотезы)
EXPERIMENTS = {
    "logreg_plain":   (run_logreg, dict(balanced=False), "Линейная модель без учёта дисбаланса"),
    "logreg_bal":     (run_logreg, dict(balanced=True), "Логрег + class_weight=balanced"),
    "knn50":          (run_knn, dict(k=50), "Косинусный kNN, k=50"),
    "lgbm":           (run_lgbm, {}, "Градиентный бустинг на эмбеддингах"),
    "mlp_base":       (run_mlp, dict(cw_power=0.0, label_smoothing=0.0), "MLP 512-256 без весов классов"),
    "mlp_cw05":       (run_mlp, dict(cw_power=0.5), "MLP + веса sqrt(1/freq) + label smoothing"),
    "mlp_cw1":        (run_mlp, dict(cw_power=1.0), "MLP + веса 1/freq"),
    "mlp_l2":         (run_mlp, dict(cw_power=0.5, l2=True), "MLP + L2-нормализация эмбеддинга"),
    "mlp_half0":      (run_mlp, dict(cw_power=0.5, half=0), "MLP только на 1-й половине эмбеддинга (1024)"),
    "mlp_half1":      (run_mlp, dict(cw_power=0.5, half=1), "MLP только на 2-й половине эмбеддинга (1024)"),
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
    ap.add_argument("--eval-folds", type=int, default=0, help="оценивать только первые N фолдов (быстрый отбор)")
    ap.add_argument("--epochs", type=int, default=0, help="переопределить число эпох MLP")
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
        if fn is run_mlp and args.epochs:
            kw = {**kw, "epochs": args.epochs}
        t0 = time.time()
        oof = np.zeros((len(X), len(CLASSES)), dtype=np.float32)
        fold_f1 = []
        done = np.zeros(len(X), dtype=bool)
        for k, (tr, va) in enumerate(skf.split(X, y)):
            if args.eval_folds and k >= args.eval_folds:
                break
            done[va] = True
            extra = {"y_va": y[va]} if fn in (run_lgbm, run_mlp) else {}
            proba, n_params = fn(X[tr], y[tr], X[va], args.seed + k, **extra, **kw)
            oof[va] = proba
            fold_f1.append(macro_f1(y[va], proba.argmax(1)))
        f1_raw = macro_f1(y[done], oof[done].argmax(1))
        f1_tuned = cross_fitted_scaled_f1(oof[done], y[done], seed=args.seed)
        np.save(os.path.join(ROOT, "experiments", "oof", f"{name}.npy"), oof)
        row = dict(name=name, description=desc, cv_f1=round(f1_raw, 4),
                   cv_f1_std=round(float(np.std(fold_f1)), 4), cv_f1_tuned=round(f1_tuned, 4),
                   params=n_params, minutes=round((time.time() - t0) / 60, 1), seed=args.seed,
                   rows=int(done.sum()), epochs=kw.get("epochs", 40) if fn is run_mlp else "")
        print(row)
        with open(res_path, "a", newline="") as f:
            wr = csv.DictWriter(f, fieldnames=list(row))
            if new_file:
                wr.writeheader()
                new_file = False
            wr.writerow(row)


if __name__ == "__main__":
    main()
