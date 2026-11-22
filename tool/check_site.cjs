const { chromium } = require('../.dart_tool/web-check/node_modules/playwright');
const path = require('node:path');
const fs = require('node:fs');
const { pathToFileURL } = require('node:url');
(async () => {
  fs.mkdirSync('artifacts', { recursive: true });
  const browser = await chromium.launch({ executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: true });
  const page = await browser.newPage();
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.setViewportSize({ width: 1440, height: 1000 });
  await page.goto(pathToFileURL(path.resolve('docs/index.html')).href);
  await page.screenshot({ path: 'artifacts/pages-desktop.png', fullPage: true });
  for (const width of [1440, 760, 390, 320]) {
    await page.setViewportSize({ width, height: 900 });
    if (await page.evaluate(() => document.documentElement.scrollWidth > innerWidth)) throw new Error(`Horizontal overflow at ${width}`);
    if (await page.locator('img').evaluateAll(images => images.some(i => !i.complete || !i.naturalWidth))) throw new Error('Broken image');
  }
  await page.getByRole('button', { name: '切换明暗主题' }).click();
  if (!await page.locator('body').evaluate(el => el.classList.contains('dark'))) throw new Error('Theme toggle failed');
  await page.getByText('需要运行 Wallpaper Engine 吗？', { exact: true }).click();
  if (!await page.locator('details').first().getAttribute('open') && !await page.locator('details').first().evaluate(el => el.open)) throw new Error('FAQ failed');
  await page.screenshot({ path: 'artifacts/pages-mobile.png', fullPage: true });
  await browser.close();
  if (errors.length) throw new Error(errors.join('\n'));
  process.stdout.write('Pages: responsive layout, images, theme and FAQ passed.\n');
})().catch(error => { process.stderr.write(error.stack + '\n'); process.exitCode = 1; });
