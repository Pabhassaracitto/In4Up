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
    return null;
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

      if (color && color !== 'transparent') {
        const span = document.createElement('span');
        span.className = 'in2up-word';
        span.setAttribute('data-word', token.toLowerCase());
        span.setAttribute('data-type',
          classification.mode === 'cefr'
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
  document.addEventListener('mouseup', function() {
    const sel = window.getSelection();
    if (sel && sel.toString().trim().length > 0) {
      window.in2upnnel.postMessage(JSON.stringify({
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
        window.in2upnnel.postMessage(JSON.stringify({
          type: 'textSelected',
          text: sel.toString().trim()
        }));
      }
    }, 100);
  });

  console.log('[in2up] Selection listener ready');
})();
''';

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
