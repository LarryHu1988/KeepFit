import fs from'node:fs/promises';import path from'node:path';import{fileURLToPath}from'node:url';
const R=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const{chromium}=await import(path.join(R,'../../126_Tools/MediaRenderer/node_modules/playwright/index.mjs'));
const sharp=(await import(path.join(R,'../../126_Tools/MediaRenderer/node_modules/sharp/lib/index.js'))).default;
const matrix=JSON.parse(await fs.readFile(path.join(R,'07_Validation/apple-screenshot-sizes.json'))).sizes.filter(x=>x.family==='APP'&&/APP_IPHONE|APP_IPAD/.test(x.displayType));
const sizes=[];
for(const x of matrix)for(const d of x.dimensions.filter(d=>d.width<d.height)){
 const device=x.displayType.includes('IPAD')?'ipad':'iphone',key=d.width+'x'+d.height,existing=sizes.find(s=>s.key===key&&s.device===device);
 if(existing)existing.displayTypes.push(x.displayType);else sizes.push({...d,key,device,source:d.width===750?'iphone-se':device,shotCount:device==='ipad'?4:7,displayTypes:[x.displayType]});
}
for(const[w,h,device,source]of[[1398,2034,'duo-outer','duo-outer'],[2007,2853,'duo-inner','duo-inner-landscape'],[2034,1398,'duo-outer-landscape','duo-outer'],[2853,2007,'duo-inner-landscape','duo-inner-landscape']])sizes.push({width:w,height:h,key:w+'x'+h,device,source,shotCount:device==='duo-inner-landscape'?4:7,displayTypes:['APP_IPHONE_DUO']});
const profiles=[['iphone-modern',886,1920,'iphone','iphone'],['iphone-home-large',1080,1920,'iphone','iphone'],['iphone-home-medium',750,1334,'iphone','iphone-se'],['ipad',1200,1600,'ipad','ipad'],['ipad-legacy',900,1200,'ipad','ipad'],['duo-outer',886,1920,'duo-outer','duo-outer'],['duo-inner',1920,886,'duo-inner-landscape','duo-inner-landscape']];
const browser=await chromium.launch({headless:true,channel:'chrome'}),page=await browser.newPage({deviceScaleFactor:1}),files=[],stages=[];
const sample=process.argv.includes('--sample'),heroes=process.argv.includes('--hero-only'),only=process.argv.find(x=>x.startsWith('--only-source='))?.split('=')[1],onlyDevice=process.argv.find(x=>x.startsWith('--only-device='))?.split('=')[1],screensOnly=process.argv.includes('--screens-only');
const jobs=onlyDevice?sizes.filter(s=>s.device===onlyDevice):only?sizes.filter(s=>s.source===only):sample?sizes.filter(s=>['1320x2868','2064x2752','2853x2007'].includes(s.key)):sizes;
async function render(w,h,params,file){
 await fs.mkdir(path.dirname(path.join(R,file)),{recursive:true});await page.setViewportSize({width:w,height:h});
 await page.goto('http://127.0.0.1:3212/05_Sources/creative.html?'+new URLSearchParams({w,h,...params}),{waitUntil:'domcontentloaded'});
 await page.waitForFunction(()=>window.ready&&[...document.images].every(x=>x.complete&&x.naturalWidth));
 await page.evaluate(()=>document.fonts.ready);
 await sharp(await page.screenshot()).flatten({background:'#f7fafb'}).removeAlpha().withIccProfile('srgb').png().toFile(path.join(R,file));
}
for(const s of jobs){
 for(const lang of['zh-Hans','en'])for(let n=1;n<=s.shotCount;n++){
  if(heroes&&n!==1&&s.device!=='duo-inner-landscape')continue;
  const file=`01_Screenshots/${lang}/${s.device}/${s.key}/${String(n).padStart(2,'0')}.png`;
  await render(s.width,s.height,{lang,slide:n,device:s.device,source:s.source},file);files.push({file,locale:lang,slide:n,...s});
 }
 console.log('SCREENSHOTS',s.device,s.key,s.shotCount);
}
if(!sample&&!only&&!onlyDevice&&!screensOnly)for(const[kind,w,h]of[['header',3840,1646],['search',3840,2560],['universal',5244,2950]])for(const lang of['zh-Hans','en','text-free']){
 const file=`03_Creatives/${lang}/${kind}-${w}x${h}.png`;await render(w,h,{lang,kind,text:lang==='text-free'?0:1},file);files.push({file,locale:lang,kind,width:w,height:h});
}
if(!screensOnly)for(const lang of['zh-Hans','en'])for(const[label,w,h,device,source]of profiles){
 if(only&&source!==only)continue;
 await render(w,h,{lang,kind:'cover',device,source},`05_Sources/covers/${lang}/${label}.png`);
 const stage=`05_Sources/preview-stages/${lang}/${label}.png`;await render(w,h,{lang,kind:'stage',device,source},stage);
 const geometry=await page.evaluate(()=>window.stageGeometry),mask=await sharp(path.join(R,'05_Sources/device-frames',source+'-aperture-alpha.png')).resize(geometry.bodyWidth,geometry.bodyHeight).toBuffer();
 const input=await fs.readFile(path.join(R,stage));await sharp(input).ensureAlpha().composite([{input:mask,left:geometry.x,top:geometry.y,blend:'dest-out'}]).png().toFile(path.join(R,stage));stages.push({profile:label,locale:lang,width:w,height:h,file:stage,...geometry});
}
let output=files;
if(only||heroes||onlyDevice||screensOnly){
 const old=JSON.parse(await fs.readFile(path.join(R,'07_Validation/image-manifest.json'))),changed=new Set(files.map(x=>x.file));
 output=[...old.filter(x=>!changed.has(x.file)&&!(['duo-inner-landscape','ipad'].includes(x.device)&&x.slide>4)),...files];
}
await fs.writeFile(path.join(R,'07_Validation/'+(sample?'sample-manifest':'image-manifest')+'.json'),JSON.stringify(output,null,2));
await fs.writeFile(path.join(R,'07_Validation/screenshot-targets.json'),JSON.stringify(sizes,null,2));
if(!screensOnly)await fs.writeFile(path.join(R,'07_Validation/'+(sample?'sample-stage-geometry':'stage-geometry')+'.json'),JSON.stringify(stages,null,2));await browser.close();
