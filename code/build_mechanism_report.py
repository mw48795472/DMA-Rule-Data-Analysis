"""Build self-contained Korean HTML/PDF/Markdown from audited new data only."""
from pathlib import Path
import base64,html,json,re,hashlib
import pandas as pd
from PIL import Image,ImageDraw,ImageFont
from pypdf import PdfReader
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import A4
from reportlab.lib.colors import HexColor,white
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.styles import ParagraphStyle
from reportlab.platypus import Paragraph,Table,TableStyle
from mechanism_report_content import TITLE,SUBTITLE,REFS,content

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'outputs/mechanisms_20261102/integration'
REPORT=ROOT/'reports';REPORT.mkdir(exist_ok=True)
BASE=ROOT.parent;REPORT_MD=BASE/'reports/DMA 규범 확산과 국제 이동 자료.md'
REPORT_MD.parent.mkdir(exist_ok=True)
REFS.extend([
 ('준수 기록·범위·결합 감사 (로컬)',(ROOT/'outputs/mechanisms_20261102/compliance/JOIN_AUDIT.json').as_posix()),
 ('신규 국제쌍 자료·관측·결합 요약 (로컬)',(ROOT/'outputs/mechanisms_20261102/flows/fresh/summary.json').as_posix()),
 ('기업 사건·목적지·결합 요약 (로컬)',(ROOT/'outputs/mechanisms_20261102/firms/summary.json').as_posix()),
 ('통합 파일 목록·행수·연도·단위·해시 (로컬)',(OUT/'integration_catalog.csv').as_posix()),
 ('흐름 결합·공변량 결측·값 보존 감사 (로컬)',(ROOT/'outputs/mechanisms_20261102/flows/fresh/final_value_preservation_checks.csv').as_posix()),
])
FONT='C:/Windows/Fonts/malgun.ttf';BOLD='C:/Windows/Fonts/malgunbd.ttf'
ESC=html.escape
def j(p):return json.loads(p.read_text(encoding='utf8'))
def r(p):return pd.read_csv(p)
fv=j(ROOT/'outputs/mechanisms_20261102/flows/fresh/summary.json')
cv=j(ROOT/'outputs/mechanisms_20261102/compliance/JOIN_AUDIT.json')
firm=j(ROOT/'outputs/mechanisms_20261102/firms/summary.json')
iv=j(OUT/'integration_validation.json')
assert fv['status']=='complete' and iv['status']=='PASS'
assert cv['base_file_unchanged'] and cv['snapshot_backdated_rows']==0
assert firm['completed_physical_moves_verified']==0
coverage=r(OUT/'figure_flow_coverage.csv')
names={'migration_inward':'이민 유입','migration_outward':'이출 유출','fdi_inward_j':'FDI 유입 J','fdi_outward_j':'FDI 유출 J','foreign_affiliates_j':'외국계 기업 J'}
flow_table=[['새 원자료 / 국제쌍','연도·단위','관측 / 결측 / 전체 셀']]
for s in fv['sources']:
    unit='명' if s['source_id'].startswith('migration') else ('백만 유로' if s['source_id'].startswith('fdi') else '명·기업 수·백만 유로')
    flow_table.append([names[s['source_id']],f'{min(s["years"])}-{max(s["years"])} / {unit}',f'{s["od_observed"]:,} / {s["od_missing"]:,} / {s["od_rows"]:,}'])
