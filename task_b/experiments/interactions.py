"""Гипотеза B: в формуле генератора есть взаимодействия признаков. Добавляем к GAM (k=3)
попарные произведения стандартизованных топ-признаков: все пары и по одной (жадный отбор).
Оценка — F1@0.5 на 5-fold CV x3."""
import itertools
import os
import sys

import numpy as np
from sklearn.metrics import f1_score
from sklearn.model_selection import StratifiedKFold

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, HERE)
from common import build_gam, load, make_features  # noqa: E402

df = load(os.path.join(HERE, "data", "train.csv"))
y = df.accepted.values
X0 = make_features(df, extra=False)
TOP = ["smartphone_price", "monthly_income", "number_of_card_transactions_month", "average_monthly_balance",
       "credit_score", "online_payments_share", "smartphone_age_months", "previous_campaign_response",
       "previous_insurance"]


def add(X, pairs):
    X = X.copy()
    for a, b in pairs:
        za = ((X[a] - X0[a].mean()) / X0[a].std()).fillna(0)
        zb = ((X[b] - X0[b].mean()) / X0[b].std()).fillna(0)
        X[f"{a}*{b}"] = za * zb
    return X


def cv(X, reps=3):
    s = []
    for r in range(reps):
        oof = np.zeros(len(y))
        for tr, va in StratifiedKFold(5, shuffle=True, random_state=20261010 + r).split(X, y):
            oof[va] = build_gam(list(X.columns), n_knots=3).fit(X.iloc[tr], y[tr]).predict_proba(X.iloc[va])[:, 1]
        s.append(f1_score(y, oof >= .5))
    return float(np.mean(s))


base = cv(X0)
print(f"GAM k3: {base:.4f}", flush=True)
pairs = list(itertools.combinations(TOP, 2))
print(f"GAM + все {len(pairs)} пар: {cv(add(X0, pairs)):.4f}", flush=True)
b1 = cv(X0, reps=1)
gains = sorted(((cv(add(X0, [p]), reps=1) - b1, p) for p in pairs), reverse=True)
for g, p in gains[:8]:
    print(f"  {p}: {g:+.4f}", flush=True)
good = [p for g, p in gains if g > 0.001]
if good:
    print(f"GAM + {len(good)} полезных пар: {cv(add(X0, good)):.4f}  {good}", flush=True)
