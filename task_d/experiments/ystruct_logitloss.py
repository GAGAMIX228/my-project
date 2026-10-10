"""Гипотеза D: формула аддитивна в шкале y (взвешенная сумма подындексов), а шум — в logit:
y_obs = 100*sigmoid(logit(Y/100) + eps). Деревья по y — верная структура, но неэффективная потеря;
деревья по logit — эффективная потеря, но не та структура. Здесь — LightGBM со своей целевой функцией:
сырой скор F в шкале y (деревья складываются в y), а потеря — MSE в logit-шкале (Гаусс–Ньютон).
Ранняя остановка — по logit-MSE на валидации (честная метрика при латентном шуме)."""
import os
import sys
import warnings

import lightgbm as lgb
import numpy as np
import pandas as pd
from sklearn.model_selection import KFold

warnings.filterwarnings("ignore")
HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from common import TARGET, load  # noqa: E402
from train import prep  # noqa: E402

OUT = os.path.join(ROOT, "submissions_d/ystruct")
os.makedirs(OUT, exist_ok=True)
tr = load(os.path.join(HERE, "data", "hard_train.csv"))
te = load(os.path.join(HERE, "data", "hard_test.csv"))
y = tr[TARGET].values
zy = np.log(y / (100 - y))
X, Xt = prep(tr, tr, True, "lgbm"), prep(te, tr, True, "lgbm")
kf = list(KFold(5, shuffle=True, random_state=0).split(tr))
SEED, NS = 352773, 5
INIT = float(np.median(y))


def lg(p):
    p = np.clip(p, 1e-3, 1 - 1e-3)
    return np.log(p / (1 - p))


def obj(preds, data):
    yy = data.get_label()
    p = np.clip(preds / 100, 1e-3, 1 - 1e-3)
    r = np.log(yy / (100 - yy)) - np.log(p / (1 - p))
    dz = 1 / (100 * p * (1 - p))
    return -2 * r * dz, 2 * dz ** 2


def feval(preds, data):
    yy = data.get_label()
    return "logit_mse", float(np.mean((lg(yy / 100) - lg(preds / 100)) ** 2)), False


LEVELS = {"base": dict(num_leaves=8, min_child_samples=40, reg_lambda=5),
          "mid": dict(num_leaves=16, min_child_samples=30, reg_lambda=1),
          "sharp": dict(num_leaves=31, min_child_samples=20, reg_lambda=1)}
COMMON = dict(objective=obj, learning_rate=0.02, subsample=0.8, subsample_freq=1, colsample_bytree=0.5,
              verbose=-1, deterministic=True, num_threads=4)

F_test_levels, oof_levels = [], []
for lvl, p in LEVELS.items():
    params = {**COMMON, **p}
    oof, its = np.zeros(len(y)), []
    for a, b in kf:
        dtr = lgb.Dataset(X.iloc[a], y[a], init_score=np.full(len(a), INIT), free_raw_data=False)
        dva = lgb.Dataset(X.iloc[b], y[b], init_score=np.full(len(b), INIT), reference=dtr)
        m = lgb.train({**params, "seed": 0}, dtr, num_boost_round=6000, valid_sets=[dva], feval=feval,
                      callbacks=[lgb.early_stopping(300, verbose=False)])
        its.append(m.best_iteration)
        oof[b] = np.clip(m.predict(X.iloc[b], num_iteration=m.best_iteration) + INIT, 0.5, 99.5)
    n = int(np.mean(its) * 1.1)
    Ft = []
    for k in range(NS):
        d = lgb.Dataset(X, y, init_score=np.full(len(y), INIT))
        m = lgb.train({**params, "seed": SEED + k}, d, num_boost_round=n)
        Ft.append(np.clip(m.predict(Xt) + INIT, 0.5, 99.5))
    F_test_levels.append(np.mean(Ft, 0))
    oof_levels.append(oof)
    print(f"{lvl}: деревьев {n} (фолды {its}); OOF logit-MSE {np.mean((zy - lg(oof / 100)) ** 2):.4f}", flush=True)

# сравнение с обычными y-деревьями по той же «честной» метрике (OOF mid-уровня MSE-деревьев)
oof_y = np.load(os.path.join(ROOT, "submissions_d/median/oof_mid.npz"))["oof"]
print(f"для сравнения: MSE-деревья (mid) OOF logit-MSE {np.mean((zy - lg(np.clip(oof_y, 0.5, 99.5) / 100)) ** 2):.4f}",
      flush=True)
oof_new = np.mean(oof_levels, 0)
print(f"новая модель (3 уровня, OOF): logit-MSE {np.mean((zy - lg(oof_new / 100)) ** 2):.4f}; "
      f"RMSE по y (шумные метки) {np.sqrt(np.mean((oof_new - y) ** 2)):.3f}", flush=True)

F = np.mean(F_test_levels, 0)   # оценка медианы (100*sigmoid(z))
xs, ws = np.polynomial.hermite_e.hermegauss(60)
ws = ws / ws.sum()
s = 0.61
Fmean = (ws[None, :] * 100 / (1 + np.exp(-(lg(F / 100)[:, None] + s * xs[None, :])))).sum(1)
best = pd.read_csv(os.path.join(ROOT, "submissions_d/sharp/submission_seed_352773_base_mid_sharp.csv")).protection_score.values
for name, p in [("ystruct_median", F), ("ystruct_mean", Fmean), ("ystruct_median_plus_best", (F + best) / 2),
                ("ystruct_mean_plus_best", (Fmean + best) / 2)]:
    pd.DataFrame({"customer_id": te.customer_id, "protection_score": np.clip(p, 0, 100)}).to_csv(
        f"{OUT}/submission_seed_{SEED}_{name}.csv", index=False)
    print(f"{name}: mean {p.mean():.2f} (лучший {best.mean():.2f}), RMSE к 77.25 = {np.sqrt(np.mean((p - best) ** 2)):.2f}",
          flush=True)
