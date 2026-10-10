"""Задача C — извлечение признаков из аудио (без нейросетей).

Предобработка (важно для переноса на тест с другими синтезаторами):
  * обрезка тишины в начале/конце (librosa.effects.trim) — в ASVspoof 2019 длина пауз
    коррелирует с меткой, и модель выучивает этот «шорткат» вместо признаков синтеза;
  * длительность в признаки не попадает (в тесте все записи 3–4.5 с, в train 1.5–6.6 с).

Признаки: LFCC (линейные кепстральные коэффициенты — лучше MFCC видят высокие частоты,
где остаются артефакты вокодеров) + дельты, MFCC, спектральные статистики; по времени —
среднее и std.

    python task_c/features.py            # -> task_c/features/{train,public_test}_spec.npz
"""
import argparse
import glob
import os
from multiprocessing import Pool

import librosa
import numpy as np
import scipy.fft
import soundfile as sf

HERE = os.path.dirname(os.path.abspath(__file__))
SR = 16000


def wav_sort_key(path):
    """Числовые имена (0.wav, 1.wav, …) — по номеру; любые другие — по алфавиту после числовых."""
    stem = os.path.splitext(os.path.basename(path))[0]
    return (0, int(stem), "") if stem.isdigit() else (1, 0, stem)


def load_audio(path, trim=True):
    x, sr = sf.read(path, dtype="float32")
    if x.ndim > 1:
        x = x.mean(1)
    if sr != SR:
        x = librosa.resample(x, orig_sr=sr, target_sr=SR)
    if trim:
        y, _ = librosa.effects.trim(x, top_db=35)
        if len(y) > SR // 4:
            x = y
    x = x / (np.abs(x).max() + 1e-6)  # нормировка громкости
    return x


def lfcc(x, n_fft=512, hop=160, n_filters=40, n_ceps=20):
    S = np.abs(librosa.stft(x, n_fft=n_fft, hop_length=hop, win_length=320)) ** 2
    freqs = np.linspace(0, SR / 2, S.shape[0])
    edges = np.linspace(0, SR / 2, n_filters + 2)
    fb = np.zeros((n_filters, S.shape[0]))
    for i in range(n_filters):  # линейные треугольные фильтры
        lo, c, hi = edges[i], edges[i + 1], edges[i + 2]
        fb[i] = np.clip(np.minimum((freqs - lo) / (c - lo), (hi - freqs) / (hi - c)), 0, None)
    E = np.log(fb @ S + 1e-10)
    return scipy.fft.dct(E, axis=0, norm="ortho")[:n_ceps]


def stats(F):
    return np.concatenate([F.mean(1), F.std(1)])


def extract(path):
    x = load_audio(path)
    L = lfcc(x)
    dL = librosa.feature.delta(L)
    ddL = librosa.feature.delta(L, order=2)
    M = librosa.feature.mfcc(y=x, sr=SR, n_mfcc=20)
    S = np.abs(librosa.stft(x, n_fft=512, hop_length=160))
    logS = np.log(S + 1e-8)
    band = np.array_split(logS, 16, axis=0)  # средняя энергия по 16 полосам частот
    bands = np.stack([b.mean(0) for b in band])
    spec = np.stack([librosa.feature.spectral_centroid(S=S, sr=SR)[0],
                     librosa.feature.spectral_bandwidth(S=S, sr=SR)[0],
                     librosa.feature.spectral_flatness(S=S)[0],
                     librosa.feature.spectral_rolloff(S=S, sr=SR)[0]])
    return np.concatenate([stats(L), stats(dL), stats(ddL), stats(M), stats(bands), stats(spec)]).astype(np.float32)


def read_targets(data_dir):
    rows = [l.split() for l in open(os.path.join(data_dir, "train", "targets.txt"))]
    return {r[1]: (r[0], r[3], int(r[4] == "spoof")) for r in rows}  # id -> (speaker, attack, label)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data-dir", default=os.path.join(HERE, "data"))
    ap.add_argument("--split", default="train,public_test")
    ap.add_argument("--workers", type=int, default=4)
    args = ap.parse_args()
    out_dir = os.path.join(HERE, "features")
    os.makedirs(out_dir, exist_ok=True)
    for split in args.split.split(","):
        if split == "train":
            meta = read_targets(args.data_dir)
            ids = sorted(meta)
            paths = [os.path.join(args.data_dir, "train", "flac", f"{i}.flac") for i in ids]
        else:
            paths = sorted(glob.glob(os.path.join(args.data_dir, split, "*.wav")),
                           key=wav_sort_key)
            ids = [os.path.basename(p) for p in paths]
        with Pool(args.workers) as pool:
            feats = pool.map(extract, paths, chunksize=64)
        out = dict(X=np.stack(feats), ids=np.array(ids))
        if split == "train":
            out.update(speaker=np.array([meta[i][0] for i in ids]),
                       attack=np.array([meta[i][1] for i in ids]),
                       y=np.array([meta[i][2] for i in ids]))
        np.savez(os.path.join(out_dir, f"{split}_spec.npz"), **out)
        print(split, out["X"].shape, flush=True)


if __name__ == "__main__":
    main()
