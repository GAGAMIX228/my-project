"""Задача B: журнал гипотез. Каждая модель оценивается одинаковым stratified 5-fold CV
(повторённым 3 раза с разными разбиениями — на 6000 строк шум одного разбиения велик).
Для каждой модели считаем F1 при пороге 0.5 и при пороге, подобранном на OOF
(честно: порог подбирается на одних фолдах OOF, проверяется на других).

    python task_b/run_experiments.py
    python task_b/run_experiments.py --only catboost_fe,lgbm_fe
"""
import argparse
import csv
import os
import sys
import time

import numpy as np
from sklearn.metrics import f1_score, roc_auc_score
from sklearn.model_selection import StratifiedKFold

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from common import CAT_FEATURES, TARGET, best_threshold, load, make_features  # noqa: E402


def fit_catboost(Xtr, ytr, Xva, yva, seed, **kw):
    from catboost import CatBoostClassifier
    params = dict(iterations=3000, learning_rate=0.03, depth=6, l2_leaf_reg=3, eval_metric="AUC",
                  random_seed=seed, verbose=0, early_stopping_rounds=200, thread_count=4)
    params.update(kw)
    cats = [c for c in CAT_FEATURES if c in Xtr.columns]
    m = CatBoostClassifier(**params, cat_features=cats)
    m.fit(Xtr, ytr, eval_set=(Xva, yva))
    return m.predict_proba(Xva)[:, 1], m.tree_count_


def fit_lgbm(Xtr, ytr, Xva, yva, seed, **kw):
    import lightgbm as lgb
    Xtr, Xva = Xtr.copy(), Xva.copy()
    for c in CAT_FEATURES:
        Xtr[c] = Xtr[c].astype("category")
        Xva[c] = Xva[c].astype(pd_cat(Xtr[c]))
    params = dict(n_estimators=3000, learning_rate=0.02, num_leaves=15, min_child_samples=30,
                  subsample=0.8, subsample_freq=1, colsample_bytree=0.7, reg_lambda=1.0,
                  random_state=seed, verbose=-1)
    params.update(kw)
    m = lgb.LGBMClassifier(**params)
    m.fit(Xtr, ytr, eval_set=[(Xva, yva)], eval_metric="auc",
          callbacks=[lgb.early_stopping(200, verbose=False)])
    return m.predict_proba(Xva)[:, 1], m.best_iteration_


def pd_cat(s):
    import pandas as pd
    return pd.CategoricalDtype(s.cat.categories)


def fit_logreg(Xtr, ytr, Xva, yva, seed, **kw):
    from sklearn.compose import ColumnTransformer
    from sklearn.impute import SimpleImputer
    from sklearn.linear_model import LogisticRegression
    from sklearn.pipeline import make_pipeline
    from sklearn.preprocessing import OneHotEncoder, StandardScaler
    num = [c for c in Xtr.columns if c not in CAT_FEATURES]
    pre = ColumnTransformer([
        ("num", make_pipeline(SimpleImputer(strategy="median", add_indicator=True), StandardScaler()), num),
        ("cat", OneHotEncoder(handle_unknown="ignore"), CAT_FEATURES)])
    m = make_pipeline(pre, LogisticRegression(C=0.5, max_iter=3000, class_weight="balanced"))
    m.fit(Xtr, ytr)
    return m.predict_proba(Xva)[:, 1], 0


def fit_gam(Xtr, ytr, Xva, yva, seed, n_knots=8, C=1.0, **kw):
    """GAM-подобная модель: сплайн по каждому числовому признаку + one-hot категорий,
    поверх — логистическая регрессия. Аддитивна в логит-пространстве."""
    from sklearn.compose import ColumnTransformer
    from sklearn.impute import SimpleImputer
    from sklearn.linear_model import LogisticRegression
    from sklearn.pipeline import make_pipeline
    from sklearn.preprocessing import OneHotEncoder, SplineTransformer, StandardScaler
    num = [c for c in Xtr.columns if c not in CAT_FEATURES]
    nan_cols = [c for c in num if Xtr[c].isna().any() or Xva[c].isna().any()]
    pre = ColumnTransformer([
        ("spl", make_pipeline(SimpleImputer(strategy="median"),
                              SplineTransformer(n_knots=n_knots, degree=3, knots="quantile",
                                                extrapolation="linear")), num),
        ("ind", make_pipeline(SimpleImputer(strategy="median", add_indicator=True)), nan_cols),
        ("cat", OneHotEncoder(handle_unknown="ignore"), CAT_FEATURES)])
    m = make_pipeline(pre, StandardScaler(with_mean=False), LogisticRegression(C=C, max_iter=5000))
    m.fit(Xtr, ytr)
    n_params = m[-1].coef_.size + 1
    return m.predict_proba(Xva)[:, 1], n_params


