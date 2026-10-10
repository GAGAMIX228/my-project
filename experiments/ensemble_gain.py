"""Гипотеза: усреднение K фолдовых моделей (как в train.py) лучше одной модели,
а добавка логрега к ансамблю даёт ещё прирост.

Протокол: 20% train откладываются как «тест». На остальных 80% обучаем K MLP по фолдам
(как в train.py) и логрег, затем меряем macro-F1 на отложенной части.

    python experiments/ensemble_gain.py
"""
import argparse
import os
import sys
import time

import numpy as np
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import StratifiedKFold, train_test_split

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)
from src.common import (Preprocessor, encode_targets, load_npz, macro_f1,  # noqa: E402
                        predict_proba_mlp, train_mlp)
from train import CONFIG  # noqa: E402

ap = argparse.ArgumentParser()
ap.add_argument("--data-dir", default=os.path.join(ROOT, "data"))
ap.add_argument("--seed", type=int, default=20261010)
args = ap.parse_args()

X, y = load_npz(os.path.join(args.data_dir, "train.npz"))
y = encode_targets(y)
X_tr, X_ho, y_tr, y_ho = train_test_split(X, y, test_size=0.2, stratify=y, random_state=args.seed)
pre = Preprocessor(l2=CONFIG["l2"]).fit(X_tr)
X_tr, X_ho = pre.transform(X_tr), pre.transform(X_ho)

mlp_kw = {k: CONFIG[k] for k in ("hidden", "dropout", "epochs", "batch_size", "lr", "weight_decay",
                                 "label_smoothing", "cw_power", "mixup", "arch")}
probas = []
skf = StratifiedKFold(n_splits=CONFIG["folds"], shuffle=True, random_state=args.seed)
for k, (tr, va) in enumerate(skf.split(X_tr, y_tr)):
    t0 = time.time()
    model, ep, f1_va = train_mlp(X_tr[tr], y_tr[tr], X_tr[va], y_tr[va], seed=args.seed + k, **mlp_kw)
    probas.append(predict_proba_mlp(model, X_ho))
    ens = np.mean(probas, 0)
    print(f"модель {k}: holdout F1 одной {macro_f1(y_ho, probas[-1].argmax(1)):.4f}, "
          f"ансамбль из {k + 1}: {macro_f1(y_ho, ens.argmax(1)):.4f} ({time.time() - t0:.0f}s)", flush=True)

lr = LogisticRegression(C=1.0, max_iter=2000, class_weight="balanced", random_state=args.seed)
lr.fit(X_tr, y_tr)
p_lr = lr.predict_proba(X_ho)
print(f"логрег: {macro_f1(y_ho, p_lr.argmax(1)):.4f}")
ens = np.mean(probas, 0)
for w in (0.1, 0.2, 0.3):
    print(f"ансамбль MLP + {w:.1f}·логрег: {macro_f1(y_ho, ((1 - w) * ens + w * p_lr).argmax(1)):.4f}")
