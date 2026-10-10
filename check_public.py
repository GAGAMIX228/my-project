"""Compare out\\A..D (made by run_private.ps1 on the PUBLIC tests) with the best public-LB submissions in reference\\.
    python check_public.py
"""
import glob
import os

import numpy as np
import pandas as pd

HERE = os.path.dirname(os.path.abspath(__file__))
REF, OUT = os.path.join(HERE, "reference"), os.path.join(HERE, "out")
ok = True


def one(pattern):
    files = glob.glob(os.path.join(OUT, pattern))
    return files[0] if files else None


def report(task, good, msg):
    global ok
    ok &= good
    print(f"[{task}] {'OK  ' if good else 'FAIL'} {msg}")


f = one(os.path.join("A", "submission_seed_*.npz"))
if f:
    got = np.load(f, allow_pickle=True)["targets"].astype(str)
    ref = pd.read_csv(os.path.join(REF, "A_targets.csv"))["target"].astype(str).values
    report("A", len(got) == len(ref) and (got == ref).all(),
           f"{os.path.basename(f)}: {len(got)} rows, match {np.mean(got == ref) if len(got) == len(ref) else 0:.4f} (LB 77.49)")
else:
    report("A", False, "out\\A\\submission_seed_*.npz not found")

for task, col, lb in [("B", "accepted", "96.70"), ("C", "score", "99.01"), ("D", "protection_score", "77.25")]:
    f = one(os.path.join(task, "submission_seed_*.csv"))
    if not f:
        report(task, False, f"out\\{task}\\submission_seed_*.csv not found")
        continue
    got, ref = pd.read_csv(f), pd.read_csv(os.path.join(REF, f"{task}.csv"))
    same_ids = len(got) == len(ref) and (got.iloc[:, 0].astype(str).values == ref.iloc[:, 0].astype(str).values).all()
    diff = float(np.abs(got[col].values - ref[col].values).max()) if same_ids else float("inf")
    report(task, same_ids and diff < 1e-6, f"{os.path.basename(f)}: {len(got)} rows, ids match {same_ids}, max |diff| {diff:.2e} (LB {lb})")

print("\nALL OK" if ok else "\nSOME CHECKS FAILED - send this output to Claude")
