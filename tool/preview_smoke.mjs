// tool/preview_smoke.mjs
//
// Smoke-test cho bản build web preview: mở từng tab của UI gallery bằng
// Chromium headless, chụp ảnh màn hình và gom lỗi console/network.
//
// Vì sao cần: sandbox của agent không chạy được Chromium (thiếu libnspr4 /
// libnss3 và apt bị chặn egress), nên bước "mở thật trong trình duyệt" được
// chạy trên runner GitHub — nơi có sẵn môi trường — rồi commit ảnh + log vào
// nhánh preview để đọc lại được.
//
// Cách dùng:
//   npm i puppeteer-core @sparticuz/chromium
//   node tool/preview_smoke.mjs http://127.0.0.1:8080 smoke-out
//
// Kết quả: <out>/*.png + <out>/report.txt (exit code 0 nếu không có lỗi nặng).

import fs from 'node:fs/promises';
import path from 'node:path';
import puppeteer from 'puppeteer-core';
import chromium from '@sparticuz/chromium';

const base = (process.argv[2] || 'http://127.0.0.1:8080').replace(/\/$/, '');
const outDir = process.argv[3] || 'smoke-out';

/** Mỗi mục = một màn cần chứng minh là đã render được. */
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
  { file: '08-web-lite.png', url: `${base}/web-lite/`, note: 'App web chính thức' },
  { file: '09-mobile-small.png', url: `${base}/#cham`, note: 'Màn hẹp 360×740' },
];

const errors = [];
const report = [];

async function shoot(browser, shot, opts = {}) {
  const page = await browser.newPage();
  const local = [];
  page.on('console', (m) => {
    if (m.type() === 'error') local.push(`console: ${m.text().slice(0, 400)}`);
  });
  page.on('pageerror', (e) => local.push(`pageerror: ${String(e).slice(0, 400)}`));
  page.on('requestfailed', (r) =>
    local.push(`requestfailed: ${r.url().slice(0, 160)} (${r.failure()?.errorText})`),
  );

  await page.setViewport({
    width: opts.width || 430,
    height: opts.height || 932,
    deviceScaleFactor: 2,
  });

  const t0 = Date.now();
  await page.goto(shot.url, { waitUntil: 'networkidle2', timeout: 180000 });
  // Flutter chỉ vẽ vào <canvas> sau khi engine khởi động ⇒ chờ canvas xuất hiện.
  await page.waitForSelector('canvas', { timeout: 180000 });
  await new Promise((r) => setTimeout(r, opts.settle ?? 4000));

  const canvases = await page.$$eval('canvas', (els) =>
    els.map((e) => `${e.width}x${e.height}`),
  );

  await page.screenshot({ path: path.join(outDir, shot.file) });

  const line =
    `${shot.file} · ${shot.note}\n` +
    `  url: ${shot.url}\n` +
    `  boot: ${Date.now() - t0} ms · canvas: ${canvases.join(', ') || 'KHÔNG CÓ'}\n` +
    (local.length ? `  lỗi:\n    ${local.join('\n    ')}\n` : '  lỗi: không có\n');
  report.push(line);
  errors.push(...local.map((l) => `${shot.file}: ${l}`));
  console.log(line);

  await page.close();
  return canvases.length > 0;
}

await fs.mkdir(outDir, { recursive: true });

const browser = await puppeteer.launch({
  args: [...chromium.args, '--no-sandbox', '--disable-dev-shm-usage'],
  executablePath: await chromium.executablePath(),
  headless: 'shell',
});

let rendered = 0;
try {
  for (const shot of shots) {
    if (shot.file === '09-mobile-small.png') {
      if (await shoot(browser, shot, { width: 360, height: 740 })) rendered++;
    } else if (await shoot(browser, shot)) {
      rendered++;
    }
  }
} finally {
  await browser.close();
}

const summary =
  `In4Up · preview smoke-test\n` +
  `thời điểm: ${new Date().toISOString()}\n` +
  `số màn render được: ${rendered}/${shots.length}\n` +
  `tổng lỗi console/network: ${errors.length}\n\n` +
  report.join('\n');

await fs.writeFile(path.join(outDir, 'report.txt'), summary, 'utf8');
console.log(summary);

if (rendered < shots.length) {
  console.error(`::error title=smoke::chỉ ${rendered}/${shots.length} màn render được`);
  process.exit(1);
}
if (errors.length) {
  console.error(`::warning title=smoke::${errors.length} lỗi console (xem report.txt)`);
}
