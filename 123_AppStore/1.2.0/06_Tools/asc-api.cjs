// Existing ASC keychain profile signs the token; credentials remain in memory.
const {execFileSync}=require('node:child_process');let token,issued=0;
async function api(method,endpoint,body){
 if(!endpoint.startsWith('/v1/'))throw Error('Only the ASC v1 API is permitted');
 if(!token||Date.now()-issued>8*60*1000){token=execFileSync('asc',['auth','token','--confirm'],{encoding:'utf8'}).trim();issued=Date.now()}
 const r=await fetch('https://api.appstoreconnect.apple.com'+endpoint,{method,headers:{Authorization:'Bearer '+token,'Content-Type':'application/json'},body:body?JSON.stringify(body):undefined,signal:AbortSignal.timeout(90000)});
 const d=r.status===204?{}:await r.json();if(!r.ok)throw Error(method+' '+endpoint+': '+r.status+' '+JSON.stringify(d.errors));return d;
}
module.exports={api};
