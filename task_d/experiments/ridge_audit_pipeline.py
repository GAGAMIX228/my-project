import sys, numpy as np, pandas as pd, warnings; warnings.filterwarnings("ignore")
sys.path.insert(0,'task_d')
from common import load, make_features, CAT_FEATURES, TARGET
from sklearn.linear_model import RidgeCV
from sklearn.pipeline import make_pipeline
from sklearn.compose import ColumnTransformer
from sklearn.impute import SimpleImputer
from sklearn.preprocessing import StandardScaler, OneHotEncoder
from sklearn.model_selection import KFold, cross_val_predict
tr=load('task_d/data/hard_train.csv'); y=tr[TARGET].values; z=np.log(y/(100-y))
X=make_features(tr,False); num=[c for c in X.columns if c not in CAT_FEATURES]
print('n', len(y), 'num', len(num))
pre=ColumnTransformer([('num',make_pipeline(SimpleImputer(strategy='median',add_indicator=True),StandardScaler()),num),
                       ('cat',OneHotEncoder(handle_unknown='ignore'),CAT_FEATURES)])
rm=lambda p: np.sqrt(np.mean((p-y)**2)); inv=lambda q:100/(1+np.exp(-q))
for rs in [0,1,2]:
    kf=KFold(5,shuffle=True,random_state=rs)
    p=cross_val_predict(make_pipeline(pre,RidgeCV(alphas=np.logspace(-3,3,13))),X,z,cv=kf)
    print('rs',rs,'pipeline ridge-logit OOF RMSE', rm(inv(p)).round(3))
kf=KFold(10,shuffle=True,random_state=0)
p=cross_val_predict(make_pipeline(pre,RidgeCV(alphas=np.logspace(-3,3,13))),X,z,cv=kf)
print('10-fold', rm(inv(p)).round(3))
# ridge on y directly
p=cross_val_predict(make_pipeline(pre,RidgeCV(alphas=np.logspace(-3,3,13))),X,y,cv=KFold(5,shuffle=True,random_state=0))
print('ridge on y', rm(p).round(3))
