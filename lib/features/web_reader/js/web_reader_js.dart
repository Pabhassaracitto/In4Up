import 'dart:convert';

//
// Tập hợp các JavaScript strings được inject vào WebView
// Mỗi function được tách riêng để dễ debug và maintain

class WebReaderJS {
  WebReaderJS._();

  /// Script chính: wrap từng từ trong <span>, gắn click handler
  /// Nhận config JSON từ Flutter
  static String buildHighlightScript(String configJson) {
    return '''
(function() {
  // ── Config từ Flutter ──────────────────────────────────
  const CONFIG = $configJson;
  const MODE = CONFIG.mode;
  const CEFR_DICT = CONFIG.cefrDictionary || {};
  const DIFFICULTY_DICT = CONFIG.difficultyDictionary || {};
  const RECALL_DICT = CONFIG.recallDictionary || {};
  const COLORS = CONFIG.colors || {};
  const SUFFIXES = CONFIG.suffixes || {};

  // ── Cleanup script (xóa highlight cũ) ─────────────────
  function removeHighlights() {
    const spans = document.querySelectorAll('.in2up-word');
    spans.forEach(span => {
      const text = document.createTextNode(span.textContent);
      span.parentNode.replaceChild(text, span);
    });
    // Merge adjacent text nodes
    document.body.normalize();
  }

  // ── Word Classification ────────────────────────────────
  function classifyWord(word) {
    const w = word.toLowerCase().replace(/[^\\w']/g, '');
    if (!w || w.length <= 1) return null;

    if (MODE === 'cefrLevel') {
      // Tra dict trước
      if (CEFR_DICT[w]) return { mode: 'cefr', level: CEFR_DICT[w] };

      // Heuristic suffix
      if (w.length <= 3) return { mode: 'cefr', level: 'a1' };
      if (w.length <= 5) return { mode: 'cefr', level: 'a2' };
      if (w.length <= 8) return { mode: 'cefr', level: 'b1' };
      return { mode: 'cefr', level: 'b2' };
    }

    if (MODE === 'difficulty') {
      if (DIFFICULTY_DICT[w]) {
        return { mode: 'difficulty', level: DIFFICULTY_DICT[w] };
      }
      return null;
    }

    if (MODE === 'wordType') {
      // Stop words
      const stopWords = new Set(['the','a','an','is','are','was','were','be',
        'been','being','have','has','had','do','does','did','will','would',
        'could','should','can','to','of','in','for','on','with','at','by',
        'from','as','and','but','or','not','i','you','he','she','it','we',
        'they','me','my','your','his','her','our','their','this','that',
        'these','those','it','its']);
      const pronouns = new Set(['i','you','he','she','it','we','they','me',
        'him','her','us','them','my','your','his','our','their']);
      const determiners = new Set(['a','an','the','some','any','every','each',
        'both','either','neither','all','few','many','much','several']);
      const prepositions = new Set(['in','on','at','by','for','with','about',
        'against','between','into','through','during','before','after',
        'above','below','to','from','up','down','of','off','over','under']);
      const conjunctions = new Set(['and','but','or','nor','for','yet','so',
        'although','because','since','unless','while','whereas','if','after',
        'before','when','where','whether','though']);
      const commonVerbs = new Set(['be','have','do','say','get','make','go',
        'know','take','see','come','think','look','want','give','use','find',
        'tell','ask','seem','feel','try','leave','call','keep','let','begin',
        'show','hear','play','run','move','live','believe','hold','bring',
        'happen','write','sit','stand','lose','pay','meet','include','continue',
        'set','learn','change','lead','understand','watch','follow','stop',
        'create','speak','read','spend','grow','open','walk','win','offer',
        'remember','love','consider','appear','buy','wait','serve','die',
        'send','expect','stay','fall','cut','reach','kill','remain','suggest',
        'raise','pass','sell','require','report','decide','pull']);

      if (pronouns.has(w)) return { mode: 'wordType', type: 'pronoun' };
      if (determiners.has(w)) return { mode: 'wordType', type: 'determiner' };
      if (prepositions.has(w)) return { mode: 'wordType', type: 'preposition' };
      if (conjunctions.has(w)) return { mode: 'wordType', type: 'conjunction' };
      if (commonVerbs.has(w)) return { mode: 'wordType', type: 'verb' };

      // Suffix-based
      const suffixes = SUFFIXES;
      for (const [type, list] of Object.entries(suffixes)) {
        for (const suffix of list) {
          if (w.endsWith(suffix) && w.length > suffix.length + 2) {
            return { mode: 'wordType', type };
          }
        }
      }

      // Default: noun nếu không phải stop word và > 4 chars
      if (!stopWords.has(w) && w.length > 4) {
        return { mode: 'wordType', type: 'noun' };
      }

      return null;
    }

    return null;
  }

  function getColor(classification) {
    if (!classification) return null;
    if (classification.mode === 'cefr') {
      return (COLORS.cefr || {})[classification.level];
    }
    if (classification.mode === 'wordType') {
      return (COLORS.wordType || {})[classification.type];
    }
    if (classification.mode === 'difficulty') {
      return (COLORS.difficulty || {})[classification.level];
    }
    return null;
  }

  function getRecallMeta(word) {
    const w = word.toLowerCase().replace(/[^\\w']/g, '');
    return RECALL_DICT[w] || null;
  }

  function applyRecallStyle(span, meta) {
    if (!meta) return;
    if (meta.saved) {
      span.style.outline = '1px solid rgba(76,175,80,0.45)';
      span.style.outlineOffset = '1px';
    }
    if (meta.note) {
      span.style.boxShadow = 'inset 0 -2px 0 rgba(255,193,7,0.75)';
    }
    if (meta.due) {
      span.style.borderTop = '2px solid rgba(244,67,54,0.85)';
    }
  }

  // ── Text node walker ──────────────────────────────────
  function processTextNode(textNode) {
    const text = textNode.textContent;
    if (!text || text.trim().length < 2) return;

    // Skip nếu parent là script, style, input, etc.
    const parent = textNode.parentNode;
    if (!parent) return;
    const tag = parent.tagName ? parent.tagName.toLowerCase() : '';
    if (['script','style','noscript','code','pre','textarea',
         'input','button','select','option'].includes(tag)) return;
    // Skip nếu đã là in2up span
    if (parent.classList && parent.classList.contains('in2up-word')) return;

    // Tokenize: chia thành words + non-words
    const tokenRegex = /[\\w']+|[^\\w\\s]+|\\s+/g;
    const tokens = text.match(tokenRegex);
    if (!tokens || tokens.length <= 1) return;

    const fragment = document.createDocumentFragment();
    let hasHighlight = false;

    tokens.forEach(token => {
      const wordMatch = token.match(/^[\\w']+\$/);
      if (!wordMatch || token.length <= 1) {
        fragment.appendChild(document.createTextNode(token));
        return;
      }

      const classification = classifyWord(token);
      const color = getColor(classification);
      const recallMeta = getRecallMeta(token);

      if (color && color !== 'transparent') {
        const span = document.createElement('span');
        span.className = 'in2up-word';
        span.setAttribute('data-word', token.toLowerCase());
        span.setAttribute('data-type',
          classification.mode === 'cefr'
            ? classification.level
            : classification.mode === 'difficulty'
              ? classification.level
              : classification.type);
        span.textContent = token;
        span.style.cssText = [
          'background-color: ' + color + '22',
          'border-bottom: 2px solid ' + color,
          'border-radius: 2px',
          'cursor: pointer',
          'padding: 0 1px',
          'transition: background-color 0.15s',
        ].join(';');

        // Hover effect via JS (không dùng CSS class để tránh xung đột)
        span.addEventListener('mouseover', () => {
          span.style.backgroundColor = color + '44';
        });
        span.addEventListener('mouseout', () => {
          span.style.backgroundColor = color + '22';
        });

        applyRecallStyle(span, recallMeta);

        // Click → gửi message về Flutter
        span.addEventListener('click', (e) => {
          e.stopPropagation();
          e.preventDefault();
          window.in2upChannel.postMessage(JSON.stringify({
            type: 'wordTap',
            word: token,
            wordType: classification.mode === 'cefr'
              ? null
              : classification.type,
            cefrLevel: classification.mode === 'cefr'
              ? classification.level
              : null,
          }));
        });

        fragment.appendChild(span);
        hasHighlight = true;
      } else {
        // Non-highlighted word: vẫn gắn click để tra từ
        const span = document.createElement('span');
        span.className = 'in2up-word in2up-plain';
        span.setAttribute('data-word', token.toLowerCase());
        span.textContent = token;
        span.style.cssText = 'cursor: pointer;';
        applyRecallStyle(span, recallMeta);
        span.addEventListener('click', (e) => {
          e.stopPropagation();
          e.preventDefault();
          window.in2upChannel.postMessage(JSON.stringify({
            type: 'wordTap',
            word: token,
            wordType: null,
            cefrLevel: null,
          }));
        });
        fragment.appendChild(span);
      }
    });

    if (hasHighlight) {
      parent.replaceChild(fragment, textNode);
    }
  }

  // ── Main: walk DOM ────────────────────────────────────
  function walkDOM(node) {
    if (node.nodeType === Node.TEXT_NODE) {
      processTextNode(node);
      return;
    }
    // Skip heavy nodes
    if (node.nodeType !== Node.ELEMENT_NODE) return;
    const tag = node.tagName ? node.tagName.toLowerCase() : '';
    if (['script','style','noscript','iframe','svg','img',
         'video','audio','canvas'].includes(tag)) return;

    // Clone childNodes karena akan dimodifikasi
    const children = Array.from(node.childNodes);
    children.forEach(child => walkDOM(child));
  }

  // ── Execute ───────────────────────────────────────────
  if (MODE === 'none') {
    removeHighlights();
  } else {
    removeHighlights(); // Xóa highlight cũ trước
    // Process main content only (tránh nav/footer/sidebar)
    const mainContent =
      document.querySelector('article') ||
      document.querySelector('[role="main"]') ||
      document.querySelector('main') ||
      document.querySelector('.content') ||
      document.querySelector('.post-content') ||
      document.querySelector('#content') ||
      document.body;

    walkDOM(mainContent);
  }

  console.log('[in2up] Highlight applied: mode=' + MODE);
})();
''';
  }

