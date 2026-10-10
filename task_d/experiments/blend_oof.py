"""OOF лучшего бленда D (3 уровня, CatBoost+LGBM, число деревьев из weights/meta.json, 2 seed на модель).
KFold(5, rs=0). -> submissions_d/blend_oof.npz"""
import json, os, sys, warnings
import lightgbm as lgb, numpy as np
from catboost import CatBoostRegressor
from sklearn.model_selection import KFold
warnings.filterwarnings("ignore")
HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__))); ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from common import CAT_FEATURES, TARGET, load  # noqa
from train import CONFIG, LEVELS, prep  # noqa
meta = json.load(open(os.path.join(HERE, "weights", "meta.json"))); seed = meta["seed"]
tr = load(os.path.join(HERE, "data", "hard_train.csv")); y = tr[TARGET].values
Xc, Xl = prep(tr, tr, False, "cat"), prep(tr, tr, True, "lgbm")
NS = int(sys.argv[1]) if len(sys.argv) > 1 else 2
oof = {lvl: np.zeros(len(y)) for lvl in LEVELS}
for f, (a, b) in enumerate(KFold(5, shuffle=True, random_state=0).split(tr)):
    for lvl, p in LEVELS.items():
        mm = meta["models"][lvl]
        for k in range(NS):
            c = CatBoostRegressor(iterations=mm["cat_trees"], learning_rate=CONFIG["cat_lr"], **p["cat"], verbose=0,
                                  cat_features=CAT_FEATURES, random_seed=seed + k, allow_writing_files=False,
                                  thread_count=4).fit(Xc.iloc[a], y[a])
            l = lgb.LGBMRegressor(n_estimators=mm["lgbm_trees"], **CONFIG["lgbm_common"], **p["lgbm"], verbose=-1,
                                  random_state=seed + k).fit(Xl.iloc[a], y[a])
            oof[lvl][b] += (c.predict(Xc.iloc[b]) + l.predict(Xl.iloc[b])) / 2 / NS
        print(f"fold {f} {lvl} done", flush=True)
blend = np.mean([np.clip(oof[l], 0, 100) for l in LEVELS], 0)
print("OOF RMSE blend", np.sqrt(np.mean((blend - y) ** 2)).round(4), {l: np.sqrt(np.mean((oof[l] - y) ** 2)).round(4) for l in LEVELS})
np.savez(os.path.join(ROOT, "submissions_d", "blend_oof.npz"), blend=blend, **oof)
