// Run with NODE_PATH pointing at jsdom's node_modules. Executes the actual
// Dart JS template after the same literal escaping/interpolation as Dart.
const {readFileSync} = require('node:fs');
const assert = require('node:assert/strict');
const {JSDOM} = require('jsdom');
const source = readFileSync('lib/features/web_reader/js/reader_follow_js.dart', 'utf8');
function script(cues, index, karaoke = true, autoScroll = true) {
  return source.split("=> '''")[1].split("''';")[0]
    .replaceAll('\\\\', '\\')
    .replace('${jsonEncode(cues)}', JSON.stringify(cues))
    .replace('$index', index).replaceAll('$autoScroll', autoScroll)
    .replaceAll('$karaoke', karaoke);
}
const dom = new JSDOM('<article><p>First sentence.</p><p>Repeated sentence.</p><p>Repeated sentence.</p></article>', {runScripts: 'outside-only'});
const w = dom.window;
const cues = ['First sentence.', 'Repeated sentence.', 'Repeated sentence.'];
let rect = {left: 0, top: 10, bottom: 40, width: 100, height: 30};
let scrolls = 0, selectedNode;
w.scrollBy = () => scrolls++;
w.Range.prototype.getBoundingClientRect = function() { selectedNode = this.startContainer; return rect; };
w.Range.prototype.getClientRects = () => [rect];
const original = w.document.querySelector('article').innerHTML;
w.eval(script(cues, 2));
assert.equal(selectedNode, w.document.querySelectorAll('p')[2].firstChild);
assert.equal(scrolls, 0, 'visible cue must not scroll');
assert.equal(w.document.querySelectorAll('.i4u-reading-overlay').length, 1);
rect = {...rect, top: 1500, bottom: 1530};
w.eval(script(cues, 1));
assert.equal(scrolls, 1, 'outside cue follows');
w.dispatchEvent(new w.Event('wheel'));
w.eval(script(cues, 2));
assert.equal(scrolls, 1, 'manual gesture suppresses follow');
w.i4uManualUntil = Date.now() - 1;
w.eval(script(cues, 2, false));
assert.equal(scrolls, 2, 'follow resumes and works with karaoke off');
assert.equal(w.document.querySelectorAll('.i4u-reading-overlay').length, 0);
w.eval(script(cues, 1, true, false));
assert.equal(scrolls, 2, 'follow can be disabled separately');
w.eval(script(cues, -1));
assert.equal(w.document.querySelectorAll('.i4u-reading-overlay').length, 0, 'stop clears overlay');
assert.equal(w.document.querySelector('article').innerHTML, original, 'publisher DOM unchanged');
console.log('PASS reader follow DOM: duplicate mapping, viewport, gesture, toggles, cleanup');
