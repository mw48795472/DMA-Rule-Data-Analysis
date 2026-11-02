"""Build Markdown research chapters from checked-in results and actual R source.
No model is re-estimated here. GitHub Pages/Jekyll renders docs/*.md.
"""
from pathlib import Path
import csv, hashlib, json, re, shutil

ROOT=Path(__file__).resolve().parents[1]
DOCS=ROOT/'docs'
REPO='https://github.com/mw48795472/DMA-Rule-Data-Analysis'
SITE='https://mw48795472.github.io/DMA-Rule-Data-Analysis/'
figures=json.loads((ROOT/'reports/plot_interpretations_20261102.json').read_text(encoding='utf8'))['figures']
for folder in ['assets/plots','downloads']:(DOCS/folder).mkdir(parents=True,exist_ok=True)

def write(name,text):
    (DOCS/name).write_text(text,encoding='utf8',newline='\n')

def front(title,order):
    return f'---\nlayout: default\ntitle: "{title}"\norder: {order}\n---\n\n'

def source_link(path):return REPO+'/blob/main/'+path

def excerpt(path,start,end,language='r'):
    lines=(ROOT/path).read_text(encoding='utf-8-sig').splitlines()
    a=next(i for i,l in enumerate(lines) if start in l)
    b=next(i for i in range(a+1,len(lines)) if end in lines[i])
    return ('```'+language+'\n'+'\n'.join(lines[a:b]).strip()+'\n```\n\n'
            +f'[실제 코드 · {path} L{a+1}–L{b}]({source_link(path)}#L{a+1}-L{b})\n\n')

def plot_md(number,summary=False):
    f=figures[number-1]
    body=f'![그림 {number:02d}. {f["title"]}](assets/plots/{f["name"]}.png)\n\n'
    body+=f'**{f["takeaway"]}** {f["result"]}\n\n'
    if not summary:
        body+=f'**브뤼셀 효과 관점** · {f["brussels"]}\n\n**티부 효과 관점** · {f["tiebout"]}\n\n**해석의 한계** · {f["limits"]}\n\n'
    return body

def table(path,columns,predicate=lambda r:True,fmt=None):
    rows=list(csv.DictReader((ROOT/path).open(encoding='utf-8-sig')))
    lines=['| '+' | '.join(columns)+' |','| '+' | '.join('---' for _ in columns)+' |']
    for row in filter(predicate,rows):
        values=[]
        for c in columns:
            v=row[c]
            if fmt and c in fmt:
                try:v=format(float(v),fmt[c])
                except ValueError:pass
            values.append(v.replace('|','/'))
        lines.append('| '+' | '.join(values)+' |')
    return '\n'.join(lines)+'\n\n'+f'[결과 CSV]({source_link(path)})\n\n'

for f in figures:shutil.copy2(ROOT/f['png'],DOCS/'assets/plots'/Path(f['png']).name)
for name in ['compliance_scope','firm_case_types','flow_coverage']:
    shutil.copy2(ROOT/f'outputs/mechanisms_20261102/integration/figure_{name}.png',DOCS/f'assets/plots/figure_{name}.png')
for name in ['DMA_Mechanisms_Research_Design_20261102.pdf','DMA_PoC_20plots_Report.pdf']:
    shutil.copy2(ROOT/'reports'/name,DOCS/'downloads'/name)

