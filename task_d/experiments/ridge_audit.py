import sys, numpy as np, pandas as pd, warnings; warnings.filterwarnings("ignore")
sys.path.insert(0,'task_d')
from common import load, make_features, CAT_FEATURES, TARGET
from sklearn.linear_model import RidgeCV
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import KFold
tr=load('task_d/data/hard_train.csv'); te=load('task_d/data/hard_test.csv'); y=tr[TARGET].values
print('y min/max', y.min(), y.max(), 'n y>=99.9', (y>=99.9).sum(), 'n y<=0.1', (y<=0.1).sum())
z=np.log(y/(100-y)); print('z range', z.min().round(2), z.max().round(2))
def prep(d, ref):
    X=make_features(d,False)
    for c in X.columns:
        if c not in CAT_FEATURES and ref[c].isna().any():
            X[c+'_na']=X[c].isna().astype(int); X[c]=X[c].fillna(ref[c].median())
    return pd.get_dummies(X,columns=CAT_FEATURES,dtype=float)
Xtr=prep(tr,tr); Xte=prep(te,tr).reindex(columns=Xtr.columns,fill_value=0)
print('test NaN left', int(Xte.isna().sum().sum()), 'missing test cols', set(prep(te,tr).columns)^set(Xtr.columns))
inv=lambda q:100/(1+np.exp(-q))
oof=np.zeros(len(y)); zo=np.zeros(len(y))
for a,b in KFold(5,shuffle=True,random_state=0).split(Xtr):
    m=make_pipeline(StandardScaler(),RidgeCV(alphas=np.logspace(-3,3,13))).fit(Xtr.iloc[a],z[a]); zo[b]=m.predict(Xtr.iloc[b])
oof=inv(zo)
m=make_pipeline(StandardScaler(),RidgeCV(alphas=np.logspace(-3,3,13))).fit(Xtr,z); zt=m.predict(Xte); tst=inv(zt)
old=pd.read_csv('submissions_d/submission_seed_510584_ridge_logit.csv').protection_score.values
print('ridge test == submitted:', np.abs(tst-old).max())
trees_oof=np.load('submissions_d/median/oof_mid.npz')['oof']
best=pd.read_csv('submissions_d/sharp/submission_seed_352773_base_mid_sharp.csv').protection_score.values
d=lambda v: np.round([v.mean(), v.std(), *np.percentile(v,[1,10,50,90,99])],2)
print('ridge  train', d(oof), '\n       test ', d(tst))
print('trees  train', d(trees_oof), '\n best  test ', d(best))
print('diff   train', d(oof-trees_oof), 'RMS', np.sqrt(np.mean((oof-trees_oof)**2)).round(3))
print('       test ', d(tst-best), 'RMS', np.sqrt(np.mean((tst-best)**2)).round(3))
print('ridge z train', d(zo), '\n        test', d(zt))
print('alpha', m[-1].alpha_)
rm=lambda p: np.sqrt(np.mean((np.clip(p,0,100)-y)**2))
print('OOF RMSE ridge', rm(oof).round(3), 'trees', rm(trees_oof).round(3))
# by-level diff
q=pd.qcut(trees_oof,10,labels=False)
for k in range(10):
    s=q==k; print(k, trees_oof[s].mean().round(1), 'ridge-trees mean', (oof-trees_oof)[s].mean().round(2), 'resid trees', (y-trees_oof)[s].mean().round(2), 'resid ridge',(y-oof)[s].mean().round(2), 'rmse t/r', rm(trees_oof[s]) if False else np.sqrt(np.mean((y[s]-trees_oof[s])**2)).round(2), np.sqrt(np.mean((y[s]-oof[s])**2)).round(2))
np.savez('/tmp/claude-0/-home-user-my-project/5023b1af-1c29-5946-bc6d-48ef3a3de8e0/scratchpad/e1.npz', oof=oof, tst=tst)
