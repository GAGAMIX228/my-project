"""Задача C — признаки из предобученной самообучающейся модели WavLM-base-plus
(microsoft/wavlm-base-plus, 94M параметров, обучена на обычной речи без меток;
антиспуфинг-чекпоинты не используются — это запрещено правилами).

Для каждой записи (тишина обрезана, как в features.py; берём до MAX_SEC секунд из центра)
сохраняем среднее по времени скрытых состояний всех 13 слоёв -> (13, 768), float16.
Классификатор поверх обучается только на train этой задачи.

    python task_c/ssl_features.py        # -> task_c/features/{train,public_test}_wavlm.npz
"""
import argparse
import glob
import os
import sys
import time

import numpy as np
import torch
from transformers import AutoModel

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from features import SR, load_audio, read_targets  # noqa: E402

MODEL = "microsoft/wavlm-base-plus"
MAX_SEC = 4.0


@torch.no_grad()
def embed(model, x):
    n = int(MAX_SEC * SR)
    if len(x) > n:
        s = (len(x) - n) // 2
        x = x[s:s + n]
    x = (x - x.mean()) / (x.std() + 1e-6)
    out = model(torch.from_numpy(x)[None], output_hidden_states=True)
    return torch.stack([h[0].mean(0) for h in out.hidden_states]).numpy().astype(np.float16)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data-dir", default=os.path.join(HERE, "data"))
    ap.add_argument("--split", default="public_test,train")
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--per-attack", type=int, default=1000,
                    help="train: все bonafide + столько записей от каждого синтезатора (0 = все)")
    args = ap.parse_args()
    torch.set_num_threads(os.cpu_count())
    model = AutoModel.from_pretrained(MODEL).eval()
    out_dir = os.path.join(HERE, "features")
    os.makedirs(out_dir, exist_ok=True)
    for split in args.split.split(","):
        if split == "train":
            meta = read_targets(args.data_dir)
            ids = sorted(meta)
            if args.per_attack:
                rng = np.random.default_rng(0)
                keep = [i for i in ids if meta[i][2] == 0]
                for a in sorted({meta[i][1] for i in ids if meta[i][2] == 1}):
                    cand = [i for i in ids if meta[i][1] == a]
                    keep += list(rng.choice(cand, min(args.per_attack, len(cand)), replace=False))
                ids = sorted(keep)
            paths = [os.path.join(args.data_dir, "train", "flac", f"{i}.flac") for i in ids]
        else:
            paths = sorted(glob.glob(os.path.join(args.data_dir, split, "*.wav")),
                           key=lambda p: int(os.path.splitext(os.path.basename(p))[0]))
            ids = [os.path.basename(p) for p in paths]
        if args.limit:
            ids, paths = ids[:args.limit], paths[:args.limit]
        t0, E = time.time(), []
        for i, p in enumerate(paths):
            E.append(embed(model, load_audio(p)))
            if (i + 1) % 1000 == 0:
                print(f"{split}: {i + 1}/{len(paths)} ({(time.time() - t0) / (i + 1):.3f} с/файл)", flush=True)
        out = dict(X=np.stack(E), ids=np.array(ids))
        if split == "train":
            out.update(speaker=np.array([meta[i][0] for i in ids]),
                       attack=np.array([meta[i][1] for i in ids]),
                       y=np.array([meta[i][2] for i in ids]))
        np.savez(os.path.join(out_dir, f"{split}_wavlm{'_lim' if args.limit else ''}.npz"), **out)
        print(split, out["X"].shape, f"{time.time() - t0:.0f}s", flush=True)


if __name__ == "__main__":
    main()
