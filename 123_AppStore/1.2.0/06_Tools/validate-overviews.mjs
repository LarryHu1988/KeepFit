import fs from'node:fs/promises';import path from'node:path';import{fileURLToPath}from'node:url';
const R=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');const{chromium}=await import(path.join(R,'../../126_Tools/MediaRenderer/node_modules/playwright/index.mjs'));
const browser=await chromium.launch({headless:true,channel:'chrome'}),page=await browser.newPage(),rows=[];
const sizes=JSON.parse(await fs.readFile(path.join(R,'07_Validation/screenshot-targets.json'))),stages=JSON.parse(await fs.readFile(path.join(R,'07_Validation/stage-geometry.json')));
const jobs=[];
for(const lang of['zh-Hans','en']){
 for(const s of sizes)jobs.push({lang,w:s.width,h:s.height,device:s.device,source:s.source,kind:'shot',slide:1});
 for(const s of stages.filter(x=>x.locale===lang))jobs.push({lang,w:s.width,h:s.height,device:s.source,source:s.source,kind:'cover',profile:s.profile});
 for(const[kind,w,h]of[['header',3840,1646],['search',3840,2560],['universal',5244,2950]])jobs.push({lang,kind,w,h});
}
for(const job of jobs){
 await page.setViewportSize({width:job.w,height:job.h});await page.goto('http://127.0.0.1:3212/05_Sources/creative.html?'+new URLSearchParams(job),{waitUntil:'domcontentloaded'});await page.waitForFunction(()=>window.ready);
 const data=await page.evaluate(()=>{const items=[...document.querySelectorAll('.hardware')].map(x=>{const r=x.getBoundingClientRect();return{src:x.getAttribute('src'),x:r.x,y:r.y,w:r.width,h:r.height}});const overlap=items.some((a,i)=>items.slice(i+1).some(b=>Math.min(a.x+a.w,b.x+b.w)>Math.max(a.x,b.x)&&Math.min(a.y+a.h,b.y+b.h)>Math.max(a.y,b.y)));return{items,overlap,inside:items.every(x=>x.x>=0&&x.y>=0&&x.x+x.w<=innerWidth+.1&&x.y+x.h<=innerHeight+.1)}});
 const expected=['eat','move','lose'].every(tab=>data.items.some(x=>x.src.endsWith(tab+'-overview.png')));rows.push({...job,...data,pass:job.kind==='header'?data.items.length===0:data.items.length===3&&expected&&!data.overlap&&data.inside});
}
await fs.writeFile(path.join(R,'07_Validation/overview-layout-validation.json'),JSON.stringify(rows,null,2));await browser.close();console.log(rows.length,'three-Tab overview/cover/artwork layouts',rows.every(x=>x.pass)?'PASS':'FAIL');if(rows.some(x=>!x.pass))process.exitCode=1;