  /// Script để remove highlight
  static const String removeHighlightScript = '''
(function() {
  const spans = document.querySelectorAll('.in2up-word');
  spans.forEach(span => {
    const text = document.createTextNode(span.textContent);
    if (span.parentNode) span.parentNode.replaceChild(text, span);
  });
  document.body.normalize();
  console.log('[in2up] Highlights removed');
})();
''';

  /// Script lấy page title
  static const String getTitleScript = '''
document.title || document.querySelector('h1')?.textContent || '';
''';

  /// Script lấy selected text
  static const String getSelectionScript = '''
window.getSelection()?.toString() || '';
''';

  /// Script extract main text content (dùng để load vào Text Studio)
  static const String extractMainTextScript = '''
(function() {
  const el =
    document.querySelector('article') ||
    document.querySelector('[role="main"]') ||
    document.querySelector('main') ||
    document.querySelector('.content') ||
    document.querySelector('.post-content') ||
    document.body;

  // Clone để không ảnh hưởng page
  const clone = el.cloneNode(true);

  // Xóa script, style, nav, aside, footer, ads
  ['script','style','nav','aside','footer','header',
   '.ad','#ad','[class*="sidebar"]','[class*="related"]',
   '[class*="recommend"]','[class*="social"]'
  ].forEach(sel => {
    try { clone.querySelectorAll(sel).forEach(e => e.remove()); } catch(e) {}
  });

  // Lấy innerText (giữ line breaks tự nhiên)
  return clone.innerText || clone.textContent || '';
})();
''';

