"""Write the 20-plot interpretation report as Markdown.

The HTML version embedded every PNG as base64 (3.5 MB) and duplicated the
PDF.  Markdown links the committed figures/*.png instead, so the report is
readable on GitHub and diffs stay small.  No number is computed here: the
authored text and the frozen figure list come from
reports/plot_interpretations_20261102.json (written by build_20plots_report.py).

    python code/report_markdown.py            # rebuild reports/DMA_PoC_20plots_Report.md
"""
from pathlib import Path
import json,re

ROOT=Path(__file__).resolve().parents[1]
REPORT=ROOT/'reports'
DATASETS=['isoc_sks_itspt','isoc_ec_eseln2','nama_10_a10_e','htec_emp_reg2','nama_10r_2gdp','edat_lfse_04',
          'demo_pjan','migr_imm8','migr_imm5prv','migr_emi3nxt','bop_fdi6_flow','fats_activ']

def anchor(text):
    """GitHub-style heading anchor: lower case, drop punctuation, spaces to hyphens."""
    text=text.lower().strip()
    text=''.join(ch for ch in text if ch.isalnum() or ch in ' -_')
    return re.sub(r'\s+','-',text)

def cell(x):
    return str(x).replace('|','/').replace('\n',' ')

def md_table(rows):
    if not rows:return ''
    head,*body=rows
    out=['| '+' | '.join(cell(c) for c in head)+' |','| '+' | '.join('---' for _ in head)+' |']
    out+=['| '+' | '.join(cell(c) for c in r)+' |' for r in body]
    return '\n'.join(out)+'\n\n'

def section(s):
    text='## '+s['title']+'\n\n'
    text+=''.join(p+'\n\n' for p in s['paragraphs'])
    text+=md_table(s.get('table'))
    return text

def build(data,figure_dir='../figures'):
    figures=data['figures']
    md=['# '+data['title'],'',data['subtitle'],'',
        '> PoC v4 · 해석 보완판 · '+data['date']+' · 주 분석연도 2024 · 수집 자료 스냅샷 2026-11-02 · 인과효과 추정 전 단계','',
        '그림 파일은 `figures/`의 PNG를 그대로 참조합니다. 같은 내용의 인쇄용 PDF는 `DMA_PoC_20plots_Report.pdf`, 그림별 해석표는 `plot_interpretations_20261102.csv`입니다.','',
        '## 목차','']
    for s in data['intro']:md.append(f'- [{s["title"]}](#{anchor(s["title"])})')
    md.append('- [그림별 해석](#그림별-해석)')
    for f in figures:
        title='그림 %02d. %s'%(f['number'],f['title'])
        md.append(f'  - [{title}](#{anchor(title)})')
    for s in data['conclusions']:md.append(f'- [{s["title"]}](#{anchor(s["title"])})')
    md.append('- [공식 원천과 방법 참고문헌](#공식-원천과-방법-참고문헌)')
    md.append('')
    text='\n'.join(md)+'\n'
    text+=''.join(section(s) for s in data['intro'])
    text+='## 그림별 해석\n\n각 그림은 **핵심 판단 → 관측 결과 → 브뤼셀 효과 관점 → 티부 효과 관점 → 해석 범위와 한계** 순서로 읽습니다. 그림은 `RUN_PLOTS.R`이 저장 결과에서 다시 그린 ggplot이며 모형을 새로 적합하지 않았습니다.\n\n'
    for f in figures:
        title='그림 %02d. %s'%(f['number'],f['title'])
        png=figure_dir+'/'+Path(f['png']).name
        text+='### '+title+'\n\n'
        text+='**'+f['takeaway']+'**\n\n'
        text+=f'![{title}]({png})\n\n'
        text+=f'*실제 저장 결과를 재현한 ggplot. 원그림: `{f["name"]}` (PNG/PDF는 `figures/`)*\n\n'
        for key,label in [('result','관측 결과'),('brussels','브뤼셀 효과 관점'),('tiebout','티부 효과 관점'),('limits','해석 범위와 한계')]:
            text+=f'**{label}** · {f[key]}\n\n'
        text+='근거 파일: '+' / '.join('`outputs/'+s+'`' if not s.endswith('ANALYSIS_VARIABLES.csv') else '`'+s+'`' for s in f['sources'])+'\n\n'
    text+=''.join(section(s) for s in data['conclusions'])
    text+='## 공식 원천과 방법 참고문헌\n\n법령·이론·방법·정의는 2026-11-02 확인. 통계 수치는 프로젝트에 보존된 원문과 CSV를 기준으로 하며, 웹페이지의 이후 개정과 다를 수 있다.\n\n'
    for num,label,url in data['references']:
        text+=f'- [{num}] {label} — <{url}>\n'
    text+='\n### 주요 통계 코드별 직접 링크\n\n'
    for ds in DATASETS:
        text+=f'- [{ds}](https://ec.europa.eu/eurostat/databrowser/view/{ds}/default/table)\n'
    text+='\n---\n\n실제 공개 통계 기반 연구 기획·진단 PoC. 규범 확산 및 규제 유발 이동의 인과효과를 확정하지 않는다.\n'
    return text

def write(data,path=REPORT/'DMA_PoC_20plots_Report.md'):
    text=build(data)
    path.write_text(text,encoding='utf-8',newline='\n')
    return text

if __name__=='__main__':
    data=json.loads((REPORT/'plot_interpretations_20261102.json').read_text(encoding='utf-8'))
    text=write(data)
    assert text.count('](../figures/')==len(data['figures'])==20
    for f in data['figures']:assert (ROOT/f['png']).is_file(),f['png']
    print(json.dumps({'status':'PASS','figures':len(data['figures']),'characters':len(text),'markdown':'reports/DMA_PoC_20plots_Report.md'},ensure_ascii=False))
