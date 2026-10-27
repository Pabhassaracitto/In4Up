import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final understand =
      File('lib/screens/understand_mode/understand_workspace_screen.dart')
          .readAsStringSync();
  final understandHeader =
      File('lib/screens/understand_mode/widgets/understand_workspace_header.dart')
          .readAsStringSync();
  final read = File('lib/screens/read_mode/read_mode_screen.dart').readAsStringSync();
  final shell = File('lib/screens/main_shell.dart').readAsStringSync();
  final auth = File('lib/services/auth_service.dart').readAsStringSync();
  final colored =
      File('lib/screens/read_mode/widgets/colored_text_widget.dart')
          .readAsStringSync();
  final storage = File('lib/services/reader_display_settings.dart').readAsStringSync();
  final textProvider = File('lib/providers/text_provider.dart').readAsStringSync();

  test('Hiểu tools do người dùng gập/mở, không tự ẩn theo timer', () {
    expect(understand, isNot(contains('AutoHideInfoBanner')));
    expect(understand, contains('understand_tools_expanded_v1'));
    expect(understandHeader, contains('onToggleExpanded'));
  });

  test('Tab Nghe nhớ trạng thái công cụ; thư viện full ẩn chrome nguồn', () {
    expect(shell, contains('listen_workspace_tools_expanded_v1'));
    expect(shell, contains('listenLibraryFull'));
    expect(shell, contains('if (!listenLibraryFull)'));
  });

  test('Read full library ẩn header nguồn, nhưng giữ affordance Công cụ đọc', () {
    expect(shell, contains('readLibraryFull'));
    expect(shell, contains('if (!readLibraryFull)'));
    expect(read, contains("context.uiText('Công cụ đọc')"));
  });

  test('web sign-in dùng popup, không dùng redirect state/sessionStorage', () {
    expect(auth, contains('if (kIsWeb) return _signInWithGoogleWeb()'));
    expect(auth, contains('auth.signInWithPopup(provider)'));
  });

  test('từ đang chọn vẫn giữ màu grammar; tap nhanh phát âm và mở thông tin', () {
    expect(colored, contains('selected && grammarResolved == null'));
    expect(colored, contains('if (_range != null) _exitSelection(clearProvider: true)'));
    expect(colored, contains('_speak(index)'));
    expect(colored, contains('_openMiniPop(context, index)'));
  });

  test('mặc định Đọc là độ khó + chỉ màu chữ; nhãn mức độ có thể tắt', () {
    expect(textProvider, contains('ColorMode _colorMode = ColorMode.difficulty'));
    expect(storage, contains('WordColorStyle _wordColorStyle = WordColorStyle.textOnly'));
    expect(storage, contains('reader_show_color_mode_details'));
    expect(colored, contains('_colorModeDetailLabel(word, colorMode)'));
  });
}