  /// Script setup text selection listener
  static const String setupSelectionListenerScript = '''
(function() {
  if (window.__in2upSelectionReady) return;
  window.__in2upSelectionReady = true;

  document.addEventListener('mouseup', function() {
    const sel = window.getSelection();
    if (sel && sel.toString().trim().length > 0) {
      window.in2upChannel.postMessage(JSON.stringify({
        type: 'textSelected',
        text: sel.toString().trim()
      }));
    }
  });

  // Touch devices
  document.addEventListener('touchend', function() {
    setTimeout(() => {
      const sel = window.getSelection();
      if (sel && sel.toString().trim().length > 0) {
        window.in2upChannel.postMessage(JSON.stringify({
          type: 'textSelected',
          text: sel.toString().trim()
        }));
      }
    }, 100);
  }, { passive: true });

  console.log('[in2up] Selection listener ready');
})();
''';

  /// Script setup reading progress listener
  static const String setupReadingProgressListenerScript = '''
(function() {
  if (window.__in2upReadingProgressReady) return;
  window.__in2upReadingProgressReady = true;

  function getMainContent() {
    return document.querySelector('article') ||
      document.querySelector('[role="main"]') ||
      document.querySelector('main') ||
      document.querySelector('.content') ||
      document.querySelector('.post-content') ||
      document.body;
  }

  function getPreview() {
    const text = (getMainContent().innerText || getMainContent().textContent || '')
      .replace(/\s+/g, ' ')
      .trim();
    return text.slice(0, 220);
  }

  function getProgress() {
    const scrollTop = window.scrollY || document.documentElement.scrollTop || 0;
    const scrollHeight = Math.max(
      document.body.scrollHeight || 0,
      document.documentElement.scrollHeight || 0
    );
    const viewportHeight = window.innerHeight || document.documentElement.clientHeight || 0;
    const maxScrollable = Math.max(1, scrollHeight - viewportHeight);
    return Math.max(0, Math.min(1, scrollTop / maxScrollable));
  }

  let lastSent = -1;
  let timer = null;

  function sendProgress(force) {
    const progress = getProgress();
    if (!force && Math.abs(progress - lastSent) < 0.03) return;
    lastSent = progress;
    window.in2upChannel.postMessage(JSON.stringify({
      type: 'readingProgress',
      progress: progress,
      preview: getPreview(),
    }));
  }

  function schedule() {
    if (timer) clearTimeout(timer);
    timer = setTimeout(() => sendProgress(false), 120);
  }

  window.addEventListener('scroll', schedule, { passive: true });
  window.addEventListener('touchend', schedule, { passive: true });
  window.addEventListener('resize', schedule);

  setTimeout(() => sendProgress(true), 250);
  setTimeout(() => sendProgress(true), 1200);

  console.log('[in2up] Reading progress listener ready');
})();
''';

