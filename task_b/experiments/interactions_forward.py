"""Гипотеза B: расширенный жадный forward-отбор попарных взаимодействий для GAM.
Старт — 4 найденные пары (common.PAIRS). На каждом шаге перебираем все пары из расширенного
списка признаков (числовые + флаги бренда/региона), добавляем лучшую, если прирост F1 > 0.0008.
Отбор — на CV с seed'ами A, итоговая проверка — на других seed'ах B (защита от подгонки)."""
import itertools
import os
import sys

import numpy as np
from sklearn.metrics import f1_score
from sklearn.model_selection import StratifiedKFold

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, HERE)
from common import PAIRS, build_gam, load, make_features  # noqa: E402

df = load(os.path.join(HERE, "data", "train.csv"))
y = df.accepted.values
X0 = make_features(df, extra=False)
X0["brand_apple"] = (X0.smartphone_brand == "Apple").astype(int)
X0["brand_premium"] = X0.smartphone_brand.isin(["Apple", "Samsung", "Google"]).astype(int)
X0["region_capital"] = X0.region.isin(["Москва", "Санкт-Петербург"]).astype(int)
X0["edu_high"] = X0.education.isin(["master", "phd"]).astype(int)
FEATS = ["smartphone_price", "monthly_income", "number_of_card_transactions_month", "average_monthly_balance",
         "credit_score", "online_payments_share", "smartphone_age_months", "previous_campaign_response",
         "previous_insurance", "number_of_bank_products", "marketing_contacts_last_year", "mobile_app_usage",
         "age", "owns_car", "brand_apple", "brand_premium", "region_capital", "edu_high"]


def add(X, pairs):
    X = X.copy()
    for a, b in pairs:
        za = ((X[a] - X0[a].mean()) / (X0[a].std() + 1e-9)).fillna(0)
        zb = ((X[b] - X0[b].mean()) / (X0[b].std() + 1e-9)).fillna(0)
        X[f"{a}*{b}"] = za * zb
    return X


def cv(X, seeds):
    s = []
    for r in seeds:
        oof = np.zeros(len(y))
        for tr, va in StratifiedKFold(5, shuffle=True, random_state=r).split(X, y):
            oof[va] = build_gam(list(X.columns), n_knots=3).fit(X.iloc[tr], y[tr]).predict_proba(X.iloc[va])[:, 1]
        s.append(f1_score(y, oof >= .5))
    return float(np.mean(s))


SEL, HOLD = [1, 2], [101, 102, 103]
chosen = list(PAIRS)
cur = cv(add(X0, chosen), SEL)
print(f"старт (4 пары): отбор {cur:.4f}", flush=True)
cands = [p for p in itertools.combinations(FEATS, 2) if p not in chosen and p[::-1] not in chosen]
for step in range(4):
    scores = [(cv(add(X0, chosen + [p]), SEL), p) for p in cands]
    best, p = max(scores)
    print(f"шаг {step + 1}: лучшая {p} -> {best:.4f} ({best - cur:+.4f})", flush=True)
    if best - cur < 0.0008:
        break
    chosen.append(p)
    cands.remove(p)
    cur = best
print("итог пары:", chosen, flush=True)
print(f"проверка на других seed'ах: 4 пары {cv(add(X0, list(PAIRS)), HOLD):.4f} | "
      f"{len(chosen)} пар {cv(add(X0, chosen), HOLD):.4f}", flush=True)
