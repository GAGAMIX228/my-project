"""Гипотеза D (латентный шум): y_obs = 100*sigmoid(z + eps). Тогда E[y_obs|x] «прижато к середине»
относительно чистого y = 100*sigmoid(z), а МЕДИАНА y_obs|x равна чистому значению (эквивариантность
квантилей). Проверяем: диагностика остатков, медианная калибровка MSE-прогноза, прямые медианные модели."""
import os
import sys
import warnings

import lightgbm as lgb
import numpy as np
import pandas as pd
import statsmodels.api as sm
from catboost import CatBoostRegressor
from scipy.stats import skew
from sklearn.model_selection import KFold

warnings.filterwarnings("ignore")
HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from common import CAT_FEATURES, TARGET, load  # noqa: E402
from train import prep  # noqa: E402

OUT = os.path.join(ROOT, "submissions_d/median")
os.makedirs(OUT, exist_ok=True)
tr = load(os.path.join(HERE, "data", "hard_train.csv"))
te = load(os.path.join(HERE, "data", "hard_test.csv"))
y = tr[TARGET].values
Xc, Xct = prep(tr, tr, False, "cat"), prep(te, tr, False, "cat")
Xl, Xlt = prep(tr, tr, True, "lgbm"), prep(te, tr, True, "lgbm")
kf = list(KFold(5, shuffle=True, random_state=0).split(tr))
best = pd.read_csv(os.path.join(ROOT, "submissions_d/sharp/submission_seed_352773_base_mid_sharp.csv")).protection_score.values


def lg(p):
    p = np.clip(p, 1e-4, 1 - 1e-4)
    return np.log(p / (1 - p))


def sig(z):
    return 100 / (1 + np.exp(-z))


def save(name, p):
    p = np.clip(p, 0, 100)
    pd.DataFrame({"customer_id": te.customer_id, "protection_score": p}).to_csv(
        f"{OUT}/submission_seed_352773_{name}.csv", index=False)
    print(f"  {name}: mean {p.mean():.2f}, RMSE к 77.25 {np.sqrt(np.mean((p - best) ** 2)):.2f}", flush=True)


# 1) OOF MSE-прогноз (уровень mid: CatBoost d7 + LGBM 16), тест — среднее фолдовых моделей
oof, mu_t = np.zeros(len(y)), np.zeros(len(te))
lpm = dict(learning_rate=0.02, num_leaves=16, min_child_samples=30, reg_lambda=1, subsample=0.8, subsample_freq=1,
           colsample_bytree=0.5, verbose=-1)
for k, (a, b) in enumerate(kf):
    c = CatBoostRegressor(iterations=762, learning_rate=0.03, depth=7, verbose=0, cat_features=CAT_FEATURES,
                          random_seed=k, allow_writing_files=False).fit(Xc.iloc[a], y[a])
    l_ = lgb.LGBMRegressor(n_estimators=645, **lpm, random_state=k).fit(Xl.iloc[a], y[a])
    oof[b] = (c.predict(Xc.iloc[b]) + l_.predict(Xl.iloc[b])) / 2
    mu_t += (c.predict(Xct) + l_.predict(Xlt)) / 2 / 5
print("OOF RMSE (шумные метки):", round(float(np.sqrt(np.mean((oof - y) ** 2))), 3), flush=True)

# 2) диагностика
bins = pd.qcut(oof, 10)
for name, t in {"y": lambda v: v, "logit": lambda v: lg(v / 100)}.items():
    g = pd.Series(t(y) - t(oof)).groupby(bins, observed=True)
    print(f"--- остатки в шкале {name}", flush=True)
    print(pd.DataFrame({"median": g.median(), "std": g.std(), "skew": g.apply(skew)}).round(2).to_string(), flush=True)

# 3) медианная калибровка
cal = lgb.LGBMRegressor(objective="quantile", alpha=0.5, n_estimators=300, learning_rate=0.05, num_leaves=8,
                        min_child_samples=300, monotone_constraints=[1], random_state=0, verbose=-1)
cal.fit(oof.reshape(-1, 1), y)
qa, qb = sm.QuantReg(lg(y / 100), sm.add_constant(lg(oof / 100))).fit(q=0.5).params
print(f"QuantReg в logit-шкале: a={qa:.3f}, b={qb:.3f} (b>1 => растяжение от центра)", flush=True)
save("cal_lgbm_mid", cal.predict(mu_t.reshape(-1, 1)))
save("cal_qr_mid", sig(qa + qb * lg(mu_t / 100)))
save("cal_qr_best", sig(qa + qb * lg(best / 100)))          # калибровка, применённая к лучшему бленду
save("cal_lgbm_best", cal.predict(best.reshape(-1, 1)))

# 4) прямые медианные модели (5-fold, тест — среднее фолдов)
pq = np.zeros(len(te))
for k, (a, b) in enumerate(kf):
    c = CatBoostRegressor(iterations=3000, learning_rate=0.03, depth=7, loss_function="Quantile:alpha=0.5",
                          verbose=0, cat_features=CAT_FEATURES, random_seed=k, allow_writing_files=False,
                          early_stopping_rounds=300).fit(Xc.iloc[a], y[a], eval_set=(Xc.iloc[b], y[b]))
    l_ = lgb.LGBMRegressor(objective="quantile", alpha=0.5, n_estimators=5000, learning_rate=0.01, num_leaves=16,
                           min_child_samples=60, subsample=0.8, subsample_freq=1, colsample_bytree=0.5, verbose=-1,
                           random_state=k).fit(Xl.iloc[a], y[a], eval_set=[(Xl.iloc[b], y[b])],
                                               callbacks=[lgb.early_stopping(300, verbose=False)])
    pq += (c.predict(Xct) + l_.predict(Xlt)) / 2 / 5
    print(f"  фолд {k}: CatBoost {c.tree_count_} дер., LGBM {l_.best_iteration_} дер.", flush=True)
save("median_models", pq)
save("median_models_plus_calbest", (pq + sig(qa + qb * lg(best / 100))) / 2)
