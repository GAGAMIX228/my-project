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

from src.common import CLASSES, MLP, Preprocessor, em_prior_shift, load_npz, predict_proba_mlp


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--test", default="data/public_test.npz")
    ap.add_argument("--weights", default="weights/model.pt")
    ap.add_argument("--out-dir", default=".")
    ap.add_argument("--prior-shift", choices=["em", "none"], default="em",
                    help="em — оценить частоты классов теста EM-алгоритмом и пересчитать вероятности")
    ap.add_argument("--scales", action="store_true",
                    help="применить множители классов, подобранные на OOF train")
    args = ap.parse_args()

    ckpt = torch.load(args.weights, map_location="cpu", weights_only=False)
    cfg, seed = ckpt["config"], ckpt["seed"]
    pre = Preprocessor.from_state(ckpt["preprocessor"])

    X, _ = load_npz(args.test)
    Xn = pre.transform(X)

    proba = np.zeros((len(X), len(CLASSES)), dtype=np.float32)
    for state in ckpt["states"]:
        model = MLP(ckpt["in_dim"], tuple(cfg["hidden"]), len(CLASSES), cfg["dropout"])
        model.load_state_dict(state)
        proba += predict_proba_mlp(model, Xn) / len(ckpt["states"])

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
