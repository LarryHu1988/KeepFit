'use strict';
const $ = id => document.getElementById(id);
let state = null, draft = null, source = 'text', photo = null, busy = false, rulesDirty = false, recognition = null;
let toastTimer, busyTimer;
const statusLabels = {needs_clarification:'待补充',ready_for_confirmation:'待确认',confirmed:'已确认'};
const el = (tag, text, cls) => { const n=document.createElement(tag); if(text!==undefined)n.textContent=text; if(cls)n.className=cls; return n; };
function toast(text, error=false) { clearTimeout(toastTimer); $('toast').textContent=text; $('toast').className='toast'+(error?' error':''); $('toast').hidden=false; toastTimer=setTimeout(()=>$('toast').hidden=true,error?11000:5500); }
async function api(path, body, method) {
  const controller = new AbortController(), timeout = setTimeout(()=>controller.abort(),75000);
  try {
    const response = await fetch(path,{method:method||(body===undefined?'GET':'POST'),credentials:'same-origin',
      headers:body===undefined?{}:{'Content-Type':'application/json','Idempotency-Key':crypto.randomUUID()},
      body:body===undefined?undefined:JSON.stringify(body),signal:controller.signal});
    const data = await response.json();
    if(!response.ok) throw new Error(data.error?.message||'请求未完成，请稍后再试。');
    return data;
  } catch(error) { if(error.name==='AbortError') throw new Error('等待时间较长，请先查看最近的试用，避免重复提交。'); throw error; }
  finally {clearTimeout(timeout);}
}
function setBusy(value, message='正在理解这餐…') {
  busy=value; $('busyNotice').hidden=!value;
  ['analyzeButton','answerButton','reviseButton','saveFeedbackButton','confirmButton'].forEach(id=>$(id).disabled=value);
  clearInterval(busyTimer);
  if(value){let seconds=0;$('busyNotice').querySelector('strong').textContent=message; $('busyText').textContent='请求已发出，通常需要几秒到几十秒。';busyTimer=setInterval(()=>{seconds++;$('busyText').textContent=`已等待 ${seconds} 秒 · 没有自动重试，也不会重复扣除试用次数。`;},1000);}
  else { updateConfirm(); $('reviseButton').disabled=!!draft&&(draft.status==='confirmed'||draft.model.simulated); }
}
function showPage(name) {
  document.querySelectorAll('.page').forEach(n=>n.hidden=n.id!==`page-${name}`);
  document.querySelectorAll('.nav').forEach(n=>n.classList.toggle('active',n.dataset.page===name));
  $('breadcrumb').textContent='工作台 / '+({try:'试用模型',rules:'调整规则',feedback:'纠正案例'}[name]);
}
function setSource(next) {
  if(busy)return;
  source=next;
  document.querySelectorAll('.input-tab').forEach(n=>{const active=n.dataset.source===source;n.classList.toggle('selected',active);n.setAttribute('aria-selected',String(active));});
  $('voiceControls').hidden=source!=='voice';$('photoControls').hidden=source!=='photo';
  $('mealText').placeholder=source==='photo'?'可以补充：这是两个人的菜，我吃了半碗米饭、三块肉。':source==='voice'?'语音转写会出现在这里，你可以先修改再识别。':'比如：中午吃了半碗米饭，三块红烧肉和一些青菜。菜是四个人一起吃的，我没有喝汤。';
  if(source!=='voice'&&recognition)recognition.abort();
}
function openConnection() {$('connectError').hidden=true;if(!$('connectionDialog').open)$('connectionDialog').showModal();}
function connectionLabel(c) {return c.connected?(c.provider==='deepseek'?'DeepSeek 已连接':'MiMo 已连接'):'尚未连接模型';}
async function refresh(fillRules=false) {
  state=await api('/v1/workbench/state'); const c=state.connection;
  $('connectionName').textContent=connectionLabel(c);$('connectionDot').classList.toggle('connected',c.connected);
  $('modeTag').textContent=c.connected?'真实模型 · 可试用':'等待连接';$('modeTag').classList.toggle('connected',c.connected);
  $('usageText').textContent=c.connected?`本轮已用 ${c.calls_used} / ${c.call_limit} 次`:'连接后即可真实识别';
  $('dialogUsage').textContent=`已请求 ${c.calls_used} / ${c.call_limit} 次 · 已报告 ${c.tokens_used.toLocaleString()} tokens`;
  $('extendTrial').hidden=c.calls_used<c.call_limit;$('disconnectButton').hidden=!c.connected;
  $('feedbackCount').textContent=state.feedback.length;
  if(fillRules&&!rulesDirty){$('questionStyle').value=state.rules.question_style;$('allowEstimates').checked=state.rules.allow_estimates;$('instructions').value=state.rules.instructions;}
  $('ruleVersion').textContent=`当前规则版本 ${state.rules.revision}`;
  renderFeedback();renderHistory();
}
function renderHistory(){
  const target=$('historyList');target.replaceChildren();
  if(!state.history.length){target.append(el('p','还没有记录。开始第一餐吧。','empty-small'));return;}
  state.history.forEach(item=>{const button=el('button',undefined,'history-item');button.append(el('span',item.text.slice(0,100)),el('small',`${statusLabels[item.status]}${item.simulated?' · 固定案例演示':''}`));button.onclick=async()=>{if(busy)return;try{draft=await api('/v1/intakes/'+item.id);showPage('try');renderResult();}catch(e){toast(e.message,true);}};target.append(button);});
}
function renderFeedback(){
  const target=$('feedbackList');target.replaceChildren();
  if(!state.feedback.length){const box=el('section',undefined,'panel settings-panel');box.append(el('h2','还没有纠正案例'),el('p','先试用模型，遇到理解不对的地方，直接写下你的纠正并保存。','hint'));target.append(box);return;}
  state.feedback.forEach(item=>{const box=el('section',undefined,'panel feedback-card'),head=el('div',undefined,'section-title');head.append(el('h2','一次有用的纠正'),el('span',item.use_for_future?'用于后续理解':'仅保存','tag subtle'));box.append(head,el('blockquote',item.original_text),el('p','你的纠正：'+item.correction,'correction'));const foot=el('div',undefined,'section-title');foot.append(el('span',new Date(item.created_at).toLocaleString('zh-CN'),'hint'));const remove=el('button','删除此案例','text-button');remove.onclick=async()=>{if(!confirm('删除后，后续识别将不再参考这条纠正。确定删除？'))return;try{await api(`/v1/workbench/feedback/${item.id}/delete`,{});await refresh();toast('案例已删除。');}catch(e){toast(e.message,true);}};foot.append(remove);box.append(foot);target.append(box);});
}
function updateConfirm(){const ready=draft&&draft.status==='ready_for_confirmation';$('confirmButton').disabled=busy||!ready||!$('acceptEstimates').checked;}
function renderResult(){
  if(!draft)return;
  $('emptyResult').hidden=true;$('resultContent').hidden=false;$('resultStatus').textContent=statusLabels[draft.status];
  $('normalizedText').textContent=draft.understanding.normalized_text;
  const totals=draft.totals;
  $('energyValue').textContent=totals?Math.round(totals.calories_kcal).toLocaleString():'—';
  $('energyLabel').textContent=draft.model.simulated?'演示数据':totals?'整餐估算':'信息待补充';
  [['proteinValue','protein_g'],['fatValue','fat_g'],['carbsValue','carbs_g']].forEach(([id,key])=>$(id).textContent=totals?Math.round(totals[key])+' g':'—');
  $('incompleteNote').hidden=!!totals;
  const foods=$('foodList');foods.replaceChildren();
  draft.items.forEach(item=>{const row=el('div',undefined,'food-item'+(!item.included_in_totals?' excluded':'')),top=el('div',undefined,'food-top');top.append(el('strong',item.name),el('span',item.included_in_totals?(item.nutrients?'约 '+Math.round(item.nutrients.calories_kcal)+' kcal':'待估算'):(item.parent_id?'组成项，不重复计入':item.consumption==='not_eaten'?'没有吃':item.eater==='other'?'他人食物':'待确认')));row.append(top,el('p',item.original_portion));const details=el('details');details.append(el('summary','查看估算依据'));if(item.consumed_grams!==null)details.append(el('p',`${item.portion_is_estimate?'估算':'记录'}可食重量：${item.consumed_grams} g`));item.estimation_notes.forEach(note=>details.append(el('p',note)));row.append(details);foods.append(row);});
  const notes=$('warnings');notes.replaceChildren();if(draft.model.simulated)notes.append(el('p','这是固定案例演示，不是真实模型识别。'));
  draft.understanding.warnings.forEach(text=>notes.append(el('p',text)));
  $('mealTime').textContent=draft.understanding.meal_time?`用餐时间：${new Date(draft.understanding.meal_time).toLocaleString('zh-CN')} · ${draft.understanding.meal_time_note}`:draft.understanding.meal_time_note;
  $('confirmControls').hidden=draft.status==='confirmed';$('confirmedMessage').hidden=draft.status!=='confirmed';$('acceptEstimates').checked=false;
  $('revisionPanel').hidden=false;$('reviseButton').disabled=busy||draft.status==='confirmed'||draft.model.simulated;
  $('questionPanel').hidden=draft.understanding.questions.length===0||draft.status==='confirmed';
  const questions=$('questions');questions.replaceChildren();
  draft.understanding.questions.forEach((q,index)=>{const wrap=el('div',undefined,'question'),label=el('label',q.text);const id='answer-'+index;label.htmlFor=id;wrap.append(label);const choices=el('div',undefined,'options'),input=el('input');input.id=id;input.dataset.question=q.id;input.maxLength=2000;input.placeholder='也可以用自己的话补充…';q.options.forEach(option=>{const button=el('button',option,'option');button.type='button';button.onclick=()=>{input.value=option;choices.querySelectorAll('button').forEach(b=>b.classList.toggle('selected',b===button));};choices.append(button);});wrap.append(choices,input);questions.append(wrap);});updateConfirm();
}
async function analyze(){
  if(busy)return;if(!state?.connection.connected){openConnection();return;}
  const text=$('mealText').value.trim();if(source!=='photo'&&!text){toast('先写下或说出你吃了什么。',true);return;}if(source==='photo'&&!photo){toast('先选择一张食物照片。',true);return;}
  const payload={source,reference_time:new Date().toISOString(),timezone:Intl.DateTimeFormat().resolvedOptions().timeZone||'Asia/Shanghai'};
  if(source==='text')payload.text=text;if(source==='voice')payload.transcript=text;if(source==='photo'){payload.image=photo;if(text)payload.text=text;}
  setBusy(true);try{draft=await api('/v1/intakes',payload);$('correctionText').value='';renderResult();toast('已生成结果，请核对实际份量和估算依据。');}catch(e){toast(e.message,true);}finally{setBusy(false);await refresh().catch(()=>{});}
}
async function answer(){if(busy||!draft)return;const answers={};$('questions').querySelectorAll('input').forEach(i=>{if(i.value.trim())answers[i.dataset.question]=i.value.trim();});if(!Object.keys(answers).length){toast('请选择一个选项，或填写补充信息。',true);return;}setBusy(true,'正在根据你的补充更新…');try{draft=await api(`/v1/intakes/${draft.id}/answers`,{expected_revision:draft.revision,answers});renderResult();}catch(e){toast(e.message,true);}finally{setBusy(false);await refresh().catch(()=>{});}}
async function saveFeedback(correction){return api('/v1/workbench/feedback',{intake_id:draft.id,expected_revision:draft.revision,correction,use_for_future:$('learnCorrection').checked});}
async function revise(onlySave=false){if(busy||!draft)return;const correction=$('correctionText').value.trim();if(!correction){toast('先写下你希望怎样纠正。',true);return;}if(!onlySave&&draft.status==='confirmed'){toast('这条记录已确认，可以保存纠正案例；要重新识别请开始新的一餐。',true);return;}setBusy(true,onlySave?'正在保存纠正案例…':'正在按你的纠正重新理解…');let saved=false;try{if(onlySave||$('learnCorrection').checked){await saveFeedback(correction);saved=true;}if(!onlySave){draft=await api(`/v1/intakes/${draft.id}/revise`,{expected_revision:draft.revision,correction});renderResult();}toast(onlySave?'纠正案例已保存，后续识别会按启用状态参考。':saved?'结果已更新，纠正案例也已保存。':'结果已更新。');$('correctionText').value='';}catch(e){toast((saved?'纠正案例已保存；':'')+e.message,true);}finally{setBusy(false);await refresh().catch(()=>{});}}
function resetPhoto(){photo=null;$('photoFile').value='';$('photoPreview').hidden=true;$('photoPreview').removeAttribute('src');$('removePhoto').hidden=true;}
async function loadPhoto(event){const file=event.target.files[0];if(!file)return;resetPhoto();if(!['image/jpeg','image/png'].includes(file.type)||file.size>4*1024*1024){toast('请选择不超过 4 MB 的 JPEG 或 PNG 图片。',true);return;}const url=URL.createObjectURL(file);try{const img=new Image();img.src=url;await img.decode();const scale=Math.min(1,1600/Math.max(img.width,img.height)),canvas=document.createElement('canvas');canvas.width=Math.round(img.width*scale);canvas.height=Math.round(img.height*scale);canvas.getContext('2d').drawImage(img,0,0,canvas.width,canvas.height);const data=canvas.toDataURL('image/jpeg',.88);photo={mime_type:'image/jpeg',base64_data:data.split(',')[1]};$('photoPreview').src=data;$('photoPreview').hidden=false;$('removePhoto').hidden=false;}catch(e){toast('图片无法读取，请换一张 JPEG 或 PNG。',true);}finally{URL.revokeObjectURL(url);}}
function startVoice(){if(recognition){recognition.stop();return;}const Speech=window.SpeechRecognition||window.webkitSpeechRecognition;if(!Speech){$('voiceStatus').textContent='当前浏览器不支持网页语音转写。可点击下方输入框，使用 Mac 的系统听写输入，再点击识别。';$('mealText').focus();return;}recognition=new Speech();recognition.lang='zh-CN';recognition.continuous=false;recognition.interimResults=false;recognition.onresult=e=>{$('mealText').value=Array.from(e.results).map(r=>r[0].transcript).join('');$('voiceStatus').textContent='转写完成，可先修改文字再识别。';};recognition.onerror=()=>{$('voiceStatus').textContent='语音转写未完成，请检查麦克风权限，也可使用系统听写。';};recognition.onend=()=>{recognition=null;$('voiceButton').textContent='开始说话';};try{recognition.start();$('voiceButton').textContent='结束说话';$('voiceStatus').textContent='正在听，请描述这餐实际吃了什么。';}catch(e){recognition=null;toast('语音无法启动，请使用系统听写。',true);}}

