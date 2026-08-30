import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/voice_command/voice_command_parser.dart';

void main() {
  test('parses Vietnamese and English command grammar', () {
    final samples = <String, VoiceCommandType>{
      'phát': VoiceCommandType.play, 'pause': VoiceCommandType.pause,
      'tiếp theo': VoiceCommandType.next, 'bài trước': VoiceCommandType.previous,
      'nhanh hơn': VoiceCommandType.faster, 'slower': VoiceCommandType.slower,
      'ẩn lời': VoiceCommandType.toggleLyrics, 'translate': VoiceCommandType.translate,
      'tam dung': VoiceCommandType.pause, 'tai tiep': VoiceCommandType.next,
    };
    for (final entry in samples.entries) {
      expect(parseVoiceCommand(entry.key)?.type, entry.value, reason: entry.key);
    }
  });

  test('unknown phrase does not trigger an action', () {
    expect(parseVoiceCommand('xin chao'), isNull);
  });
}
