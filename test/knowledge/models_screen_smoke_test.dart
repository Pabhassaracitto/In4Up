// test/knowledge/models_screen_smoke_test.dart
//
// (TẠM THỜI — bisect helper, XÓA sau khi CI xanh)
// Mục đích: ép CFE compile graph đầy đủ của feature MODELS-001
// (screen + manager + barrel + engine + floating_text_actions) để lỗi
// compile hiện trong log CI (đọc được qua job log).
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/screens/read_mode/widgets/floating_text_actions.dart';
import 'package:in4up/screens/settings/stt_model_settings_screen.dart';
import 'package:in4up_stt/in4up_stt.dart';

void main() {
  test('MODELS-001 graph compiles (smoke)', () {
    expect(SttModelSettingsScreen, isNotNull);
    expect(FloatingTextActions, isNotNull);
    expect(SherpaModelManager, isNotNull);
    expect(SherpaPiperTtsCore, isNotNull);
    expect(PiperTtsVoice, isNotNull);
  });
}