document.querySelectorAll('[data-page]').forEach(n=>n.onclick=()=>showPage(n.dataset.page));
document.querySelectorAll('[data-source]').forEach(n=>n.onclick=()=>setSource(n.dataset.source));
document.querySelectorAll('[data-open-connect]').forEach(n=>n.onclick=openConnection);
document.querySelectorAll('[data-sample]').forEach(n=>n.onclick=()=>{if(busy)return;setSource('text');$('mealText').value=n.dataset.sample;$('mealText').focus();});
$('closeConnect').onclick=()=>$('connectionDialog').close();
$('providerSelect').onchange=()=>{$('consoleLink').href=state?.vendors.find(v=>v.id===$('providerSelect').value)?.console||'https://platform.deepseek.com/api_keys';};
$('connectionForm').onsubmit=async event=>{event.preventDefault();const key=$('apiKey').value.trim();if(!key){$('connectError').textContent='请填写所选平台的密钥。';$('connectError').hidden=false;return;}$('connectButton').disabled=true;$('connectButton').textContent='正在验证连接…';$('connectError').hidden=true;$('apiKey').value='';try{await api('/v1/workbench/connect',{provider:$('providerSelect').value,api_key:key});await refresh();$('connectionDialog').close();toast('模型已连接。现在可以输入任意一餐，点击“开始识别”。');}catch(e){$('connectError').textContent=e.message;$('connectError').hidden=false;}finally{$('connectButton').disabled=false;$('connectButton').textContent='验证并连接';}};
$('disconnectButton').onclick=async()=>{try{await api('/v1/workbench/disconnect',{});await refresh();toast('已断开连接，并清除本机内存中的密钥。');}catch(e){toast(e.message,true);}};
$('extendTrial').onclick=async()=>{try{await api('/v1/workbench/extend-trial',{});await refresh();toast('已开启下一轮 10 次试用。每次仍由你手动发起。');}catch(e){toast(e.message,true);}};
$('saveRules').onclick=async()=>{$('saveRules').disabled=true;try{await api('/v1/workbench/rules',{expected_revision:state.rules.revision,question_style:$('questionStyle').value,allow_estimates:$('allowEstimates').checked,instructions:$('instructions').value});rulesDirty=false;await refresh(true);toast('规则已保存，将用于下一次识别或补问。');}catch(e){toast(e.message,true);}finally{$('saveRules').disabled=false;}};
['questionStyle','allowEstimates','instructions'].forEach(id=>$(id).oninput=()=>rulesDirty=true);
$('analyzeButton').onclick=analyze;$('answerButton').onclick=answer;$('reviseButton').onclick=()=>revise(false);$('saveFeedbackButton').onclick=()=>revise(true);
$('acceptEstimates').onchange=updateConfirm;
$('confirmButton').onclick=async()=>{if(busy||!draft||!$('acceptEstimates').checked)return;setBusy(true,'正在保存记录…');try{const record=await api(`/v1/intakes/${draft.id}/confirm`,{expected_revision:draft.revision,accept_estimates:true});draft=record.snapshot;renderResult();toast('这条试用记录已保存到本机工作台。');}catch(e){toast(e.message,true);}finally{setBusy(false);await refresh().catch(()=>{});}};
$('photoFile').onchange=loadPhoto;$('removePhoto').onclick=resetPhoto;$('voiceButton').onclick=startVoice;
refresh(true).catch(e=>toast('工作台暂时无法连接本机服务：'+e.message,true));