overview=front('DMA 규범 확산과 국제 이동',1)+'''# 규범은 어디로 퍼지고, 생산요소는 어디로 이동하는가

유럽 디지털시장법(DMA)을 둘러싼 **브뤼셀 효과**와 **티부형 이동**을 구분하기 위한 공간분석·자료 구축 PoC입니다. 기존 공간회귀 결과와 추가 수집한 준수 변화·국가쌍 자료를 연결해, 현재 무엇을 관측했고 무엇을 아직 검증하지 못했는지 설명합니다.

> 자료 기준일 **2026-11-02** · 국가 패널 **32개국 × 9년 = 288행** · 지역 회귀 **218개 지역** · 그림 **23개**

## 먼저 읽을 결과

1. **공간지연 설명변수를 제한하면 공선성이 낮아집니다.** 확장형 전체 SDM의 최대 VIF는 43.29, 노출도에만 공간지연을 둔 제한형은 4.10입니다. 표준화 자체가 VIF를 낮추지는 않습니다.
2. **국가 수준에서 SDM의 일관된 우위는 확인되지 않았습니다.** 간결형에서는 OLS의 AICc가 가장 작고, 확장형 SEM의 낮은 AICc에는 공간계수 경계 추정 문제가 있습니다.
3. **지역 SDM 잔차 검정은 경계적입니다.** 부트스트랩 9,999회에서 p=0.0526입니다. 몬테카를로 구간이 0.05를 가로지르므로 “공간의존성을 완전히 제거했다”는 결론은 피합니다.
4. **규범 확산과 실제 이동은 관측 단위부터 다릅니다.** 준수 변경의 적용 시장과 기업·사업장·자본·인력의 출발지–목적지를 각각 측정합니다. 현재 자료로 DMA가 이동을 유발했다고 확정하지 않습니다.

## 분석을 따라 읽는 순서

| 질문 | 문서 |
|---|---|
| 어떻게 결합하고 검정했는가? | [전처리 → VIF → Moran → 공간회귀](analysis.html) |
| 각 그림은 어떤 코드와 결과에서 나왔는가? | [23개 plot과 코드·해석](plots.html) |
| 두 효과를 어떻게 구분해 검증할 것인가? | [추가 자료와 연구설계](mechanisms.html) |
| RStudio에서 어떻게 다시 실행하는가? | [재현과 원천자료](reproduce.html) |

## 공간지연변수 구성과 공선성

분석에서는 원래 설명변수 X와 공간지연 WX를 함께 포함한 설계행렬의 VIF를 확인했습니다. 아래는 실제 설계행렬 생성 코드입니다. `SDM_full`은 모든 X를, `SDM_exposure`는 사전 노출도만 공간지연합니다.

'''
overview+=excerpt('code/03_models.R','design_matrix<-','model_type<-')+plot_md(3,True)
overview+='## 모형 선택과 결과의 안정성\n\n'+plot_md(4,True)
overview+='간결형 EU27 동일 표본의 저장 결과입니다. 다른 결과변수·표본 간 정보기준을 섞지 않습니다.\n\n'
overview+=table('outputs/all_model_comparisons.csv',['model','n','AICc','spatial_parameter','near_boundary'],lambda r:r['group']=='parsimonious',{'AICc':'.2f','spatial_parameter':'.3f'})
overview+='## 잔차 검정의 정밀도\n\n'+plot_md(13,True)
overview+='## 준수 변화와 국가 간 흐름을 별도로 측정\n\n'
overview+='![준수 기록의 적용범위](assets/plots/figure_compliance_scope.png)\n\n공식 자료에서 정리한 변경 12개와 현재 범위 스냅샷 1개입니다. 발표·회사 자기보고·확인된 시행일을 분리하며, 스냅샷을 과거로 소급하지 않습니다. 전체 게이트키퍼의 준수율을 나타내는 표본은 아닙니다.\n\n'
overview+='![국가쌍 자료의 수치 관측률](assets/plots/figure_flow_coverage.png)\n\n국가쌍 자료 205,784행 중 85,278행에 수치가 있습니다. 연령·방향·산업·단위별 차원을 포함한 행 수이며, 고유 이동 사건 수가 아닙니다. 일반 이민과 ICT 인력 이동, FDI와 실물 사업장 이전도 구분합니다.\n\n'
overview+='## 보고서와 자료\n\n[연구설계 보고서 PDF · 15쪽](downloads/DMA_Mechanisms_Research_Design_20261102.pdf) · [기존 20개 그림 보고서 PDF · 30쪽](downloads/DMA_PoC_20plots_Report.pdf) · [전체 저장소]('+REPO+')\n\n웹 문서는 Markdown으로 관리하며, 분석 단계마다 실제 R 코드 발췌와 저장된 결과를 함께 제시합니다. 웹 게시 과정에서는 모형을 새로 추정하지 않습니다.\n'
write('index.md',overview)

