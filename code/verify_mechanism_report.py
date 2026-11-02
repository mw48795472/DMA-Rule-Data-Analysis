from pathlib import Path
import hashlib,json
from PIL import Image,ImageOps,ImageDraw
from pypdf import PdfReader
ROOT=Path(__file__).resolve().parents[1]
out=ROOT/'outputs/mechanisms_20261102/integration'
qa=out/'pdf_qa'
frozen=json.loads((ROOT/'reports/report_input_hashes.json').read_text(encoding='utf8'))
assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==digest for p,digest in frozen.items())
sources=json.loads((out/'integration_source_hashes.json').read_text(encoding='utf8'))
assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==digest for p,digest in sources.items())
nb=json.loads((ROOT/'MECHANISMS_REVIEW.ipynb').read_text(encoding='utf8'))
for i,cell in enumerate(nb['cells']):
    if cell['cell_type']=='code':compile(''.join(cell['source']),f'cell{i}','exec')
pdf=ROOT/'reports/DMA_Mechanisms_Research_Design_20261102.pdf'
r=PdfReader(str(pdf));assert len(r.pages)==15
assert sum(len(p.images) for p in r.pages)==3
pages=sorted(qa.glob('page-*.png'));assert len(pages)==15
thumbs=[]
for p in pages:
    im=Image.open(p).convert('RGB');im.thumbnail((298,422))
    tile=Image.new('RGB',(320,452),'#dce6eb');tile.paste(im,((320-im.width)//2,8))
    ImageDraw.Draw(tile).text((12,432),p.stem,fill='black');thumbs.append(tile)
sheet=Image.new('RGB',(320*3,452*5),'white')
for i,im in enumerate(thumbs):sheet.paste(im,((i%3)*320,(i//3)*452))
sheet.save(qa/'contact_sheet.png')
checks=dict(status='PASS',old_report_input_files_unchanged=len(frozen),new_source_hashes_verified=len(sources),
 notebook_code_compiles=True,pdf_pages=15,pdf_figures=3,rendered_pages=15,visual_review='PENDING')
(out/'final_artifact_checks.json').write_text(json.dumps(checks,indent=2),encoding='utf8')
print(json.dumps(checks))
