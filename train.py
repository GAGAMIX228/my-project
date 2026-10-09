"""Обучение финальной модели: ансамбль K MLP (по одному на фолд) + подбор множителей
классов под macro-F1 на OOF-предсказаниях.

Запуск:
    python train.py --data-dir data              # seed выбирается случайно и печатается
    python train.py --data-dir data --seed 12345 # воспроизведение

Результат: weights/model.pt (веса всех фолдов, нормализация, множители классов, seed).
"""
import argparse
import json
import os
import time

import numpy as np
import torch
from sklearn.model_selection import StratifiedKFold

from src.common import (CLASSES, Preprocessor, count_params, encode_targets, fit_class_scales,
                        load_npz, macro_f1, predict_proba_mlp, set_seed, train_mlp)

# Конфиг финальной модели. Выбран по результатам experiments/results.csv.
CONFIG = dict(
    folds=5,
    l2=False,
    hidden=(512, 256),
    dropout=0.3,
    epochs=40,
    batch_size=512,
    lr=2e-3,
    weight_decay=1e-2,
    label_smoothing=0.05,
    cw_power=0.5,
    mixup=0.0,
)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data-dir", default="data")
    ap.add_argument("--out", default="weights/model.pt")
    ap.add_argument("--seed", type=int, default=None)
    args = ap.parse_args()

    seed = args.seed if args.seed is not None else int(np.random.SeedSequence().entropy % 1_000_000)
    print(f"SEED = {seed}")
    set_seed(seed)
    device = "cuda" if torch.cuda.is_available() else "cpu"

    X, y = load_npz(os.path.join(args.data_dir, "train.npz"))
    y = encode_targets(y)
    print(f"train: {X.shape}, классы: {dict(zip(CLASSES, np.bincount(y).tolist()))}")

    pre = Preprocessor(l2=CONFIG["l2"]).fit(X)
    Xn = pre.transform(X)

    mlp_kw = {k: CONFIG[k] for k in ("hidden", "dropout", "epochs", "batch_size", "lr",
                                     "weight_decay", "label_smoothing", "cw_power", "mixup")}
    skf = StratifiedKFold(n_splits=CONFIG["folds"], shuffle=True, random_state=seed)
    oof = np.zeros((len(X), len(CLASSES)), dtype=np.float32)
    states = []
    for k, (tr, va) in enumerate(skf.split(Xn, y)):
        t0 = time.time()
        model, ep, f1 = train_mlp(Xn[tr], y[tr], Xn[va], y[va], seed=seed + k, device=device, **mlp_kw)
        oof[va] = predict_proba_mlp(model, Xn[va], device)
        states.append({n: t.cpu() for n, t in model.state_dict().items()})
        print(f"fold {k}: best epoch {ep}, val macro-F1 {f1:.4f} ({time.time() - t0:.0f}s)")

    scales, f1_tuned = fit_class_scales(oof, y)
    f1_raw = macro_f1(y, oof.argmax(1))
    n_params = count_params(model) * CONFIG["folds"]
    print(f"OOF macro-F1: {f1_raw:.4f} -> с множителями классов {f1_tuned:.4f}; scales={np.round(scales, 3)}")
    print(f"параметров в ансамбле: {n_params:,}")

    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
    torch.save({
        "seed": seed,
        "config": CONFIG,
        "in_dim": X.shape[1],
        "preprocessor": pre.state(),
        "scales": scales,
        "states": states,
    }, args.out)
    with open(os.path.splitext(args.out)[0] + "_report.json", "w") as f:
        json.dump({"seed": seed, "oof_macro_f1": f1_raw, "oof_macro_f1_scaled": f1_tuned,
                   "scales": scales.tolist(), "n_params": n_params,
                   "config": {k: list(v) if isinstance(v, tuple) else v for k, v in CONFIG.items()}},
                  f, ensure_ascii=False, indent=2)
    print(f"сохранено: {args.out}")


if __name__ == "__main__":
    main()
