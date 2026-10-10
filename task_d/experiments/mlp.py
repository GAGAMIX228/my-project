"""Гипотеза D: модель другого типа (MLP) добавляет разнообразия к деревьям.
Признаки: числовые (медианы + индикаторы пропусков, стандартизация, quantile->normal для
скошенных) + one-hot категорий. MLP 2 слоя, сильный weight decay (метки шумные), 5 seed."""
import os
import sys
import warnings

import numpy as np
import pandas as pd
import torch
import torch.nn as nn
from sklearn.model_selection import KFold
from sklearn.preprocessing import QuantileTransformer

warnings.filterwarnings("ignore")
HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from common import CAT_FEATURES, TARGET, load, make_features  # noqa: E402

torch.set_num_threads(2)
tr = load(os.path.join(HERE, "data", "hard_train.csv"))
te = load(os.path.join(HERE, "data", "hard_test.csv"))
y = tr[TARGET].values.astype(np.float32)


def to_matrix(df, ref_X=None, qt=None):
    X = make_features(df, True)
    X = pd.get_dummies(X, columns=CAT_FEATURES, dtype=float)
    return X


Xtr, Xte = to_matrix(tr), to_matrix(te)
Xte = Xte.reindex(columns=Xtr.columns, fill_value=0)
for c in list(Xtr.columns):
    if Xtr[c].isna().any() or Xte[c].isna().any():
        Xtr[c + "_na"], Xte[c + "_na"] = Xtr[c].isna().astype(float), Xte[c].isna().astype(float)
        med = Xtr[c].median()
        Xtr[c], Xte[c] = Xtr[c].fillna(med), Xte[c].fillna(med)
qt = QuantileTransformer(output_distribution="normal", n_quantiles=500, random_state=0).fit(Xtr)
A, B = qt.transform(Xtr).astype(np.float32), qt.transform(Xte).astype(np.float32)
ym, ys = y.mean(), y.std()


def fit(Xa, ya, seed, epochs=60, wd=3e-2):
    torch.manual_seed(seed)
    m = nn.Sequential(nn.Linear(Xa.shape[1], 128), nn.SiLU(), nn.Dropout(0.2), nn.Linear(128, 64), nn.SiLU(),
                      nn.Dropout(0.2), nn.Linear(64, 1))
    opt = torch.optim.AdamW(m.parameters(), lr=2e-3, weight_decay=wd)
    sched = torch.optim.lr_scheduler.OneCycleLR(opt, max_lr=2e-3, total_steps=epochs * int(np.ceil(len(Xa) / 128)))
    Xt, yt = torch.from_numpy(Xa), torch.from_numpy((ya - ym) / ys)
    g = torch.Generator().manual_seed(seed)
    for _ in range(epochs):
        m.train()
        perm = torch.randperm(len(Xt), generator=g)
        for i in range(0, len(Xt), 128):
            idx = perm[i:i + 128]
            loss = ((m(Xt[idx]).squeeze(1) - yt[idx]) ** 2).mean()
            opt.zero_grad()
            loss.backward()
            opt.step()
            sched.step()
    m.eval()
    return m


def pred(m, X):
    with torch.no_grad():
        return m(torch.from_numpy(X)).squeeze(1).numpy() * ys + ym


# CV для ориентира (на шумных метках): сравнить с LGBM ~10.44
oof = np.zeros(len(y))
for k, (a, b) in enumerate(KFold(5, shuffle=True, random_state=0).split(A)):
    oof[b] = pred(fit(A[a], y[a], k), A[b])
print("MLP CV RMSE (шумные метки):", round(float(np.sqrt(np.mean((np.clip(oof, 0, 100) - y) ** 2))), 3), flush=True)
p = np.clip(np.mean([pred(fit(A, y, 352773 + k), B) for k in range(5)], 0), 0, 100)
best = pd.read_csv(os.path.join(ROOT, "submissions_d/sharp/submission_seed_352773_base_mid_sharp.csv"))
print("RMSE MLP к сабмиту 77.25:", round(float(np.sqrt(np.mean((p - best.protection_score) ** 2))), 2), flush=True)
od = os.path.join(ROOT, "submissions_d/mlp")
os.makedirs(od, exist_ok=True)
pd.DataFrame({"customer_id": te.customer_id, "protection_score": p}).to_csv(f"{od}/mlp_only.csv", index=False)
for w in (0.2, 0.33):
    q = (1 - w) * best.protection_score.values + w * p
    pd.DataFrame({"customer_id": te.customer_id, "protection_score": q}).to_csv(
        f"{od}/submission_seed_352773_trees_mlp{int(w * 100)}.csv", index=False)
print("готово", flush=True)
