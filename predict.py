"""Предсказание без обучения: читает weights/model.pt и пишет submission_seed_{SEED}.npz.

Запуск:
    python predict.py --test data/public_test.npz
    python predict.py --test data/private_test.npz --out-dir submissions
    python predict.py --prior-shift none          # без поправки на частоты классов
"""
import argparse
import os

import numpy as np
import torch

from src.common import CLASSES, Preprocessor, build_model, em_prior_shift, load_npz, predict_proba_mlp


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--test", default="data/public_test.npz")
    ap.add_argument("--weights", default="weights/model.pt")
    ap.add_argument("--out-dir", default=".")
    ap.add_argument("--prior-shift", choices=["em", "none"], default="em",
                    help="em — оценить частоты классов теста EM-алгоритмом и пересчитать вероятности")
    ap.add_argument("--test-norm", action="store_true",
                    help="стандартизировать тест по его собственным среднему/std (борьба со сдвигом домена)")
    ap.add_argument("--logreg-weight", type=float, default=None,
                    help="переопределить долю логрега в смеси (по умолчанию — из конфига весов)")
    ap.add_argument("--scales", action="store_true",
                    help="применить множители классов, подобранные на OOF train")
    args = ap.parse_args()

    ckpt = torch.load(args.weights, map_location="cpu", weights_only=False)
    cfg, seed = ckpt["config"], ckpt["seed"]
    pre = Preprocessor.from_state(ckpt["preprocessor"])

    X, _ = load_npz(args.test)
    if args.test_norm:
        pre.fit(X)
    Xn = pre.transform(X)

    proba = np.zeros((len(X), len(CLASSES)), dtype=np.float32)
    for state in ckpt["states"]:
        model = build_model(ckpt["in_dim"], cfg.get("arch", "mlp"), cfg["hidden"], cfg["dropout"])
        model.load_state_dict(state)
        proba += predict_proba_mlp(model, Xn) / len(ckpt["states"])

    w = cfg.get("logreg_weight", 0.0) if args.logreg_weight is None else args.logreg_weight
    if w > 0 and ckpt.get("logreg") is not None:
        logits = Xn @ ckpt["logreg"]["coef"].T + ckpt["logreg"]["intercept"]
        p_lr = np.exp(logits - logits.max(1, keepdims=True))
        proba = (1 - w) * proba + w * p_lr / p_lr.sum(1, keepdims=True)

    if args.prior_shift == "em":
        est, proba = em_prior_shift(proba, ckpt["train_prior"])
        print("EM-оценка частот классов в тесте:", dict(zip(CLASSES.tolist(), np.round(est, 3).tolist())))
    if args.scales:
        proba = proba * ckpt["scales"]
    pred = CLASSES[proba.argmax(1)]

    os.makedirs(args.out_dir, exist_ok=True)
    out = os.path.join(args.out_dir, f"submission_seed_{seed}.npz")
    np.savez(out, embeddings=X, targets=pred)
    uniq, cnt = np.unique(pred, return_counts=True)
    print(f"{out}: {len(pred)} предсказаний, распределение {dict(zip(uniq.tolist(), cnt.tolist()))}")


if __name__ == "__main__":
    main()
