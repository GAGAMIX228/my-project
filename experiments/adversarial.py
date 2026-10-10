"""Adversarial validation: насколько train отличается от public_test и какие примеры train
больше всего похожи на тест.

Логрег учится отличать train (0) от теста (1). Для каждого примера train считается
out-of-fold вероятность «это тест» -> experiments/adv_scores.npy. Самые тестоподобные
примеры train используются как валидация, имитирующая лидерборд
(`run_experiments.py --adv-val 0.2`).

    python experiments/adversarial.py
"""
import os
import sys

import numpy as np
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import roc_auc_score
from sklearn.model_selection import StratifiedKFold

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)
from src.common import load_npz  # noqa: E402

X, _ = load_npz(os.path.join(ROOT, "data", "train.npz"))
T, _ = load_npz(os.path.join(ROOT, "data", "public_test.npz"))
A = np.vstack([X, T])
d = np.r_[np.zeros(len(X)), np.ones(len(T))]
A = (A - A.mean(0)) / (A.std(0) + 1e-6)

oof = np.zeros(len(A))
for k, (tr, va) in enumerate(StratifiedKFold(5, shuffle=True, random_state=0).split(A, d)):
    m = LogisticRegression(C=0.1, max_iter=1000, class_weight="balanced")
    m.fit(A[tr], d[tr])
    oof[va] = m.predict_proba(A[va])[:, 1]
    print(f"fold {k}: AUC {roc_auc_score(d[va], oof[va]):.3f}", flush=True)
print(f"AUC train vs public_test: {roc_auc_score(d, oof):.3f}")
np.save(os.path.join(ROOT, "experiments", "adv_scores.npy"), oof[:len(X)].astype(np.float32))
