"""Задача C — предсказание без обучения: считает признаки для папки с .wav, применяет обе
модель из task_c/weights и пишет submission_seed_{SEED}.csv (idx, score; score = «подделка»).

    python task_c/predict.py --test-dir task_c/data/public_test
"""
import argparse
import glob
import json
import os
import sys

import joblib
import lightgbm as lgb
import numpy as np
import pandas as pd
import torch
from scipy.stats import rankdata
from transformers import AutoModel

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from features import extract, load_audio  # noqa: E402
from ssl_features import MODEL, embed  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--test-dir", default=os.path.join(HERE, "data", "public_test"))
    ap.add_argument("--weights", default=os.path.join(HERE, "weights"))
    ap.add_argument("--out-dir", default=".")
    args = ap.parse_args()
    meta = json.load(open(os.path.join(args.weights, "meta.json")))
    paths = sorted(glob.glob(os.path.join(args.test_dir, "*.wav")),
                   key=lambda p: int(os.path.splitext(os.path.basename(p))[0]))
    ids = [os.path.basename(p) for p in paths]

    Xs = np.stack([extract(p) for p in paths])
    score = lgb.Booster(model_file=os.path.join(args.weights, "spec_lgbm.txt")).predict(Xs)
    if meta["config"].get("use_wavlm"):
        torch.set_num_threads(os.cpu_count())
        wavlm = AutoModel.from_pretrained(MODEL).eval()
        Xw = np.stack([embed(wavlm, load_audio(p))[meta["config"]["wavlm_layer"]] for p in paths]).astype(np.float32)
        p_w = joblib.load(os.path.join(args.weights, "wavlm_l6_logreg.joblib")).predict_proba(Xw)[:, 1]
        score = (rankdata(score) + rankdata(p_w)) / (2 * len(ids))  # среднее рангов, в [0, 1]

    os.makedirs(args.out_dir, exist_ok=True)
    out = os.path.join(args.out_dir, f"submission_seed_{meta['seed']}.csv")
    pd.DataFrame({"idx": ids, "score": score}).to_csv(out, index=False)
    print(f"{out}: {len(ids)} строк")


if __name__ == "__main__":
    main()
