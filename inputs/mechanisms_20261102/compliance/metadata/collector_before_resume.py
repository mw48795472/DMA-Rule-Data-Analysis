"""Archive public official compliance evidence. No credentials or API keys used."""
from pathlib import Path
import concurrent.futures,csv,datetime,hashlib,html,json,re,subprocess,sys,urllib.request,urllib.error
from pypdf import PdfReader
ROOT=Path(__file__).resolve().parents[1]
D=ROOT/'inputs/mechanisms_20261102/compliance'
for x in ['raw','csv','metadata','text']:(D/x).mkdir(parents=True,exist_ok=True)
SOURCES=[
('apple_eu_20240125','https://developer.apple.com/news/?id=fsmaf67j','html','do not apply to apps distributed anywhere else'),
('apple_global_20240125','https://developer.apple.com/news/?id=f1v8pyay','html','globally'),
('apple_web_20240312','https://developer.apple.com/news/?id=8c1m8hqt','html','Web Distribution'),
('apple_compliance_2026','https://www.apple.com/legal/dma/NCS-March-2026.pdf','pdf','March 7, 2024'),
('google_compliance_20240305','https://blog.google/company-news/inside-google/around-the-globe/google-europe/complying-with-the-digital-markets-act/','html','External offers program'),
('google_linked_services','https://business.safety.google/privacy/google-services/search/','html','European Economic Area'),
('microsoft_20240307','https://blogs.microsoft.com/eupolicy/2024/03/07/microsoft-dma-compliance-windows-linkedin/','html','EEA'),
('meta_choices_20240122','https://about.fb.com/news/2024/01/offering-people-more-choice-on-how-they-can-use-our-services-in-the-eu/','html','Switzerland'),
('meta_interop_20240306','https://engineering.fb.com/2024/03/06/security/whatsapp-messenger-messaging-interoperability-eu/','html','interoperability'),
('tiktok_20240304','https://newsroom.tiktok.com/tiktoks-compliance-with-the-dma?lang=en-150','html','portability'),
('tiktok_api_20240322','https://developers.tiktok.com/blog/2024-introducing-tiktok-data-portability-api','html','European Economic Area'),
('amazon_20240307','https://www.aboutamazon.eu/news/policy/amazon-and-the-digital-markets-act','html','Consent'),
('amazon_consent_help','https://www.primevideo.com/help?nodeId=TTMAnFoZYT0qLhmEdG&tr=ge','html','6 March 2024'),
('booking_report_20241114','https://www.bookingholdings.com/wp-content/uploads/2024/11/DMA-Compliance-Report.pdf','pdf','1 July 2024'),
('booking_ec_20260928','https://digital-markets-act.ec.europa.eu/factsheet-how-dma-ensures-businesses-using-bookingcom-are-free-set-their-prices-and-bookingcom-2026-09-28_en','html','July 2024'),
('ec_noncompliance_20250423','https://ec.europa.eu/commission/presscorner/api/files/document/print/en/ip_25_1085/IP_25_1085_EN.pdf','pdf','23 April 2025'),
('apple_news_other_law','https://developer.apple.com/news/','html','United States court decision'),
('ec_compliance_portal','https://digital-markets-act-cases.ec.europa.eu/reports/compliance-reports','html','Compliance'),
]
def clean(x):return re.sub(r'\s+',' ',html.unescape(re.sub('<[^>]+>',' ',x)))
def run(job):
    sid,url,ext,phrase=job;f=D/'raw'/(sid+'.'+ext)
    rec=dict(source_id=sid,url=url,api_key_required='no',retrieved_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),status='',file='',sha256='',bytes=0,validation_phrase=phrase)
    try:
        if not f.exists():
            req=urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0 (public academic research data collection)'})
            try:
                with urllib.request.urlopen(req,timeout=60) as response:data=response.read()
                f.write_bytes(data)
            except urllib.error.URLError as ex:
                if 'CERTIFICATE_VERIFY_FAILED' not in str(ex):raise
                q=lambda s:"'"+str(s).replace("'","''")+"'"
                subprocess.run(['powershell.exe','-NoProfile','-Command','Invoke-WebRequest -UseBasicParsing -Uri '+q(url)+' -OutFile '+q(f)],check=True,capture_output=True,timeout=80)
        data=f.read_bytes()
        text='\n'.join(p.extract_text() or '' for p in PdfReader(str(f)).pages) if ext=='pdf' else clean(data.decode('utf-8','replace'))
        (D/'text'/(sid+'.txt')).write_text(text,encoding='utf-8')
        rec.update(file=f.relative_to(ROOT).as_posix(),sha256=hashlib.sha256(data).hexdigest(),bytes=len(data),status='downloaded_content_verified' if clean(phrase).casefold() in clean(text).casefold() else 'downloaded_needs_review')
    except Exception as ex:
        rec['status']='access_failed';rec['error']=str(ex)[:700]
    print(sid,rec['status'],rec['bytes'],flush=True)
    return rec
if __name__=='__main__':
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:rows=list(pool.map(run,SOURCES))
    cols=['source_id','url','api_key_required','retrieved_utc','status','file','sha256','bytes','validation_phrase','error']
    with (D/'SOURCE_MANIFEST.csv').open('w',encoding='utf-8-sig',newline='') as stream:
        w=csv.DictWriter(stream,fieldnames=cols);w.writeheader();w.writerows(rows)
    print(json.dumps({'sources':len(rows),'content_verified':sum(r['status']=='downloaded_content_verified' for r in rows),'failed':sum(r['status']=='access_failed' for r in rows)}))
    if not any(r['status']=='downloaded_content_verified' for r in rows):sys.exit(2)
