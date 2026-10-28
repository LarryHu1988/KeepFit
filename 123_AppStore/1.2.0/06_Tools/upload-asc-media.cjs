const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict'),{execFile}=require('node:child_process'),{promisify}=require('node:util'),{api}=require('./asc-api.cjs');
const R=path.resolve(__dirname,'..'),OUT=path.join(R,'08_AppStoreConnect'),plan=JSON.parse(fs.readFileSync(path.join(OUT,'upload-plan.json'))),run=promisify(execFile),receipt=path.join(OUT,'MediaReceipts');fs.mkdirSync(receipt,{recursive:true});
const save=(file,value)=>fs.writeFileSync(path.join(receipt,file),JSON.stringify(value,null,2));
async function cli(args){return JSON.parse((await run('asc',[...args,'--output','json'],{encoding:'utf8',maxBuffer:24*1024*1024,timeout:1200000})).stdout)}
async function uploadDuo(job,kind){
 const images=kind==='screenshot',resource=images?'appScreenshots':'appPreviews',setResource=images?'appScreenshotSets':'appPreviewSets',field=images?'screenshotDisplayType':'previewType',type=images?job.displayType:job.displayType.replace(/^APP_/,'');
 let sets=(await api('GET',`/v1/appStoreVersionLocalizations/${job.localizationId}/${setResource}`)).data,set=sets.find(x=>x.attributes[field]===type);
 if(!set)set=(await api('POST',`/v1/${setResource}`,{data:{type:setResource,attributes:{[field]:type},relationships:{appStoreVersionLocalization:{data:{type:'appStoreVersionLocalizations',id:job.localizationId}}}}})).data;
 let current=(await api('GET',`/v1/${setResource}/${set.id}/${resource}`)).data;const items=images?job.screenshots:job.previews,done=[];const desired=new Set(items.map(x=>x.md5));for(const old of current.filter(x=>!desired.has(x.attributes.sourceFileChecksum))){save(job.locale+'-'+type+'-'+old.id+'-replaced-wrapper.json',old);await api('DELETE',`/v1/${resource}/${old.id}`)}current=current.filter(x=>desired.has(x.attributes.sourceFileChecksum));
 for(const item of items){
  let asset=current.find(x=>x.attributes.sourceFileChecksum===item.md5);
  if(!asset){
   const bytes=fs.readFileSync(path.join(R,item.file));assert.equal(crypto.createHash('md5').update(bytes).digest('hex'),item.md5);
   asset=(await api('POST',`/v1/${resource}`,{data:{type:resource,attributes:{fileName:path.basename(item.file),fileSize:bytes.length,...(!images?{mimeType:'video/mp4',previewFrameTimeCode:'00:00:00:00'}:{})},relationships:{[images?'appScreenshotSet':'appPreviewSet']:{data:{type:setResource,id:set.id}}}}})).data;
   for(const op of asset.attributes.uploadOperations||[]){
    assert.equal(new URL(op.url).protocol,'https:');let success=false;
    for(let attempt=0;attempt<3&&!success;attempt++){
     const res=await fetch(op.url,{method:op.method,headers:Object.fromEntries(op.requestHeaders.map(h=>[h.name,h.value])),body:bytes.subarray(op.offset,op.offset+op.length),signal:AbortSignal.timeout(120000)});await res.arrayBuffer();success=res.ok;if(!success&&attempt===2)throw Error('Upload transfer failed '+res.status);
    }
   }
   await api('PATCH',`/v1/${resource}/${asset.id}`,{data:{type:resource,id:asset.id,attributes:{uploaded:true,sourceFileChecksum:item.md5,...(!images?{previewFrameTimeCode:'00:00:00:00'}:{})}}});
  }
  done.push({assetId:asset.id,...item});console.log('DUO',job.locale,kind,path.basename(item.file));
 }
 await api('PATCH',`/v1/${setResource}/${set.id}/relationships/${resource}`,{data:done.map(x=>({type:resource,id:x.assetId}))});return{setId:set.id,results:done};
}
async function upload(job){
 for(const kind of (process.argv.includes('--screens-only')?['screenshot']:['screenshot','preview'])){
  const items=kind==='screenshot'?job.screenshots:job.previews;if(!items.length)continue;
  const file=job.locale+'-'+job.displayType+'-'+kind+'.json';if(fs.existsSync(path.join(receipt,file))){console.log('RESUME',file);continue}
  console.log('UPLOAD',job.locale,job.displayType,kind,items.length);
  for(const item of items)assert.equal(crypto.createHash('md5').update(fs.readFileSync(path.join(R,item.file))).digest('hex'),item.md5);
  let result;
  if(true)result=await uploadDuo(job,kind);
  else result=await cli([kind==='screenshot'?'screenshots':'video-previews','upload','--version-localization',job.localizationId,'--path',kind==='screenshot'?job.screenshotDirectory:path.join(R,items[0].file),'--device-type',kind==='screenshot'?job.displayType:job.displayType.replace(/^APP_/,''),'--replace','--confirm']);
  save(file,result);console.log('UPLOADED',job.locale,job.displayType,kind);
 }
}
(async()=>{
 const version=(await api('GET','/v1/appStoreVersions/'+plan.versionId)).data;assert.equal(version.attributes.versionString,'1.2.0');assert.equal(version.attributes.appStoreState,'PREPARE_FOR_SUBMISSION');
 const jobs=[...plan.jobs],errors=[];async function worker(){while(jobs.length){const job=jobs.shift();try{await upload(job)}catch(e){errors.push({locale:job.locale,type:job.displayType,error:e.message,stderr:e.stderr,stdout:e.stdout});console.error('FAILED',job.locale,job.displayType,e.message)}}}
 await Promise.all([worker(),worker(),worker()]);save('upload-summary.json',{at:new Date().toISOString(),errors});console.log(errors.length?'UPLOADS_NEED_REPAIR':'ALL_MEDIA_UPLOADED',errors.length);if(errors.length)process.exitCode=1;
})().catch(e=>{console.error(e.message);process.exitCode=1});
