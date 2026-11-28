import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final native = File('android/app/src/main/kotlin/com/in4up/MainActivity.kt').readAsStringSync();
  final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
  test('one Android PROCESS_TEXT route handles both cold and warm starts', () {
    expect(RegExp('android\\.intent\\.action\\.PROCESS_TEXT').allMatches(manifest).length, 1);
    expect(native, contains('getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT)'));
    expect(native, contains('it.length <= 32768'));
    expect(native, contains('processChannel == null || !processTextListenerReady'));
    expect(native, contains('processTextListenerReady = true'));
    expect(native, contains('outState.putString(STATE_PENDING_PROCESS_TEXT, it)'));
    expect(native, contains('savedInstanceState.getString(STATE_PENDING_PROCESS_TEXT)'));
    expect(native, contains('val link = intent.dataString'));
    expect(native, contains('channel == null || !deepLinkListenerReady'));
    expect(native, isNot(contains('processTextLink(')));
  });
}