flow_overview='새 Eurostat 원자료는 '+', '.join(f'{names[s["source_id"]]} {s["source_rows"]:,}행' for s in fv['sources'])+'이다. 집계 지역과 동일국가 관계를 제외한 국제쌍은 총 205,784행, 수치 관측은 85,278행이다. 여러 연령 정의·연령군·기업 범주·지표가 포함되어 행 수는 고유 국가쌍 수가 아니다. 기존 스냅샷은 별도 보존했으며 범위 변경을 경제적 증가로 읽지 않는다.'
join_overview=f'준수 자료에는 확인된 범위 {cv["scope_bridge_rows"]}행과 국가-연도 브리지 {cv["country_year_bridge_rows"]}행이 있다. 그중 변경 근거 {cv["matched_change_bridge_rows"]}행이 기존 패널에 결합되며, 기록 ID·근거 라벨을 붙인 결과도 {cv["joined_country_year_rows"]}행을 유지한다. 기록이 있는 국가-연도는 {cv["country_years_with_documented_records"]}개다. TikTok 현재 스냅샷은 과거 패널에 소급하지 않았고 2025년 지속 적용도 자동 가정하지 않았다. 새 흐름의 국가집계 결합 역시 {fv["joined_country_year_rows"]}행을 보존한다.'
access_overview=f'준수 공식 원문은 9개 모두 본문 확인과 원본 SHA-256 저장을 마쳤다. 기업 원문은 14개 요청 중 {firm["downloads"]}개를 저장했고 SEC 공시는 웹에서 확인한 법적 재편 근거와 로컬 원문 저장 제한을 구분했다. Eurostat 새 수치 원문 5개와 메타데이터 3개를 저장했다. 초기 제한 환경의 DNS 실패 기록은 최종 실제 HTTP 접근 상태와 별도로 보존했다. 최신 성공/실패 상태는 각 SOURCE_MANIFEST.csv가 기준이다.'
m=dict(compliance_records=cv['events'],firm_cases=firm['events'],bridge_countries=iv['legacy_bridge_countries'],bridge_rows=iv['legacy_bridge_rows'],flow_overview=flow_overview,flow_table=flow_table,join_overview=join_overview,access_overview=access_overview)
PAGES=content(m)
for page_i,para_i,refs in [(0,1,'[21] [23]'),(2,0,'[21]'),(3,0,'[23]'),(4,0,'[22]'),(4,2,'[22]'),
                            (5,0,'[24]'),(5,1,'[23]'),(5,2,'[21] [22]'),(5,3,'[22] [25]'),(5,4,'[22]'),(10,0,'[21] [23] [24]')]:
    PAGES[page_i]['paragraphs'][para_i]+=' '+refs

def drawbar(name,title,labels,values,maxval,foot,details=None):
    im=Image.new('RGB',(1500,670),'white');d=ImageDraw.Draw(im)
    f=lambda n,b=False:ImageFont.truetype(BOLD if b else FONT,n)
    d.text((36,20),title,font=f(33,True),fill='#163743')
    x0,x1=460,1350;top=105;h=min(82,420/max(1,len(labels)))
    for i,(lab,val) in enumerate(zip(labels,values)):
        y=top+i*h
        d.text((36,y+10),lab,font=f(25),fill='#25434c')
        d.rounded_rectangle((x0,y+6,x1,y+49),radius=6,fill='#e7eff2')
        w=(x1-x0)*float(val)/maxval
        if w>0:d.rounded_rectangle((x0,y+6,x0+w,y+49),radius=6,fill='#177889')
        s=details[i] if details else str(val)
        d.text((x1+20,y+10),s,font=f(24,True),fill='#163743')
    d.text((36,590),foot,font=f(22),fill='#566b75')
    p=OUT/(name+'.png');im.save(p);return p
scope=r(OUT/'figure_compliance_scope.csv').groupby('geographic_scope_code')['count'].sum()
figs={}
figs['compliance']=drawbar('figure_compliance_scope','그림 1  |  관측한 준수 근거의 지리적 범위',list(scope.index),list(scope.values),5,'13개 목적표집 기록. EEA_UK 1개는 도입 사건이 아닌 현재 범위 스냅샷.')
cases=r(OUT/'figure_firm_case_types.csv').sort_values('count',ascending=False)
figs['firms']=drawbar('figure_firm_case_types','그림 2  |  수집한 기업 사건의 유형',list(cases.label),list(cases['count']),10,'11개 사례의 구성. 모집단 비율이 아니며 실물 이전 완료 검증은 0건.')
figs['flows']=drawbar('figure_flow_coverage','그림 3  |  새 국가쌍 자료의 수치 관측률',list(coverage.label),list(coverage.observed_pct),100,'각 자료의 서로 다른 범위·차원 내 비결측 비율. 흐름 규모의 비교가 아님.',[f'{v:.1f}%' for v in coverage.observed_pct])

def cite_md(s):
    return re.sub(r'\[(\d+)\]',lambda z:'(['+REFS[int(z[1])-1][0]+']('+REFS[int(z[1])-1][1]+'))',s)