analysis=front('전처리와 공간분석 코드',2)+'''# 전처리에서 공간회귀까지

각 단계는 **분석 질문 → 실제 R 코드 → 저장 결과 → 해석** 순서입니다. 발췌 코드는 전체 파이프라인의 일부이므로 앞 단계의 객체가 필요합니다. 완전한 실행 진입점은 [재현 안내](reproduce.html)를 참고하세요.

## 1. 결측과 국가·연도 키를 점검한다

국가·연도 키의 중복을 먼저 검사하고 원래 288행을 유지하는 왼쪽 결합을 수행합니다. 없는 연도의 값을 이월하거나 누락을 0으로 대체하지 않습니다.

'''
analysis+=excerpt('code/02_join_audit.R','before<-panel','bb<-split')+plot_md(1,True)
analysis+='## 2. SHP와 지역코드의 유효성을 확인한다\n\n국가 수치를 지역 자료에 복제하지 않습니다. NUTS 2024 코드 일치와 실제 통계 경계의 일치는 구별합니다.\n\n'
analysis+=excerpt('code/02_join_audit.R','shp<-list.files','rp<-suppressWarnings')+plot_md(2,True)
analysis+='## 3. 표본 순서와 공간가중치 W를 고정한다\n\nk=4 최근접 이웃 관계를 대칭 합집합으로 만들고 행 표준화합니다. 대칭화 전의 k와 최종 이웃 수는 다를 수 있습니다. W의 대각 원소는 0이며 각 행의 합은 1인지 검사합니다.\n\n'
analysis+=excerpt('code/03_models.R','make_weights <-','moran_value<-')
analysis+='## 4. X와 WX의 VIF를 함께 본다\n\nVIF는 각 설명변수를 나머지 열로 회귀한 설명력으로 계산합니다. X만 검사하면 WX와의 공선성을 놓칠 수 있습니다. 제한형은 가설상 핵심인 사전 노출도에만 지연항을 둡니다.\n\n'
analysis+=excerpt('code/03_models.R','vif_values<-','interval<-')+excerpt('code/03_models.R','design_matrix<-','model_type<-')+plot_md(3)
analysis+='## 5. 원변수의 Moran’s I와 회귀 잔차 검정을 구분한다\n\n원변수는 무작위배치 순열검정, OLS 잔차는 회귀 적합을 반영한 검정을 사용합니다. 공간모형의 혁신잔차는 해당 모형을 재적합하는 부트스트랩으로 진단합니다.\n\n'
analysis+=excerpt('code/03_models.R',' set.seed(cfg$seed);raw<-',' X<-model.matrix')+plot_md(5)
analysis+='## 6. 동일 표본에서 OLS·SAR·SEM·SDM을 적합한다\n\n다음은 `run_group()` 내부의 실제 적합 함수입니다. `ff`에는 같은 표준화 설명변수를 사용하고, SDM에서만 Durbin 항을 추가합니다. SEM의 오차 공간의존성과 SAR의 종속변수 공간지연을 구별합니다.\n\n'
analysis+=excerpt('code/03_models.R',' fit_one<-',' fits<-setNames')+plot_md(4)
analysis+='## 7. SDM 직접·간접·총효과를 분해한다\n\n공간승수를 반영한 직접효과와 총효과의 차이를 간접효과로 정의합니다. 계산된 간접효과를 곧바로 EU 규범의 해외 확산으로 해석할 수는 없습니다.\n\n'
analysis+=excerpt('code/03_models.R','impact_values<-','run_group<-')+plot_md(6)
analysis+='## 8. 지역 SDM 잔차 검정의 반복 횟수를 늘린다\n\n동일한 y·X·W·난수열을 유지하고, 모의 결과마다 모형을 다시 적합합니다. 199회에서 9,999회로 늘린 것은 검정의 시뮬레이션 정밀도이며 정책 효과의 변화가 아닙니다.\n\n'
analysis+=excerpt('code/07_refine_regional_bootstrap.R','summarise_B<-','checks<-do.call')+table('outputs/regional_sdm_bootstrap_comparison.csv',['simulations','p_bootstrap','MC_SE_approx','MC_lower','MC_upper'],fmt={'p_bootstrap':'.4f','MC_SE_approx':'.4f','MC_lower':'.4f','MC_upper':'.4f'})+plot_md(13)
analysis+='## 9. 영국·비EU 범위와 연령 정의를 별도로 비교한다\n\n'+plot_md(16)+plot_md(18)
analysis+='## 10. LTA는 아직 연구 준비 단계다\n\n'+plot_md(20)+'[전체 그림과 시각화 코드 보기](plots.html) · [브뤼셀 효과·티부형 이동의 후속 검증 설계](mechanisms.html)\n'
write('analysis.md',analysis)

