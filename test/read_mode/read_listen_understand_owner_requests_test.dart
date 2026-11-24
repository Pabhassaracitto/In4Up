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

  test('Sprint 1 UI compact — bỏ chồng thanh đáy, thống nhất MiniPlayer & bỏ prose thừa', () {
    final memoryScreen =
        File('lib/screens/memory_mode/memory_mode_screen.dart').readAsStringSync();
    final memoryTopBar =
        File('lib/screens/memory_mode/widgets/memory_top_bar.dart').readAsStringSync();
    final homeScreen =
        File('lib/screens/home/home_screen.dart').readAsStringSync();
    final writeScreen =
        File('lib/screens/read_mode/write_studio_screen.dart').readAsStringSync();
    final listenScreen =
        File('lib/screens/listen_mode/listen_mode_screen.dart').readAsStringSync();
    final shellSettings =
        File('lib/screens/settings/shell_ui_settings_screen.dart').readAsStringSync();

    // Không chồng MemoryBottomBar lên trên BottomNav của MainShell;
    // 3 chế độ ôn (SRS / Nhồi / Khó) nằm gọn trong MemoryTopBar.
    expect(memoryScreen, isNot(contains('MemoryBottomBar')));
    expect(memoryTopBar, contains('ReviewMode.spaced'));
    expect(memoryTopBar, contains('ReviewMode.cram'));
    expect(memoryTopBar, contains('ReviewMode.difficult'));

    // Thống nhất 1 MiniPlayer duy nhất ở MainShell, bỏ _GlobalMiniPlayer riêng ở Home.
    expect(homeScreen, isNot(contains('_GlobalMiniPlayer')));
    expect(shell, contains('if (_currentTab == _PrimaryTab.listen && _listenModeIndex == 0)'));

    // Tab Hiểu không render chồng 2 header (MainShell + UnderstandWorkspaceHeader).
    expect(shell, contains('showWorkspaceHeader: false'));
    expect(understandHeader, isNot(contains('Comprehension Workspace')));

    // Bỏ các câu hướng dẫn văn xuôi chiếm diện tích cố định.
    expect(listenScreen, isNot(contains('Kéo để')));
    expect(writeScreen, isNot(contains('_TipCard(')));
    expect(shellSettings, isNot(contains('Ưu tiên cho người dùng nâng cao')));
  });

  test('Sprint 2 UI — Calm Bento Home, thanh bài tập Viết 1 hàng & Quick Actions đóng tức thì', () {
    final homeScreen =
        File('lib/screens/home/home_screen.dart').readAsStringSync();
    final writeScreen =
        File('lib/screens/read_mode/write_studio_screen.dart').readAsStringSync();
    final toolsOverlay =
        File('lib/screens/tools/tools_overlay_v2.dart').readAsStringSync();

    // Home bỏ HebbianInputCard trùng Mic với FAB, giữ I4U AI Chat + Studio submodes.
    expect(homeScreen, isNot(contains('HebbianInputCard(')));
    expect(homeScreen, contains("'I4U AI Chat'"));
    expect(homeScreen, contains('_StudioPillTile('));

    // WriteStudio dùng thanh cuộn ngang có icon thay cho lưới Wrap 2 cột.
    expect(writeScreen, isNot(contains('Widget _buildLineNavigator')));
    expect(writeScreen, contains('final IconData icon;'));

    // ToolsOverlayV2 dùng PopScope + tìm kiếm + đóng nhanh không chờ stagger.
    expect(toolsOverlay, isNot(contains('WillPopScope')));
    expect(toolsOverlay, contains('PopScope('));
    expect(toolsOverlay, contains('_buildSearchBar()'));

    // MainShell dùng vector _titleIcon thay cho chuỗi emoji tiêu đề.
    expect(shell, contains('IconData? get _titleIcon'));
    expect(shell, isNot(contains("'🎧 Nghe'")));
  });

  test('Read full library ẩn header nguồn, nhưng giữ affordance Công cụ đọc', () {
    expect(shell, contains('readLibraryFull'));
    expect(shell, contains('if (!readLibraryFull && _readModeIndex == 0)'));
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