EXPERIMENTS = {
    "logreg":        (fit_logreg, False, {}, "Логрег (one-hot, медианы, стандартизация)"),
    "logreg_fe":     (fit_logreg, True, {}, "Логрег + сгенерированные признаки"),
    "lgbm":          (fit_lgbm, False, {}, "LightGBM, исходные признаки"),
    "lgbm_fe":       (fit_lgbm, True, {}, "LightGBM + сгенерированные признаки"),
    "catboost":      (fit_catboost, False, {}, "CatBoost, исходные признаки"),
    "catboost_fe":   (fit_catboost, True, {}, "CatBoost + сгенерированные признаки"),
    "catboost_d4":   (fit_catboost, True, {"depth": 4}, "CatBoost depth=4"),
    "catboost_d8":   (fit_catboost, True, {"depth": 8}, "CatBoost depth=8"),
    "gam":           (fit_gam, False, {}, "GAM: сплайны по признакам + логрег"),
    "gam_fe":        (fit_gam, True, {}, "GAM + сгенерированные признаки"),
    "gam_k12":       (fit_gam, True, {"n_knots": 12}, "GAM, 12 узлов сплайна"),
    "catboost_bal":  (fit_catboost, True, {"auto_class_weights": "Balanced"}, "CatBoost + веса классов"),
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data-dir", default=os.path.join(HERE, "data"))
    ap.add_argument("--only", default="")
    ap.add_argument("--repeats", type=int, default=3)
    ap.add_argument("--seed", type=int, default=20261010)
    args = ap.parse_args()

    df = load(os.path.join(args.data_dir, "train.csv"))
    y = df[TARGET].values
    print(f"train: {df.shape}, доля accepted=1: {y.mean():.3f}")
    names = [n for n in args.only.split(",") if n] or list(EXPERIMENTS)
    os.makedirs(os.path.join(HERE, "oof"), exist_ok=True)
    res_path = os.path.join(HERE, "results.csv")
    new_file = not os.path.exists(res_path)

    for name in names:
        fn, extra, kw, desc = EXPERIMENTS[name]
        X = make_features(df, extra=extra)
        t0 = time.time()
        f1_05, f1_thr, aucs, thrs, size = [], [], [], [], []
        oof_all = np.zeros((args.repeats, len(df)))
        for r in range(args.repeats):
            oof = np.zeros(len(df))
            skf = StratifiedKFold(5, shuffle=True, random_state=args.seed + r)
            for k, (tr, va) in enumerate(skf.split(X, y)):
                oof[va], n = fn(X.iloc[tr], y[tr], X.iloc[va], y[va], args.seed + 10 * r + k, **kw)
                size.append(n)
            oof_all[r] = oof
            aucs.append(roc_auc_score(y, oof))
            f1_05.append(f1_score(y, oof >= 0.5))
            # честная оценка порога: подбираем на половине OOF, проверяем на другой
            rng = np.random.default_rng(r)
            half = rng.permutation(len(y)) < len(y) // 2
            t1, _ = best_threshold(y[half], oof[half])
            t2, _ = best_threshold(y[~half], oof[~half])
            pred = np.where(half, oof >= t2, oof >= t1)
            f1_thr.append(f1_score(y, pred))
            thrs.append(best_threshold(y, oof)[0])
        np.save(os.path.join(HERE, "oof", f"{name}.npy"), oof_all)
        row = dict(name=name, description=desc, auc=round(np.mean(aucs), 4),
                   f1_at_05=round(np.mean(f1_05), 4), f1_tuned=round(np.mean(f1_thr), 4),
                   f1_tuned_std=round(np.std(f1_thr), 4), threshold=round(np.mean(thrs), 3),
                   size=int(np.mean(size)), minutes=round((time.time() - t0) / 60, 1), seed=args.seed)
        print(row, flush=True)
        with open(res_path, "a", newline="") as f:
            wr = csv.DictWriter(f, fieldnames=list(row))
            if new_file:
                wr.writeheader()
                new_file = False
            wr.writerow(row)


if __name__ == "__main__":
    main()
