from pathlib import Path
import base64,csv,hashlib,html,json,math,os,re,shutil
import pandas as pd
from PIL import Image as PILImage
from pypdf import PdfReader
from reportlab.pdfgen import canvas
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.colors import HexColor,white
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.platypus import Paragraph,Table,TableStyle
from report_20plots_content import TITLE,SUBTITLE,DATE,FIGURES,INTRO,END,REFERENCES

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'outputs'; REPORT=ROOT/'reports'; REPORT.mkdir(exist_ok=True)
ESC=html.escape
checks=[]
def check(name,ok):
    checks.append({'check':name,'pass':bool(ok)})
    if not ok:raise AssertionError(name)
def read(n):return pd.read_csv(OUT/n)
def at(df,**criteria):
    for k,v in criteria.items():df=df[df[k]==v]
    check('unique row '+str(criteria),len(df)==1)
    return df.iloc[0]
def near(x,y,t=1e-7):return abs(float(x)-y)<t

idx=read('plot_index.csv')
check('exactly 20 ordered figures',idx.figure.tolist()==list(range(1,21)) and [f['number'] for f in FIGURES]==list(range(1,21)))
models=read('all_model_comparisons.csv');vif=read('max_vif.csv');moran=read('raw_moran_multiple_testing.csv')
check('regional SDM sample',at(models,group='regional',model='SDM_full')['n']==218)
check('regional SDM AICc',near(at(models,group='regional',model='SDM_full').AICc,705.8151163101))
check('regional SDM rho',near(at(models,group='regional',model='SDM_full').spatial_parameter,.4045045035))
check('regional SDM bootstrap p',near(at(models,group='regional',model='SDM_full').p_bootstrap,.0526))
check('regional other residual repetitions',set(models[(models.group=='regional')&(models.model!='SDM_full')].residual_simulations)=={199})
check('regional impact repetitions preserved',set(models[models.group=='regional'].impact_simulations)=={199})
check('national VIF high',near(at(vif,group='augmented',model='SDM_full').max_VIF,43.2903642612))
check('national VIF reduced',near(at(vif,group='parsimonious',model='SDM_exposure').max_VIF,3.1796991133))
check('ICT Moran p',near(at(moran,group='legacy').p,.0066))
check('ICT Moran BY',near(at(moran,group='legacy').p_BY,.055))
effects=read('all_impacts.csv')
check('legacy direct effect',near(at(effects,group='legacy',model='SDM_exposure',term='z_exposure',effect='direct').estimate,-.2687399425))
check('augmented direct interval crosses zero',at(effects,group='augmented',model='SDM_exposure',term='z_exposure',effect='direct').lower<0<at(effects,group='augmented',model='SDM_exposure',term='z_exposure',effect='direct').upper)
coverage=read('combined_missingness.csv')
check('FDI coverage 18',at(coverage,scope='EU27',year=2024,variable='fdi_inward_j_pct_gdp').observed==18)
regions=read('region_code_audit.csv').drop_duplicates('geo')
check('regional code audit counts',regions.reason.value_counts().to_dict()=={'code_match_only':259,'UK_not_in_2024_boundary':45,'old_or_noncurrent_code_requires_crosswalk':16,'extra_regio_no_polygon':15})
bt=read('regional_sdm_bootstrap_comparison.csv');last=at(bt,simulations=9999)
check('MC interval',near(last.MC_lower,.0463205493) and near(last.MC_upper,.0590499521))
mig=read('migration_extension/migration_europe_2024.csv')
check('migration audit scope',len(mig)==43)
check('base and PT expanded coverage',mig.rate_all_ages.notna().sum()==34 and mig.rate_all_ages_plus_PT.notna().sum()==35)
check('8 observed nonEU countries',len(mig[(~mig.eu27)&mig.rate_all_ages.notna()])==8)
check('UK rate',near(at(mig,country='UK').rate_all_ages,14.6123890534))
check('PT age rate',near(at(mig,country='PT').rate_15_64_plus_PT,44.6349614169))
mm=read('migration_extension/migration_moran_tests.csv').query('k==4')
check('all migration sensitivity p > .05',len(mm)==8 and (mm.p>.05).all())
check('Europe PT Moran p',near(at(mm,sample='Europe_plus_PT').p,.8064))
lta=read('lta_design/panel_summary.csv')
check('LTA regional rows',at(lta,scope='regional').complete_rows==858 and at(lta,scope='regional').balanced_units==205)
check('LTA not fitted',not lta.latent_model_fitted.any())

