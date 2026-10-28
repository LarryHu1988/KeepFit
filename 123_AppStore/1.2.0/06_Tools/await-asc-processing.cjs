const fs=require('fs'),path=require('path'),{execFileSync}=require('child_process');
const root=path.resolve(__dirname,'..'),out=path.join(root,'08_AppStoreConnect');
(async()=>{for(let round=1;round<=30;round++){
for(const script of ['verify-asc-media.cjs','fix-asc-posters.cjs']){try{const r=execFileSync(process.execPath,[path.join(__dirname,script)],{encoding:'utf8',timeout:180000,maxBuffer:10*1024*1024});fs.writeFileSync(path.join(out,script+'.log'),r)}catch(e){console.log('CHECK_ERROR',script,e.message.slice(0,200))}}
const m=JSON.parse(fs.readFileSync(path.join(out,'media-verification.json'))),p=JSON.parse(fs.readFileSync(path.join(out,'poster-verification.json')));console.log(JSON.stringify({at:new Date().toISOString(),round,mediaPending:m.problems.length,postersComplete:p.complete,postersPending:p.pending}));if(!m.problems.length&&!p.pending)return;await new Promise(r=>setTimeout(r,30000));}process.exitCode=2})().catch(e=>{console.error(e);process.exitCode=1})