  static String buildRestoreScrollScript(double progress) {
    final clamped = progress.clamp(0.0, 1.0);
    return '''
(function() {
  const progress = $clamped;
  if (progress <= 0.01) return;

  function applyRestore() {
    const scrollHeight = Math.max(
      document.body.scrollHeight || 0,
      document.documentElement.scrollHeight || 0
    );
    const viewportHeight = window.innerHeight || document.documentElement.clientHeight || 0;
    const maxScrollable = Math.max(0, scrollHeight - viewportHeight);
    const target = Math.max(0, Math.min(maxScrollable, maxScrollable * progress));
    window.scrollTo({ top: target, behavior: 'auto' });
  }

  setTimeout(applyRestore, 120);
  setTimeout(applyRestore, 500);
  setTimeout(applyRestore, 1200);
})();
''';
  }

  static String buildFocusCueScript(String term) {
    final encoded = jsonEncode(term);
    return '''
(function() {
  const term = ($encoded || '').toString().trim();
  if (!term) return;

  const old = document.getElementById('in2up-focus-cue');
  if (old) {
    const parent = old.parentNode;
    if (parent) {
      parent.replaceChild(document.createTextNode(old.textContent || ''), old);
      parent.normalize();
    }
  }

  function normalize(value) {
    return (value || '').toLowerCase().replace(/[^\\w']/g, '');
  }

  const normTerm = normalize(term);
  if (!normTerm) return;

  const wrapped = Array.from(document.querySelectorAll('.in2up-word'));
  const direct = wrapped.find((el) => normalize(el.textContent) === normTerm);
  if (direct) {
    direct.scrollIntoView({ block: 'center', behavior: 'smooth' });
    direct.style.outline = '2px solid #64B5F6';
    direct.style.outlineOffset = '2px';
    direct.style.boxShadow = '0 0 0 6px rgba(100,181,246,0.18)';
    setTimeout(() => {
      direct.style.outline = '';
      direct.style.outlineOffset = '';
      direct.style.boxShadow = '';
    }, 2600);
    return;
  }

  const root = document.querySelector('article') ||
    document.querySelector('[role="main"]') ||
    document.querySelector('main') ||
    document.body;

  const walker = document.createTreeWalker(
    root,
    NodeFilter.SHOW_TEXT,
    {
      acceptNode(node) {
        if (!node || !node.textContent || !node.textContent.trim()) {
          return NodeFilter.FILTER_REJECT;
        }
        const parent = node.parentNode;
        const tag = parent && parent.tagName ? parent.tagName.toLowerCase() : '';
        if (['script','style','noscript','textarea','code','pre'].includes(tag)) {
          return NodeFilter.FILTER_REJECT;
        }
        return NodeFilter.FILTER_ACCEPT;
      }
    }
  );

  let node;
  while ((node = walker.nextNode())) {
    const text = node.textContent || '';
    const lower = text.toLowerCase();
    const index = lower.indexOf(term.toLowerCase());
    if (index < 0) continue;
    try {
      const range = document.createRange();
      range.setStart(node, index);
      range.setEnd(node, index + term.length);
      const mark = document.createElement('mark');
      mark.id = 'in2up-focus-cue';
      mark.style.background = 'rgba(100,181,246,0.28)';
      mark.style.outline = '2px solid #64B5F6';
      mark.style.borderRadius = '4px';
      mark.style.padding = '0 2px';
      range.surroundContents(mark);
      mark.scrollIntoView({ block: 'center', behavior: 'smooth' });
      setTimeout(() => {
        const parent = mark.parentNode;
        if (!parent) return;
        parent.replaceChild(document.createTextNode(mark.textContent || ''), mark);
        parent.normalize();
      }, 2600);
      return;
    } catch (_) {}
  }
})();
''';
  }