def cite_html(s):
    return re.sub(r'\[(\d+)\]',lambda z:'<a href="'+ESC(REFS[int(z[1])-1][1],quote=True)+'">['+z[1]+']</a>',ESC(s))
def htable(rows):
    return '<table>'+''.join('<tr>'+''.join(('<th>' if i==0 else '<td>')+ESC(str(x))+('</th>' if i==0 else '</td>') for x in row)+'</tr>' for i,row in enumerate(rows))+'</table>'
css='''body{margin:0;background:#eef3f5;color:#173743;font-family:"Malgun Gothic",sans-serif;line-height:1.85}main{max-width:1000px;margin:auto;background:white;padding:50px}header{border-top:8px solid #177889;padding-top:20px}h1{font-size:34px;line-height:1.45}h2{font-size:25px;color:#146579;line-height:1.5}h3{font-size:21px;line-height:1.55}p{font-size:15px;margin:15px 0}section{padding:25px 0;border-top:1px solid #cddfe5}a{color:#126e82;overflow-wrap:anywhere}img{width:100%;height:auto}table{width:100%;border-collapse:collapse;font-size:13px;margin:20px 0}th{background:#177889;color:white}th,td{padding:10px;text-align:left;vertical-align:top;border-bottom:1px solid #dbe5e9}tr:nth-child(even){background:#f2f7f8}.meta{font-size:12px;color:#5c727a}.ref{font-size:12px}nav{display:grid;grid-template-columns:1fr 1fr;gap:8px;font-size:13px}@media(max-width:700px){main{padding:20px}nav{display:block}}@media print{body{background:white}main{padding:0}section{break-before:page}table,img{break-inside:avoid}}'''
ht=['<!doctype html><html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>'+TITLE+'</title><style>'+css+'</style></head><body><main><header><div class="meta">공개자료 수집 스냅샷 · 2026-11-02 · 인과모형 미적합</div><h1>'+TITLE+'</h1><p>'+SUBTITLE+'</p></header><nav>']
ht+=['<a href="#p'+str(i)+'">'+p['title']+'</a>' for i,p in enumerate(PAGES)];ht+=['</nav>']
md=['# '+TITLE,'',cite_md(PAGES[0]['paragraphs'][0]),'','자료 수집·검증 기준일: 2026-11-02. 기존 20개 그림 보고서와 추정 결과는 보존했다.','']
for i,p in enumerate(PAGES):
    ht+=['<section id="p'+str(i)+'"><h2>'+p['title']+'</h2>']
    if p.get('group'):md+=['## '+p['group'],'']
    md+=['### '+p['title'],'']
    if p.get('figure'):
        fig=figs[p['figure']];ht+=['<img alt="'+ESC(p['title'])+'" src="data:image/png;base64,'+base64.b64encode(fig.read_bytes()).decode()+'">']
        md+=['!['+p['title']+']('+fig.as_posix()+')','']
    for para in p['paragraphs']:ht+=['<p>'+cite_html(para)+'</p>'];md+=[cite_md(para),'']
    if p.get('table'):
        ht+=[htable(p['table'])]
        md+=['| '+' | '.join(map(str,p['table'][0]))+' |','| '+' | '.join(['---']*len(p['table'][0]))+' |']
        md+=['| '+' | '.join(map(str,row))+' |' for row in p['table'][1:]];md+=['']
    ht+=['</section>']
ht+=['<section><h2>원천과 방법 문헌</h2>'];md+=['## 원천과 방법 문헌','']
for i,(label,url) in enumerate(REFS,1):ht+=['<p class="ref">['+str(i)+'] '+label+'<br><a href="'+ESC(url,quote=True)+'">'+ESC(url)+'</a></p>'];md+=[f'[{i}] [{label}]({url})','']
ht+=['</section><p class="meta">계수·효과 크기를 새로 추정하지 않았다. 파일 단위 감사와 원문 보존 상태는 동봉 CSV/JSON 참조.</p></main></body></html>']
htmlfile=REPORT/'DMA_Mechanisms_Research_Design_20261102.html';htmlfile.write_text(''.join(ht),encoding='utf8')
REPORT_MD.write_text('\n'.join(md),encoding='utf8')