inputs=set()
for f in FIGURES:
    row=idx[idx.figure==f['number']].iloc[0]
    f['png']=row.png;f['pdf']=row.pdf;f['name']=row['name']
    check('figure image '+str(f['number']),(ROOT/f['png']).is_file())
    inputs.add(ROOT/f['png'])
    for s in f['sources']:
        p=OUT/s
        if not p.exists():p=ROOT/s
        check('figure source '+s,p.is_file())
        inputs.add(p)
inputs.update([OUT/x for x in ['plot_index.csv','all_model_comparisons.csv','raw_moran_multiple_testing.csv','migration_extension/migration_moran_tests.csv','lta_design/panel_summary.csv']])
hashes={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(inputs)}
frozen=REPORT/'report_input_hashes.json'
if frozen.exists():
    old=json.loads(frozen.read_text(encoding='utf-8'))
    check('frozen inputs unchanged; review prose before changing snapshot',old==hashes)

# Markdown body (figures linked from figures/, no embedded images); same authored content as the PDF.
from report_markdown import write as write_markdown
markdown_text=write_markdown(dict(title=TITLE,subtitle=SUBTITLE,date=DATE,figures=FIGURES,intro=INTRO,conclusions=END,references=REFERENCES))
check('20 figure links in Markdown',markdown_text.count('](../figures/')==20)

# A4, embedded Korean fonts, full-width plots, and explicit continuation pages.
regular=Path(os.environ.get('DMA_REPORT_FONT','C:/Windows/Fonts/malgun.ttf'))
bold=Path(os.environ.get('DMA_REPORT_FONT_BOLD','C:/Windows/Fonts/malgunbd.ttf'))
check('Korean report fonts',regular.is_file() and bold.is_file())
pdfmetrics.registerFont(TTFont('Korean',str(regular)))
pdfmetrics.registerFont(TTFont('KoreanBold',str(bold)))
pdfmetrics.registerFontFamily('Korean',normal='Korean',bold='KoreanBold',italic='Korean',boldItalic='KoreanBold')
TEAL=HexColor('#126e82'); INK=HexColor('#18313b'); GREY=HexColor('#536a74')
pdf_path=REPORT/'DMA_PoC_20plots_Report.pdf'