  /// Script thêm floating action button vào trang web
  static String buildFabScript(String configJson) {
    return '''
(function() {
  // Xóa FAB cũ nếu có
  const old = document.getElementById('in2up-fab');
  if (old) old.remove();

  const config = $configJson;
  const mode = config.mode;

  const fab = document.createElement('div');
  fab.id = 'in2up-fab';
  fab.style.cssText = [
    'position: fixed',
    'bottom: 80px',
    'right: 16px',
    'width: 48px',
    'height: 48px',
    'border-radius: 50%',
    'background: #6C63FF',
    'display: flex',
    'align-items: center',
    'justify-content: center',
    'cursor: pointer',
    'z-index: 99999',
    'box-shadow: 0 4px 16px rgba(108,99,255,0.4)',
    'transition: transform 0.2s',
    'font-size: 20px',
  ].join(';');

  const icons = { none: '🎨', cefrLevel: '📊', wordType: '🏷️' };
  fab.textContent = icons[mode] || '🎨';

  fab.addEventListener('mousedown', () => {
    fab.style.transform = 'scale(0.9)';
  });
  fab.addEventListener('mouseup', () => {
    fab.style.transform = 'scale(1)';
    window.in2upChannel.postMessage(JSON.stringify({ type: 'fabTap' }));
  });

  document.body.appendChild(fab);
})();
''';
  }
}
