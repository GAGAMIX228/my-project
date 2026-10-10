"""Задача C — обучение финальной модели: смесь (усреднение рангов) двух классификаторов:
  * LightGBM на спектральных признаках (LFCC/MFCC/полосы, features.py) — ловит TTS-атаки;
  * логрег на слое 6 WavLM-base-plus (ssl_features.py) — ловит voice conversion (A05),
    где спектральные признаки слабы.
Leave-one-attack-out CV: spec 0.977, WavLM-L6 0.976, смесь 0.994 (худшая атака 0.979).

Перед обучением нужны признаки:  python task_c/features.py && python task_c/ssl_features.py
    python task_c/train.py [--seed N]
Результат: task_c/weights/{spec_lgbm.txt, wavlm_l6_logreg.joblib, meta.json}.
"""
import argparse
import json
import os
import sys

import joblib
import lightgbm as lgb
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from run_experiments import m_logreg  # noqa: E402

CONFIG = dict(wavlm_layer=6, logreg_C=0.1,
              lgbm=dict(n_estimators=400, learning_rate=0.05, num_leaves=31, subsample=0.8,
                        subsample_freq=1, colsample_bytree=0.5, class_weight="balanced"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--seed", type=int, default=None)
    ap.add_argument("--out-dir", default=os.path.join(HERE, "weights"))
    args = ap.parse_args()
    seed = args.seed if args.seed is not None else int(np.random.SeedSequence().entropy % 1_000_000)
    print(f"SEED = {seed}")
    np.random.seed(seed)
    os.makedirs(args.out_dir, exist_ok=True)

    s = np.load(os.path.join(HERE, "features", "train_spec.npz"))
    m_spec = lgb.LGBMClassifier(**CONFIG["lgbm"], random_state=seed, verbose=-1).fit(s["X"], s["y"])
    m_spec.booster_.save_model(os.path.join(args.out_dir, "spec_lgbm.txt"))

    w = np.load(os.path.join(HERE, "features", "train_wavlm.npz"))
    Xw = w["X"][:, CONFIG["wavlm_layer"]].astype(np.float32)
    m_w = m_logreg(CONFIG["logreg_C"]).fit(Xw, w["y"])
    joblib.dump(m_w, os.path.join(args.out_dir, "wavlm_l6_logreg.joblib"))

    n_params = int(m_spec.booster_.trees_to_dataframe().shape[0]) + Xw.shape[1] + 1
    meta = dict(seed=seed, config=CONFIG, n_train_spec=len(s["y"]), n_train_wavlm=len(w["y"]),
                classifier_params=n_params, wavlm_backbone="microsoft/wavlm-base-plus (94.4M, frozen)")
    json.dump(meta, open(os.path.join(args.out_dir, "meta.json"), "w"), ensure_ascii=False, indent=2)
    print(meta)


if __name__ == "__main__":
    main()
