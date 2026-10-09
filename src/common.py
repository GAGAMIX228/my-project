"""Общие утилиты: загрузка данных, фиксация seed, MLP, подбор весов классов под macro-F1."""
import os
import random

import numpy as np
import torch
import torch.nn as nn
from sklearn.metrics import f1_score

CLASSES = np.array(["angry", "neutral", "positive", "sad"])


def set_seed(seed: int) -> None:
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    torch.cuda.manual_seed_all(seed)
    os.environ["PYTHONHASHSEED"] = str(seed)
    torch.backends.cudnn.deterministic = True
    torch.backends.cudnn.benchmark = False


def load_npz(path: str):
    data = np.load(path, allow_pickle=True)
    X = data["embeddings"].astype(np.float32)
    y = data["targets"] if "targets" in data.files else None
    return X, y


def encode_targets(y):
    """Метки могут прийти строками или числами — приводим к индексам CLASSES."""
    y = np.asarray(y)
    if y.dtype.kind in "iu":
        return y.astype(np.int64)
    y = np.char.lower(np.char.strip(y.astype(str)))
    idx = {c: i for i, c in enumerate(CLASSES)}
    return np.array([idx[v] for v in y], dtype=np.int64)


def macro_f1(y_true, y_pred) -> float:
    return f1_score(y_true, y_pred, average="macro")


# ---------- предобработка ----------

class Preprocessor:
    """L2-нормализация (опционально) + стандартизация по статистикам train."""

    def __init__(self, l2: bool = False):
        self.l2 = l2
        self.mean = None
        self.std = None

    def _l2(self, X):
        return X / (np.linalg.norm(X, axis=1, keepdims=True) + 1e-8)

    def fit(self, X):
        if self.l2:
            X = self._l2(X)
        self.mean = X.mean(0).astype(np.float32)
        self.std = (X.std(0) + 1e-6).astype(np.float32)
        return self

    def transform(self, X):
        if self.l2:
            X = self._l2(X)
        return ((X - self.mean) / self.std).astype(np.float32)

    def state(self):
        return {"l2": self.l2, "mean": self.mean, "std": self.std}

    @classmethod
    def from_state(cls, s):
        p = cls(l2=bool(s["l2"]))
        p.mean, p.std = s["mean"], s["std"]
        return p


# ---------- MLP ----------

class MLP(nn.Module):
    def __init__(self, in_dim: int, hidden=(512, 256), n_classes: int = 4, dropout: float = 0.3):
        super().__init__()
        layers, d = [], in_dim
        for h in hidden:
            layers += [nn.Linear(d, h), nn.BatchNorm1d(h), nn.GELU(), nn.Dropout(dropout)]
            d = h
        layers.append(nn.Linear(d, n_classes))
        self.net = nn.Sequential(nn.Dropout(dropout / 2), *layers)

    def forward(self, x):
        return self.net(x)


class TwoTowerMLP(nn.Module):
    """Эмбеддинг = конкатенация двух L2-нормированных векторов по 1024 (почти некоррелированных).
    Каждую половину обрабатывает своя «башня», затем общая голова."""

    def __init__(self, in_dim: int, hidden=(256, 256), n_classes: int = 4, dropout: float = 0.3):
        super().__init__()
        half, (h_tower, h_head) = in_dim // 2, hidden
        self.half = half

        def tower():
            return nn.Sequential(nn.Dropout(dropout / 2), nn.Linear(half, h_tower),
                                 nn.BatchNorm1d(h_tower), nn.GELU(), nn.Dropout(dropout))
        self.t0, self.t1 = tower(), tower()
        self.head = nn.Sequential(nn.Linear(2 * h_tower, h_head), nn.BatchNorm1d(h_head), nn.GELU(),
                                  nn.Dropout(dropout), nn.Linear(h_head, n_classes))

    def forward(self, x):
        return self.head(torch.cat([self.t0(x[:, :self.half]), self.t1(x[:, self.half:])], 1))


def build_model(in_dim, arch="mlp", hidden=(512, 256), dropout=0.3):
    cls = TwoTowerMLP if arch == "twotower" else MLP
    return cls(in_dim, tuple(hidden), len(CLASSES), dropout)


def count_params(model: nn.Module) -> int:
    return sum(p.numel() for p in model.parameters())


def class_weights(y, power: float):
    """power=0 — без весов, 0.5 — sqrt(обратной частоты), 1 — обратная частота."""
    counts = np.bincount(y, minlength=len(CLASSES)).astype(np.float64)
    w = (counts.sum() / counts) ** power
    return (w / w.mean()).astype(np.float32)


