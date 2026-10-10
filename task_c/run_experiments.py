"""Задача C — журнал гипотез. Валидация «leave-one-attack-out»: в тесте синтезаторы другие,
поэтому обучаемся на 5 из 6 атак (A01–A06) и меряем ROC-AUC на 6-й, которую модель не видела.
Bonafide делится по говорящим (разные говорящие в train/val). Итог — среднее AUC по 6 разбиениям
и худшее AUC (насколько модель ломается на «чужом» синтезаторе).

    python task_c/run_experiments.py --feats spec
    python task_c/run_experiments.py --feats wavlm --only logreg_l3
"""
import argparse
import csv
import os
import time

import numpy as np
from sklearn.metrics import roc_auc_score

HERE = os.path.dirname(os.path.abspath(__file__))


def load(feats, layers=None):
    d = np.load(os.path.join(HERE, "features", f"train_{feats}.npz"), allow_pickle=True)
    X = d["X"].astype(np.float32)
    if X.ndim == 3:  # (n, слои, 768)
        X = X[:, layers].reshape(len(X), -1) if layers is not None else X.reshape(len(X), -1)
    return X, d["y"], d["attack"], d["speaker"]


def splits(y, attack, speaker, seed=0):
    """Для каждой атаки: val = эта атака + bonafide ~20% говорящих; train = остальное."""
    rng = np.random.default_rng(seed)
    bona_spk = np.unique(speaker[y == 0])
    for a in sorted(set(attack[y == 1])):
        val_spk = set(rng.choice(bona_spk, max(1, len(bona_spk) // 5), replace=False))
        is_val_bona = (y == 0) & np.isin(speaker, list(val_spk))
        va = (attack == a) | is_val_bona
        tr = ~va & ~((y == 1) & np.isin(speaker, list(val_spk)))  # без утечки говорящих
        yield a, np.where(tr)[0], np.where(va)[0]


def m_logreg(C=1.0):
    from sklearn.linear_model import LogisticRegression
    from sklearn.pipeline import make_pipeline
    from sklearn.preprocessing import StandardScaler
    return make_pipeline(StandardScaler(), LogisticRegression(C=C, max_iter=3000, class_weight="balanced"))


def m_lgbm():
    import lightgbm as lgb
    return lgb.LGBMClassifier(n_estimators=400, learning_rate=0.05, num_leaves=31, subsample=0.8,
                              subsample_freq=1, colsample_bytree=0.5, class_weight="balanced", verbose=-1)


def m_svm():
    from sklearn.pipeline import make_pipeline
    from sklearn.preprocessing import StandardScaler
    from sklearn.svm import SVC
    return make_pipeline(StandardScaler(), SVC(C=1.0, kernel="rbf", class_weight="balanced", probability=False))


def m_gmm_like():
    """LDA — линейный дискриминант, близок к классическому GMM-бэкенду ASVspoof."""
    from sklearn.discriminant_analysis import LinearDiscriminantAnalysis
    from sklearn.pipeline import make_pipeline
    from sklearn.preprocessing import StandardScaler
    return make_pipeline(StandardScaler(), LinearDiscriminantAnalysis(solver="lsqr", shrinkage="auto"))


def score(m, X):
    return m.decision_function(X) if hasattr(m, "decision_function") else m.predict_proba(X)[:, 1]


EXPERIMENTS = {
    # name: (model_fn, feats, layers, описание)
    "spec_logreg":   (m_logreg, "spec", None, "LFCC/MFCC-статистики + логрег"),
    "spec_lda":      (m_gmm_like, "spec", None, "LFCC/MFCC-статистики + LDA"),
    "spec_lgbm":     (m_lgbm, "spec", None, "LFCC/MFCC-статистики + LightGBM"),
    "wavlm_all_lr":  (lambda: m_logreg(0.1), "wavlm", None, "WavLM: все 13 слоёв + логрег"),
    "wavlm_l0_lr":   (lambda: m_logreg(0.1), "wavlm", [0], "WavLM: слой 0 (CNN-признаки) + логрег"),
    "wavlm_l3_lr":   (lambda: m_logreg(0.1), "wavlm", [3], "WavLM: слой 3 + логрег"),
    "wavlm_l6_lr":   (lambda: m_logreg(0.1), "wavlm", [6], "WavLM: слой 6 + логрег"),
    "wavlm_l9_lr":   (lambda: m_logreg(0.1), "wavlm", [9], "WavLM: слой 9 + логрег"),
    "wavlm_l12_lr":  (lambda: m_logreg(0.1), "wavlm", [12], "WavLM: слой 12 + логрег"),
    "wavlm_l1_5_lr": (lambda: m_logreg(0.1), "wavlm", [1, 2, 3, 4, 5], "WavLM: слои 1-5 + логрег"),
    "wavlm_l3_svm":  (m_svm, "wavlm", [3], "WavLM: слой 3 + SVM (RBF)"),
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    args = ap.parse_args()
    names = [n for n in args.only.split(",") if n] or list(EXPERIMENTS)
    res_path = os.path.join(HERE, "results.csv")
    new_file = not os.path.exists(res_path)
    for name in names:
        fn, feats, layers, desc = EXPERIMENTS[name]
        if not os.path.exists(os.path.join(HERE, "features", f"train_{feats}.npz")):
            print(f"{name}: нет признаков {feats}, пропуск")
            continue
        X, y, attack, speaker = load(feats, layers)
        t0, per = time.time(), {}
        for a, tr, va in splits(y, attack, speaker):
            m = fn().fit(X[tr], y[tr])
            per[a] = roc_auc_score(y[va], score(m, X[va]))
        row = dict(name=name, description=desc, mean_auc=round(np.mean(list(per.values())), 4),
                   min_auc=round(min(per.values()), 4),
                   per_attack=" ".join(f"{a}:{v:.3f}" for a, v in per.items()),
                   n_train=len(y), minutes=round((time.time() - t0) / 60, 1))
        print(row, flush=True)
        with open(res_path, "a", newline="") as f:
            wr = csv.DictWriter(f, fieldnames=list(row))
            if new_file:
                wr.writeheader()
                new_file = False
            wr.writerow(row)


if __name__ == "__main__":
    main()
