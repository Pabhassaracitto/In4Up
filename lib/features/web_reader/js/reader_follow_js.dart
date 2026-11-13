import 'dart:convert';

/// Non-destructive range overlays: never wrap/rewrite the publisher's DOM.
String readerFollowScript(List<String> cues, int index,
    {required bool karaoke, required bool autoScroll}) => '''
(() => {
  document.querySelectorAll('.i4u-reading-overlay').forEach(e => e.remove());
  if (!window.i4uFollowInstalled) {
    window.i4uFollowInstalled = true;
    const manual = () => { window.i4uManualUntil = Date.now() + 5000; };
    window.addEventListener('wheel', manual, {passive: true});
    window.addEventListener('touchmove', manual, {passive: true});
    window.addEventListener('pointermove', e => { if (e.buttons) manual(); }, {passive: true});
    window.addEventListener('keydown', e => {
      if (['ArrowDown','ArrowUp','PageDown','PageUp','Home','End',' '].includes(e.key)) manual();
    });
  }
  const cues = ${jsonEncode(cues)}, index = $index;
  if (index < 0 || index >= cues.length) return;
  const root = document.querySelector('article,[role="main"],main,.content,.post-content') || document.body;
  const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
  const positions = [];
  let flat = '', node;
  while ((node = walker.nextNode())) {
    if (node.parentElement.closest('script,style,nav,aside,footer,header,.i4u-reading-overlay')) continue;
    for (let i = 0; i < node.length; i++) {
      const ch = /\\s/.test(node.data[i]) ? ' ' : node.data[i];
      if (ch === ' ' && flat.endsWith(' ')) continue;
      flat += ch;
      positions.push([node, i]);
    }
  }
  let cursor = 0, at = -1, text;
  for (let i = 0; i <= index; i++) {
    text = cues[i].replace(/\\s+/g, ' ').trim();
    at = flat.indexOf(text, cursor);
    if (at < 0) { if (i === index) return; continue; }
    cursor = at + text.length;
  }
  const start = positions[at], end = positions[at + text.length - 1];
  if (!start || !end) return;
  const range = document.createRange();
  range.setStart(start[0], start[1]); range.setEnd(end[0], end[1] + 1);
  const rect = range.getBoundingClientRect();
  if ($autoScroll && Date.now() >= (window.i4uManualUntil || 0) &&
      (rect.top < 0 || rect.bottom > innerHeight)) {
    window.scrollBy({top: rect.top - innerHeight / 3, behavior: 'instant'});
  }
  if (!$karaoke) return;
  for (const r of range.getClientRects()) {
    const mark = document.createElement('div');
    mark.className = 'i4u-reading-overlay';
    Object.assign(mark.style, {position:'absolute', pointerEvents:'none',
      background:'rgba(255,193,7,.35)', zIndex:'2147483646',
      left:(r.left + scrollX)+'px', top:(r.top + scrollY)+'px', width:r.width+'px', height:r.height+'px'});
    document.body.appendChild(mark);
  }
})();
''';
