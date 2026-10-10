"""Гипотеза D: шум латентный, y_obs = 100*sigmoid(z + eps), eps ~ N(0, s^2), s ~ 0.6 (диагностика:
std остатка в logit-шкале постоянна ~0.6, skew ~0). На тесте выигрывает СРЕДНЕЕ (медиана -5 баллов).
Поэтому: оцениваем z в logit-шкале (там шум однородный и гауссов -> MSE эффективен), а прогноз берём
как E[100*sigmoid(z + eps)] (а не 100*sigmoid(z) — это медиана, отсюда провал LightGBM на logit, 62.16).
Ансамбль — те же 3 уровня сложности, что в финале, но на logit-цели."""
import os
import sys
import warnings

import lightgbm as lgb
import numpy as np
import pandas as pd
from catboost import CatBoostRegressor
from sklearn.model_selection import KFold

warnings.filterwarnings("ignore")
HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from common import CAT_FEATURES, TARGET, load  # noqa: E402
from train import LEVELS, prep  # noqa: E402

OUT = os.path.join(ROOT, "submissions_d/logit_mean")
os.makedirs(OUT, exist_ok=True)
tr = load(os.path.join(HERE, "data", "hard_train.csv"))
te = load(os.path.join(HERE, "data", "hard_test.csv"))
y = tr[TARGET].values
z = np.log(y / (100 - y))
Xc, Xct = prep(tr, tr, False, "cat"), prep(te, tr, False, "cat")
Xl, Xlt = prep(tr, tr, True, "lgbm"), prep(te, tr, True, "lgbm")
kf = list(KFold(5, shuffle=True, random_state=0).split(tr))
SEED, NS = 352773, 3
LC = dict(learning_rate=0.02, subsample=0.8, subsample_freq=1, colsample_bytree=0.5)

zt_levels, oof_levels = [], []
for lvl, p in LEVELS.items():
    cp = dict(learning_rate=0.03, **p["cat"])
    its = [CatBoostRegressor(iterations=8000, **cp, verbose=0, cat_features=CAT_FEATURES, early_stopping_rounds=300,
                             allow_writing_files=False).fit(Xc.iloc[a], z[a], eval_set=(Xc.iloc[b], z[b])).tree_count_
           for a, b in kf]
    nc = int(np.mean(its) * 1.1)
    pc = np.mean([CatBoostRegressor(iterations=nc, **cp, verbose=0, cat_features=CAT_FEATURES, random_seed=SEED + k,
                                    allow_writing_files=False).fit(Xc, z).predict(Xct) for k in range(NS)], 0)
    lp = dict(**LC, **p["lgbm"], verbose=-1)
    oof = np.zeros(len(z))
    its = []
    for a, b in kf:
        m = lgb.LGBMRegressor(n_estimators=8000, **lp).fit(Xl.iloc[a], z[a], eval_set=[(Xl.iloc[b], z[b])],
                                                            callbacks=[lgb.early_stopping(200, verbose=False)])
        its.append(m.best_iteration_)
        oof[b] = m.predict(Xl.iloc[b])
    nl = int(np.mean(its) * 1.1)
    pl = np.mean([lgb.LGBMRegressor(n_estimators=nl, **lp, random_state=SEED + k).fit(Xl, z).predict(Xlt)
                  for k in range(NS)], 0)
    zt_levels.append((pc + pl) / 2)
    oof_levels.append(oof)
    print(f"{lvl}: CatBoost {nc}, LGBM {nl} деревьев; std остатка OOF в logit {np.std(z - oof):.3f}", flush=True)

zt = np.mean(zt_levels, 0)
s_hat = float(np.std(z - np.mean(oof_levels, 0)))
print(f"оценка s (std латентного шума, с учётом ошибки модели) = {s_hat:.3f}", flush=True)
np.save(f"{OUT}/z_test.npy", zt)

# E[100*sigmoid(z + s*eps)], eps ~ N(0,1) — квадратура Гаусса–Эрмита
xs, ws = np.polynomial.hermite_e.hermegauss(60)
ws = ws / ws.sum()
best = pd.read_csv(os.path.join(ROOT, "submissions_d/sharp/submission_seed_352773_base_mid_sharp.csv")).protection_score.values


def mean_y(zv, s):
    return (ws[None, :] * 100 / (1 + np.exp(-(zv[:, None] + s * xs[None, :])))).sum(1)


for s in (0.5, 0.6, 0.7):
    p = np.clip(mean_y(zt, s), 0, 100)
    pd.DataFrame({"customer_id": te.customer_id, "protection_score": p}).to_csv(
        f"{OUT}/submission_seed_{SEED}_logitmean_s{int(s * 100)}.csv", index=False)
    q = (p + best) / 2
    pd.DataFrame({"customer_id": te.customer_id, "protection_score": q}).to_csv(
        f"{OUT}/submission_seed_{SEED}_logitmean_s{int(s * 100)}_plus_best.csv", index=False)
    print(f"s={s}: mean {p.mean():.2f} (лучший {best.mean():.2f}), RMSE к 77.25 = {np.sqrt(np.mean((p - best) ** 2)):.2f}",
          flush=True)
med = 100 / (1 + np.exp(-zt))
print(f"для справки медиана sigmoid(z): mean {med.mean():.2f}, RMSE к 77.25 = {np.sqrt(np.mean((med - best) ** 2)):.2f}")
