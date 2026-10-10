"""Задача B: «Защищённый смартфон». Общие функции: загрузка, признаки, порог под F1."""
import os
import random

import numpy as np
import pandas as pd
from sklearn.metrics import f1_score

TARGET = "accepted"
ID = "customer_id"
CAT_FEATURES = ["gender", "region", "family_status", "education", "employment_type", "smartphone_brand"]


def set_seed(seed: int) -> None:
    random.seed(seed)
    np.random.seed(seed)
    os.environ["PYTHONHASHSEED"] = str(seed)


def load(path: str) -> pd.DataFrame:
    return pd.read_csv(path)


def make_features(df: pd.DataFrame, extra: bool = True) -> pd.DataFrame:
    """Базовые признаки + (extra=True) сгенерированные. Пропуски оставляем: бустинг
    обрабатывает NaN сам, а сам факт пропуска информативен (нет кредита / нет приложения)."""
    X = df.drop(columns=[c for c in (ID, TARGET) if c in df.columns]).copy()
    for c in CAT_FEATURES:
        if c in X.columns:
            X[c] = X[c].astype(str)
    if extra:
        inc = X["monthly_income"].clip(lower=1)
        X["phone_price_to_income"] = X["smartphone_price"] / inc
        X["balance_to_income"] = X["average_monthly_balance"] / inc
        X["loan_to_income"] = X["loan_amount"] / inc
        X["phone_value_left"] = X["smartphone_price"] * (1 - X["smartphone_age_months"] / 48)
        X["app_missing"] = X["mobile_app_usage"].isna().astype(int)
        X["credit_score_missing"] = X["credit_score"].isna().astype(int)
        X["claims_per_year"] = X["insurance_claims"] / (X["years_with_bank"] + 1)
        X["log_city_population"] = np.log1p(X["city_population"])
    return X


def best_threshold(y, proba):
    """Порог вероятности, максимизирующий F1 (по сетке 0.05..0.95)."""
    grid = np.linspace(0.05, 0.95, 181)
    scores = [f1_score(y, proba >= t) for t in grid]
    i = int(np.argmax(scores))
    return float(grid[i]), float(scores[i])
