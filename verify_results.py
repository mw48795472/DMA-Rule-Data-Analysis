"""Independent numerical audit; no model selection or edits to input data."""
from pathlib import Path
import csv,json
import numpy as np
ROOT=Path(__file__).resolve().parent
def read(p):return list(csv.DictReader(open(p,encoding='utf-8-sig')))
def save(p,rows):
    with open(p,'w',encoding='utf-8-sig',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
checks=[];vif_checks=[]
for folder in sorted((ROOT/'outputs').iterdir()):
    if not folder.is_dir() or not (folder/'model_comparison.csv').exists():continue
    data=read(folder/'sample.csv');scales=read(folder/'scaling.csv');zvars=[r['term'] for r in scales]
    wr=read(folder/'weights.csv');ids=[r['id'] for r in data]
    assert ids==[r['id'] for r in wr]
    W=np.array([[float(r[c]) for c in ids] for r in wr]); y=np.array([float(r['outcome']) for r in data]);n=len(y)
    X=np.array([[1]+[float(r[v]) for v in zvars] for r in data])
    coeff=read(folder/'coefficients.csv');vr=read(folder/'vif.csv')
    for r in read(folder/'model_comparison.csv'):
        m=r['model'];a=float(r['spatial_parameter']);A=np.eye(n)-a*W
        lags=zvars if m=='SDM_full' else ['z_exposure'] if m=='SDM_exposure' else []
        Z=np.column_stack([X]+[W@X[:,zvars.index(v)+1] for v in lags])
        labels=['(Intercept)']+zvars+['lag.'+v for v in lags]
        betas={c['term']:float(c['estimate_standardized_X']) for c in coeff if c['model']==m}
        b=np.array([betas[v] for v in labels]); e=A@(y-Z@b) if m=='SEM' else A@y-Z@b
        logdet=0 if m=='OLS' else np.linalg.slogdet(A)[1]
        ll=logdet-n/2*(np.log(2*np.pi)+1+np.log(e@e/n))
        zz=e-e.mean();I=n/W.sum()*(zz@W@zz)/(zz@zz)
        dl=abs(ll-float(r['logLik']));di=abs(I-float(r['innovation_I']))
        assert dl<1e-7 and di<1e-8,(folder.name,m,dl,di)
        checks.append(dict(group=folder.name,model=m,logLik_abs_difference=dl,innovation_I_abs_difference=di,passed=True))
        for j,label in enumerate(labels[1:],1):
            yy=Z[:,j];xx=np.delete(Z,j,axis=1);eh=yy-xx@np.linalg.lstsq(xx,yy,rcond=None)[0]
            vif=np.sum((yy-yy.mean())**2)/np.sum(eh**2)
            rv=float(next(t['VIF'] for t in vr if t['model']==m and t['term']==label))
            delta=abs(vif-rv);assert delta<1e-7
            vif_checks.append(dict(group=folder.name,model=m,term=label,VIF_python=vif,absolute_difference=delta))
save(ROOT/'outputs'/'python_ML_Moran_validation.csv',checks)
save(ROOT/'outputs'/'python_VIF_validation.csv',vif_checks)
print(json.dumps({'models_checked':len(checks),'VIFs_checked':len(vif_checks),'max_logLik_diff':max(r['logLik_abs_difference'] for r in checks),'max_Moran_diff':max(r['innovation_I_abs_difference'] for r in checks),'max_VIF_diff':max(r['absolute_difference'] for r in vif_checks)},indent=2))