plot_lines=(ROOT/'code/11_plot_saved_results.R').read_text(encoding='utf8').splitlines()
save_indices=[i for i,l in enumerate(plot_lines) if re.search(r'(?:save_plot|savefig|dma_save_plot)\(p,"\d{2}_',l)]
def plot_code(f):
    b=next(i for i in save_indices if '"'+f['name']+'"' in plot_lines[i])
    previous=max([i for i in save_indices if i<b],default=25)
    a=previous+1
    if b-a>22:a=b-22
    code='\n'.join(plot_lines[a:b+1]).strip()
    return f'```r\n{code}\n```\n\n[전체 시각화 코드 · L{a+1}–L{b+1}]({source_link("code/11_plot_saved_results.R")}#L{a+1}-L{b+1})\n\n'
gallery=front('23개 plot · 코드와 해석',3)+'''# 그림을 코드와 함께 읽기

기존 공간분석 20개와 추가 자료 검토 3개를 모았습니다. 각 그림 아래에 관측 결과, 두 이론의 해석 범위, 한계와 실제 시각화 코드가 이어집니다. 발췌 코드에 사용하는 데이터 객체·공통 함수는 전체 R 파일 앞부분에서 정의합니다.

```r
# RStudio 프로젝트에서 실행: 저장 결과로 20개 그림을 생성합니다.
source("RUN_PLOTS.R", encoding = "UTF-8")
# 추가 자료와 그림 3개
source("RUN_MECHANISMS.R", encoding = "UTF-8")
```

## 그림 목록

'''
gallery+='\n'.join(f'- [그림 {f["number"]:02d} · {f["title"]}](#fig-{f["number"]:02d})' for f in figures)
gallery+='\n- [추가 그림 M1–M3 · 준수·기업 사건·흐름 가용성](#mechanism-plots)\n\n'
for f in figures:
    n=f['number'];gallery+=f'## 그림 {n:02d} · {f["title"]} {{#fig-{n:02d}}}\n\n'+plot_md(n)+f'### 이 그림을 만드는 핵심 코드\n\n'+plot_code(f)
    gallery+='**결과 원천 파일**: '+', '.join('`'+s+'`' for s in f['sources'])+'\n\n'
gallery+='## 추가 그림 M1–M3 {#mechanism-plots}\n\n[추가 자료와 연구설계](mechanisms.html)에는 세 그림의 자료 로딩·결합 검사 코드와 두 메커니즘의 구분 기준이 함께 있습니다.\n\n'
extra=[('compliance_scope','M1 · 준수 기록의 적용범위','13개 목적표집 기록은 전체 게이트키퍼의 준수율이 아닙니다.'),('firm_case_types','M2 · 기업 사건의 유형','11개 사건은 공개 사례입니다. 실제 이전 완료·목적지별 인력 이동과 발표를 구분합니다.'),('flow_coverage','M3 · 국가쌍 자료의 관측률','205,784개 다차원 셀 중 수치 관측 85,278개입니다. 경제 흐름의 크기가 아니라 자료 가용성을 나타냅니다.')]
for name,title,caption in extra:gallery+=f'### {title}\n\n![{title}](assets/plots/figure_{name}.png)\n\n{caption}\n\n'
gallery+=excerpt('code/mechanism_plots.R','mechanism_plots <-','dir.create(')
write('plots.md',gallery)