pdfmetrics.registerFont(TTFont('Korean',FONT));pdfmetrics.registerFont(TTFont('KoreanBold',BOLD))
pdfmetrics.registerFontFamily('Korean',normal='Korean',bold='KoreanBold',italic='Korean',boldItalic='KoreanBold')
pdfpath=REPORT/'DMA_Mechanisms_Research_Design_20261102.pdf'
c=canvas.Canvas(str(pdfpath),pagesize=A4,pageCompression=1);c.setTitle(TITLE);c.setAuthor('DMA PoC research project')
W,H=A4;M=43;WIDTH=W-2*M;page=0;y=0;current='';index=[];overflows=[]
def new(title):
    global page,y,current
    if page:c.showPage()
    page+=1;current=title;y=H-65
    c.setFillColor(HexColor('#177889'));c.rect(M,H-34,WIDTH,3,fill=1,stroke=0)
    c.setFillColor(HexColor('#5c727a'));c.setFont('Korean',8)
    c.drawString(M,H-49,'DMA 메커니즘 자료·연구설계 | 2026-11-02')
    c.drawString(M,25,'공개자료 수집·측정 감사 | 새 인과모형 미적합')
    c.drawRightString(W-M,25,f'{page:02d}')
    index.append(dict(page=page,title=title));para(title,17,24,True,12)
def para(s,font=9.5,lead=14.5,bold=False,gap=8):
    global y
    sty=ParagraphStyle('text',fontName='KoreanBold' if bold else 'Korean',fontSize=font,leading=lead,wordWrap='CJK',textColor=HexColor('#173743'))
    text=cite_html(s)
    obj=Paragraph(text,sty);_,h=obj.wrap(WIDTH,10000)
    if h>y-47:new(current+' (계속)')
    if h>y-47:overflows.append(dict(page=page,height=h,y=y))
    obj.drawOn(c,M,y-h);y-=h+gap
def chart(p):
    global y
    iw,ih=Image.open(p).size;h=WIDTH*ih/iw
    if h>y-47:new(current+' (그림)')
    c.drawImage(str(p),M,y-h,width=WIDTH,height=h,mask='auto');y-=h+7
def table(rows):
    global y
    ratios=[.30,.70] if len(rows[0])==2 else [.29,.32,.39]
    normal=ParagraphStyle('cell',fontName='Korean',fontSize=8,leading=11.5,wordWrap='CJK')
    head=ParagraphStyle('head',parent=normal,fontName='KoreanBold',textColor=white)
    def make(rr):
        t=Table([[Paragraph(ESC(str(x)),head if i==0 else normal) for x in row] for i,row in enumerate(rr)],colWidths=[WIDTH*z for z in ratios])
        t.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,0),HexColor('#177889')),('ROWBACKGROUNDS',(0,1),(-1,-1),[white,HexColor('#f2f7f8')]),('VALIGN',(0,0),(-1,-1),'TOP'),('LEFTPADDING',(0,0),(-1,-1),6),('RIGHTPADDING',(0,0),(-1,-1),6),('TOPPADDING',(0,0),(-1,-1),6),('BOTTOMPADDING',(0,0),(-1,-1),6)]));return t
    t=make(rows);_,h=t.wrap(WIDTH,10000)
    if h>y-47:new(current+' (표)')
    assert h<=y-47,'Table does not fit'
    t.drawOn(c,M,y-h);y-=h+10
for i,p in enumerate(PAGES):
    new(p['title'])
    if i==0:para(TITLE,20,28,True);para(SUBTITLE,11,17)
    if p.get('figure'):chart(figs[p['figure']])
    for text in p['paragraphs']:para(text)
    if p.get('table'):table(p['table'])
for start in range(0,len(REFS),10):
    new('수집·결합 감사 자료' if start==20 else '원천과 방법 문헌'+(' (계속)' if start else ''))
    for i,(label,url) in enumerate(REFS[start:start+10],start+1):
        para(f'[{i}] {label}',8.8,12.5,True,2);para(url,7.4,10.5,False,8)
