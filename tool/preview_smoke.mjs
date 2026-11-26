// tool/preview_smoke.mjs
//
// Smoke-test cho bản build web preview: mở từng tab của UI gallery bằng
// Chromium headless, chụp ảnh màn hình và gom lỗi console/network.
//
// Vì sao cần: sandbox của agent không chạy được Chromium (thiếu libnspr4 /
// libnss3, apt bị chặn egress), nên bước "mở thật trong trình duyệt" được
// chạy trên runner GitHub — nơi có sẵn môi trường — rồi commit ảnh + log vào
// nhánh preview để đọc lại được.
//
// Cách dùng (script phải nằm CẠNH node_modules):
//   npm i puppeteer-core @sparticuz/chromium
//   node preview_smoke.mjs http://127.0.0.1:8080 smoke-out
//
// Kết quả: <out>/*.png + <out>/report.txt

import fs from 'node:fs/promises';
import path from 'node:path';
import puppeteer from 'puppeteer-core';
import chromium from '@sparticuz/chromium';

const base = (process.argv[2] || 'http://127.0.0.1:8080').replace(/\/$/, '');
const outDir = process.argv[3] || 'smoke-out';

const shots = [
  { file: '01-typography.png', url: `${base}/#chu`, note: 'Sàn chữ ≥11sp' },
  { file: '02-touch-targets.png', url: `${base}/#cham`, note: 'Vùng chạm ≥40pt' },
  { file: '03-sheets.png', url: `${base}/#sheet`, note: 'Danh sách sheet' },
  {
    file: '04-sheet-pdf.png',
    url: `${base}/#sheet-pdf`,
    note: 'PdfReaderThemeSheet mở thật (SafeArea)',
  },
  {
    file: '05-sheet-grammar.png',
    url: `${base}/#sheet-grammar`,
    note: 'GrammarQuickSettingsSheet mở thật',
  },
  { file: '06-locales.png', url: `${base}/#locale`, note: '8 locale ưu tiên' },
  { file: '07-library.png', url: `${base}/#thuvien`, note: 'Trạng thái GLIB' },
  {
    file: '07b-locale-zh.png',
    url: `${base}/?lang=zh#locale`,
    note: 'Toàn bộ UI ở 中文 (zh)',
  },
  {
    file: '07c-locale-si.png',
    url: `${base}/?lang=si#locale`,
    note: 'Toàn bộ UI ở සිංහල (si)',
  },
  { file: '08-web-lite.png', url: `${base}/web-lite/`, note: 'App web chính thức' },
  {
    file: '09-mobile-small.png',
    url: `${base}/#cham`,
    note: 'Màn hẹp 360×740',
    width: 360,
    height: 740,
  },
];

const errors = [];
const lines = [];
let rendered = 0;

await fs.mkdir(outDir, { recursive: true });

async function writeReport(extra = '') {
  const summary =
    `In4Up · preview smoke-test\n` +
    `thời điểm: ${new Date().toISOString()}\n` +
    `số màn render được: ${rendered}/${shots.length}\n` +
    `tổng lỗi console/network: ${errors.length}\n` +
    (extra ? `\n${extra}\n` : '\n') +
    lines.join('\n');
  await fs.writeFile(path.join(outDir, 'report.txt'), summary, 'utf8');
  return summary;
}

async function shoot(browser, shot) {
  const page = await browser.newPage();
  const local = [];
  page.on('console', (m) => {
    if (m.type() === 'error') local.push(`console: ${m.text().slice(0, 400)}`);
  });
  page.on('pageerror', (e) => local.push(`pageerror: ${String(e).slice(0, 400)}`));
  page.on('requestfailed', (r) =>
    local.push(
      `requestfailed: ${r.url().slice(0, 160)} (${r.failure()?.errorText})`,
    ),
  );

  await page.setViewport({
    width: shot.width || 430,
    height: shot.height || 932,
    deviceScaleFactor: 2,
  });

  const t0 = Date.now();
  let boot = 'ok';
  let canvases = [];
  let bodyText = '';

  await page.goto(shot.url, { waitUntil: 'networkidle2', timeout: 180000 });

  // Flutter (CanvasKit/skwasm) dựng khung `flutter-view` / `flt-glass-pane`;
  // không phụ thuộc <canvas> vì engine có thể render bằng element khác.
  try {
    await page.waitForFunction(
      () =>
        !!document.querySelector(
          'flutter-view, flt-glass-pane, flt-scene-host, canvas',
        ),
      { timeout: 120000, polling: 500 },
    );
  } catch {
    boot = 'KHÔNG thấy flutter-view/canvas sau 120s';
  }

  // Loader trong index.html chỉ tự xoá sau frame đầu ⇒ chờ nó biến mất.
  try {
    await page.waitForFunction(() => !document.getElementById('in4up-loader'), {
      timeout: 60000,
      polling: 400,
    });
  } catch {
    boot += ' · loader vẫn còn';
  }
  await new Promise((r) => setTimeout(r, 2500));

  // Flutter (CanvasKit) đặt <canvas> trong SHADOW DOM của flt-glass-pane —
  // `document.querySelector('canvas')` không thấy. Phải đi xuyên shadow root.
  const probe = await page.evaluate(() => {
    const out = { canvases: [], scenes: 0, text: '' };
    const visit = (root, depth) => {
      if (!root || depth > 6) return;
      for (const el of root.querySelectorAll('*')) {
        const tag = el.tagName.toLowerCase();
        if (tag === 'canvas') out.canvases.push(`${el.width}x${el.height}`);
        if (tag === 'flt-scene-host') out.scenes++;
        if (el.shadowRoot) visit(el.shadowRoot, depth + 1);
      }
    };
    visit(document, 0);
    out.text = (document.body?.innerText ?? '').replace(/\s+/g, ' ').slice(0, 200);
    return out;
  });
  canvases = probe.canvases;
  const scenes = probe.scenes;
  bodyText = probe.text;

  await page.screenshot({ path: path.join(outDir, shot.file) });
  await page.close();

  const ok = canvases.length > 0 || scenes > 0 || bodyText.length > 0;
  if (ok) rendered++;
  lines.push(
    `${shot.file} · ${shot.note}\n` +
      `  url: ${shot.url}\n` +
      `  boot: ${Date.now() - t0} ms · ${boot}\n` +
      `  canvas: ${canvases.join(', ') || 'KHÔNG CÓ'} · scene: ${scenes} · text: ${bodyText || '(rỗng)'}\n` +
      (local.length ? `  lỗi:\n    ${local.join('\n    ')}\n` : '  lỗi: không có\n'),
  );
  errors.push(...local.map((l) => `${shot.file}: ${l}`));
  console.log(`${shot.file}: ${ok ? 'OK' : 'FAIL'} (${boot})`);
}

let browser;
try {
  browser = await puppeteer.launch({
    args: [...chromium.args, '--no-sandbox', '--disable-dev-shm-usage'],
    executablePath: await chromium.executablePath(),
    headless: true,
  });
  for (const shot of shots) {
    await shoot(browser, shot);
  }
} catch (e) {
  const fatal = `fatal: ${String(e).slice(0, 600)}`;
  errors.push(fatal);
  lines.push(fatal);
} finally {
  await browser?.close();
}

console.log(await writeReport());

if (rendered < shots.length) {
  console.error(`::error title=smoke::chỉ ${rendered}/${shots.length} màn render được`);
  process.exit(1);
}
if (errors.length) {
  console.error(`::warning title=smoke::${errors.length} lỗi console (xem report.txt)`);
}
