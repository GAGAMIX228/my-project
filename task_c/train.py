"""Задача C — обучение финальной модели на спектральных признаках (LFCC/MFCC/энергии полос,
тишина обрезана; features.py): смесь рангов трёх групп моделей
  * LightGBM x5 seed;
  * CatBoost depth=6 x3 seed;
  * CatBoost depth=8 x3 seed.

Проверенные варианты (public LB):
  spec LightGBM 98.46 | WavLM-L6 логрег 45.86 | смесь spec+WavLM 79.88
  LightGBM x5 98.72 | CatBoost 98.82 | LGBM x5 + CatBoost 98.85
  LGBM x5 + CatBoost d6 x3 98.95 | + d8 x3 98.97 | LGBM x5 + d6 x3 + d8 x3 99.01  <- финал

Перед обучением нужны признаки:  python task_c/features.py
    python task_c/train.py [--seed N]
Результат: task_c/weights/{lgbm_k.txt, cat_d6_k.cbm, cat_d8_k.cbm, meta.json}.
"""
import argparse
import json
import os
import sys

import joblib
import lightgbm as lgb
from catboost import CatBoostClassifier
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from run_experiments import m_logreg  # noqa: E402

CONFIG = dict(use_wavlm=False, wavlm_layer=6, logreg_C=0.1, n_lgbm=5, n_cat=3, cat_depths=[6, 8],
              cat=dict(iterations=1500, learning_rate=0.05),
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
    for f in os.listdir(args.out_dir):
        os.remove(os.path.join(args.out_dir, f))
    files = dict(lgbm=[], cat=[])
    for k in range(CONFIG["n_lgbm"]):
        m = lgb.LGBMClassifier(**CONFIG["lgbm"], random_state=seed + k, verbose=-1).fit(s["X"], s["y"])
        files["lgbm"].append(f"lgbm_{k}.txt")
        m.booster_.save_model(os.path.join(args.out_dir, files["lgbm"][-1]))
    w = np.where(s["y"] == 1, 1.0, (s["y"] == 1).sum() / (s["y"] == 0).sum())  # балансировка классов
    for depth in CONFIG["cat_depths"]:
        for k in range(CONFIG["n_cat"]):
            m = CatBoostClassifier(**CONFIG["cat"], depth=depth, verbose=0, random_seed=seed + k,
                                   allow_writing_files=False, thread_count=4).fit(s["X"], s["y"], sample_weight=w)
            files["cat"].append(f"cat_d{depth}_{k}.cbm")
            m.save_model(os.path.join(args.out_dir, files["cat"][-1]))
        print(f"CatBoost depth={depth} x{CONFIG['n_cat']} готов", flush=True)
    meta = dict(seed=seed, config=CONFIG, n_train_spec=len(s["y"]), files=files)
    if CONFIG["use_wavlm"]:  # отключено: проигрывает на LB (см. docstring)
        w = np.load(os.path.join(HERE, "features", "train_wavlm.npz"))
        Xw = w["X"][:, CONFIG["wavlm_layer"]].astype(np.float32)
        m_w = m_logreg(CONFIG["logreg_C"]).fit(Xw, w["y"])
        joblib.dump(m_w, os.path.join(args.out_dir, "wavlm_l6_logreg.joblib"))
    json.dump(meta, open(os.path.join(args.out_dir, "meta.json"), "w"), ensure_ascii=False, indent=2)
    print(meta)


if __name__ == "__main__":
    main()
