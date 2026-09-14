import 'package:flutter_test/flutter_test.dart';
import 'package:in4up_stt/tts/piper_voice_catalog.dart';

void main() {
  test('priority languages are featured first', () {
    final featured = PiperVoiceCatalog.featured();
    expect(featured.any((v) => v.languageCode == 'vi_VN'), isTrue);
    expect(featured.any((v) => v.languageCode.startsWith('en_')), isTrue);
    expect(featured.any((v) => v.languageCode == 'zh_CN'), isTrue);
    expect(featured.any((v) => v.languageCode == 'hi_IN'), isTrue);
    expect(featured.any((v) => v.languageCode.startsWith('si')), isFalse);
  });

  test('ids are unique and HuggingFace paths look valid', () {
    final ids = PiperVoiceCatalog.all.map((v) => v.id).toSet();
    expect(ids.length, PiperVoiceCatalog.all.length);
    for (final v in PiperVoiceCatalog.all) {
      expect(v.hfOnnxRel.endsWith('.onnx'), isTrue);
      expect(v.hfOnnxUrl.contains('rhasspy/piper-voices'), isTrue);
      expect(v.hfJsonUrl.endsWith('.onnx.json'), isTrue);
      expect(PiperVoiceCatalog.byId(v.id), same(v));
    }
  });

  test('show-more list is non-empty', () {
    expect(PiperVoiceCatalog.more(), isNotEmpty);
  });
}
