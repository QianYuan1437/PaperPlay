'use strict';
const $ = (selector, root = document) => root.querySelector(selector);
const $$ = (selector, root = document) => [...root.querySelectorAll(selector)];
const paths = {
  grid: '<rect x="3" y="3" width="7" height="7" rx="2"/><rect x="14" y="3" width="7" height="7" rx="2"/><rect x="3" y="14" width="7" height="7" rx="2"/><rect x="14" y="14" width="7" height="7" rx="2"/>',
  library: '<rect x="3" y="6" width="18" height="15" rx="3"/><path d="M7 3h10M3 16l5-5 5 5 3-3 5 5"/>',
  list: '<path d="M8 5h13M8 12h13M8 19h13M3 5h.01M3 12h.01M3 19h.01"/>',
  play: '<path d="m8 5 11 7-11 7Z"/>', pause: '<path d="M8 5v14M16 5v14"/>',
  folder: '<path d="M3 7V5a2 2 0 0 1 2-2h5l2 3h7a2 2 0 0 1 2 2v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2Z"/>',
  pulse: '<path d="M2 12h5l3-8 4 16 3-8h5"/>', sliders: '<path d="M3 6h4m4 0h10M3 18h10m4 0h4"/><circle cx="9" cy="6" r="2"/><circle cx="15" cy="18" r="2"/>',
  arrow: '<path d="M6 18 18 6M6 6h12v12"/>', download: '<path d="M12 3v12m-5-5 5 5 5-5M4 17v4h16v-4"/>', windows: '<path d="m3 5 18-2v18L3 19ZM11 4v16M3 12h18"/>',
  code: '<path d="m8 5-7 7 7 7m8-14 7 7-7 7M14 3l-4 18"/>', headphones: '<path d="M3 14v-3a9 9 0 0 1 18 0v3"/><rect x="3" y="12" width="4" height="9" rx="2"/><rect x="17" y="12" width="4" height="9" rx="2"/>',
  blur: '<path d="M7 3v18M12 2v20M17 3v18M3 7h18M2 12h20M3 17h18"/>', moon: '<path d="M20 14A9 9 0 0 1 10 3a9 9 0 1 0 10 11Z"/>', reset: '<path d="M3 4v6h6M3 10a9 9 0 1 1 1 8"/>',
  next: '<path d="m5 5 10 7-10 7ZM19 5v14"/>', previous: '<path d="m19 5-10 7 10 7ZM5 5v14"/>', volume: '<path d="m3 9 5 0 5-5v16l-5-5H3ZM17 8a6 6 0 0 1 0 8m3-11a10 10 0 0 1 0 14"/>',
  repeat: '<path d="m16 2 4 4-4 4M4 11V8a2 2 0 0 1 2-2h14M8 22l-4-4 4-4m12-1v3a2 2 0 0 1-2 2H4"/>', expand: '<path d="M8 3H3v5m13-5h5v5M3 16v5h5m8 0h5v-5"/>',
  plus: '<path d="M12 4v16M4 12h16"/>', heart: '<path d="M20 12 12 20 4 12C-2 4 9-1 12 6c3-7 14-2 8 6Z"/>', search: '<circle cx="10" cy="10" r="7"/><path d="m15 15 6 6"/>', close: '<path d="m6 6 12 12M6 18 18 6"/>', up: '<path d="m6 14 6-6 6 6"/>', down: '<path d="m6 10 6 6 6-6"/>'
};
const icon = name => `<svg viewBox="0 0 24 24" aria-hidden="true">${paths[name] || paths.play}</svg>`;
$$('[data-icon]').forEach(node => node.replaceWith(document.createRange().createContextualFragment(icon(node.dataset.icon))));
const escapeText = value => String(value).replace(/[&<>"']/g, char => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]));
const demos = [
  {id:'tide',title:'暮色潮汐',tag:'AFTER THE SUN',src:'media/tide.mp4',art:'media/tide.svg'},
  {id:'forest',title:'山间来信',tag:'INTO THE QUIET',src:'media/forest.mp4',art:'media/forest.svg'},
  {id:'moon',title:'月下浮光',tag:'A LITTLE STILLNESS',src:'media/moon.mp4',art:'media/moon.svg'}
];
const catalog = [...demos];
const defaults = {theme:matchMedia('(prefers-color-scheme: dark)').matches?'dark':'light',accent:'gold',blur:false,audio:false,glass:true,reduce:false,stats:true,blurSize:12};
let settings = {...defaults}, saved = [], favorites = [], queue = demos.map(item=>item.id);
try {
  const stored = JSON.parse(localStorage.getItem('paperplay-demo') || '{}');
  for (const key of ['blur','audio','glass','reduce','stats']) if (typeof stored[key] === 'boolean') settings[key] = stored[key];
  if (['dark','light'].includes(stored.theme)) settings.theme = stored.theme;
  if (['gold','sage','blue','rose'].includes(stored.accent)) settings.accent = stored.accent;
  if (Number.isFinite(stored.blurSize)) settings.blurSize = Math.max(4,Math.min(24,stored.blurSize));
  favorites = Array.isArray(stored.favorites)?stored.favorites.filter(id=>demos.some(item=>item.id===id)):[];
  saved = Array.isArray(stored.saved)?stored.saved.slice(0,8).filter(item=>Array.isArray(item)).map(items=>items.filter(id=>demos.some(item=>item.id===id))):[];
} catch (_) { /* Local storage is optional. */ }
const persist = () => { try { localStorage.setItem('paperplay-demo',JSON.stringify({...settings,favorites,saved})); } catch (_) {} };
const media = $('#media'), view = $('#view');
let currentId = 'tide', route = 'overview', mode = 0, onlyFavorites = false, search = '', toastTimer, playRequest = 0;
const routes = {overview:'概览',library:'订阅库',queue:'播放队列',player:'播放器',local:'本地媒体',performance:'性能',appearance:'外观'};
const labels = {overview:'随心选择，即刻播放',library:'三段风景，随时开场',queue:'按你喜欢的顺序',player:'此刻，留给喜欢的画面',local:'选择文件，仅在浏览器内播放',performance:'当前浏览器 · 实时测量',appearance:'让界面，成为你的样子'};
const modes = ['列表循环','随机播放','单曲循环','顺序播放'];
const current = () => catalog.find(item=>item.id===currentId);
const time = value => !Number.isFinite(value)?'0:00':`${Math.floor(value/60)}:${String(Math.floor(value%60)).padStart(2,'0')}`;
function toast(message) { $('#toast').textContent=message; $('#toast').classList.add('show'); clearTimeout(toastTimer); toastTimer=setTimeout(()=>$('#toast').classList.remove('show'),2600); }
function applySettings() {
  document.body.classList.toggle('dark',settings.theme==='dark');
  document.body.dataset.accent=settings.accent;
  document.body.classList.toggle('blurred',settings.blur);
  document.body.classList.toggle('audio-only',settings.audio || !!current()?.audio);
  document.body.classList.toggle('solid',!settings.glass);
  document.body.classList.toggle('reduced',settings.reduce);
  document.documentElement.style.setProperty('--blur',`${settings.blurSize}px`);
  $('#audio-toggle').setAttribute('aria-pressed',String(settings.audio));
  $('#blur-toggle').setAttribute('aria-pressed',String(settings.blur));
  $('#theme-toggle').setAttribute('aria-label',settings.theme==='dark'?'切换浅色主题':'切换深色主题');
  $$('button[data-accent]').forEach(button=>button.setAttribute('aria-pressed',String(button.dataset.accent===settings.accent)));
  $$('[data-setting]').forEach(input=>input.type==='checkbox'?input.checked=settings[input.dataset.setting]:input.value=settings[input.dataset.setting]);
  persist();
  syncSampler();
}
function stage() {
  const item=current();
  return `<div class="stage ${media.paused?'':'playing'}" id="stage"><div class="audio-cover"><div class="wave">${Array.from({length:19},(_,i)=>`<i style="--n:${i}"></i>`).join('')}</div></div><button class="stage-play" data-action="toggle" aria-label="${media.paused?'播放':'暂停'}"><span class="play-orbit">${icon(media.paused?'play':'pause')}</span></button><div class="stage-title"><span>${escapeText(item?.tag||'YOUR OWN COLLECTION')}</span><strong>${escapeText(item?.title||'选择一段喜欢的画面')}</strong></div><button class="icon-button fullscreen" data-action="fullscreen" aria-label="全屏播放">${icon('expand')}</button></div>`;
}
const routeButton = (target,text) => `<a class="pill" href="#${target}">${text}${icon('arrow')}</a>`;
function trackRows() {
  return queue.slice(0,3).map((id,i)=>{const item=catalog.find(item=>item.id===id);return `<button data-action="select" data-id="${id}" class="${id===currentId?'selected':''}"><span class="track-index">0${i+1}</span><span class="track-name">${escapeText(item.title)}</span>${icon(id===currentId&&!media.paused?'pause':'play')}</button>`;}).join('') || '<span>队列为空</span>';
}
function card(item) {
  return `<article class="panel media-card"><div class="media-art"><button class="art-play" data-action="select" data-id="${item.id}" aria-label="播放 ${escapeText(item.title)}"><img class="preview-image" src="${item.art}" alt="" loading="lazy">${icon(item.audio?'headphones':'play')}</button><button class="icon-button favorite" data-action="favorite" data-id="${item.id}" aria-pressed="${favorites.includes(item.id)}" aria-label="收藏 ${escapeText(item.title)}">${icon('heart')}</button></div><div class="media-caption"><strong>${escapeText(item.title)}</strong><button class="icon-button" data-action="enqueue" data-id="${item.id}" aria-label="将 ${escapeText(item.title)} 加入队列">${icon('plus')}</button></div></article>`;
}
function render() {
  const wasPlaying=!media.paused;
  $('#media-home').append(media);
  $('#page-name').textContent=routes[route]; $('#view-label').textContent=labels[route];
  $$('[data-route]').forEach(link=>{const active=link.dataset.route===route;link.classList.toggle('active',active);if(active)link.setAttribute('aria-current','page');else link.removeAttribute('aria-current');});
  if (route==='overview') {
    view.innerHTML=`<article class="panel"><div class="panel-head"><h2>${icon('play')}视频播放</h2>${routeButton('player','打开播放器')}</div>${stage()}</article><div class="bento-bottom"><article class="panel"><div class="panel-head"><h3>${icon('library')}壁纸订阅</h3>${routeButton('library','浏览')}</div><div class="mini-gallery">${demos.map(item=>`<button data-action="select" data-id="${item.id}" aria-label="播放 ${item.title}"><img class="preview-image" src="${item.art}" alt=""></button>`).join('')}</div></article><article class="panel"><div class="panel-head"><h3>${icon('list')}播放队列</h3>${routeButton('queue','管理')}</div><div class="mini-queue">${trackRows()}</div></article></div>`;
  } else if (route==='player') {
    view.innerHTML=`<article class="panel"><div class="panel-head"><h2>${icon('play')}<span id="player-title">${escapeText(current()?.title||'播放器')}</span></h2><button class="pill" data-action="fullscreen">全屏${icon('expand')}</button></div>${stage()}</article><div class="saved-list"><button class="pill" data-action="previous">${icon('previous')}上一首</button><button class="pill" data-action="next">下一首${icon('next')}</button>${routeButton('queue','播放队列')}</div>`;
  } else if (route==='library'||route==='local') {
    const items=catalog.filter(item=>route==='local'?item.local:!item.local);
    view.innerHTML=`<div class="toolbar"><label class="search">${icon('search')}<input id="search" type="search" placeholder="搜索媒体" aria-label="搜索媒体" value="${escapeText(search)}"></label>${route==='local'?`<button class="pill" data-action="import">${icon('plus')}导入文件</button>`:`<button class="pill" data-action="favorites" aria-pressed="${onlyFavorites}">${icon('heart')}收藏</button>`}</div><div class="media-grid" id="media-grid">${items.filter(matches).map(card).join('')}</div><div class="empty" id="no-results" ${items.filter(matches).length?'hidden':''}>${icon(route==='local'?'folder':'search')}<span>${route==='local'&&!items.length?'选择视频或音频，开始播放':'没有匹配的媒体'}</span>${route==='local'?'<button class="button primary" data-action="import">选择本地文件</button>':''}</div>${route==='local'?'<div class="drop-zone" id="drop-zone">也可以把文件拖到这里</div>':''}`;
  } else if (route==='queue') {
    view.innerHTML=`<article class="panel"><div class="panel-head"><h2>${icon('list')}播放队列</h2><div class="saved-list" style="margin:0"><button class="pill" data-action="save" ${queue.length?'':'disabled'}>保存列表</button><button class="pill" data-action="clear" ${queue.length?'':'disabled'}>清空</button></div></div>${queue.length?`<ol class="queue-list">${queue.map((id,i)=>{const item=catalog.find(item=>item.id===id);return `<li class="${id===currentId?'active':''}"><img class="preview-image" src="${item.art}" alt=""><button class="queue-title" data-action="select" data-id="${id}">${escapeText(item.title)}</button><button class="icon-button" data-action="up" data-id="${id}" aria-label="上移 ${escapeText(item.title)}" ${i===0?'disabled':''}>${icon('up')}</button><button class="icon-button" data-action="down" data-id="${id}" aria-label="下移 ${escapeText(item.title)}" ${i===queue.length-1?'disabled':''}>${icon('down')}</button><button class="icon-button" data-action="remove" data-id="${id}" aria-label="移除 ${escapeText(item.title)}">${icon('close')}</button></li>`;}).join('')}</ol>`:`<div class="empty">${icon('list')}<span>给下一刻，选一段声音。</span>${routeButton('library','去选媒体')}</div>`}</article><div class="saved-list">${saved.map((ids,i)=>`<button class="pill" data-action="load" data-index="${i}">列表 ${i+1} · ${ids.length} 首${icon('play')}</button>`).join('')}</div>`;
  } else if (route==='performance') {
    view.innerHTML=`<div class="metrics"><article class="panel metric"><h3>动画帧率</h3><strong><b id="fps">—</b><span>FPS</span></strong><canvas id="fps-chart" aria-label="浏览器帧率曲线"></canvas></article><article class="panel metric"><h3>帧间隔</h3><strong><b id="frame-ms">—</b><span>ms</span></strong><canvas id="frame-chart" aria-label="浏览器帧间隔曲线"></canvas></article></div><article class="panel"><div class="panel-head"><h2>${icon('pulse')}浏览器性能</h2></div><div class="settings-body"><label class="setting-row">统计曲线<input class="switch" type="checkbox" data-setting="stats"></label><label class="setting-row">减少界面动效<input class="switch" type="checkbox" data-setting="reduce"></label><div class="setting-row"><span>浏览器堆内存</span><strong id="heap">—</strong></div><a class="button quiet" href="https://github.com/QianYuan1437/PaperPlay/releases/latest" target="_blank" rel="noopener">桌面版 CPU / GPU 统计${icon('arrow')}</a></div></article>`;
    drawMetrics();
  } else {
    view.innerHTML=`<article class="panel"><div class="panel-head"><h2>${icon('sliders')}外观与动效</h2></div><div class="settings-body"><div class="setting-row"><span>主题色</span><div class="color-dots">${['gold','sage','blue','rose'].map((accent,i)=>`<button data-accent="${accent}" aria-label="${['暖金','苔绿','雾蓝','柔粉'][i]}主题"></button>`).join('')}</div></div><div class="setting-row"><span>明暗主题</span><button class="pill" data-action="theme">${settings.theme==='dark'?'深色':'浅色'}${icon('moon')}</button></div><label class="setting-row">透明材质<input class="switch" type="checkbox" data-setting="glass"></label><label class="setting-row">模糊预览<input class="switch" type="checkbox" data-setting="blur"></label><label class="setting-row">模糊强度<input type="range" min="4" max="24" data-setting="blurSize"></label><label class="setting-row">减少界面动效<input class="switch" type="checkbox" data-setting="reduce"></label><label class="setting-row">性能统计<input class="switch" type="checkbox" data-setting="stats"></label></div></article><div class="saved-list">${routeButton('player','预览播放效果')}${routeButton('performance','查看性能')}</div>`;
  }
  const target=$('#stage'); if(target)target.prepend(media);
  if(wasPlaying&&media.paused) safePlay();
  applySettings(); updateTransport();
  if(!settings.reduce&&!matchMedia('(prefers-reduced-motion: reduce)').matches) view.animate([{opacity:.3,transform:'translateY(10px)'},{opacity:1,transform:'translateY(0)'}],{duration:380,easing:'cubic-bezier(.16,1,.3,1)'});
}
function matches(item) {return item.title.toLocaleLowerCase().includes(search.toLocaleLowerCase())&&(!onlyFavorites||route==='local'||favorites.includes(item.id));}
function filterLibrary() {const items=catalog.filter(item=>(route==='local'?item.local:!item.local)&&matches(item));$('#media-grid').innerHTML=items.map(card).join('');$('#no-results').hidden=items.length>0;}
async function safePlay() {
  const request=++playRequest;
  try {await media.play();} catch(error) {if(request===playRequest&&error.name!=='AbortError')toast(error.name==='NotSupportedError'?'浏览器不支持此格式，可在桌面版播放':'请点击播放继续');}
}
function select(id, play=true) {
  const item=catalog.find(entry=>entry.id===id); if(!item)return;
  if(!queue.includes(id))queue.push(id);
  if(id!==currentId || !media.getAttribute('src')) {playRequest++;media.pause();currentId=id;media.src=item.src;media.poster=item.art;media.load();}
  if(play)safePlay(); render();
}
function toggle() {if(!current()){toast('先从媒体库选择一个文件');return;}if(media.paused)safePlay();else{playRequest++;media.pause();}}
function advance(direction=1,automatic=false) {
  if(!queue.length)return;
  let index=queue.indexOf(currentId);
  if(automatic&&mode===2){media.currentTime=0;safePlay();return;}
  if(automatic&&mode===3&&index===queue.length-1){media.pause();updateTransport();return;}
  if(mode===1&&queue.length>1&&direction>0){const choices=queue.filter(id=>id!==currentId);select(choices[Math.floor(Math.random()*choices.length)]);return;}
  index=(index+direction+queue.length)%queue.length; select(queue[index]);
}
function stopEmpty() {playRequest++;media.pause();media.removeAttribute('src');media.load();currentId=null;}
function updateTransport() {
  const item=current(), playing=!media.paused&&!media.ended;
  $('#now-title').textContent=item?.title||'未选择媒体';$('#now-art').src=item?.art||'icon.png';$('#now-kind').textContent=item?.local?'本地文件':'原创演示片段';
  $('#play').innerHTML=icon(playing?'pause':'play');$('#play').setAttribute('aria-label',playing?'暂停':'播放');
  $('#queue-count').textContent=queue.length;
  $('#mode').innerHTML=`${icon('repeat')}<span>${modes[mode]}</span>`;$('#mode').setAttribute('aria-label',`播放模式：${modes[mode]}`);
  $('#mute').setAttribute('aria-label',media.muted?'取消静音':'静音');$('#mute').style.opacity=media.muted?'.45':'1';
  const stageNode=$('#stage');if(stageNode){stageNode.classList.toggle('playing',playing);$('.stage-play',stageNode).setAttribute('aria-label',playing?'暂停':'播放');$('.play-orbit',stageNode).innerHTML=icon(playing?'pause':'play');}
  $('.brand img').src=playing?'icon-playing.png':'icon.png';
}
function seekUpdate() {$('#elapsed').value=time(media.currentTime);$('#duration').value=time(media.duration);$('#seek').value=Number.isFinite(media.duration)&&media.duration?media.currentTime/media.duration*1000:0;}
async function fullscreen() {const target=$('#stage');if(!target){location.hash='player';return;}try{if(document.fullscreenElement)await document.exitFullscreen();else if(target.requestFullscreen)await target.requestFullscreen();else toast('此浏览器不支持全屏');}catch(_){toast('当前浏览器未允许全屏');}}
const actions={
  toggle, next:()=>advance(),previous:()=>advance(-1),fullscreen,import:()=>$('#file-input').click(),
  select:button=>select(button.dataset.id),
  enqueue:button=>{if(queue.includes(button.dataset.id)){toast('已在播放队列中');return;}queue.push(button.dataset.id);updateTransport();toast('已加入播放队列');},
  favorite:button=>{const id=button.dataset.id;favorites=favorites.includes(id)?favorites.filter(value=>value!==id):[...favorites,id];persist();filterLibrary();},
  favorites:()=>{onlyFavorites=!onlyFavorites;render();},
  clear:()=>{queue=[];stopEmpty();render();},
  remove:button=>{const index=queue.indexOf(button.dataset.id);queue.splice(index,1);if(button.dataset.id===currentId){if(queue.length)select(queue[Math.min(index,queue.length-1)],!media.paused);else stopEmpty();}render();},
  up:button=>move(button.dataset.id,-1),down:button=>move(button.dataset.id,1),
  save:()=>{const ids=queue.filter(id=>demos.some(item=>item.id===id));if(!ids.length){toast('本地文件需重新选择，演示只保存内置片段');return;}saved=[...saved,ids].slice(-8);persist();render();toast('列表已保存');},
  load:button=>{queue=[...saved[Number(button.dataset.index)]];if(queue.length)select(queue[0]);else render();},
  theme:()=>{settings.theme=settings.theme==='dark'?'light':'dark';applySettings();if(route==='appearance')render();}
};
function move(id,delta){const i=queue.indexOf(id),next=i+delta;if(i<0||next<0||next>=queue.length)return;[queue[i],queue[next]]=[queue[next],queue[i]];render();}
document.addEventListener('click',event=>{const accent=event.target.closest('button[data-accent]');if(accent){settings.accent=accent.dataset.accent;applySettings();return;}const button=event.target.closest('[data-action]');if(button&&!button.disabled)actions[button.dataset.action]?.(button);});
document.addEventListener('input',event=>{if(event.target.id==='search'){search=event.target.value;filterLibrary();}if(event.target.dataset.setting){const input=event.target;settings[input.dataset.setting]=input.type==='checkbox'?input.checked:Number(input.value);if(input.dataset.setting==='stats'&&!input.checked){history.length=0;drawMetrics();}applySettings();}});
function navigate(){const next=location.hash.slice(1);route=Object.hasOwn(routes,next)?next:'overview';search='';render();}
window.addEventListener('hashchange',navigate);
$('#play').onclick=toggle;$('#next').onclick=()=>advance();$('#previous').onclick=()=>advance(-1);$('#now-playing').onclick=()=>{location.hash='player';};
$('#theme-toggle').onclick=actions.theme;$('#audio-toggle').onclick=()=>{settings.audio=!settings.audio;applySettings();};$('#blur-toggle').onclick=()=>{settings.blur=!settings.blur;applySettings();};
$('#mode').onclick=()=>{mode=(mode+1)%modes.length;updateTransport();toast(modes[mode]);};
$('#mute').onclick=()=>{media.muted=!media.muted;updateTransport();};$('#volume').oninput=event=>{media.volume=event.target.value/100;media.muted=false;updateTransport();};
$('#seek').oninput=event=>{if(Number.isFinite(media.duration))media.currentTime=Number(event.target.value)/1000*media.duration;seekUpdate();};
media.volume=.35;
media.addEventListener('timeupdate',seekUpdate);media.addEventListener('loadedmetadata',seekUpdate);media.addEventListener('emptied',seekUpdate);
media.addEventListener('play',updateTransport);media.addEventListener('pause',updateTransport);media.addEventListener('ended',()=>advance(1,true));
media.addEventListener('error',()=>{if(media.getAttribute('src'))toast('无法播放此文件，可尝试其他格式或桌面版');});
function importFiles(files){let count=0;for(const file of files){if(!/^(video|audio)\//.test(file.type)&&! /\.(mp4|webm|mkv|mov|mp3|wav|ogg|m4a|flac)$/i.test(file.name))continue;catalog.push({id:`local-${crypto.randomUUID()}`,title:file.name,tag:'YOUR OWN COLLECTION',src:URL.createObjectURL(file),art:'media/moon.svg',audio:file.type.startsWith('audio/')||/\.(mp3|wav|ogg|m4a|flac)$/i.test(file.name),local:true});count++;}if(count){search='';location.hash='local';if(route==='local')render();toast(`已导入 ${count} 个文件`);}else toast('请选择视频或音频文件');}
$('#file-input').onchange=event=>{importFiles(event.target.files);event.target.value='';};
view.addEventListener('dragover',event=>{if(route==='local'){event.preventDefault();$('#drop-zone')?.classList.add('dragover');}});view.addEventListener('dragleave',()=>$('#drop-zone')?.classList.remove('dragover'));view.addEventListener('drop',event=>{if(route==='local'){event.preventDefault();importFiles(event.dataTransfer.files);}});
$('#reset-demo').onclick=()=>{media.pause();catalog.filter(item=>item.local).forEach(item=>URL.revokeObjectURL(item.src));catalog.splice(0,catalog.length,...demos);queue=demos.map(item=>item.id);saved=[];favorites=[];settings={...defaults};mode=0;onlyFavorites=false;search='';currentId=null;media.volume=.35;media.muted=false;$('#volume').value=35;history.length=0;select('tide',false);applySettings();toast('演示已重置');};
window.addEventListener('pagehide',event=>{if(!event.persisted)catalog.filter(item=>item.local).forEach(item=>URL.revokeObjectURL(item.src));});
// Browser measurements are explicitly labelled, never presented as desktop CPU/GPU data.
const history=[];let previousFrame=0,start=0,frames=0,totalMs=0,raf;
function syncSampler(){if(!settings.stats||document.hidden){cancelAnimationFrame(raf);raf=null;previousFrame=0;start=0;frames=0;totalMs=0;}else if(!raf){raf=requestAnimationFrame(tick);}}
function tick(now){if(previousFrame){frames++;totalMs+=now-previousFrame;}previousFrame=now;if(!start)start=now;if(now-start>=1000){if(settings.stats&&frames){history.push({fps:frames*1000/(now-start),ms:totalMs/frames});if(history.length>40)history.shift();if(route==='performance')drawMetrics();}start=now;frames=0;totalMs=0;}raf=requestAnimationFrame(tick);}
function curve(canvas,key){if(!canvas)return;const width=canvas.clientWidth,height=canvas.clientHeight,dpr=Math.min(devicePixelRatio||1,2);canvas.width=width*dpr;canvas.height=height*dpr;const ctx=canvas.getContext('2d');ctx.scale(dpr,dpr);const color=getComputedStyle(document.body).getPropertyValue('--accent').trim();ctx.strokeStyle=color;ctx.globalAlpha=.13;ctx.lineWidth=1;for(let i=0;i<3;i++){const y=4+i*(height-8)/2;ctx.beginPath();ctx.moveTo(0,y);ctx.lineTo(width,y);ctx.stroke();}if(history.length<2)return;const max=Math.max(key==='fps'?60:20,...history.map(point=>point[key]))*1.1;const points=history.map((point,i)=>({x:i*width/(history.length-1),y:height-4-point[key]/max*(height-8)}));ctx.beginPath();ctx.moveTo(points[0].x,points[0].y);for(let i=1;i<points.length;i++){const a=points[i-1],b=points[i],mid=(a.x+b.x)/2;ctx.bezierCurveTo(mid,a.y,mid,b.y,b.x,b.y);}ctx.globalAlpha=1;ctx.lineWidth=2;ctx.stroke();ctx.lineTo(width,height);ctx.lineTo(0,height);ctx.closePath();const gradient=ctx.createLinearGradient(0,0,0,height);gradient.addColorStop(0,color+'50');gradient.addColorStop(1,color+'00');ctx.fillStyle=gradient;ctx.fill();}
function drawMetrics(){if(route!=='performance'||!$('#fps'))return;const last=settings.stats?history.at(-1):null;$('#fps').textContent=last?Math.round(last.fps):'—';$('#frame-ms').textContent=last?last.ms.toFixed(1):'—';$('#heap').textContent=settings.stats&&performance.memory?`${(performance.memory.usedJSHeapSize/1048576).toFixed(0)} MB`:'—';curve($('#fps-chart'),'fps');curve($('#frame-chart'),'ms');}
document.addEventListener('visibilitychange',()=>{document.body.classList.toggle('page-hidden',document.hidden);cancelAnimationFrame(raf);previousFrame=0;start=0;frames=0;totalMs=0;raf=null;syncSampler();});
window.addEventListener('resize',()=>{if(route==='performance')drawMetrics();});
raf=requestAnimationFrame(tick);
// Download anchors retain a usable release-page fallback without API access.
fetch('https://api.github.com/repos/QianYuan1437/PaperPlay/releases/latest',{signal:AbortSignal.timeout(5000)}).then(response=>{if(!response.ok)throw Error('unavailable');return response.json();}).then(release=>{
  if(typeof release.tag_name==='string')$('#version').textContent=release.tag_name;
  for(const [selector,suffix] of [['#download','-windows-x64-setup.exe'],['#portable','-windows-x64.zip']]){const asset=release.assets?.find(item=>item.name.endsWith(suffix));if(asset?.browser_download_url?.startsWith('https://github.com/QianYuan1437/PaperPlay/releases/download/'))$(selector).href=asset.browser_download_url;}
}).catch(()=>{});
navigate();

view.addEventListener('pointermove',event=>{if(settings.reduce||matchMedia('(prefers-reduced-motion: reduce)').matches||event.pointerType==='touch')return;const panel=event.target.closest('.panel');if(!panel)return;const bounds=panel.getBoundingClientRect();panel.style.setProperty('--pointer-x',`${event.clientX-bounds.left}px`);panel.style.setProperty('--pointer-y',`${event.clientY-bounds.top}px`);});
