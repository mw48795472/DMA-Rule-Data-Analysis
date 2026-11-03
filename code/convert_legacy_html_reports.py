"""One-off conversion of the archived v3/v4 HTML reports to Markdown.

The archived reports under reference/ were self-contained HTML files with the
figures embedded as base64 PNG (1.6-2.1 MB each).  This script rewrites them
as Markdown: text, tables and lists are converted 1:1, and every embedded
image is replaced by a link.  Images whose bytes are identical to a committed
figures/*.png link to that file; images that differ (older renderings) are
extracted next to the Markdown so the archive stays complete.

    python code/convert_legacy_html_reports.py reference/v3/DMA_PoC_v3_Report.html ...
"""
from html.parser import HTMLParser
from pathlib import Path
import base64,hashlib,json,re,sys

ROOT=Path(__file__).resolve().parents[1]
FIGURES={hashlib.sha256(p.read_bytes()).hexdigest():p for p in (ROOT/'figures').glob('*.png')}
BLOCK={'p','div','h1','h2','h3','ul','ol','li','table','figure','figcaption','footer','main','body','html','head','tr','thead','tbody','br'}

class ToMarkdown(HTMLParser):
    def __init__(self,html_path):
        super().__init__(convert_charrefs=True)
        self.html_path=html_path;self.out=[];self.stack=[];self.href=None
        self.row=None;self.table=None;self.list_depth=0;self.list_kind=[];self.item_no=[]
        self.images=[];self.skip=0;self.heading=False
    # helpers
    def text(self,s):
        if self.row is not None:self.row[-1]+=s
        else:self.out.append(s)
    def newline(self,n=2):
        joined=''.join(self.out).rstrip(' ')
        self.out=[joined]
        while not joined.endswith('\n'*n):joined+='\n'
        self.out=[joined]
    def handle_starttag(self,tag,attrs):
        a=dict(attrs);cls=a.get('class','')
        if tag in {'style','script','title','head'}:self.skip+=1;return
        if tag in {'h1','h2','h3'}:self.newline();self.text('#'*int(tag[1])+' ');self.heading=True
        elif tag=='p':
            self.newline()
            if cls in {'meta','small','note','sub'}:self.text('> ')
        elif tag=='div':
            self.newline()
            if cls in {'lead','meta','note'}:self.text('> ')
        elif tag=='b':self.text('**')
        elif tag=='code':self.text('`')
        elif tag=='br':self.text(' — ' if self.heading else '\n')
        elif tag=='a':self.href=a.get('href');self.text('[')
        elif tag in {'ul','ol'}:self.newline(1 if self.list_kind else 2);self.list_kind.append(tag);self.item_no.append(0)
        elif tag=='li':
            self.item_no[-1]+=1;prefix='  '*(len(self.list_kind)-1)
            self.text(prefix+(f'{self.item_no[-1]}. ' if self.list_kind[-1]=='ol' else '- '))
        elif tag=='table':self.newline();self.table=[]
        elif tag=='tr':self.row=[]
        elif tag in {'td','th'}:self.row.append('')
        elif tag=='figure':self.newline()
        elif tag=='figcaption':self.newline();self.text('*')
        elif tag=='img':
            src=a.get('src','');alt=a.get('alt','').strip()
            m=re.match(r'data:image/png;base64,(.+)',src,re.S)
            if m:
                data=base64.b64decode(re.sub(r'\s+','',m.group(1)));digest=hashlib.sha256(data).hexdigest()
                if digest in FIGURES:
                    rel=Path(*['..']*len(self.html_path.parent.relative_to(ROOT).parts))/'figures'/FIGURES[digest].name
                    target=rel.as_posix();status='linked'
                else:
                    number=re.search(r'그림\s*(\d+)',alt)
                    name='fig%02d_%s.png'%(int(number.group(1)) if number else len(self.images)+1,self.html_path.stem.lower())
                    folder=self.html_path.parent/'figures';folder.mkdir(exist_ok=True)
                    (folder/name).write_bytes(data);target='figures/'+name;status='extracted'
                self.images.append(dict(alt=alt,target=target,status=status,bytes=len(data)))
                self.newline();self.text(f'![{alt}]({target})');self.newline()
            else:self.newline();self.text(f'![{alt}]({src})');self.newline()
        elif tag=='footer':self.newline();self.text('---\n\n*')
    def handle_endtag(self,tag):
        if tag in {'style','script','title','head'}:self.skip-=1;return
        if tag in {'h1','h2','h3','p','div','figure'}:self.newline();self.heading=False
        elif tag=='b':self.text('**')
        elif tag=='code':self.text('`')
        elif tag=='a':
            self.text(']('+(self.href or '')+')' if self.href and not self.href.startswith('#') else ']');self.href=None
        elif tag=='li':self.text('\n')
        elif tag in {'ul','ol'}:self.list_kind.pop();self.item_no.pop();self.newline()
        elif tag=='tr':
            self.table.append([re.sub(r'\s+',' ',c).strip().replace('|','/') for c in self.row]);self.row=None
        elif tag=='table':
            rows=self.table;self.table=None
            if rows:
                width=max(len(r) for r in rows);rows=[r+['']*(width-len(r)) for r in rows]
                lines=['| '+' | '.join(rows[0])+' |','| '+' | '.join(['---']*width)+' |']+['| '+' | '.join(r)+' |' for r in rows[1:]]
                self.out.append('\n'.join(lines));self.newline()
        elif tag=='figcaption':self.text('*');self.newline()
        elif tag=='footer':self.text('*');self.newline()
    def handle_data(self,data):
        if self.skip:return
        if self.row is None and not data.strip() and (not self.out or self.out[-1].endswith('\n')):return
        self.text(re.sub(r'[ \t\r\n]+',' ',data))
    def result(self):
        text=''.join(self.out)
        text=re.sub(r'\n{3,}','\n\n',text)
        text=re.sub(r'(?m)^(#+ .*?)\s+$',r'\1',text)
        text=re.sub(r'\*\*\s*\*\*','',text)
        return text.strip()+'\n'

def convert(html_path):
    html_path=Path(html_path).resolve()
    parser=ToMarkdown(html_path);parser.feed(html_path.read_text(encoding='utf-8'))
    title=re.search(r'<title>(.*?)</title>',html_path.read_text(encoding='utf-8'),re.S)
    note=('> 보존용 문서. 원본은 그림을 내장한 단독 HTML 보고서(`%s`)였으며 2026-11-03에 Markdown으로 변환했다. '
          '본문·표·그림 설명은 그대로 두었고, 그림은 `figures/`의 동일 PNG를 참조한다(바이트가 다른 옛 렌더링은 같은 폴더의 `figures/`에 추출). '
          '수치는 당시 분석 스냅샷이며 현재 결과는 `outputs/`와 `reports/`를 기준으로 한다.\n\n')%html_path.name
    body=parser.result()
    # Insert the archive note right after the H1 line (a meta line may precede the H1).
    m=re.search(r'(?m)^# .*$',body)
    text=body[:m.end()]+'\n\n'+note+body[m.end():].lstrip('\n')
    md_path=html_path.with_suffix('.md')
    md_path.write_text(text,encoding='utf-8',newline='\n')
    return dict(markdown=md_path.relative_to(ROOT).as_posix(),title=title.group(1) if title else None,
                images=parser.images,characters=len(text))

if __name__=='__main__':
    paths=sys.argv[1:] or ['reference/v3/DMA_PoC_v3_Report.html','reference/before_20plots/DMA_PoC_v4_Report.html']
    print(json.dumps([convert(ROOT/p) for p in paths],ensure_ascii=False,indent=1))
