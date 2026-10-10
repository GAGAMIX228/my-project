"""Гипотеза «ансамбль разных моделей»: усредняем сохранённые OOF-вероятности.

    python experiments/blend.py --data-dir data mlp_cw05 lgbm logreg_bal
"""
import argparse
import itertools
import os
import sys

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)
from src.common import cross_fitted_scaled_f1, encode_targets, load_npz, macro_f1  # noqa: E402

ap = argparse.ArgumentParser()
ap.add_argument("--data-dir", default=os.path.join(ROOT, "data"))
ap.add_argument("names", nargs="+")
args = ap.parse_args()

_, y = load_npz(os.path.join(args.data_dir, "train.npz"))
y = encode_targets(y)
oofs = {n: np.load(os.path.join(ROOT, "experiments", "oof", f"{n}.npy")) for n in args.names}
# при --eval-folds OOF заполнен не везде — берём только строки, где есть все модели
mask = np.all([o.sum(1) > 0 for o in oofs.values()], axis=0)
y = y[mask]
oofs = {n: o[mask] for n, o in oofs.items()}
for r in range(1, len(oofs) + 1):
    for combo in itertools.combinations(oofs, r):
        p = np.mean([oofs[n] for n in combo], axis=0)
        print(f"{' + '.join(combo):60s} F1={macro_f1(y, p.argmax(1)):.4f}  "
              f"tuned={cross_fitted_scaled_f1(p, y):.4f}")