narrative=(ROOT/'reports/DMA_Mechanisms_Research_Design_20261102.md').read_text(encoding='utf8')
narrative=re.sub(r'\]\(\.\./([^\)]+)\)',lambda m:']('+source_link(m[1])+')',narrative)
for name,_,_ in extra:
    narrative=re.sub(r'!\[([^\]]*)\]\([^\n]*?/figure_'+name+r'\.png\)',lambda m:'!['+m[1]+'](assets/plots/figure_'+name+'.png)',narrative)
loadcode=excerpt('code/mechanism_plots.R','mi <-','scope <-')
insert='''## 원자료와 국가 패널을 읽는 코드

RStudio에서 `RUN_MECHANISMS.R`이 먼저 프로젝트 경로를 초기화합니다. 다음은 실제 로딩 코드입니다. 준수 기록, 기업 사건, 국가쌍 흐름을 별도 객체로 유지하고 국가·연도 브리지의 키를 검사합니다.

'''+loadcode
narrative=narrative.replace('## 두 메커니즘은 다른 관측 단위를 요구한다',insert+'## 두 메커니즘은 다른 관측 단위를 요구한다')
narrative=narrative.replace('## 원천과 방법 문헌','## 결과를 그리는 코드\n\n'+excerpt('code/mechanism_plots.R','mechanism_plots <-','dir.create(')+'## 원천과 방법 문헌')
narrative=narrative.replace('`reports/DMA_Mechanisms_Research_Design_20261102.pdf/html`','`reports/DMA_Mechanisms_Research_Design_20261102.pdf`')
write('mechanisms.md',front('추가 자료와 메커니즘 연구설계',4)+narrative)