class PDF:
    def __init__(self,path):
        self.c=canvas.Canvas(str(path),pagesize=A4,pageCompression=1)
        self.c.setTitle(TITLE);self.c.setAuthor('DMA PoC analysis project')
        self.w,self.h=A4;self.margin=43;self.width=self.w-86;self.page=0;self.y=0
        self.current='';self.index=[];self.overflow=[]
    def new(self,title,key=None):
        if self.page:self.c.showPage()
        self.page+=1;self.current=title;self.y=self.h-61
        c=self.c;c.setFillColor(TEAL);c.rect(self.margin,self.h-34,self.width,3,fill=1,stroke=0)
        c.setFont('Korean',8);c.setFillColor(GREY)
        c.drawString(self.margin,self.h-47,'DMA 공간분석 PoC | 20개 그림 해석 | '+DATE)
        c.drawString(self.margin,25,'자료·공간모형 진단 및 후속 연구 기획')
        c.drawRightString(self.w-self.margin,25,f'{self.page:02d}')
        if key:c.bookmarkPage(key);c.addOutlineEntry(title,key,level=0,closed=False)
        self.p(title,font=18,leading=25,bold=True,color=TEAL,gap=12)
        self.index.append({'page':self.page,'title':title})
    def p(self,text,label=None,font=10,leading=15,bold=False,color=INK,gap=9):
        style=ParagraphStyle('body',fontName='KoreanBold' if bold else 'Korean',fontSize=font,leading=leading,textColor=color,wordWrap='CJK')
        value=(('<b>'+ESC(label)+'</b>  ') if label else '')+ESC(text)
        obj=Paragraph(value,style);_,height=obj.wrap(self.width,10000)
        if height>self.y-45:
            self.new(self.current.split(' (계속)')[0]+' (계속)')
        check_height=height<=self.y-45
        if not check_height:self.overflow.append({'page':self.page,'height':height,'y':self.y})
        obj.drawOn(self.c,self.margin,self.y-height);self.y-=height+gap
    def image(self,path):
        w,h=PILImage.open(path).size
        scale=min(self.width/w,430/h)
        dw,dh=w*scale,h*scale
        if dh>self.y-45:self.new(self.current+' (그림)')
        self.c.drawImage(str(path),self.margin+(self.width-dw)/2,self.y-dh,width=dw,height=dh,mask='auto')
        self.y-=dh+8
    def table(self,rows):
        if not rows:return
        cols=len(rows[0]);ratios={2:[.31,.69],3:[.23,.40,.37]}.get(cols,[1/cols]*cols)
        style=ParagraphStyle('cell',fontName='Korean',fontSize=8.6,leading=12,wordWrap='CJK',textColor=INK)
        head=ParagraphStyle('head',parent=style,fontName='KoreanBold',textColor=white)
        pending=rows[1:]
        while pending:
            subset=[]
            for row in pending:
                trial=[rows[0]]+subset+[row]
                data=[[Paragraph(ESC(str(x)),head if i==0 else style) for x in r] for i,r in enumerate(trial)]
                t=Table(data,colWidths=[self.width*r for r in ratios])
                t.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,0),TEAL),('VALIGN',(0,0),(-1,-1),'TOP'),('LEFTPADDING',(0,0),(-1,-1),7),('RIGHTPADDING',(0,0),(-1,-1),7),('TOPPADDING',(0,0),(-1,-1),6),('BOTTOMPADDING',(0,0),(-1,-1),6),('ROWBACKGROUNDS',(0,1),(-1,-1),[white,HexColor('#f1f6f7')]),('LINEBELOW',(0,0),(-1,-1),.3,HexColor('#dbe4e8'))]))
                _,height=t.wrap(self.width,10000)
                if height>self.y-48:break
                subset.append(row);best=t;best_h=height
            if not subset:self.new(self.current.split(' (계속)')[0]+' (계속)');continue
            best.drawOn(self.c,self.margin,self.y-best_h);self.y-=best_h+13
            pending=pending[len(subset):]
            if pending:self.new(self.current.split(' (계속)')[0]+' (계속)')

doc=PDF(pdf_path)
for i,s in enumerate(INTRO):
    doc.new(s['title'],'intro'+str(i))
    if i==0:doc.p(TITLE,font=21,leading=28,bold=True);doc.p(SUBTITLE,font=12,leading=18,color=GREY)
    for p in s['paragraphs']:doc.p(p)
    doc.table(s['table'])
for f in FIGURES:
    doc.new('그림 %02d. %s'%(f['number'],f['title']),'fig%02d'%f['number'])
    doc.p(f['takeaway'],font=11,leading=16,bold=True,color=TEAL)
    doc.image(ROOT/f['png'])
    for key,label in [('result','관측 결과'),('brussels','브뤼셀 효과 관점'),('tiebout','티부 효과 관점'),('limits','해석 범위와 한계')]:doc.p(f[key],label=label,font=9.6,leading=14,gap=7)
    doc.p('근거: '+' / '.join(f['sources']),font=7.6,leading=11,color=GREY,gap=3)
for i,s in enumerate(END):
    doc.new(s['title'],'end'+str(i))
    for p in s['paragraphs']:doc.p(p)
    doc.table(s['table'])
