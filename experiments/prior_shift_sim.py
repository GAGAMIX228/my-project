"""Гипотеза: в тесте частоты классов отличаются от train (в train angry/positive по 33.6%,
neutral/sad по 16.4%, а по условию «нейтральных всегда больше»).
Моделируем тест с другими частотами подвыборкой OOF и сравниваем:
  raw   — argmax вероятностей модели;
  scale — множители классов, подобранные на OOF с частотами train;
  em    — EM-оценка частот теста (без меток!) + пересчёт вероятностей.

    python experiments/prior_shift_sim.py mlp_cw05
"""
import os
import sys

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)
from src.common import (CLASSES, em_prior_shift, encode_targets, fit_class_scales,  # noqa: E402
                        load_npz, macro_f1)

name = sys.argv[1] if len(sys.argv) > 1 else "mlp_cw05"
_, y = load_npz(os.path.join(ROOT, "data", "train.npz"))
y = encode_targets(y)
oof = np.load(os.path.join(ROOT, "experiments", "oof", f"{name}.npy"))
m = oof.sum(1) > 0
oof, y = oof[m], y[m]
train_prior = np.bincount(y, minlength=4) / len(y)

rng = np.random.default_rng(0)
half = len(y) // 2
perm = rng.permutation(len(y))
fit_i, ev_i = perm[:half], perm[half:]
scales, _ = fit_class_scales(oof[fit_i], y[fit_i])

scenarios = {
    "как train":            train_prior,
    "сбалансированно":      np.array([.25, .25, .25, .25]),
    "neutral 40%":          np.array([.2, .4, .2, .2]),
    "neutral 60%":          np.array([.13, .6, .15, .12]),
}
print(f"{'сценарий':22s} {'raw':>7s} {'scale':>7s} {'em':>7s} {'em+scale':>9s}   EM-оценка частот")
for sname, target in scenarios.items():
    n = 6600
    idx = np.concatenate([rng.choice(ev_i[y[ev_i] == c], int(round(n * target[c])), replace=True)
                          for c in range(4)])
    p, t = oof[idx], y[idx]
    est, p_em = em_prior_shift(p, train_prior)
    print(f"{sname:22s} {macro_f1(t, p.argmax(1)):7.4f} {macro_f1(t, (p * scales).argmax(1)):7.4f} "
          f"{macro_f1(t, p_em.argmax(1)):7.4f} {macro_f1(t, (p_em * scales).argmax(1)):9.4f}   "
          f"{dict(zip(CLASSES, np.round(est, 3)))}  (истина {np.round(target, 3)})")
