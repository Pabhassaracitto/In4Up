// Audit v1.29.0 — điều hướng và công cụ nghe ở Đọc / Nghe / Nói.
//
// PSRC-246 đã được nối trong shell; các kiểm tra này khóa lối về thư viện,
// việc bung lời sau khi tạo thành công, và phân biệt công cụ theo ngữ cảnh để
// tránh dọn nhầm TTS đọc tài liệu hoặc Shadowing.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/language/generated_priority_native_pack.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('Đọc — đường về thư viện khác với mở nguồn hiện tại', () {
    test('lối về nằm trong panel công cụ, nguồn khác vẫn mở theo ngữ cảnh', () {
      final dock = _read('lib/screens/read_mode/widgets/read_bottom_dock.dart');
      final screen = _read('lib/screens/read_mode/read_mode_screen.dart');
      final shell = _read('lib/screens/main_shell.dart');

      expect(dock, contains("uiText('Về thư viện đọc')"));
      expect(dock, contains("uiText('Mở nguồn')"));
      expect(dock, contains('if (onOpenReadLibrary != null)'));
      expect(dock, contains('else if (onOpenSource != null)'));
      expect(screen, contains('_source == ReadContentSource.document'));
      expect(shell, contains('ReadLibraryScreen(showBackButton: true)'));
      // Không có lối vào mới đè lên nội dung đọc; chỉ chip trong dock bung.
      expect(dock, contains("Key('read-dock-open-library')"));
    });

    test('nhãn mới có đủ 8 locale ưu tiên và khớp file sinh', () {
      const locales = ['en', 'hi', 'zh', 'zh_TW', 'si', 'my', 'th', 'ja'];
      final sourcePack = (jsonDecode(
        File('tool/priority_native_pack.json').readAsStringSync(),
      ) as Map<String, dynamic>)['Về thư viện đọc'] as Map<String, dynamic>;
      final generatedPack = generatedPriorityNativePack['Về thư viện đọc'];

      expect(sourcePack.keys.toSet(), containsAll(locales));
      expect(generatedPack?.keys.toSet(), containsAll(locales));
      for (final locale in locales) {
        expect(generatedPack![locale], sourcePack[locale], reason: locale);
      }
    });
  });

  group('Nghe — tạo lời thành công tự bung rèm tới trần khả dụng', () {
    test('signal thành công mở lời, bỏ trạng thái ẩn và yêu cầu chiều cao tối đa', () {
      final listen = _read('lib/screens/listen_mode/listen_mode_screen.dart');
      final success = listen.substring(
        listen.indexOf('void _handleLrcGenerated()'),
        listen.indexOf('void _showWaveformActionSheet'),
      );
      final layout = listen.substring(
        listen.indexOf('final maxH = (listenViewportH'),
        listen.indexOf('final compactCurtain ='),
      );
      final signal = listen.substring(
        listen.indexOf('void _onPlayerStateChange()'),
        listen.indexOf('void _togglePanel('),
      );

      expect(success, contains('_showLrcOnMain = true'));
      expect(success, contains('_lrcHiddenByUser = false'));
      expect(success, contains('_lrcHeight = double.maxFinite'));
      expect(success, contains('if (_aiSheetOpen) _closeAiSheet()'));
      expect(success, contains('if (_sheetOpen) _closeSheet()'));
      expect(layout, contains('.clamp(_lrcMinHeight, 650.0)'));
      expect(layout, contains('displayHeight > maxH'));
      expect(layout, contains('_lrcHeight = normalized'));
      expect(signal, contains('widget.player.lrcJustGenerated'));
      expect(signal, contains('widget.onLrcGenerated()'));
    });
  });

  group('Đọc / Nói — giữ công cụ riêng theo mục đích, không xóa nhầm', () {
    test('TTS đọc tài liệu và Shadowing audio mẫu là hai luồng khác nhau', () {
      final readAudio = _read('lib/screens/read_mode/widgets/smart_playback_bar.dart');
      final speak = _read('lib/features/shadowing/widgets/shadowing_widget.dart');

      // Đọc: tổng hợp văn bản / playback recipe, có preset Shadowing hữu ích
      // để luyện nghe-đọc ngay trong ngữ cảnh tài liệu đang mở.
      expect(readAudio, contains('PlaybackRecipe.shadowing'));
      expect(readAudio, contains('startReadPlayback'));
      // Nói: nghe mẫu là audio nguồn của câu đang chọn rồi ghi âm/đối chiếu;
      // không thay thế bằng TTS đọc văn bản của tab Đọc.
      expect(speak, contains('shadowing.speakSentence(index)'));
      expect(speak, contains('shadowing.startShadowing'));
      expect(speak, contains("label: const Text('Nghe mẫu')"));
    });

    test('phần tạo lời giữ mic trực tiếp với nhãn đúng, không mạo danh Shadowing', () {
      final listen = _read('lib/screens/listen_mode/listen_mode_screen.dart');
      expect(listen, contains("context.uiText(micOn ? 'Dừng mic' : 'Mic trực tiếp')"));
      expect(listen, contains('startConversation()'));
      expect(listen, isNot(contains("label: Text('Shadowing')")));
    });
  });
}