doc.new('공식 원천과 방법 참고문헌','references')
doc.p('법령·이론·방법·정의: 2026-11-02 확인. 통계는 보존 원문과 CSV 기준이다. 이후 웹 개정과 다를 수 있다. 상세 데이터 코드·요청 URL·수집일·해시는 프로젝트의 source manifest 참조.',font=9,leading=13)
for num,label,url in REFERENCES:
    doc.p('['+num+'] '+label,font=9,leading=13,bold=True,gap=2)
    doc.p(url,font=7.5,leading=10.5,color=TEAL,gap=10)
doc.new('주요 통계 코드와 재현 출처','datasets')
for ds in datasets:doc.p(ds+' - https://ec.europa.eu/eurostat/databrowser/view/'+ds+'/default/table',font=8.4,leading=12,gap=10)
doc.p('원천 파일: inputs/base/source_links_api.csv, inputs/additional/download_manifest.csv, inputs/extension_20261102/SOURCE_MANIFEST.csv',font=9,leading=14)
doc.p('통계 수치와 해석에 사용한 모든 로컬 파일은 reports/report_input_hashes.json에 SHA-256으로 기록했다. 그림 원본은 figures/의 같은 번호 PNG/PDF다.',font=9,leading=14)
doc.c.save()
check('no PDF layout block overflow',not doc.overflow)
reader=PdfReader(str(pdf_path));texts=[p.extract_text() or '' for p in reader.pages]
check('PDF count matches renderer',len(reader.pages)==doc.page)
check('all 20 figure titles in PDF',all(('그림 %02d.'%f['number']) in '\n'.join(texts) for f in FIGURES))
check('20 PDF chart images',sum(len(p.images) for p in reader.pages)==20)
check('no empty PDF page',all(len(t.strip())>80 for t in texts))

data=dict(title=TITLE,subtitle=SUBTITLE,date=DATE,figures=FIGURES,intro=INTRO,conclusions=END,references=REFERENCES)
(REPORT/'plot_interpretations_20261102.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
with (REPORT/'plot_interpretations_20261102.csv').open('w',encoding='utf-8-sig',newline='') as stream:
    keys=['number','title','takeaway','result','brussels','tiebout','limits','sources','png','pdf']
    wr=csv.DictWriter(stream,fieldnames=keys);wr.writeheader()
    for f in FIGURES:wr.writerow({k:' | '.join(f[k]) if k=='sources' else f[k] for k in keys})
frozen.write_text(json.dumps(hashes,ensure_ascii=False,indent=2),encoding='utf-8')
validation={'status':'PASS','figures':20,'pdf_pages':len(reader.pages),'pdf_chart_images':20,'markdown_figure_links':20,'checks':checks,'page_index':doc.index,'visual_review':'PENDING','analysis_refitted':False}
(REPORT/'report_validation.json').write_text(json.dumps(validation,ensure_ascii=False,indent=2),encoding='utf-8')
(ROOT/'REPORT_UPDATE_README.txt').write_text('20개 그림 해석 보고서 (2026-11-02)\n\nreports/DMA_PoC_20plots_Report.pdf : 인쇄·공유용\nreports/DMA_PoC_20plots_Report.md : GitHub에서 읽는 Markdown 본문(figures/ PNG 참조)\nreports/plot_interpretations_20261102.csv : 그림별 해석표\n\n그림 재현은 RUN_PLOTS.R을 RStudio에서 Source하세요.\n이번 갱신은 해석 보고서이며 회귀·부트스트랩·LTA를 새로 적합하지 않았습니다.\nMarkdown 본문만 다시 만들려면 python code/report_markdown.py 를 실행하세요.\n새 분석 결과에서는 해석 문구와 report_input_hashes.json 스냅샷을 검토한 뒤 보고서를 재생성하세요.\n',encoding='utf-8')
print(json.dumps({'status':'PASS','figures':20,'pdf_pages':len(reader.pages),'checks':len(checks),'pdf':str(pdf_path)},ensure_ascii=False))
