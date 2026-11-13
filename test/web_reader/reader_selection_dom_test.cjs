const {readFileSync} = require('node:fs');
const assert = require('node:assert/strict');
const {JSDOM} = require('jsdom');
const source = readFileSync('lib/features/web_reader/js/web_reader_js.dart', 'utf8');
function script(name) {
  return source.split(`static const String ${name} = '''`)[1].split("''';")[0]
    .replaceAll('\\\\', '\\');
}
const dom = new JSDOM('<article>  <header>Ignore header</header><p>Same sentence.</p><script>ignore script</script><p>Same sentence.</p></article>', {runScripts: 'outside-only'});
const w = dom.window;
let message;
w.in4upChannel = {postMessage: value => message = JSON.parse(value)};
w.eval(script('setupSelectionListenerScript'));
const range = w.document.createRange();
const selected = w.document.querySelectorAll('p')[1].firstChild;
range.setStart(selected, 5);
range.setEnd(selected, 13);
w.getSelection().addRange(range);
w.document.dispatchEvent(new w.Event('mouseup'));
const article = w.eval(script('extractMainTextScript')).trim();
assert.equal(article, 'Same sentence.Same sentence.');
assert.equal(message.text, 'sentence');
assert.equal(message.readingOffset, 'Same sentence.'.length + 5);
assert.equal(article.slice(message.readingOffset, message.readingOffset + message.text.length), message.text);
console.log('PASS reader selection: repeated content maps to selected DOM occurrence');