reproduce=front('재현과 원천자료',5)+'''# RStudio에서 같은 자료와 그림 열기

## 빠른 실행

저장소 전체를 내려받아 `DMA_PoC_v4.Rproj`를 엽니다. 개별 R 파일만 이동하면 입력자료와 공간자료의 상대 경로가 끊길 수 있습니다.

```r
# 첫 실행에서 필요한 패키지를 준비합니다.
source("setup.R", encoding = "UTF-8")

# 자료·경로 확인
source("CHECK_PATHS.R", encoding = "UTF-8")

# 저장된 결과를 읽어 그림을 생성합니다.
source("RUN_PLOTS.R", encoding = "UTF-8")
source("RUN_MECHANISMS.R", encoding = "UTF-8")
```

새 그림은 `mechanism_plots`에 ggplot 객체로 남고 PNG로도 저장됩니다. `RUN_PLOTS.R`은 기존 그림 20개를 다시 만듭니다. 두 진입점은 공간회귀와 부트스트랩을 새로 실행하지 않습니다.

## 전체 분석을 다시 적합하려면

```r
source("RUN_FULL_ANALYSIS.R", encoding = "UTF-8")
```

원자료 재처리, 모형 적합, 지역 SDM 부트스트랩 9,999회 등이 포함되어 시간이 걸립니다. 저장된 결과가 갱신되므로 기존 결과를 비교하려면 별도 작업 복사본에서 실행하세요. 웹 문서에는 검증된 저장 결과를 사용하며 사이트 배포 때마다 분석을 재실행하지 않습니다.

## 실행 파일과 자료

'''
items=[('DMA_PoC_v4.Rproj','RStudio 프로젝트'),('RUN_PLOTS.R','기존 20개 ggplot 생성'),('RUN_MECHANISMS.R','새 자료와 그림 3개'),('MECHANISMS_REVIEW.ipynb','Python 자료 검토'),('code/03_models.R','VIF·Moran·SAR/SEM/SDM'),('code/07_refine_regional_bootstrap.R','지역 SDM 잔차 재적합 부트스트랩'),('outputs/mechanisms_20261102/integration/integration_catalog.csv','신규 자료 목록'),('outputs/mechanisms_20261102/integration/integration_missingness.csv','결측 감사'),('FILE_MANIFEST.csv','저장소 파일·크기·해시')]
reproduce+='\n'.join(f'- [{label}]({source_link(path)})' for path,label in items)+'\n\n'
reproduce+='''## 원천과 API 키

| 원천 | 자료 | 접근 |
|---|---|---|
| [Eurostat 이민](https://ec.europa.eu/eurostat/databrowser/view/migr_imm5prv/default/table) / [이출](https://ec.europa.eu/eurostat/databrowser/view/migr_emi3nxt/default/table) | 이전·다음 거주국별 흐름 | 공개 API, 개인 키 불필요 |
| [Eurostat FDI](https://ec.europa.eu/eurostat/databrowser/view/bop_fdi6_flow/default/table) / [FATS](https://ec.europa.eu/eurostat/databrowser/view/fats_activ/default/table) | 정보통신업 투자·외국계 기업 활동 | 공개 API, 개인 키 불필요 |
| [Eurofound ERM](https://apps.eurofound.europa.eu/restructuring-events/methodology) | 공개 기업 사건 | 공개 페이지; 전수 CSV는 별도 연구 신청 |
| [GISCO](https://gisco-services.ec.europa.eu/distribution/v2/) | 국가·NUTS 공간 경계 | 공개 배포 |
| 게이트키퍼·EC 공식 문서 | 준수 변화와 적용범위 | 공개 문서, 개인 키 불필요 |

원문 URL·다운로드 상태·해시는 각 자료 폴더의 `SOURCE_MANIFEST.csv`에 있습니다. 원천자료와 공식 문서의 이용조건은 해당 제공기관을 따릅니다.

## 웹 문서를 수정하려면

웹 본문은 `docs/*.md`, 실제 분석은 `code/*.R`로 구분됩니다. `code/build_pages.py`는 저장 결과와 R 코드 발췌에서 문서와 README를 생성합니다. 통계 결과를 변경하지 않습니다.

```bash
python code/build_pages.py
```

그림·설명·분석 소스를 수정한 뒤 문서를 다시 생성하고 변경 내용을 검토합니다. GitHub Pages는 `main` 브랜치의 `/docs`를 게시합니다. 기존 HTML 보고서를 웹 본문으로 복사하지 않으며 Markdown과 코드 블록이 페이지의 원문입니다.
'''
write('reproduce.md',reproduce)