c.save()
reader=PdfReader(str(pdfpath));texts=[x.extract_text() or '' for x in reader.pages]
assert not overflows and all(len(t.strip())>80 for t in texts)
assert len(reader.pages)==page
assert all(p['title'] in '\n'.join(texts) for p in PAGES)
assert len(PAGES)==12
validation=dict(status='PASS',pdf_pages=page,pdf_embedded_figures=sum(len(p.images) for p in reader.pages),html_embedded_figures=3,
   narrative_sections=len(PAGES),causal_models_fitted=False,old_analysis_untouched=True,visual_review='PENDING',page_index=index,
   source_summaries={'compliance':cv,'firms':firm,'fresh_flows':fv},outputs={str(p.relative_to(BASE)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [pdfpath,htmlfile,REPORT_MD]})
(REPORT/'mechanism_report_validation.json').write_text(json.dumps(validation,ensure_ascii=False,indent=2),encoding='utf8')

cells=[dict(cell_type='markdown',metadata={},source=['# DMA 메커니즘 자료 확인\n','세 관측 단위를 분리한 자료 로딩·감사 노트북. 새 인과모형을 적합하지 않습니다.'])]
def code(s):cells.append(dict(cell_type='code',metadata={},execution_count=None,outputs=[],source=s.splitlines(keepends=True)))
code("from pathlib import Path\nimport pandas as pd\ntry:\n    from IPython.display import display, Image\nexcept ImportError:\n    display = print\n    def Image(filename): return Path(filename)\nroot=Path.cwd()\nwhile not (root/'project_paths.R').exists() and root != root.parent: root=root.parent\nassert (root/'project_paths.R').exists(), '프로젝트 폴더에서 노트북을 여세요'\nout=root/'outputs/mechanisms_20261102'\ncatalog=pd.read_csv(out/'integration/integration_catalog.csv')\ndisplay(catalog[['domain','path','rows','year_min','year_max']])\n")
code("compliance=pd.read_csv(out/'compliance/compliance_events.csv')\nfirms=pd.read_csv(root/'inputs/mechanisms_20261102/firms/csv/firm_events.csv')\nflow_dir=out/'flows/fresh'\nflows={name:pd.read_csv(flow_dir/file,low_memory=False) for name,file in {'immigration':'migration_inward_od.csv','emigration':'migration_outward_od.csv','fdi_inward':'fdi_inward_od.csv','fdi_outward':'fdi_outward_od.csv','foreign_affiliates':'fats_inward_control_od.csv'}.items()}\nassert compliance.event_id.is_unique and firms.event_id.is_unique\ndisplay(pd.read_csv(out/'integration/bridge_audit.csv'))\ndisplay(pd.read_csv(out/'integration/figure_flow_coverage.csv'))\n")
code("for f in ['figure_compliance_scope.png','figure_firm_case_types.png','figure_flow_coverage.png']:\n    display(Image(filename=str(out/'integration'/f)))\n")
nb=dict(nbformat=4,nbformat_minor=5,metadata={'kernelspec':{'display_name':'Python 3','language':'python','name':'python3'},'language_info':{'name':'python'}},cells=cells)
(ROOT/'MECHANISMS_REVIEW.ipynb').write_text(json.dumps(nb,ensure_ascii=False,indent=2),encoding='utf8')
(ROOT/'MECHANISMS_README_ko.txt').write_text('DMA 메커니즘 자료 확장 (2026-11-02)\n\nRStudio: DMA_PoC_v4.Rproj를 열고 RUN_MECHANISMS.R 전체를 Source하세요.\n새 자료는 inputs/mechanisms_20261102/ 및 outputs/mechanisms_20261102/에 있습니다.\n새 Eurostat 패널은 outputs/mechanisms_20261102/flows/fresh/가 기준입니다.\n흐름의 기존 스냅샷은 상위 flows/에 별도로 보존했습니다. 두 범위의 행 수 변화를 경제적 변화로 해석하지 마세요.\n세 기술 그림과 읽을 수 있는 ggplot 객체는 mechanism_plots에 있습니다.\n보고서: reports/DMA_Mechanisms_Research_Design_20261102.pdf 및 .html\n검증: reports/mechanism_report_validation.json 및 outputs/mechanisms_20261102/integration/\n국가·지역 기존 추정 및 20개 그림 보고서는 변경하지 않았습니다.\n결측은 0이 아니며 현재 범위 스냅샷을 소급하지 않습니다. 새 인과모형은 적합하지 않습니다.\n',encoding='utf8')
print(json.dumps(dict(status='PASS',pages=page,pdf=str(pdfpath),markdown=str(REPORT_MD)),ensure_ascii=False))
