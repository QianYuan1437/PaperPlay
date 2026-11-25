const { chromium } = require(process.env.PLAYWRIGHT_PATH || './pages-tests/node_modules/playwright');
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname,'../docs');
const artifacts = path.resolve(__dirname,'../artifacts/pages-ui');
fs.mkdirSync(artifacts,{recursive:true});
const types={'.html':'text/html','.css':'text/css','.js':'text/javascript','.svg':'image/svg+xml','.png':'image/png','.mp4':'video/mp4'};
const server=http.createServer((req,res)=>{
  const pathname=decodeURIComponent(new URL(req.url,'http://localhost').pathname);
  const file=path.resolve(root,'.'+(pathname==='/'?'/index.html':pathname));
  if(!file.startsWith(root+path.sep)||!fs.existsSync(file)){res.writeHead(404);res.end();return;}
  const size=fs.statSync(file).size;
  const range=req.headers.range?.match(/bytes=(\d+)-(\d*)/);
  res.setHeader('Content-Type',types[path.extname(file)]||'application/octet-stream');
  res.setHeader('Accept-Ranges','bytes');
  if(range){const start=Number(range[1]),end=Math.min(Number(range[2]||size-1),size-1);res.writeHead(206,{'Content-Range':`bytes ${start}-${end}/${size}`,'Content-Length':end-start+1});fs.createReadStream(file,{start,end}).pipe(res);}
  else{res.writeHead(200,{'Content-Length':size});fs.createReadStream(file).pipe(res);}
});
(async()=>{
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  const url=`http://127.0.0.1:${server.address().port}`;
  const browser=await chromium.launch({headless:true,...(process.env.PAPERPLAY_BROWSER_CHANNEL?{channel:process.env.PAPERPLAY_BROWSER_CHANNEL}:{})});
  try {
    const page=await browser.newPage({viewport:{width:1440,height:1000},colorScheme:'light'});
    const go=async name=>{await page.locator(`[data-route=${name}]`).click();await page.waitForFunction(value=>document.querySelector('#navigation a[aria-current=page]')?.dataset.route===value,name);};
    const errors=[];page.on('pageerror',error=>{errors.push(error.message);console.error(error);});
    await page.route('https://api.github.com/**',route=>route.fulfill({json:{tag_name:'v1.0.10',assets:[{name:'PaperPlay-1.0.10-windows-x64-setup.exe',browser_download_url:'https://github.com/QianYuan1437/PaperPlay/releases/download/v1.0.10/PaperPlay-1.0.10-windows-x64-setup.exe'}]}}));
    await page.goto(url);await page.locator('#stage video').waitFor();
    await page.waitForTimeout(500);await page.screenshot({path:path.join(artifacts,'desktop-overview.png'),fullPage:true});
    await page.addScriptTag({path:require.resolve('./pages-tests/node_modules/axe-core/axe.min.js')});
    const audit=await page.evaluate(async()=>await axe.run(document,{runOnly:{type:'tag',values:['wcag2a','wcag2aa','wcag21aa']}}));
    assert.deepEqual(audit.violations.map(item=>({id:item.id,nodes:item.nodes.map(node=>({target:node.target,summary:node.failureSummary}))})),[]);
    await page.locator('#play').click();
    await page.waitForFunction(()=>document.querySelector('video').currentTime>.3);
    await page.locator('#play').click();
    assert(await page.locator('video').evaluate(video=>video.paused));
    await page.locator('#blur-toggle').click();assert.equal(await page.locator('#blur-toggle').getAttribute('aria-pressed'),'true');
    await page.locator('#audio-toggle').click();assert(await page.locator('body').evaluate(body=>body.classList.contains('audio-only')));
    await page.locator('#audio-toggle').click();await page.locator('#blur-toggle').click();
    await go('library');
    await page.locator('#search').fill('山间');assert.equal(await page.locator('.media-card').count(),1);
    await page.locator('[data-action=favorite]').click();await page.locator('#search').fill('');await page.locator('[data-action=favorites]').click();assert.equal(await page.locator('.media-card').count(),1);
    await page.locator('[data-action=favorites]').click();await page.locator('.art-play[data-id=moon]').click();
    await page.waitForFunction(()=>document.querySelector('video').currentTime>.1);
    assert.equal(await page.locator('#now-title').textContent(),'月下浮光');
    await page.locator('#now-playing').click();await page.locator('#stage').waitFor();
    await page.locator('.fullscreen').click();await page.waitForFunction(()=>!!document.fullscreenElement);
    await page.locator('.fullscreen').click();await page.waitForFunction(()=>!document.fullscreenElement);
    await page.locator('#seek').fill('500');assert(await page.locator('video').evaluate(video=>video.currentTime>4));
    await page.locator('#mode').click();assert((await page.locator('#mode').textContent()).includes('随机播放'));
    await page.locator('#next').click();assert.notEqual(await page.locator('#now-title').textContent(),'月下浮光');
    await page.locator('#mute').click();assert(await page.locator('video').evaluate(video=>video.muted));
    await page.locator('#volume').fill('20');assert.equal(await page.locator('video').evaluate(video=>video.volume),.2);
    await go('queue');await page.locator('[data-action=down]').first().click();
    assert.equal(await page.locator('.queue-title').first().textContent(),'山间来信');
    await page.locator('[data-action=save]').click();await page.locator('[data-action=clear]').click();assert.equal(await page.locator('.queue-list li').count(),0);
    await page.locator('[data-action=load]').click();assert.equal(await page.locator('.queue-list li').count(),3);
    await page.locator('[data-action=remove]').first().click();assert.equal(await page.locator('.queue-list li').count(),2);
    await go('library');await page.locator('[data-action=enqueue][data-id=forest]').click();assert.equal(await page.locator('#queue-count').textContent(),'3');
    await go('local');
    await page.locator('[data-action=import]').first().waitFor();
    const picker=page.waitForEvent('filechooser');await page.locator('[data-action=import]').first().click();
    await (await picker).setFiles(path.resolve(__dirname,'../test/fixtures/sample.mp4'));
    await page.locator('.media-card').waitFor();
    assert.equal(await page.locator('.media-card').count(),1);await page.locator('.art-play').click();await page.waitForFunction(()=>document.querySelector('video').currentTime>.1);
    await go('appearance');await page.locator('#view [data-accent=blue]').click();
    await page.locator('[data-setting=blur]').check();assert.equal(await page.locator('#blur-toggle').getAttribute('aria-pressed'),'true');
    await page.locator('[data-setting=reduce]').check();await page.locator('[data-setting=glass]').uncheck();
    await page.locator('#theme-toggle').click();assert(await page.locator('body').evaluate(body=>body.classList.contains('dark')));
    await page.waitForTimeout(400);
    const darkAudit=await page.evaluate(async()=>await axe.run(document,{runOnly:{type:'tag',values:['wcag2a','wcag2aa','wcag21aa']}}));
    assert.deepEqual(darkAudit.violations.map(item=>({id:item.id,nodes:item.nodes.map(node=>node.target)})),[]);
    await go('performance');await page.waitForFunction(()=>document.querySelector('#fps') && document.querySelector('#fps').textContent!=='—');
    await page.locator('[data-setting=stats]').uncheck();assert.equal(await page.locator('#fps').textContent(),'—');
    await page.locator('[data-setting=stats]').check();await page.waitForFunction(()=>document.querySelector('#fps') && document.querySelector('#fps').textContent!=='—');
    await page.screenshot({path:path.join(artifacts,'desktop-performance.png'),fullPage:true});
    await page.reload();assert.equal(await page.locator('body').getAttribute('data-accent'),'blue');assert.equal(await page.locator('#blur-toggle').getAttribute('aria-pressed'),'true');
    await page.locator('#reset-demo').click();await go('overview');
    await page.locator('#play').click();await page.waitForFunction(()=>document.querySelector('video').currentTime>.2);
    // Moving between views must retain the actual media element and playback.
    for(const name of ['library','player','appearance','overview']){await go(name);assert.equal(await page.locator('video').count(),1);assert(await page.locator('video').evaluate(video=>!video.paused));}
    await page.locator('#play').click();
    for(const width of [1280,960,768,390,360]){
      await page.setViewportSize({width,height:844});
      for(const name of ['overview','library','queue','player','local','performance','appearance']){
        await go(name);
        assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),`${name} overflows at ${width}`);
      }
      await go('overview');
      if(width===390){await page.waitForTimeout(500);await page.screenshot({path:path.join(artifacts,'mobile-overview.png'),fullPage:true});}
    }
    const fallback=await browser.newPage({viewport:{width:1440,height:1000},reducedMotion:'reduce'});
    await fallback.route('https://api.github.com/**',route=>route.abort());await fallback.goto(url);
    assert.equal(await fallback.locator('#download').getAttribute('href'),'https://github.com/QianYuan1437/PaperPlay/releases/latest');
    assert.equal(await fallback.locator('.ambient i').first().evaluate(node=>getComputedStyle(node).animationName),'none');
    await fallback.keyboard.press('Tab');assert.equal(await fallback.locator(':focus').textContent(),'跳到体验区');
    assert.deepEqual(errors,[]);
    console.log('Pages: playback, seek, audio, blur, queue, import, settings, charts, persistence, API fallback and 5 viewport widths passed.');
  } finally {await browser.close();server.close();}
})().catch(error=>{console.error(error);server.close();process.exitCode=1;});