def train_mlp(X_tr, y_tr, X_va=None, y_va=None, *, seed, hidden=(512, 256), dropout=0.3,
              epochs=40, batch_size=512, lr=2e-3, weight_decay=1e-2, label_smoothing=0.05,
              cw_power=0.5, mixup=0.0, arch="mlp", device="cpu", verbose=False):
    """Обучает MLP. Если передан val — сохраняет лучшую по macro-F1 эпоху.
    Возвращает (model, best_epoch, best_f1)."""
    set_seed(seed)
    model = build_model(X_tr.shape[1], arch, hidden, dropout).to(device)
    opt = torch.optim.AdamW(model.parameters(), lr=lr, weight_decay=weight_decay)
    steps = epochs * int(np.ceil(len(X_tr) / batch_size))
    sched = torch.optim.lr_scheduler.OneCycleLR(opt, max_lr=lr, total_steps=steps, pct_start=0.1)
    w = torch.tensor(class_weights(y_tr, cw_power), device=device)
    crit = nn.CrossEntropyLoss(weight=w, label_smoothing=label_smoothing)

    Xt = torch.from_numpy(X_tr).to(device)
    yt = torch.from_numpy(y_tr).to(device)
    g = torch.Generator(device="cpu").manual_seed(seed)

    best_f1, best_ep, best_state = -1.0, epochs, None
    for ep in range(epochs):
        model.train()
        perm = torch.randperm(len(Xt), generator=g).to(device)
        for i in range(0, len(Xt), batch_size):
            idx = perm[i:i + batch_size]
            xb, yb = Xt[idx], yt[idx]
            if mixup > 0:
                lam = float(np.random.beta(mixup, mixup))
                j = torch.randperm(len(xb), generator=g).to(device)
                out = model(lam * xb + (1 - lam) * xb[j])
                loss = lam * crit(out, yb) + (1 - lam) * crit(out, yb[j])
            else:
                loss = crit(model(xb), yb)
            opt.zero_grad()
            loss.backward()
            opt.step()
            sched.step()
        if X_va is not None:
            f1 = macro_f1(y_va, predict_proba_mlp(model, X_va, device).argmax(1))
            if verbose:
                print(f"  epoch {ep + 1:3d}  val macro-F1 {f1:.4f}")
            if f1 > best_f1:
                best_f1, best_ep = f1, ep + 1
                best_state = {k: v.detach().clone() for k, v in model.state_dict().items()}
    if best_state is not None:
        model.load_state_dict(best_state)
    return model, best_ep, best_f1


@torch.no_grad()
def predict_proba_mlp(model, X, device="cpu", batch_size=4096):
    model.eval()
    out = []
    for i in range(0, len(X), batch_size):
        xb = torch.from_numpy(X[i:i + batch_size]).to(device)
        out.append(torch.softmax(model(xb), 1).cpu().numpy())
    return np.concatenate(out)


# ---------- подбор весов классов под macro-F1 ----------

def fit_class_scales(proba, y, n_rounds: int = 3):
    """Координатный спуск по множителям вероятностей классов: argmax(p * s).
    Метрика macro-F1 не совпадает с log-loss, поэтому сдвиг порогов в пользу
    редких классов обычно даёт прирост. Подбирать строго на OOF-предсказаниях."""
    s = np.ones(proba.shape[1])
    grid = np.exp(np.linspace(np.log(0.25), np.log(4.0), 41))
    best = macro_f1(y, proba.argmax(1))
    for _ in range(n_rounds):
        for c in range(proba.shape[1]):
            for v in grid:
                t = s.copy()
                t[c] = v
                f = macro_f1(y, (proba * t).argmax(1))
                if f > best + 1e-6:
                    best, s = f, t
    return s / s[np.argmax(np.bincount(y))], best  # нормируем на мажоритарный класс


def cross_fitted_scaled_f1(proba, y, folds: int = 5, seed: int = 0):
    """Честная оценка эффекта fit_class_scales: множители подбираются на одних
    фолдах OOF, а macro-F1 считается на отложенном."""
    from sklearn.model_selection import StratifiedKFold
    pred = np.zeros(len(y), dtype=np.int64)
    for fit_idx, ev_idx in StratifiedKFold(folds, shuffle=True, random_state=seed).split(proba, y):
        s, _ = fit_class_scales(proba[fit_idx], y[fit_idx])
        pred[ev_idx] = (proba[ev_idx] * s).argmax(1)
    return macro_f1(y, pred)


def em_prior_shift(proba, train_prior, n_iter: int = 100, tol: float = 1e-6):
    """Оценка частот классов на неразмеченном тесте (Saerens et al., 2002).
    proba — вероятности модели, обученной при частотах train_prior.
    Возвращает (оценка test_prior, пересчитанные под неё вероятности)."""
    train_prior = np.asarray(train_prior, dtype=np.float64)
    prior = train_prior.copy()
    for _ in range(n_iter):
        adj = proba * (prior / train_prior)
        adj /= adj.sum(1, keepdims=True)
        new = adj.mean(0)
        if np.abs(new - prior).max() < tol:
            prior = new
            break
        prior = new
    adj = proba * (prior / train_prior)
    return prior, adj / adj.sum(1, keepdims=True)
