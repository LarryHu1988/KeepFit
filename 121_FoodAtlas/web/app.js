'use strict';
const $ = (selector) => document.querySelector(selector);
const esc = (value) => String(value ?? '').replace(/[&<>"']/g, (char) => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]));
const number = (value, digits = 1) => value == null || !Number.isFinite(value) ? '—' : value.toLocaleString('zh-CN', {maximumFractionDigits: digits});
const count = (value) => number(value, 0);
const keys = ['calories_kcal', 'protein_g', 'fat_g', 'carbs_g'];
const state = {source: 'all', page: 1, pages: 1, detail: null};
let listingRequest, searchTimer, detailVersion = 0;
const initial = new URLSearchParams(location.search);
$('#search').value = initial.get('q') || '';
state.source = initial.get('source') || 'all';
const nutrientNames = {
 '1002':'氮','1003':'蛋白质','1004':'脂肪','1005':'碳水化合物（差减法）','1007':'灰分','1008':'能量','1009':'淀粉',
 '1010':'蔗糖','1011':'葡萄糖','1012':'果糖','1013':'乳糖','1014':'麦芽糖','1018':'乙醇','1024':'比重',
 '1050':'碳水化合物（加和法）','1051':'水分','1057':'咖啡因','1058':'可可碱','1062':'能量','1063':'总糖',
 '1079':'膳食纤维','1082':'可溶性纤维','1084':'不溶性纤维','1085':'总脂肪（NLEA）',
 '1087':'钙','1089':'铁','1090':'镁','1091':'磷','1092':'钾','1093':'钠','1094':'硫','1095':'锌',
 '1097':'钴','1098':'铜','1099':'氟','1100':'碘','1101':'锰','1102':'钼','1103':'硒',
 '1104':'维生素 A（IU）','1105':'视黄醇','1106':'维生素 A（RAE）','1107':'β-胡萝卜素','1108':'α-胡萝卜素',
 '1109':'维生素 E（α-生育酚）','1110':'维生素 D（D2+D3，IU）','1111':'维生素 D2','1112':'维生素 D3',
 '1114':'维生素 D（D2+D3）','1122':'番茄红素','1123':'叶黄素与玉米黄质',
 '1162':'维生素 C','1165':'维生素 B1（硫胺素）','1166':'维生素 B2（核黄素）','1167':'烟酸',
 '1170':'泛酸','1175':'维生素 B6','1176':'生物素','1177':'总叶酸','1178':'维生素 B12',
 '1180':'总胆碱','1185':'维生素 K','1186':'叶酸（合成）','1187':'食物叶酸','1190':'叶酸（DFE）',
 '1253':'胆固醇','1257':'反式脂肪酸总量','1258':'饱和脂肪酸总量','1292':'单不饱和脂肪酸总量','1293':'多不饱和脂肪酸总量',
 '2047':'能量（Atwater 通用系数）','2048':'能量（Atwater 特定系数）'};
const qualifierNames = {missing:'未提供',not_tested:'未检测',not_detected:'未检出',not_computable:'无法计算',trace:'微量',invalid:'异常原值',invalid_source_value:'异常原值',invalid_negative:'异常负值',below_detection:'低于检出限'};
const macroLabels = ['热量','蛋白质','脂肪','碳水化合物'];
const translationLabels = {machine:'机器译名 · 待校对',glossary:'词表译名 · 含原文待校对',curated:'原文 / 已整理译名',pending:'英文名称补齐中'};
function basisLabel(row) {
 if (!row.metadata) return '100 克 / g';
 if (row.metadata.kind === 'plate') return '餐盘份量参考';
 if (row.metadata.basis_status === 'verified') return row.metadata.basis_unit === 'g' ? '100 克 / g（已折算）' : `原标签 / ${number(row.metadata.basis_quantity)}mL（见详情）`;
 return '标签基准待核验';
}

async function api(url, signal) {
 const response = await fetch(url, {signal});
 if (!response.ok) throw new Error(response.status === 404 ? '没有找到这条食物记录。' : '暂时无法读取本地数据，请检查服务后重试。');
 return response.json();
}
function params() {
 return new URLSearchParams({q:$('#search').value.trim(), source:state.source, category:$('#category').value,
   quality:$('#quality').value, sort:$('#sort').value, page:state.page, limit:40});
}
function activeSource() {
 document.querySelectorAll('[data-source]').forEach((button) => {
   const active = button.dataset.source === state.source;
   button.classList.toggle('active', active);
   button.setAttribute('aria-pressed', String(active));
 });
}
async function loadFoods(reset = false) {
 if (reset) state.page = 1;
 listingRequest?.abort();
 const controller = new AbortController(); listingRequest = controller;
 const query = params();
 $('#foods').setAttribute('aria-busy', 'true'); $('#error').hidden = true;
 $('#results-count').textContent = '正在检索…';
 activeSource();
 $('#export').href = '/api/export.csv?' + query;
 const pageURL = new URLSearchParams(query);
 pageURL.delete('limit');
 history.replaceState(null, '', '?' + pageURL);
 try {
  const data = await api('/api/foods?' + query, controller.signal);
  state.pages = data.pages;
  $('#results-count').textContent = `找到 ${count(data.total)} 个食物名${$('#search').value.trim() ? ' · “' + $('#search').value.trim() + '”' : ''}`;
  $('#foods').innerHTML = data.items.length ? data.items.map((row) => `<tr><td><button class="food-name" data-food="${esc(row.id)}">${esc(row.name_zh || '中文名称待补齐')}</button><span class="food-en" lang="en">${esc(row.name_en || 'English name pending')}</span><span class="food-meta">${row.variants > 1 ? `<span class="badge">同名 ${row.variants} 条 · 可切换</span>` : ''}<span>${esc(translationLabels[row.translation_method])}</span>${row.metadata ? `<span>· ${row.metadata.detail_status === 'index_only' ? '明细采集中' : row.metadata.kind === 'plate' ? '来源无营养表' : '原始标签见详情'}</span>` : keys.some((k) => row[k] == null) ? '<span>· 营养有缺项</span>' : ''}</span></td><td class="unit">${esc(basisLabel(row))}</td>${keys.map((key, i) => `<td class="numeric ${i === 0 ? 'energy' : ''} ${row[key] == null ? 'missing' : ''}">${number(row[key], i ? 2 : 1)}</td>`).join('')}<td><span class="source-badge ${row.source_id.startsWith('china-') ? 'china' : ''}">${esc(row.source_label)}</span></td></tr>`).join('') : '<tr><td colspan="7" class="empty">没有找到匹配的食物。<br>试试更短的中文关键词、英文名，或重置来源和分类筛选。</td></tr>';
  $('#page-note').textContent = data.total ? `显示 ${(state.page - 1) * 40 + 1}–${Math.min(state.page * 40, data.total)} / ${count(data.total)} 项` : '暂无结果';
  $('#page-current').textContent = `${state.page} / ${data.pages}`;
  $('#previous').disabled = state.page <= 1; $('#next').disabled = state.page >= data.pages;
 } catch (error) {
  if (error.name === 'AbortError') return;
  $('#error').textContent = error.message; $('#error').hidden = false;
  $('#results-count').textContent = '读取失败';
  $('#foods').innerHTML = '<tr><td colspan="7" class="empty">数据未能加载，请重试搜索。</td></tr>';
 } finally {
  if (listingRequest === controller) $('#foods').setAttribute('aria-busy', 'false');
 }
}

async function initialize() {
 try {
  const stats = await api('/api/stats');
  $('#stat-foods').textContent = count(stats.foods); $('#stat-records').textContent = count(stats.records);
  $('#stat-merged').textContent = `折叠 ${count(stats.merged)} 条同名记录`;
  $('#stat-bilingual').textContent = `${number(stats.bilingual * 100 / stats.records, 1)}%`;
  $('#stat-portions').textContent = count(stats.source_portions);
  $('#source-count').textContent = `${stats.sources.length} 个来源`;
  $('#source-nav').innerHTML = `<button class="source" data-source="all">全部食物<span>${count(stats.records)}</span></button>${stats.sources.map((source) => `<button class="source" data-source="${esc(source.id)}">${esc(source.label)}<span>${count(source.count)}</span></button>`).join('')}`;
  $('#category').insertAdjacentHTML('beforeend', stats.categories.map((c) => `<option value="${esc(c.id)}">${esc(c.label)}</option>`).join(''));
  for (const key of ['category','quality','sort']) {
   const value = initial.get(key);
   if (value && [...$('#' + key).options].some((o) => o.value === value)) $('#' + key).value = value;
  }
  $('#source-details').innerHTML = stats.sources.map((s) => `<div class="source-entry"><strong>${esc(s.label)}</strong><p>${esc(s.version)} · ${count(s.count)} 条原始记录</p><p>${esc(s.license)}</p><a href="${safeURL(s.url)}" target="_blank" rel="noopener noreferrer">访问官方来源 ↗</a></div>`).join('');
  $('#source-details').insertAdjacentHTML('beforebegin', '<p>常见英文食物优先使用食物/部位/加工状态词表，未覆盖的限定词保留英文，标注为“词表译名 · 含原文待校对”。不能把双语覆盖率当作翻译准确率。</p>');
  await loadFoods();
  await updateCollection();
 } catch (error) { $('#error').hidden = false; $('#error').textContent = error.message; }
}
function safeURL(url) {
 try { const value = new URL(url); return ['https:', 'http:'].includes(value.protocol) ? esc(value.href) : '#'; }
 catch { return '#'; }
}

async function openFood(id) {
 const version = ++detailVersion;
 if (!$('#detail-dialog').open) $('#detail-dialog').showModal();
 $('#detail-body').innerHTML = '<div class="empty">正在读取完整营养档案…</div>';
 try {
  const food = await api('/api/foods/' + encodeURIComponent(id));
  if (version !== detailVersion || !$('#detail-dialog').open) return;
  state.detail = food;
  if (food.metadata) {
   renderSupplement(food);
   $('#detail-dialog').scrollTop = 0;
   return;
  }
  const portions = [{value:'base', label:'100 克 / g（标准基准）', grams:100}, {value:'gram', label:'1 克 / g（自定克数）', grams:1}];
  for (const portion of food.portions) {
   if (portion.basis === 'mass') continue;
   portions.push({value:portion.portion_id, label:`${portion.label} · 原始 ${number(portion.amount,3)} ${portion.unit} = ${number(portion.gram_weight,3)}g`, grams:portion.grams_per_unit, original:portion});
  }
  state.portions = portions;
  const variants = food.variants.length > 1 ? `<div class="variant-box"><label for="variant">这个食物名下有 ${food.variants.length} 条原始记录</label><select id="variant">${food.variants.map((r) => `<option value="${esc(r.id)}" ${r.id === food.id ? 'selected' : ''}>${esc(r.source_label)} · ${esc(r.id)} · ${number(r.calories_kcal)} kcal/100g</option>`).join('')}</select><p>下方只显示当前选中记录的数据，不混用或平均其他来源。</p></div>` : '';
  $('#detail-body').innerHTML = `<article class="detail-content"><p class="eyebrow">${esc(food.category_zh)}</p><h2 id="detail-title">${esc(food.name_zh || '中文名称待补齐')}</h2><p class="detail-en" lang="en">${esc(food.name_en || 'English name pending')}</p><div class="detail-tags"><span>${esc(food.source_label)}</span><span>${esc(food.id)}</span>${food.translation_method === 'machine' ? '<span class="translation">机器译名 · 待校对</span>' : '<span>原文 / 已整理译名</span>'}</div>${variants}<div class="portion-box"><div class="portion-heading"><strong>按实际份量换算</strong><small>仅使用来源提供的克重</small></div><div class="portion-controls"><label for="quantity">数量<input id="quantity" type="number" value="1" min="0.001" max="100000" step="any" inputmode="decimal"></label><label for="portion">计量单位 / 来源份量<select id="portion">${portions.map((p) => `<option value="${esc(p.value)}">${esc(p.label)}</option>`).join('')}</select></label></div><p id="portion-equivalence" class="portion-equivalence"></p><p id="portion-error" class="error" hidden>请输入大于 0 且不超过 100,000 的有效数量。</p></div><div class="macro-grid">${keys.map((k,i) => `<div class="macro-tile"><span>${macroLabels[i]}</span><b><output id="macro-${k}">—</output><small>${i ? 'g' : 'kcal'}</small></b></div>`).join('')}</div><div id="macro-visual" class="macro-visual"></div><p class="detail-notice">热量以选中来源为准，可能使用特定 Atwater 系数，不一定等于蛋白质×4 + 脂肪×9 + 碳水×4。缺失数值不补算为零。</p><section class="detail-section"><h3>全部营养成分 <small id="nutrient-caption"></small></h3><input id="nutrient-search" type="search" placeholder="筛选营养项，例如：钠 / sodium" aria-label="筛选营养成分"><div class="table-wrap"><table class="nutrient-table"><thead><tr><th>营养成分 / 原名</th><th>当前份量</th><th>原值 / 100g</th></tr></thead><tbody id="nutrient-rows"></tbody></table></div><p class="data-note">百分比、比重不随份量缩放。原值列保留来源文本及单位，微量和未检出不等于零。</p></section><section class="detail-section source-card"><h3>来源与记录信息</h3><p><strong>${esc(food.source_name)}</strong></p><p>${esc(food.license)}</p><p><a href="${safeURL(food.source_url)}" target="_blank" rel="noopener noreferrer">查看这条食物的官方来源 ↗</a></p>${food.commercial_use_authorized ? '' : '<p class="detail-notice">中国疾控公开查询数据：仅供本地参考，商业使用须先获授权。</p>'}<details class="raw-info"><summary>查看原始名称、别名与计算方法</summary><p>原始名称：${esc(food.name)}</p><p>别名：${food.aliases.length ? food.aliases.map((a) => esc(a.alias)).join(' / ') : '来源未提供'}</p><p>可食比例：${food.edible_percent == null ? '来源未提供' : number(food.edible_percent) + '%'}</p><p>能量方法：${esc(food.energy_method)}</p><p>记录编号：<code>${esc(food.id)}</code></p></details></section></article>`;
  $('#quantity').addEventListener('input', updatePortion);
  const translationTag = document.querySelector('.detail-tags .translation') || document.querySelector('.detail-tags span:last-child');
  translationTag.textContent = translationLabels[food.translation_method];
  translationTag.classList.toggle('translation', food.translation_method !== 'curated');
  $('#portion').addEventListener('change', updatePortion);
  $('#nutrient-search').addEventListener('input', renderNutrients);
  $('#variant')?.addEventListener('change', (event) => openFood(event.target.value));
  updatePortion();
  $('#detail-dialog').scrollTop = 0;
 } catch (error) {
  if (version === detailVersion) $('#detail-body').innerHTML = `<div class="empty">${esc(error.message)}</div>`;
 }
}
async function updateCollection() {
 try {
  const data = await api('/api/progress');
  if (!data.jobs.length) return;
  $('#collection-status').hidden = false;
  const labels = data.jobs.find((job) => job.id === 'china-nlc-packaged');
  const plate = data.jobs.find((job) => job.id === 'china-cdc-plate');
  const latest = labels?.updated_at;
  const updated = latest ? new Date(latest).toLocaleTimeString('zh-CN',{timeZone:'Asia/Shanghai',hour12:false}) : '—';
  $('#collection-status').innerHTML = `<div class="collection-heading"><strong>中国食物库补采进度</strong><span>明细未齐全 · 自动更新 / ${esc(updated)}</span></div><div class="collection-metrics"><div><small>有效商品索引已入库</small><b>${count(labels?.total || 0)}</b></div><div><small>原始标签已采集</small><b>${count(labels?.completed || 0)} <em>/ ${count(labels?.total || 0)}</em></b></div><div><small>餐盘条目已入库</small><b>${count(plate?.completed || 0)} <em>/ ${count(plate?.total || 0)}</em></b></div><div><small>标签计量基准已核验</small><b>${count(data.basis.filter((r) => r.basis_status === 'verified').reduce((sum,r) => sum+r.n,0))}</b></div></div><progress max="${labels?.total || 1}" value="${labels?.completed || 0}" aria-label="原始商品标签采集进度"></progress><p>${labels?.status === 'running' && data.collector_alive ? '后台限速采集中，可继续查询已入库内容。' : labels?.status === 'running' ? '采集进程当前未运行，可使用启动器断点续采。' : '采集任务状态：' + esc(labels?.status || '未开始') + '。'} 原始标签不等于每100克营养值；基准未核验时不开放按克换算。${data.quarantined_index_records ? `另有 ${data.quarantined_index_records} 条无名称源记录单独留存。` : ''}</p>`;
  $('#collection-status').insertAdjacentHTML('beforeend','<p><a href="/api/export-labels.csv" download>导出已采集的原始营养标签 CSV ↓</a></p>');
 } catch {
  if (!$('#collection-status').hidden) $('#collection-status').setAttribute('data-stale','true');
 }
}

function renderSupplement(food) {
 const m = food.metadata;
 const isPlate = m.kind === 'plate';
 const panel = food.label_nutrients || [];
 const fields = [['条码 / 识别码',m.barcode],['品牌',m.brand],['生产厂家',m.manufacturer],['净含量 / 规格',m.net_content],['食物类别',food.category],['配料',m.ingredients],['储存方式',m.storage],['产地',m.origin]];
 const reference = m.basis_status === 'verified' ? `原始标签基准：每 ${number(m.basis_quantity)} ${m.basis_unit}` : '标签计量基准尚未核验，不能视为每100克或每100毫升';
 const warning = isPlate ? '此来源提供菜名、餐盘工具份量与原始配比向量，未提供完整营养成分表。配比向量不是蛋白质、脂肪、碳水数据；这里不生成营养估算。' : m.detail_status === 'index_only' ? '此条已完成索引入库，营养明细尚在采集中。不是零热量食物。' : '下表是官方对比页/详情页提供的标签原值。未经核验的计量基准不用于摄入计算，不假定 1mL 等于 1g。';
 $('#detail-body').innerHTML = `<article class="detail-content"><p class="eyebrow">${esc(food.source_label)}</p><h2 id="detail-title">${esc(food.name_zh)}</h2><p class="detail-en" lang="en">${esc(food.name_en || 'English name pending')}</p><div class="detail-tags"><span>${esc(food.id)}</span><span class="translation">${esc(translationLabels[food.translation_method])}</span><span>${isPlate ? '菜品 / 份量参考' : '商品标签原始记录'}</span></div><p class="detail-notice">${warning}</p>${isPlate ? `<section class="detail-section"><h3>来源中的份量说明</h3><div class="source-card"><p>${esc(m.portion_description || '未提供')}</p><p>工具 quantity 字段：${esc(m.raw_source.quantity)} ${esc(m.basis_unit || '')}</p><p>工具显示文字：${esc(m.raw_source.bzQuantity)}</p><p class="detail-notice">工具 quantity 与说明文字可能口径不同，不把它们自动等同于一碗/一盘熟食的克重。</p></div></section>` : `<section class="detail-section"><h3>原始营养标签 <small>${panel.length ? count(panel.length)+' 项' : '尚未采集'}</small></h3><p class="basis-warning">${esc(reference)}</p>${panel.length ? `<div class="table-wrap"><table class="nutrient-table"><thead><tr><th>营养成分</th><th>标签原值</th><th>解析状态</th></tr></thead><tbody>${panel.map((r) => `<tr><td>${esc(r.name)}</td><td>${esc(r.raw_value || '—')}</td><td>${esc(r.qualifier === 'reported' ? '来源报告值' : qualifierNames[r.qualifier] || r.qualifier)}</td></tr>`).join('')}</tbody></table></div>` : '<p class="source-card">该商品的营养明细尚未入库，后台采集成功后会在这里显示。</p>'}</section><section class="detail-section"><h3>条码、品牌与规格</h3><dl class="product-fields">${fields.map(([name,value]) => `<dt>${esc(name)}</dt><dd>${esc(value || '尚未采集或来源未提供')}</dd>`).join('')}</dl></section>`}<section class="detail-section source-card"><h3>来源与使用边界</h3><p>${esc(food.license)}</p><p><a href="${safeURL(food.source_url)}" target="_blank" rel="noopener noreferrer">查看官方来源 ↗</a></p><p>本地参考资料，商业使用授权尚未确认，未加入App发行数据库。</p><p><a href="/api/foods/${encodeURIComponent(food.id)}" download>下载这条完整原始记录 JSON ↓</a></p><details class="raw-info"><summary>查看原始字段与来源采集状态</summary><p>状态：${esc(m.detail_status)} / ${esc(m.basis_status)}</p><pre>${esc(JSON.stringify(m.raw_source,null,2))}</pre></details></section></article>`;
 if (food.variants.length > 1) {
  document.querySelector('.detail-tags').insertAdjacentHTML('afterend', `<div class="variant-box"><label for="variant">同条码、品牌、规格和标签一致的 ${food.variants.length} 条来源记录</label><select id="variant">${food.variants.map((r) => `<option value="${esc(r.id)}" ${r.id === food.id ? 'selected' : ''}>${esc(r.id)} · ${esc(r.name)}</option>`).join('')}</select></div>`);
  $('#variant').addEventListener('change',(event) => openFood(event.target.value));
 }
}

function updatePortion() {
 const quantity = Number($('#quantity').value);
 const valid = Number.isFinite(quantity) && quantity > 0 && quantity <= 100000;
 $('#portion-error').hidden = valid;
 const unit = state.portions.find((p) => p.value === $('#portion').value);
 state.grams = valid ? unit.grams * quantity : null;
 const grams = state.grams;
 const food = state.detail;
 $('#portion-equivalence').textContent = valid ? `当前可食重量 ${number(grams,3)} 克${unit.original ? ` · 每 1 ${unit.original.unit} = ${number(unit.grams,3)} 克` : ''}` : '等待有效份量';
 keys.forEach((key, i) => { $('#macro-' + key).textContent = number(grams == null || food[key] == null ? null : food[key] * grams / 100, i ? 2 : 1); });
 const complete = keys.slice(1).every((k) => food[k] != null);
 const energy = [food.protein_g * 4, food.fat_g * 9, food.carbs_g * 4];
 const total = energy.reduce((sum, x) => sum + x, 0);
 $('#macro-visual').innerHTML = complete && total > 0 ? `<p>三大营养素供能构成 <small>按 4 / 9 / 4 系数估算，非实测热量占比</small></p><div class="macro-bar" role="img" aria-label="蛋白质 ${number(energy[0]/total*100)}%，脂肪 ${number(energy[1]/total*100)}%，碳水 ${number(energy[2]/total*100)}%">${energy.map((e,i) => `<span class="${['protein','fat','carbs'][i]}" data-width="${e/total*100}"></span>`).join('')}</div><div class="macro-legend">${energy.map((e,i) => `<span><i class="dot ${['protein','fat','carbs'][i]}"></i> ${macroLabels[i+1]} ${number(e/total*100)}%</span>`).join('')}</div>` : '<p>来源营养不完整或无供能，暂不绘制供能比例。</p>';
 document.querySelectorAll('[data-width]').forEach((node) => node.style.width = node.dataset.width + '%');
 renderNutrients();
}
function renderNutrients() {
 const term = $('#nutrient-search').value.trim().toLowerCase();
 const nutrients = state.detail.nutrients_per_100g;
 const massUnits = new Set(['g','mg','ug','µg','μg','kcal','kJ','IU']);
 const rows = nutrients.filter((r) => [r.name,nutrientNames[r.nutrient_id] || '',r.nutrient_id].join(' ').toLowerCase().includes(term));
 $('#nutrient-caption').textContent = `${count(rows.length)} / ${count(nutrients.length)} 项 · ${number(state.grams,3)}g`;
 $('#nutrient-rows').innerHTML = rows.map((r) => {
  const label = nutrientNames[r.nutrient_id] || r.name;
  const amount = r.amount == null || state.grams == null ? null : r.amount * (massUnits.has(r.unit) ? state.grams / 100 : 1);
  const status = qualifierNames[r.qualifier] || (r.amount == null ? r.qualifier : '');
  const raw = r.raw_value === '' ? '—' : r.raw_value;
  return `<tr><td>${esc(label)}${label !== r.name ? `<span class="nutrient-en">${esc(r.name)}</span>` : ''}<span class="nutrient-en">ID ${esc(r.nutrient_id)}</span></td><td class="${amount == null ? 'nutrient-empty' : ''}">${amount == null ? '—' : number(amount, 4) + ' ' + esc(r.unit)}${status ? `<span class="nutrient-status">${esc(status)}</span>` : ''}</td><td>${esc(raw)} ${esc(r.unit)}</td></tr>`;
 }).join('') || '<tr><td colspan="3" class="empty">没有匹配的营养项</td></tr>';
}

$('#source-nav').addEventListener('click', (event) => { const button = event.target.closest('[data-source]'); if (button) { state.source = button.dataset.source; loadFoods(true); } });
$('#foods').addEventListener('click', (event) => { const button = event.target.closest('[data-food]'); if (button) openFood(button.dataset.food); });
$('#search-form').addEventListener('submit', (event) => { event.preventDefault(); clearTimeout(searchTimer); loadFoods(true); });
$('#search').addEventListener('input', () => { clearTimeout(searchTimer); searchTimer = setTimeout(() => loadFoods(true), 280); });
document.querySelectorAll('[data-query]').forEach((button) => button.addEventListener('click', () => { $('#search').value = button.dataset.query; loadFoods(true); }));
['category','quality','sort'].forEach((id) => $('#' + id).addEventListener('change', () => loadFoods(true)));
$('#reset').addEventListener('click', () => { $('#search').value = ''; state.source = 'all'; $('#category').value = 'all'; $('#quality').value = 'all'; $('#sort').value = 'default'; loadFoods(true); });
$('#previous').addEventListener('click', () => { if (state.page > 1) { state.page--; loadFoods(); } });
$('#next').addEventListener('click', () => { if (state.page < state.pages) { state.page++; loadFoods(); } });
$('#close-detail').addEventListener('click', () => $('#detail-dialog').close());
$('#about-button').addEventListener('click', () => $('#about-dialog').showModal());
$('#about-footer').addEventListener('click', () => $('#about-dialog').showModal());
$('#close-about').addEventListener('click', () => $('#about-dialog').close());
document.addEventListener('keydown', (event) => { if (event.key === '/' && !['INPUT','SELECT','TEXTAREA'].includes(document.activeElement.tagName) && !document.querySelector('dialog[open]')) { event.preventDefault(); $('#search').focus(); } });
document.querySelectorAll('dialog').forEach((dialog) => dialog.addEventListener('click', (event) => { if (event.target === dialog) { const rect = dialog.getBoundingClientRect(); if (event.clientX < rect.left || event.clientX > rect.right || event.clientY < rect.top || event.clientY > rect.bottom) dialog.close(); } }));
initialize();
setInterval(() => { if (!document.hidden) updateCollection(); }, 15000);
