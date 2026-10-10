"""Задача D: «Клиент под защитой» — регрессия protection_score (0–100), метрика RMSE."""
import numpy as np
import pandas as pd

TARGET = "protection_score"
ID = "customer_id"
CAT_FEATURES = ["region", "city_type", "gender", "education", "family_status", "employment", "wealth_segment"]
INSURANCE = ["life_insurance", "property_insurance", "health_insurance", "travel_insurance",
             "car_insurance", "gadget_insurance", "cyber_protection", "identity_protection"]


def load(path):
    return pd.read_csv(path)


def make_features(df, extra=True):
    X = df.drop(columns=[c for c in (ID, TARGET) if c in df.columns]).copy()
    if extra:
        has_car, has_house = X["car_value"].notna(), X["house_value"].notna()
        # «покрытие рисков»: есть актив/риск и есть соответствующая страховка
        X["car_covered"] = (has_car & (X["car_insurance"] == 1)).astype(int)
        X["car_uncovered"] = (has_car & (X["car_insurance"] == 0)).astype(int)
        X["house_covered"] = (has_house & (X["property_insurance"] == 1)).astype(int)
        X["house_uncovered"] = (has_house & (X["property_insurance"] == 0)).astype(int)
        X["family_life_covered"] = ((X["children"] > 0) & (X["life_insurance"] == 1)).astype(int)
        X["cyber_hygiene"] = X[["password_manager", "two_factor_auth", "security_training",
                                "cyber_protection", "identity_protection"]].sum(1)
        X["policy_ratio"] = X["active_policies"] / (X["active_policies"] + X["expired_policies"] + 1)
        X["coverage_share"] = X["insurance_products"] / 8
        X["loan_to_income"] = X["loan_amount"] / X["income"]
        X["assets"] = X["house_value"].fillna(0) + X["car_value"].fillna(0)
    return X
