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
    expect(toolsOverlay, isNot(contains('WillPopScope(')));
    expect(toolsOverlay, contains('PopScope('));
    expect(toolsOverlay, contains('_buildSearchBar()'));

    // MainShell dùng vector _titleIcon thay cho chuỗi emoji tiêu đề.
    expect(shell, contains('IconData? get _titleIcon'));
    expect(shell, isNot(contains("'🎧 Nghe'")));
  });

  test('Sprint 3 Design System, >=11sp typography, >=44pt touch targets & non-destructive bubbles', () {
    final mainDart = File('lib/main.dart').readAsStringSync();
    final appColors = File('lib/core/theme/app_colors.dart').readAsStringSync();
    final appTypography =
        File('lib/core/theme/app_typography.dart').readAsStringSync();
    final appSpacing =
        File('lib/core/theme/app_spacing.dart').readAsStringSync();
    final collapsibleBar =
        File('lib/widgets/collapsible_action_bar.dart').readAsStringSync();
    final actionButton = File(
            'lib/widgets/workspace_navigation/workspace_action_button.dart')
        .readAsStringSync();
    final wordlistBubble = File(
            'lib/screens/tools/word_list/wordlist_bubble.dart')
        .readAsStringSync();
    final liveCaptionBubble =
        File('lib/features/cabin/widgets/live_caption_bubble.dart')
            .readAsStringSync();
    final miniPlayer =
        File('lib/screens/listen_mode/widgets/mini_player.dart')
            .readAsStringSync();
    final wordListScreen =
        File('lib/screens/tools/word_list/word_list_screen.dart')
            .readAsStringSync();

    // Design System tokens wired to ThemeData.
    expect(mainDart, contains('AppTheme.dark()'));
    expect(appColors, contains('bgBase'));
    expect(appColors, contains('surfaceElevated'));
    expect(appColors, contains('surfaceModal'));
    expect(appTypography, contains('minReadableSize = 11.0'));
    expect(appSpacing, contains('minTouchTarget = 44.0'));

    // >= 44pt touch targets on shared toolbars & action buttons.
    expect(collapsibleBar, contains('AppSpacing.minTouchTarget'));
    expect(actionButton, contains('AppSpacing.minTouchTarget'));

    // WordlistBubble: body tap expands/collapses; explicit 44pt stop button stops playback.
    expect(wordlistBubble, contains('_handleBodyTap'));
    expect(wordlistBubble, contains('wordlistBubbleStopButtonKey'));
    expect(wordlistBubble, contains('AppSpacing.minTouchTarget'));
    expect(wordlistBubble, isNot(contains('fontSize: 10')));

    // LiveCaptionBubble: localized fallback, >=11sp typography, 44pt close target.
    expect(liveCaptionBubble, contains("context.uiText('Đang nghe cabin...')"));
    expect(liveCaptionBubble, contains('AppSpacing.minTouchTarget'));
    expect(liveCaptionBubble, isNot(contains('fontSize: 9')));

    // MiniPlayer & WordListScreen: cleaned i18n leaks & micro-fonts.
    expect(miniPlayer, isNot(contains("'Select Mode'")));
    expect(miniPlayer, isNot(contains("'Phat Phap'")));
    expect(miniPlayer, isNot(contains('fontSize: 9')));
    expect(wordListScreen, isNot(contains("_menuItem('settings', Icons.tune, 'Options')")));
    expect(wordListScreen, isNot(contains('fontSize: 9')));
  });

  test('Sprint 4 repo-wide >=11sp floor, >=40pt icon targets, SafeArea sheets & localized tooltips/hints', () {
    final fontRe = RegExp(r'fontSize:\s*([0-9]+(?:\.[0-9]+)?)\b');
    final boxRe = RegExp(
      r'BoxConstraints\(\s*minWidth:\s*(\d+)\s*,\s*minHeight:\s*(\d+)\s*\)',
    );
    final viRe = RegExp(
      r'[ăâđêôơưáàảãạắằẳẵặấầẩẫậéèẻẽẹếềểễệíìỉĩịóòỏõọốồổỗộớờởỡợúùủũụứừửữựýỳỷỹỵĂÂĐÊÔƠƯÁÀẢÃẠ]',
    );

    final subElevenFonts = <String>[];
    final tinyBoxes = <String>[];
    final unwrappedProps = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final content = entity.readAsStringSync();

      for (final m in fontRe.allMatches(content)) {
        final v = double.parse(m.group(1)!);
        if (v < 11.0) {
          subElevenFonts.add('${entity.path}: ${m.group(0)}');
        }
      }

      for (final m in boxRe.allMatches(content)) {
        final w = int.parse(m.group(1)!);
        final h = int.parse(m.group(2)!);
        if ((w < 40 || h < 40) && !(w <= 22 && h <= 22)) {
          tinyBoxes.add('${entity.path}: ${w}x$h');
        }
      }

      for (final prop in const ['tooltip', 'labelText', 'hintText']) {
        final propRe = RegExp("\\b$prop:\\s*(['\"][^'\"\\n]+['\"])");
        for (final m in propRe.allMatches(content)) {
          if (viRe.hasMatch(m.group(1)!)) {
            unwrappedProps.add('${entity.path}: $prop: ${m.group(1)}');
          }
        }
      }
    }

    expect(subElevenFonts, isEmpty,
        reason: 'Repo-wide typography floor must stay >= 11sp');
    expect(tinyBoxes, isEmpty,
        reason: 'Interactive BoxConstraints must not shrink below 40pt');
    expect(unwrappedProps, isEmpty,
        reason: 'Vietnamese tooltip/labelText/hintText must use context.uiText');

    // AppColors surface tokens wired across MainShell, HomeScreen, Read & Understand.
    final homeScreen = File('lib/screens/home/home_screen.dart').readAsStringSync();
    final understandScreen =
        File('lib/screens/understand_mode/understand_mode_screen.dart')
            .readAsStringSync();
    expect(shell, contains('AppColors.bgBase'));
    expect(shell, contains('AppColors.surfaceElevated'));
    expect(homeScreen, contains('AppColors.bgBase'));
    expect(understandScreen, contains('AppColors.surfaceElevated'));
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
