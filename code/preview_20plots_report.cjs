const {createRequire}=require('node:module');
const {pathToFileURL}=require('node:url');
const path=require('node:path');
const fs=require('node:fs');
const req=createRequire('C:/Users/mw595/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json');
const {chromium}=req('playwright');
(async()=>{
 const root=path.resolve(__dirname,'..');
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'});
 const page=await browser.newPage({viewport:{width:1440,height:1100},deviceScaleFactor:1});
 await page.goto(pathToFileURL(path.join(root,'reports','DMA_PoC_20plots_Report.html')).href,{waitUntil:'load'});
 const qa=await page.evaluate(()=>({title:document.title,figureSections:document.querySelectorAll('.figure-section').length,
 images:Array.from(document.images).map(i=>({complete:i.complete,width:i.naturalWidth})),
 horizontalOverflow:document.documentElement.scrollWidth>innerWidth,
 localReferenceLinksValid:Array.from(document.querySelectorAll('a[href^="#"]')).every(a=>document.getElementById(a.getAttribute('href').slice(1)))}));
 await page.screenshot({path:path.join(root,'reports','qa_pages','html_overview.png')});
 await page.locator('#fig13').screenshot({path:path.join(root,'reports','qa_pages','html_figure13.png')});
 await page.setViewportSize({width:390,height:844});
 qa.mobileOverflow=await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth);
 fs.writeFileSync(path.join(root,'reports','html_layout_validation.json'),JSON.stringify(qa,null,2));
 console.log(JSON.stringify(qa));
 await browser.close();
 if(qa.figureSections!==20||qa.horizontalOverflow||qa.mobileOverflow||!qa.localReferenceLinksValid||qa.images.some(i=>!i.complete||i.width===0))process.exit(1);
})().catch(e=>{console.error(e);process.exit(1)});