readme='''# DMA 규범 확산과 국제 이동 · 공간분석 PoC

**EU 규범이 비EU 서비스에 확산되는가, 기업·투자·인력의 위치가 달라지는가?** 두 질문을 분리해 검토하는 데이터·공간모형 연구입니다.

**[웹 보고서 바로 보기]('''+SITE+''')** · [분석 과정과 R 코드]('''+SITE+'''analysis.html) · [23개 plot 해설]('''+SITE+'''plots.html) · [추가 자료와 연구설계]('''+SITE+'''mechanisms.html)

> 2026-11-02 자료 스냅샷 · 32개국·288개 국가-연도 · 지역 회귀 218개 지역
>
> 웹 본문은 **설명 → 실제 R 코드 → 결과·그림 → 해석**을 연결한 Markdown 문서입니다. 현재 결과는 기술·조건부 연관성 분석이며 DMA의 인과효과를 확정하지 않습니다.

## 1. 공간지연변수를 제한하면 공선성이 줄어든다

확장형 전체 SDM의 최대 VIF는 **43.29**, 노출도만 공간지연한 제한형은 **4.10**입니다. X와 WX를 함께 진단했으며 표준화 자체가 VIF를 낮추지는 않습니다.

'''
readme+=excerpt('code/03_models.R','design_matrix<-','model_type<-')
readme+='![X와 WX의 최대 VIF 비교](figures/03_vif_comparison.png)\n\n'
readme+='''## 2. 복잡한 공간모형이 항상 우세하지는 않다

같은 EU27 표본·ICT 고용비중을 비교하면 간결형의 AICc는 **OLS 86.83, SAR 88.62, SEM 90.38, 제한형 SDM 92.63**입니다. 확장형 SEM의 낮은 AICc(85.31)는 공간계수가 하한에 걸리는 문제와 함께 판단해야 합니다.

![동일 표본의 모형 비교](figures/04_national_model_comparison.png)

```r
# 저장된 모형 비교표에서 동일 표본·결과변수만 선택
comparison <- read.csv("outputs/all_model_comparisons.csv")
subset(comparison, group == "parsimonious",
       select = c(model, n, AICc, spatial_parameter, near_boundary))
```

## 3. 노출도 효과는 변수 구성에 민감하다

제한형 SDM의 직접효과는 기존 **−0.269**, 확장형 **−0.108**, 간결형 **−0.052%p**입니다. 확장형·간결형의 95% 구간은 0을 포함하며, 세 구성의 간접·총효과 구간도 0을 포함합니다. 공간 간접효과를 규범 확산의 직접 증거로 해석하지 않습니다.

![제한형 SDM 직접·간접·총효과](figures/06_exposure_impacts.png)

## 4. 부트스트랩을 늘려도 잔차 판단은 경계적이다

지역 SDM 잔차 검정은 199회에서 **p=0.0700**, 9,999회에서 **p=0.0526**입니다. 몬테카를로 구간 **0.0463–0.0590**은 0.05를 가로지릅니다. 이는 검정 정밀도의 개선이며 정책 효과가 달라졌다는 뜻이 아닙니다.

![지역 SDM 잔차 검정의 반복 횟수 비교](figures/13_regional_bootstrap_precision.png)

실제 [모형 재적합 코드](code/07_refine_regional_bootstrap.R)에서는 동일 표본·W·난수열을 유지합니다. 원변수 Moran’s I, OLS 조정 잔차 검정, 공간모형 혁신잔차 부트스트랩을 구분합니다.

## 5. 준수 범위와 실제 이동을 다른 자료층으로 둔다

준수 변경 **12개 + 현재 범위 스냅샷 1개**, 기업 사건 **11건·목적지 관계 17개**를 수집했습니다. 발표·자기보고·시행일·실물 이전 완료를 구분하며 현재 스냅샷을 과거로 소급하지 않습니다.

![준수 기록의 적용범위](outputs/mechanisms_20261102/integration/figure_compliance_scope.png)

국가쌍 자료 **205,784행 중 85,278행**에 수치가 있습니다. 연령·방향·산업·단위 차원을 포함한 셀이므로 이동 사건 수가 아닙니다. 일반 이민은 ICT 노동 이동과, FDI는 사업장 이전과 동일하지 않습니다.

![국가쌍 자료의 관측률](outputs/mechanisms_20261102/integration/figure_flow_coverage.png)

| 연구 질문 | 관측 단위 | 다음에 필요한 증거 |
|---|---|---|
| 브뤼셀 효과 | 서비스·기능 × 이용자 시장 × 시점 | 비EU 실제 기능 가용성, 시행일, 현지 규제 |
| 티부형 기업 이동 | 기업·사업장 × 출발지·목적지 × 시점 | 완료 문서, 사업장 고용, 비이전 비교기업 |
| 투자·인력 이동 | 출발국 × 목적국 × 연도·산업/직업 | 사전 노출, 직업별 흐름, 결측·진짜 0 구분 |

## RStudio에서 그림까지 실행

저장소 전체를 내려받아 `DMA_PoC_v4.Rproj`를 열고 실행합니다.

```r
source("setup.R", encoding = "UTF-8")          # 최초 패키지 준비
source("RUN_PLOTS.R", encoding = "UTF-8")      # 기존 20개 그림
source("RUN_MECHANISMS.R", encoding = "UTF-8") # 새 자료와 3개 그림
```

위 그림 진입점은 저장된 결과를 사용합니다. 전체 분석 재적합은 `RUN_FULL_ANALYSIS.R`이며 9,999회 부트스트랩 등에 시간이 걸립니다. [재현 안내]('''+SITE+'''reproduce.html) · [Python 노트북](MECHANISMS_REVIEW.ipynb)

## 보고서·원천자료

- [연구설계 보고서 PDF · 15쪽](reports/DMA_Mechanisms_Research_Design_20261102.pdf)
- [기존 20개 그림 보고서 PDF · 30쪽](reports/DMA_PoC_20plots_Report.pdf)
- `inputs/`: CSV·SHP·원문·출처 메타데이터 / `outputs/`: 결합·결측·검정 결과
- **신규 흐름 자료는 `outputs/mechanisms_20261102/flows/fresh/`**가 기준입니다.
- [신규 자료 목록](outputs/mechanisms_20261102/integration/integration_catalog.csv) · [파일 해시 목록](FILE_MANIFEST.csv)
- Eurostat·GISCO·공식 준수 문서·Eurofound 공개 사건을 사용했습니다. 개인 API 키는 필요하지 않으며 ERM 전수 CSV는 별도 연구 신청 대상입니다. URL과 수집 상태는 각 `SOURCE_MANIFEST.csv`, 이용조건은 해당 원천기관을 참고하세요.

문서 원문은 [`docs/*.md`](docs), 문서 생성기는 [`code/build_pages.py`](code/build_pages.py)입니다. 웹 배포는 기존 분석값을 변경하지 않습니다.
'''
(ROOT/'README.md').write_text(readme,encoding='utf8',newline='\n')

