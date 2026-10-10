"""Задача C — обучение финальной модели: LightGBM на спектральных признаках
(LFCC/MFCC/энергии полос, тишина обрезана; features.py).

Проверенные варианты (leave-one-attack-out CV / public LB):
  * spec LightGBM:            CV 0.977 / LB 98.46  <- финал
  * WavLM-L6 + логрег:        CV 0.976 / LB 45.86  (признаки WavLM не переносятся на синтезаторы теста)
  * смесь рангов spec+WavLM:  CV 0.994 / LB 79.88

Перед обучением нужны признаки:  python task_c/features.py
    python task_c/train.py [--seed N]
Результат: task_c/weights/{spec_lgbm.txt, meta.json}.
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

CONFIG = dict(use_wavlm=False, wavlm_layer=6, logreg_C=0.1,
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

    n_params = int(m_spec.booster_.trees_to_dataframe().shape[0])
    meta = dict(seed=seed, config=CONFIG, n_train_spec=len(s["y"]), tree_nodes=n_params)
    if CONFIG["use_wavlm"]:  # отключено: проигрывает на LB (см. docstring)
        w = np.load(os.path.join(HERE, "features", "train_wavlm.npz"))
        Xw = w["X"][:, CONFIG["wavlm_layer"]].astype(np.float32)
        m_w = m_logreg(CONFIG["logreg_C"]).fit(Xw, w["y"])
        joblib.dump(m_w, os.path.join(args.out_dir, "wavlm_l6_logreg.joblib"))
    json.dump(meta, open(os.path.join(args.out_dir, "meta.json"), "w"), ensure_ascii=False, indent=2)
    print(meta)


if __name__ == "__main__":
    main()