# Verify local Markdown targets and data preservation before publication.
for p in [ROOT/'README.md',*DOCS.glob('*.md')]:
    text=p.read_text(encoding='utf8')
    assert not re.search(r'\]\((?:file:|C:/)',text),p.name
    for link in re.findall(r'!?\[[^\]]*\]\(([^)]+)\)',text):
        if link.startswith(('https://','http://','#')):continue
        link=link.split('#')[0]
        dest=p.parent/link
        if dest.suffix=='.html':dest=dest.with_suffix('.md')
        assert dest.exists(),(str(p),link)
for path in ['reports/report_input_hashes.json','outputs/mechanisms_20261102/integration/integration_source_hashes.json']:
    frozen=json.loads((ROOT/path).read_text(encoding='utf8'))
    assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h for p,h in frozen.items())
excluded={'.git','.Rlibrary','.Rproj.user','__pycache__','.ipynb_checkpoints','qa_pages','pdf_qa'}
files=sorted(p for p in ROOT.rglob('*') if p.is_file() and not excluded.intersection(p.relative_to(ROOT).parts)
             and p.name not in {'FILE_MANIFEST.csv','.Rhistory','.RData','.Renviron','.env'})
with (ROOT/'FILE_MANIFEST.csv').open('w',encoding='utf-8-sig',newline='') as stream:
    writer=csv.DictWriter(stream,fieldnames=['file','bytes','sha256']);writer.writeheader()
    for p in files:writer.writerow(dict(file=p.relative_to(ROOT).as_posix(),bytes=p.stat().st_size,sha256=hashlib.sha256(p.read_bytes()).hexdigest()))
print(json.dumps({'status':'PASS','markdown_chapters':len(list(DOCS.glob('*.md'))),'plots':len(list((DOCS/'assets/plots').glob('*.png'))),'source_hashes_unchanged':True,'local_links':'PASS','manifest_files':len(files)},ensure_ascii=False))
