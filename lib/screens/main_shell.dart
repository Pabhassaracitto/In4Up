import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in4up/core/language/localized_material.dart';
import 'package:provider/provider.dart';
import 'package:in4up/l10n/app_localizations.dart';

import '../features/learn_by_heart/screens/learn_by_heart_hub_screen.dart';
import '../features/cabin/screens/live_cabin_screen.dart';
import '../features/dictionary/widgets/dict_manager_screen.dart';
import '../features/video/widgets/video_player_screen.dart';
import '../features/video/widgets/video_library_screen.dart';
import '../core/navigation/shell_navigation_request.dart';
import '../core/responsive/app_responsive.dart';
import '../features/cabin/widgets/live_caption_bubble.dart';
import '../features/pdf_reader/pdf_reader_screen.dart';
import '../features/web_reader/web_reader_screen.dart';
import '../features/tipitaka/tipitaka.dart';
import '../features/understand_ai/understand_ai_context.dart';
import '../features/youtube/youtube_sheet.dart';
import '../models/read_content_source.dart';
import '../models/shell_content_order.dart';
import '../providers/player_provider.dart';
import '../providers/text_provider.dart';
import '../providers/vocabulary_bridge.dart';
import '../providers/vocabulary_provider.dart';
import '../services/battery_optimization_service.dart';
import '../services/storage_service.dart';
import 'ai_chat/ai_chat_screen.dart';
import 'home/home_screen.dart';
import 'listen_mode/listen_mode_screen.dart';
import 'listen_mode/speak_mode_screen.dart';
import 'listen_mode/widgets/audio_library_drawer.dart';
import 'listen_mode/widgets/mini_player.dart';
import 'memory_mode/remember_workspace_screen.dart';
import 'read_mode/read_mode_screen.dart';
import 'read_mode/services/read_text_action_runner.dart';
import 'read_mode/widgets/read_source_picker.dart';
import 'read_mode/widgets/read_text_action_hooks.dart';
import 'read_mode/write_studio_screen.dart';
import 'settings/shell_ui_settings_screen.dart';
import 'settings/stt_model_settings_screen.dart';
import 'text_library_drawer.dart';
import 'tools/map_tab.dart';
import 'tools/review_tab.dart';
import 'tools/stats_tab.dart';
import 'tools/tools_overlay_v2.dart' as tools;
import 'tools/triangle_tab.dart';
import 'tools/venn_tab.dart';
import 'tools/sound_list/sound_list_screen.dart';
import 'tools/word_list/stats_dashboard.dart';
import 'tools/word_list/timeline_view.dart';
import 'tools/word_list/word_list_screen.dart';
import 'tools/word_list/wordlist_bubble.dart';
import '../widgets/workspace_navigation/workspace_navigation.dart';
import 'tools/youglish/youglish_screen.dart';
import 'understand_mode/services/understand_ai_coach_launcher.dart';
import 'understand_mode/understand_workspace_screen.dart';


enum _PrimaryTab { home, listen, read, understand, remember }

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final StorageService _storage = StorageService();

  // ===== SHELL-GEAR-001: logging seam (CHỈ debug — không đổi hành vi) =====
  // Owner long-press nút gear → sọc vàng-đen (phải + đáy) + assertion
  // overlay.dart. Chưa tái hiện được ngoài máy owner → seam này để logcat
  // (`adb logcat | grep SHELL-GEAR-001`) chứng minh TRÌNH TỰ: cầm giữ nút
  // nào → mode/tab/route đổi giữa chừng như thế nào → đối chứng hypothesis
  // orphaned Ink TRƯỚC khi thay InkWell bằng highlight tự vẽ (theo lane A4:
  // chưa có log xác nhận thì không thay InkWell).
  void _shellGearLog(String event) {
    if (kDebugMode) debugPrint('[SHELL-GEAR-001] $event');
  }

  _PrimaryTab _currentTab = _PrimaryTab.home;
  int _listenModeIndex = 0;
  int _readModeIndex = 0;
  ShellContentOrder _contentOrder = ShellContentOrder.listenRead;
  ReadContentSource _readSource = ReadContentSource.document;
  ListenContentSource _listenSource = ListenContentSource.audioLibrary;
  UnderstandWorkspaceMode _understandMode = UnderstandWorkspaceMode.sync;

  bool _compactModeSwitch = false;
  bool _autoHideModeSwitch = false;
  bool _enableLongPressModeSwitch = false;
  bool _rememberLastSubMode = true;
  bool _modeSwitchExpanded = false;
  Timer? _modeSwitchHideTimer;
  Timer? _shellHintTimer;

  @override
  void initState() {
    super.initState();
    _loadShellUiSettings();
    ShellNavigationRequest.pending.addListener(_onShellNavigationRequest);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vocabProvider = context.read<VocabularyProvider>();
      VocabularyBridge.init(vocabProvider);
      _scheduleShellHintIfNeeded();
      // BATTERY-OPT-001: xin miễn tối ưu pin (models STT/AI chạy ngầm).
      unawaited(BatteryOptimizationService.maybeRequestOnStartup(context));
    });
  }

  @override
  void dispose() {
    ShellNavigationRequest.pending.removeListener(_onShellNavigationRequest);
    _modeSwitchHideTimer?.cancel();
    _shellHintTimer?.cancel();
    super.dispose();
  }

  bool get _isHome => _currentTab == _PrimaryTab.home;
  bool get _listenFirst => _contentOrder.isListenFirst;
  bool get _showListenModes => _currentTab == _PrimaryTab.listen;
  bool get _showReadModes => _currentTab == _PrimaryTab.read;
  bool get _hasSecondaryModes => _showListenModes || _showReadModes;
  bool get _showModeChip =>
      _hasSecondaryModes && (_compactModeSwitch || _autoHideModeSwitch);
  bool get _showModeSwitch {
    if (!_hasSecondaryModes) return false;
    if (!_compactModeSwitch && !_autoHideModeSwitch) return true;
    return _modeSwitchExpanded;
  }

  String get _currentModeLabel {
    if (_showListenModes) {
      if (_listenModeIndex == 0) return 'Nghe';
      if (_listenModeIndex == 1) return 'Nói';
      return 'Xem';
    }
    if (_showReadModes) {
      return _readModeIndex == 0 ? 'Đọc' : 'Viết';
    }
    return '';
  }

  String get _alternateModeLabel {
    if (_showListenModes) {
      if (_listenModeIndex == 0) return 'Nói';
      if (_listenModeIndex == 1) return 'Xem';
      return 'Nghe';
    }
    if (_showReadModes) {
      return _readModeIndex == 0 ? 'Viết' : 'Đọc';
    }
    return '';
  }

  void _loadShellUiSettings({bool preserveWorkspaceState = false}) {
    _compactModeSwitch = _storage.getShellCompactMode();
    _autoHideModeSwitch = _storage.getShellAutoHideModeSwitch();
    _enableLongPressModeSwitch = _storage.getShellLongPressModeSwitch();
    _rememberLastSubMode = _storage.getShellRememberLastSubMode();
    _contentOrder = _storage.getShellContentOrder();

    if (!preserveWorkspaceState) {
      _listenModeIndex =
          ((_rememberLastSubMode ? _storage.getShellListenSubMode() : 0)
                  .clamp(0, 2))
              .toInt();
      _readModeIndex =
          ((_rememberLastSubMode ? _storage.getShellReadSubMode() : 0)
                  .clamp(0, 1))
              .toInt();
      _readSource = _rememberLastSubMode
          ? _storage.getReadContentSource()
          : _storage.getDefaultReadContentSource();
      _listenSource = _rememberLastSubMode
          ? _storage.getListenContentSource()
          : _storage.getDefaultListenContentSource();
      _understandMode = _rememberLastSubMode
          ? _storage.getUnderstandWorkspaceMode()
          : _storage.getDefaultUnderstandWorkspaceMode();
    } else {
      _listenModeIndex = _listenModeIndex.clamp(0, 2).toInt();
      _readModeIndex = _readModeIndex.clamp(0, 1).toInt();
    }

    _syncModeSwitchVisibility();
  }

  void _syncModeSwitchVisibility() {
    _modeSwitchHideTimer?.cancel();
    if (!_hasSecondaryModes) {
      _modeSwitchExpanded = false;
      return;
    }

    if (_compactModeSwitch) {
      _modeSwitchExpanded = false;
      return;
    }

    if (_autoHideModeSwitch) {
      _modeSwitchExpanded = true;
      _scheduleModeSwitchAutoHide();
      return;
    }

    _modeSwitchExpanded = true;
  }

  void _scheduleModeSwitchAutoHide() {
    _modeSwitchHideTimer?.cancel();
    if (!_autoHideModeSwitch) return;
    _modeSwitchHideTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted || !_hasSecondaryModes) return;
      setState(() => _modeSwitchExpanded = false);
    });
  }

  void _scheduleShellHintIfNeeded() {
    _shellHintTimer?.cancel();
    if (!_hasSecondaryModes || !mounted) return;

    final shouldShowLongPressHint =
        _enableLongPressModeSwitch && !_storage.getShellLongPressHintSeen();
    final shouldShowModeChipHint =
        (_compactModeSwitch || _autoHideModeSwitch) &&
            !_storage.getShellModeChipHintSeen();

    if (!shouldShowLongPressHint && !shouldShowModeChipHint) return;

    _shellHintTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted || !_hasSecondaryModes) return;

      final parts = <String>[];
      if (shouldShowLongPressHint) {
        parts.add(_showListenModes
            ? 'Giữ tab Nghe để vào Nói.'
            : 'Giữ tab Đọc để vào Viết.');
      }
      if (shouldShowModeChipHint) {
        parts.add(
            'Chạm chip mode dưới tiêu đề để hiện hoặc ẩn nhanh thanh mode.');
      }

      if (parts.isEmpty) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(parts.join(' ')),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );

      if (shouldShowLongPressHint) {
        _storage.saveShellLongPressHintSeen(true);
      }
      if (shouldShowModeChipHint) {
        _storage.saveShellModeChipHintSeen(true);
      }
    });
  }

  void _toggleCurrentSecondaryMode() {
    // SHELL-GEAR-001: log trình tự long-press đổi mode (ứng viên trùng với
    // long-press gear → swap screen giữa ink splash).
    _shellGearLog('title-long-press: toggle secondary mode '
        '(${_showListenModes ? 'listen $_listenModeIndex→${(_listenModeIndex + 1) % 3}' : 'read $_readModeIndex→${_readModeIndex == 0 ? 1 : 0}'})');
    HapticFeedback.selectionClick();
    if (_showListenModes) {
      _setListenMode((_listenModeIndex + 1) % 3); // Cycle: 0→1→2→0
    } else if (_showReadModes) {
      _setReadMode(_readModeIndex == 0 ? 1 : 0);
    }
  }

  void _handleModeChipTap() {
    if (!_hasSecondaryModes) return;
    if (!_compactModeSwitch && !_autoHideModeSwitch) return;
    setState(() {
      _modeSwitchExpanded = !_modeSwitchExpanded;
    });
    if (_modeSwitchExpanded) {
      _scheduleModeSwitchAutoHide();
    } else {
      _modeSwitchHideTimer?.cancel();
    }
  }

  Future<void> _openShellUiSettings() async {
    // SHELL-GEAR-001: ứng viên gear #1 (drawer "Giao diện shell",
    // Icons.tune_rounded) — log cầm giữ/tap gear + route push + drawer close
    // (surface đổi giữa splash là kịch bản orphaned Ink chính).
    _shellGearLog('drawer-gear: open ShellUiSettings (route push + drawer close)');
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ShellUiSettingsScreen()),
    );
    if (!mounted) return;
    setState(() {
      _loadShellUiSettings(preserveWorkspaceState: true);
    });
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _scheduleShellHintIfNeeded());
  }

  Color get _currentAccent {
    switch (_currentTab) {
      case _PrimaryTab.home:
        return Colors.white;
      case _PrimaryTab.listen:
        if (_listenModeIndex == 0) return const Color(0xFF6C63FF);
        if (_listenModeIndex == 1) return const Color(0xFFB388FF);
        return const Color(0xFFFFB300); // Xem = amber
      case _PrimaryTab.read:
        return _readModeIndex == 0
            ? const Color(0xFF2196F3)
            : const Color(0xFF26C6DA);
      case _PrimaryTab.understand:
        return const Color(0xFFFFB300);
      case _PrimaryTab.remember:
        return const Color(0xFF4CAF50);
    }
  }

  String get _titleText {
    switch (_currentTab) {
      case _PrimaryTab.home:
        return 'In4Up';
      case _PrimaryTab.listen:
        if (_listenModeIndex == 0) return '🎧 Nghe';
        if (_listenModeIndex == 1) return '🎙️ Nói';
        return '📹 Xem';
      case _PrimaryTab.read:
        return _readModeIndex == 0 ? '📖 Đọc' : '✍️ Viết';
      case _PrimaryTab.understand:
        return '💡 Hiểu';
      case _PrimaryTab.remember:
        return '🧠 Nhớ';
    }
  }

  bool get _shouldShowShellMiniPlayer {
    if (_currentTab == _PrimaryTab.home) return false;
    if (_currentTab == _PrimaryTab.listen) return false;
    if (_currentTab == _PrimaryTab.read) return false;
    if (_currentTab == _PrimaryTab.understand) return false;
    return true;
  }

  IconData get _leadingIcon {
    if (_currentTab == _PrimaryTab.home) return Icons.smart_toy_outlined;
    if (_currentTab == _PrimaryTab.remember) return Icons.format_list_bulleted;
    return _leftLibraryIcon;
  }

  Color get _leadingColor {
    if (_currentTab == _PrimaryTab.home) return const Color(0xFFFF9800);
    if (_currentTab == _PrimaryTab.remember) return const Color(0xFF66BB6A);
    return _leftLibraryIsAudio
        ? const Color(0xFF6C63FF)
        : const Color(0xFF2196F3);
  }

  String get _leadingTooltip {
    if (_currentTab == _PrimaryTab.home) return 'Quản lý Model AI';
    if (_currentTab == _PrimaryTab.remember) return 'Danh sách từ';
    return _leftLibraryTooltip;
  }

  void _setPrimaryTab(_PrimaryTab tab) {
    if (_currentTab == tab) {
      if ((tab == _PrimaryTab.listen || tab == _PrimaryTab.read) &&
          (_compactModeSwitch || _autoHideModeSwitch)) {
        _handleModeChipTap();
      }
      return;
    }

    // SHELL-GEAR-001: log swap surface (đối chứng orphaned Ink).
    _shellGearLog('set-tab: ${_currentTab.name}→${tab.name}');
    setState(() {
      _currentTab = tab;
      if (!_rememberLastSubMode) {
        if (tab == _PrimaryTab.listen) {
          _listenModeIndex = 0;
          _listenSource = _storage.getDefaultListenContentSource();
          _storage.saveShellListenSubMode(0);
        } else if (tab == _PrimaryTab.read) {
          _readModeIndex = 0;
          _readSource = _storage.getDefaultReadContentSource();
          _storage.saveShellReadSubMode(0);
        } else if (tab == _PrimaryTab.understand) {
          _understandMode = _storage.getDefaultUnderstandWorkspaceMode();
          _storage.saveUnderstandWorkspaceMode(_understandMode);
        }
      }
      _syncModeSwitchVisibility();
    });
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _scheduleShellHintIfNeeded());
  }

  void _setListenMode(int index) {
    // SHELL-GEAR-001: log swap screen Nghe/Nói/Xem (IndexedStack index đổi).
    _shellGearLog('set-listen-mode: $_listenModeIndex→$index (surface swap)');
    setState(() {
      _currentTab = _PrimaryTab.listen;
      _listenModeIndex = index;
      _storage.saveShellListenSubMode(index);
      _syncModeSwitchVisibility();
    });
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _scheduleShellHintIfNeeded());
  }

  /// CABIN-SAVE-001: màn phía trên (Cabin) yêu cầu mở Tab Đọc.
  void _onShellNavigationRequest() {
    final target = ShellNavigationRequest.pending.value;
    if (target == null || !mounted) return;
    ShellNavigationRequest.pending.value = null;
    switch (target) {
      case ShellNavigationTarget.read:
        _setReadMode(0);
    }
  }

  void _setReadMode(int index) {
    // SHELL-GEAR-001: log swap screen Đọc/Viết.
    _shellGearLog('set-read-mode: $_readModeIndex→$index (surface swap)');
    setState(() {
      _currentTab = _PrimaryTab.read;
      _readModeIndex = index;
      _storage.saveShellReadSubMode(index);
      _syncModeSwitchVisibility();
    });
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _scheduleShellHintIfNeeded());
  }

  void _setReadSource(ReadContentSource source, {bool openSource = false}) {
    setState(() {
      _currentTab = _PrimaryTab.read;
      _readSource = source;
      _storage.saveReadContentSource(source);
      _syncModeSwitchVisibility();
    });
    if (openSource) _openReadSource(source);
  }

  void _openReadSource(ReadContentSource source) {
    switch (source) {
      case ReadContentSource.document:
        _openTextLibrary();
        return;
      case ReadContentSource.web:
        unawaited(_handleTool('web_reader'));
        return;
      case ReadContentSource.tipitaka:
        unawaited(_handleTool('tipitaka'));
        return;
    }
  }

  void _setListenSource(
    ListenContentSource source, {
    bool openSource = false,
  }) {
    setState(() {
      _currentTab = _PrimaryTab.listen;
      _listenSource = source;
      _storage.saveListenContentSource(source);
      _syncModeSwitchVisibility();
    });
    if (openSource) _openListenSource(source);
  }

  void _openListenSource(ListenContentSource source) {
    switch (source) {
      case ListenContentSource.audioLibrary:
        _openAudioLibrary();
        return;
      case ListenContentSource.youtube:
        unawaited(_handleTool('youtube_downloader'));
        return;
      case ListenContentSource.videoLibrary:
        _setListenMode(2);
        unawaited(_handleTool('video_library'));
        return;
    }
  }

  void _setUnderstandMode(UnderstandWorkspaceMode mode) {
    if (_understandMode == mode && _currentTab == _PrimaryTab.understand) {
      return;
    }
    setState(() {
      _currentTab = _PrimaryTab.understand;
      _understandMode = mode;
      _storage.saveUnderstandWorkspaceMode(mode);
      _syncModeSwitchVisibility();
    });
  }

  UnderstandLearningMode get _understandLearningMode {
    return _understandMode == UnderstandWorkspaceMode.shadowing
        ? UnderstandLearningMode.shadowing
        : UnderstandLearningMode.sync;
  }

  void _handleUnderstandModeChanged(UnderstandLearningMode mode) {
    final next = mode == UnderstandLearningMode.shadowing
        ? UnderstandWorkspaceMode.shadowing
        : UnderstandWorkspaceMode.sync;
    if (_understandMode == next) return;
    _understandMode = next;
    _storage.saveUnderstandWorkspaceMode(next);
  }

  Future<void> _openQuickActions() async {
    // SHELL-GEAR-001: rule-out — nút bolt mở tools overlay (OverlayEntry).
    _shellGearLog('quick-actions: open tools overlay');
    final toolId = await tools.showToolsOverlayV2(
      context,
      tools: _buildQuickActions(context),
    );

    if (!mounted || toolId == null) return;
    await _storage.recordQuickActionUsage(toolId);
    await _handleTool(toolId);
  }

  List<tools.ToolItem> _buildQuickActions(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final toolById = <String, tools.ToolItem>{
      'shell_ui_settings': tools.ToolItem(
        id: 'shell_ui_settings',
        title: context.uiText('Giao diện shell'),
        subtitle: context.uiText('Mặc định workspace, nguồn và mode'),
        icon: Icons.tune_rounded,
        color: const Color(0xFF90CAF9),
      ),
      'live_cabin': tools.ToolItem(
        id: 'live_cabin',
        title: context.uiText('Dịch Live Cabin'),
        subtitle: context.uiText('Dịch cabin song song trực tiếp từ giọng nói'),
        icon: Icons.interpreter_mode_rounded,
        color: const Color(0xFF00E676),
      ),
      'youtube_downloader': tools.ToolItem(
        id: 'youtube_downloader',
        title: l10n.youtube,
        subtitle: l10n.youtubeSubtitle,
        icon: Icons.play_circle_filled,
        color: const Color(0xFFFF0000),
      ),
      'web_reader': tools.ToolItem(
        id: 'web_reader',
        title: l10n.webReader,
        subtitle: l10n.webReaderSubtitle,
        icon: Icons.language,
        color: const Color(0xFF26A69A),
      ),
      'pdf_reader': tools.ToolItem(
        id: 'pdf_reader',
        title: l10n.pdfReader,
        subtitle: l10n.pdfReaderSubtitle,
        icon: Icons.picture_as_pdf,
        color: const Color(0xFFEF5350),
      ),
      'tipitaka': tools.ToolItem(
        id: 'tipitaka',
        title: context.uiText('Tipiṭaka'),
        subtitle: context.uiText('Đọc Tam Tạng, tra cứu kinh điển'),
        icon: Icons.menu_book_rounded,
        color: const Color(0xFFFF9800),
      ),
      'video_library': tools.ToolItem(
        id: 'video_library',
        title: context.uiText('Thư viện video'),
        subtitle: context.uiText('Quản lý & phát video học tập'),
        icon: Icons.video_library_outlined,
        color: const Color(0xFFE91E63),
      ),
      'video_player': tools.ToolItem(
        id: 'video_player',
        title: context.uiText('Video'),
        subtitle: context.uiText('Xem video local + phụ đề'),
        icon: Icons.videocam,
        color: const Color(0xFFFFB300),
      ),
      'dict_manager': tools.ToolItem(
        id: 'dict_manager',
        title: context.uiText('Từ điển MDX'),
        subtitle: context.uiText('Quản lý & tra cứu từ điển MDX'),
        icon: Icons.auto_stories,
        color: const Color(0xFF7E57C2),
      ),
      'dictionary': tools.ToolItem(
        id: 'dictionary',
        title: context.uiText('Từ điển'),
        subtitle: context.uiText('Quản lý từ điển MDX đa ngữ'),
        icon: Icons.auto_stories_rounded,
        color: const Color(0xFF2196F3),
      ),
      'speak_mode': tools.ToolItem(
        id: 'speak_mode',
        title: context.uiText('Nói'),
        subtitle: context.uiText('Luyện shadowing và phát âm'),
        icon: Icons.mic_rounded,
        color: const Color(0xFFB388FF),
      ),
      'write_mode': tools.ToolItem(
        id: 'write_mode',
        title: context.uiText('Viết'),
        subtitle: context.uiText('Bài tập chép và recall theo nội dung'),
        icon: Icons.edit_square,
        color: const Color(0xFF26C6DA),
      ),
      'understand_tab': tools.ToolItem(
        id: 'understand_tab',
        title: context.uiText('Hiểu'),
        subtitle: context.uiText('Không gian đồng bộ audio và text'),
        icon: Icons.lightbulb,
        color: const Color(0xFFFFB300),
      ),
      'understand_ai_coach': tools.ToolItem(
        id: 'understand_ai_coach',
        title: context.uiText('Hỏi AI'),
        subtitle: context.uiText('Trợ lý hiểu bài theo Audio + Text hiện tại'),
        icon: Icons.psychology_outlined,
        color: const Color(0xFF7DD3FC),
      ),
      'youglish': tools.ToolItem(
        id: 'youglish',
        title: l10n.youglish,
        subtitle: l10n.youglishSubtitle,
        icon: Icons.record_voice_over,
        color: const Color(0xFF00BCD4),
      ),
      'learn_by_heart': tools.ToolItem(
        id: 'learn_by_heart',
        title: context.uiText('Thuộc lòng'),
        subtitle: context.uiText('Kinh Pháp Cú, kinh tụng & đoạn kinh ý nghĩa'),
        icon: Icons.auto_stories_rounded,
        color: const Color(0xFF4CAF50),
      ),
      'review': tools.ToolItem(
        id: 'review',
        title: l10n.review,
        subtitle: l10n.reviewSubtitle,
        icon: Icons.school,
        color: const Color(0xFF66BB6A),
      ),
      'word_list': tools.ToolItem(
        id: 'word_list',
        title: l10n.wordList,
        subtitle: l10n.wordListSubtitle,
        icon: Icons.format_list_bulleted,
        color: const Color(0xFF6C63FF),
      ),
      'sound_list': tools.ToolItem(
        id: 'sound_list',
        title: context.uiText('Âm mục'),
        subtitle: context.uiText('Điểm, đoạn & mục lục âm thanh'),
        icon: Icons.menu_book_outlined,
        color: const Color(0xFF26C6DA),
      ),
      'timeline': tools.ToolItem(
        id: 'timeline',
        title: l10n.timeline,
        subtitle: l10n.timelineSubtitle,
        icon: Icons.timeline,
        color: const Color(0xFF9C27B0),
      ),
      'wordlist_stats': tools.ToolItem(
        id: 'wordlist_stats',
        title: l10n.wordListStats,
        subtitle: l10n.wordListStatsSubtitle,
        icon: Icons.analytics_outlined,
        color: const Color(0xFF42A5F5),
      ),
      'stats': tools.ToolItem(
        id: 'stats',
        title: l10n.overview,
        subtitle: l10n.overviewSubtitle,
        icon: Icons.bar_chart_rounded,
        color: const Color(0xFF42A5F5),
      ),
      'word_map': tools.ToolItem(
        id: 'word_map',
        title: l10n.wordMap,
        subtitle: l10n.wordMapSubtitle,
        icon: Icons.map_outlined,
        color: const Color(0xFF26C6DA),
      ),
      'triangle': tools.ToolItem(
        id: 'triangle',
        title: l10n.triangle,
        subtitle: l10n.triangleSubtitle,
        icon: Icons.change_history_rounded,
        color: const Color(0xFFFFA726),
      ),
      'venn': tools.ToolItem(
        id: 'venn',
        title: l10n.vennDiagram,
        subtitle: l10n.vennDiagramSubtitle,
        icon: Icons.hub_outlined,
        color: const Color(0xFFAB47BC),
      ),
    };

    List<tools.ToolItem> take(List<String> ids) => [
          for (final id in ids)
            if (toolById[id] != null) toolById[id]!,
        ];

    final openContent = switch (_currentTab) {
      _PrimaryTab.home => take([
          'shell_ui_settings',
          'tipitaka',
          'youtube_downloader',
          'web_reader',
          'pdf_reader',
          'video_player',
          'video_library',
          'dictionary',
          'dict_manager',
        ]),
      _PrimaryTab.listen => take([
          'youtube_downloader',
          'video_library',
          'pdf_reader',
          'shell_ui_settings',
        ]),
      _PrimaryTab.read => take([
          'web_reader',
          'pdf_reader',
          'tipitaka',
          'dict_manager',
          'shell_ui_settings',
        ]),
      _PrimaryTab.understand => take([
          'pdf_reader',
          'web_reader',
          'youtube_downloader',
          'shell_ui_settings',
        ]),
      _PrimaryTab.remember => take([
          'word_list',
          'learn_by_heart',
          'shell_ui_settings',
        ]),
    };

    final learnFromContent = switch (_currentTab) {
      _PrimaryTab.home => take([
          'speak_mode',
          'write_mode',
          'understand_tab',
          'understand_ai_coach',
          'youglish',
          'live_cabin',
        ]),
      _PrimaryTab.listen => take([
          'speak_mode',
          'understand_tab',
          'understand_ai_coach',
          'youglish',
          'live_cabin',
        ]),
      _PrimaryTab.read => take([
          'write_mode',
          'understand_tab',
          'understand_ai_coach',
          'youglish',
        ]),
      _PrimaryTab.understand => take([
          'understand_ai_coach',
          'speak_mode',
          'youglish',
          'live_cabin',
        ]),
      _PrimaryTab.remember => take([
          'review',
          'learn_by_heart',
        ]),
    };

    final reviewAndAnalysis = switch (_currentTab) {
      _PrimaryTab.home => take([
          'review',
          'learn_by_heart',
          'word_list',
          'timeline',
          'stats',
          'word_map',
        ]),
      _PrimaryTab.listen => take([
          'sound_list',
          'review',
          'word_list',
          'timeline',
        ]),
      _PrimaryTab.read => take([
          'review',
          'word_list',
          'wordlist_stats',
          'word_map',
        ]),
      _PrimaryTab.understand => take([
          'review',
          'word_list',
          'timeline',
          'word_map',
        ]),
      _PrimaryTab.remember => take([
          'review',
          'learn_by_heart',
          'word_list',
          'sound_list',
          'timeline',
          'stats',
          'word_map',
          'wordlist_stats',
          'triangle',
          'venn',
        ]),
    };

    final allowedIds = <String>{
      ...openContent.map((tool) => tool.id),
      ...learnFromContent.map((tool) => tool.id),
      ...reviewAndAnalysis.map((tool) => tool.id),
    };
    final recent = toolById.values
        .where((tool) => allowedIds.contains(tool.id))
        .where((tool) => _storage.getQuickActionLastUsedMillis(tool.id) > 0)
        .toList()
      ..sort((a, b) => _storage
          .getQuickActionLastUsedMillis(b.id)
          .compareTo(_storage.getQuickActionLastUsedMillis(a.id)));

    return _dedupeQuickActionGroups([
      recent.take(4).toList(),
      _rankQuickActions(openContent),
      _rankQuickActions(learnFromContent),
      _rankQuickActions(reviewAndAnalysis),
    ]);
  }

  List<tools.ToolItem> _dedupeQuickActionGroups(
    List<List<tools.ToolItem>> groups,
  ) {
    final seen = <String>{};
    final result = <tools.ToolItem>[];
    for (final group in groups) {
      for (final tool in group) {
        if (seen.add(tool.id)) result.add(tool);
      }
    }
    return result;
  }

  List<tools.ToolItem> _rankQuickActions(List<tools.ToolItem> items) {
    final ranked = [...items];
    ranked.sort((a, b) => _quickActionScore(b).compareTo(_quickActionScore(a)));
    return ranked;
  }

  int _quickActionScore(tools.ToolItem item) {
    final usage = _storage.getQuickActionUsageCount(item.id);
    final lastUsedMillis = _storage.getQuickActionLastUsedMillis(item.id);
    final now = DateTime.now().millisecondsSinceEpoch;
    final hoursSinceUse =
        lastUsedMillis <= 0 ? 9999 : ((now - lastUsedMillis) / 3600000).floor();
    final recencyBonus = hoursSinceUse >= 72 ? 0 : (72 - hoursSinceUse);

    return (_basePriorityForTool(item.id) * 1000) + (usage * 24) + recencyBonus;
  }

  int _basePriorityForTool(String id) {
    const home = {
      'speak_mode': 98,
      'write_mode': 97,
      'understand_tab': 96,
      'tipitaka': 94,
      'shell_ui_settings': 92,
      'youtube_downloader': 90,
      'web_reader': 88,
      'pdf_reader': 87,
      'review': 86,
      'word_list': 85,
    };
    const listen = {
      'speak_mode': 100,
      'understand_tab': 98,
      'video_library': 97,
      'youtube_downloader': 96,
      'youglish': 95,
      'understand_ai_coach': 94,
      'sound_list': 92,
      'shell_ui_settings': 88,
    };
    const read = {
      'write_mode': 100,
      'web_reader': 98,
      'pdf_reader': 97,
      'tipitaka': 96,
      'dict_manager': 94,
      'understand_ai_coach': 92,
      'word_list': 90,
      'shell_ui_settings': 88,
    };
    const understand = {
      'understand_ai_coach': 100,
      'speak_mode': 98,
      'youglish': 96,
      'review': 94,
      'word_list': 92,
      'shell_ui_settings': 88,
    };
    const remember = {
      'review': 100,
      'learn_by_heart': 99,
      'word_list': 98,
      'sound_list': 97,
      'timeline': 95,
      'stats': 94,
      'word_map': 93,
      'wordlist_stats': 92,
      'triangle': 90,
      'venn': 89,
      'shell_ui_settings': 86,
    };

    final map = switch (_currentTab) {
      _PrimaryTab.home => home,
      _PrimaryTab.listen => listen,
      _PrimaryTab.read => read,
      _PrimaryTab.understand => understand,
      _PrimaryTab.remember => remember,
    };
    return map[id] ?? 50;
  }

  Future<void> _handleTool(String toolId) async {
    final nav = Navigator.of(context);
    final vocabProvider = context.read<VocabularyProvider>();
    final l10n = AppLocalizations.of(context);

    void pushVocab(String title, Color color, Widget child) {
      nav.push(
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider<VocabularyProvider>.value(
            value: vocabProvider,
            child: _ToolPage(title: title, color: color, child: child),
          ),
        ),
      );
    }

    switch (toolId) {
      case 'live_cabin':
        nav.push(
          MaterialPageRoute(
            builder: (_) => const LiveCabinScreen(),
          ),
        );
        return;
      case 'learn_by_heart':
        nav.push(
          MaterialPageRoute(
            builder: (_) => const LearnByHeartHubScreen(),
          ),
        );
        return;
      case 'speak_mode':
        _setListenMode(1);
        return;
      case 'write_mode':
        _setReadMode(1);
        return;
      case 'understand_tab':
        _setPrimaryTab(_PrimaryTab.understand);
        return;
      case 'understand_ai_coach':
        _setPrimaryTab(_PrimaryTab.understand);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) openUnderstandAiCoach(context);
        });
        return;
      case 'word_list':
        nav.push(MaterialPageRoute(builder: (_) => const WordListScreen()));
        return;
      case 'sound_list':
        nav.push(
          MaterialPageRoute(builder: (_) => const SoundListScreen()),
        );
        return;
      case 'timeline':
        nav.push(MaterialPageRoute(builder: (_) => const TimelineView()));
        return;
      case 'wordlist_stats':
        nav.push(MaterialPageRoute(builder: (_) => const StatsDashboard()));
        return;
      case 'web_reader':
        final openForWriting =
            _currentTab == _PrimaryTab.read && _readModeIndex == 1;
        nav.push(
          MaterialPageRoute(
            builder: (_) => WebReaderScreen(writingMode: openForWriting),
          ),
        );
        return;
      case 'youtube_downloader':
        await YoutubeSheet.show(context);
        return;
      case 'pdf_reader':
        final result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
        );
        if (!mounted) return;
        if (result != null && result.files.single.path != null) {
          final openForWriting =
              _currentTab == _PrimaryTab.read && _readModeIndex == 1;
          nav.push(
            MaterialPageRoute(
              builder: (_) => PdfReaderScreen(
                pdfPath: result.files.single.path!,
                writingMode: openForWriting,
              ),
            ),
          );
        }
        return;
      case 'youglish':
        nav.push(MaterialPageRoute(builder: (_) => const YouGlishScreen()));
        return;
      case 'stats':
        pushVocab(l10n.overview, const Color(0xFF42A5F5), const StatsTab());
        return;
      case 'word_map':
        pushVocab(l10n.wordMap, const Color(0xFF26C6DA), const MapTab());
        return;
      case 'triangle':
        pushVocab(
          l10n.triangle,
          const Color(0xFFFFA726),
          const TriangleTab(),
        );
        return;
      case 'venn':
        pushVocab(
          l10n.vennDiagram,
          const Color(0xFFAB47BC),
          const VennTab(),
        );
        return;
      case 'review':
        pushVocab(l10n.review, const Color(0xFF66BB6A), const ReviewTab());
        return;
              case 'tipitaka':
        // The library resolves the bundled/installed DB and shows the data
        // manager when neither is available. Navigator.push itself cannot
        // catch an async database-open failure, so do not use try/catch here.
        nav.push(
          MaterialPageRoute(builder: (_) => const TipitakaLibraryScreen()),
        );
        return;
      case 'video_player':
        nav.push(
          MaterialPageRoute(builder: (_) => const VideoLibraryScreen()),
        );
        return;
      case 'dictionary':
        nav.push(
          MaterialPageRoute(builder: (_) => const DictManagerScreen()),
        );
        return;
      case 'shell_ui_settings':
        await _openShellUiSettings();
        return;
      case 'dict_manager':
        nav.push(
          MaterialPageRoute(builder: (_) => const DictManagerScreen()),
        );
        return;
      case 'video_library':
        nav.push(
          MaterialPageRoute(builder: (_) => const VideoLibraryScreen()),
        );
        return;
    }
  }

  Widget _buildCurrentScreen() {
    switch (_currentTab) {
      case _PrimaryTab.home:
        return HomeScreen(
          onNavigateToListen: () => _setListenMode(0),
          onNavigateToSpeak: () => _setListenMode(1),
          onNavigateToWatch: () => _setListenMode(2),
          onNavigateToRead: () => _setReadMode(0),
          onNavigateToWrite: () => _setReadMode(1),
          onNavigateToUnderstand: () => _setPrimaryTab(_PrimaryTab.understand),
          onNavigateToMemory: () => _setPrimaryTab(_PrimaryTab.remember),
          onOpenAiChat: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AiChatScreen()),
            );
          },
        );
      case _PrimaryTab.listen:
        return IndexedStack(
          index: _listenModeIndex,
          children: [
            const ListenModeScreen(),
            SpeakModeScreen(
              onOpenYouGlish: () => _handleTool('youglish'),
              onOpenQuickActions: _openQuickActions,
              onOpenUnderstand: () => _setPrimaryTab(_PrimaryTab.understand),
            ),
            // LISTEN-VIEW-001: embedded → no back button (nothing to pop;
            // popping here would pop the root route = black screen).
            const VideoLibraryScreen(showBackButton: false),
          ],
        );
      case _PrimaryTab.read:
        return IndexedStack(
          index: _readModeIndex,
          children: [
            ReadModeScreen(
              initialSource: _readSource,
              onSourceChanged: (source) => _setReadSource(source),
              sourceCallbacks: ReadSourceCallbacks(
                onOpenDocumentLibrary: _openTextLibrary,
                onOpenWebReader: () => _handleTool('web_reader'),
                onOpenTipitakaLibrary: () => _handleTool('tipitaka'),
              ),
              textActionCallbacks: _readTextActionCallbacks,
              showSourcePicker: false,
            ),
            WriteStudioScreen(
              onOpenWebReader: () => _handleTool('web_reader'),
              onOpenPdfReader: () => _handleTool('pdf_reader'),
              onOpenQuickActions: _openQuickActions,
            ),
          ],
        );
      case _PrimaryTab.understand:
        return UnderstandWorkspaceScreen(
          initialMode: _understandLearningMode,
          onModeChanged: _handleUnderstandModeChanged,
          showInternalModeTabs: false,
          onOpenSpeakMode: () => _setListenMode(1),
          onOpenYouGlish: () {
            _handleTool('youglish');
          },
          onOpenReview: () {
            _handleTool('review');
          },
          onOpenQuickActions: _openQuickActions,
        );
      case _PrimaryTab.remember:
        return RememberWorkspaceScreen(
          onOpenLearnByHeart: () {
            _handleTool('learn_by_heart');
          },
          onOpenReview: () {
            _handleTool('review');
          },
          onOpenWordList: () {
            _handleTool('word_list');
          },
          onOpenTimeline: () {
            _handleTool('timeline');
          },
          onOpenStats: () {
            _handleTool('stats');
          },
          onOpenMap: () {
            _handleTool('word_map');
          },
          onOpenQuickActions: _openQuickActions,
        );
    }
  }

  Widget _buildDesktopSidebar(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = <({String label, IconData icon, IconData selectedIcon, _PrimaryTab tab})>[
      (label: l10n.home, icon: Icons.home_outlined, selectedIcon: Icons.home, tab: _PrimaryTab.home),
      (label: l10n.read, icon: Icons.menu_book_outlined, selectedIcon: Icons.menu_book, tab: _PrimaryTab.read),
      (label: l10n.listen, icon: Icons.headphones_outlined, selectedIcon: Icons.headphones, tab: _PrimaryTab.listen),
      (label: l10n.understand, icon: Icons.lightbulb_outline, selectedIcon: Icons.lightbulb, tab: _PrimaryTab.understand),
      (label: l10n.remember, icon: Icons.psychology_outlined, selectedIcon: Icons.psychology, tab: _PrimaryTab.remember),
    ];

    return Material(
      color: const Color(0xFF111827),
      child: SafeArea(
        right: false,
        bottom: false,
        child: SizedBox(
          width: 248,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 16, 24),
                child: Text(
                  '4U Scholar',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.94),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                  child: Semantics(
                    button: true,
                    selected: _currentTab == item.tab,
                    label: item.label,
                    child: ListTile(
                      selected: _currentTab == item.tab,
                      selectedTileColor: _currentAccent.withValues(alpha: 0.14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      leading: Icon(
                        _currentTab == item.tab ? item.selectedIcon : item.icon,
                        color: _currentTab == item.tab ? _currentAccent : Colors.white70,
                      ),
                      title: Text(
                        item.label,
                        style: TextStyle(
                          color: _currentTab == item.tab ? Colors.white : Colors.white70,
                          fontWeight: _currentTab == item.tab ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _setPrimaryTab(item.tab);
                      },
                    ),
                  ),
                ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Text(
                  'Workspace',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.42), fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF080B1A),
      // Keep the physical drawer side paired with the content-tab side. The
      // same preference also controls the bottom navigation order.
      drawer: _listenFirst
          ? const AudioLibraryDrawer(isLeft: true)
          : const TextLibraryDrawer(isLeft: true),
      endDrawer: _listenFirst
          ? const TextLibraryDrawer(isLeft: false)
          : const AudioLibraryDrawer(isLeft: false),
      drawerEnableOpenDragGesture: !_isHome,
      endDrawerEnableOpenDragGesture: !_isHome,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop =
              constraints.maxWidth >= AppResponsive.expandedWidth;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isDesktop) _buildDesktopSidebar(context),
              Expanded(
                child: SafeArea(
                  bottom: false,
                  child: Stack(
          children: [
            Column(
              children: [
                _buildAppBar(context),
                _buildWorkspaceHeader(context),
                Expanded(
                  child: ClipRect(
                    child: _buildCurrentScreen(),
                  ),
                ),
                if (_shouldShowShellMiniPlayer)
                  Consumer<PlayerProvider>(
                    builder: (context, player, _) {
                      if (player.currentSongPath == null) {
                        return const SizedBox.shrink();
                      }
                      return Dismissible(
                        key: ValueKey('mini_${player.currentSongPath}'),
                        direction: DismissDirection.horizontal,
                        background: Container(
                          margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 24),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.close,
                                  color: Colors.redAccent, size: 18),
                              SizedBox(width: 6),
                              Text('Vuốt để ẩn',
                                  style: TextStyle(
                                      color: Colors.redAccent, fontSize: 12)),
                            ],
                          ),
                        ),
                        secondaryBackground: Container(
                          margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Vuốt để ẩn',
                                  style: TextStyle(
                                      color: Colors.redAccent, fontSize: 12)),
                              SizedBox(width: 6),
                              Icon(Icons.close,
                                  color: Colors.redAccent, size: 18),
                            ],
                          ),
                        ),
                        onDismissed: (_) {
                          HapticFeedback.mediumImpact();
                          player.clearCurrentSong();
                        },
                        child: MiniPlayer(
                          margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                          onTap: () => _setListenMode(0),
                        ),
                      );
                    },
                  ),
              ],
            ),
            // ★ Wordlist floating bubble – persistent TTS across tabs
            const WordlistBubble(),
            // ★ Live Cabin floating bubble – persistent STS across tabs
            const LiveCaptionBubble(),
          ],
        ),
                  ),
                ),
              ],
            );
          },
        ),
      bottomNavigationBar:
          MediaQuery.sizeOf(context).width >=
              AppResponsive.expandedWidth
          ? null
          : _buildBottomNav(context),
    );
  }

  void _openLeftLibrary() {
    _scaffoldKey.currentState?.openDrawer();
  }

  void _openRightLibrary() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  void _openAudioLibrary() {
    if (_listenFirst) {
      _openLeftLibrary();
    } else {
      _openRightLibrary();
    }
  }

  void _openTextLibrary() {
    if (_listenFirst) {
      _openRightLibrary();
    } else {
      _openLeftLibrary();
    }
  }

  bool get _leftLibraryIsAudio => _listenFirst;

  IconData get _leftLibraryIcon =>
      _leftLibraryIsAudio
          ? Icons.library_music_rounded
          : Icons.menu_book_rounded;

  String get _leftLibraryTooltip =>
      _leftLibraryIsAudio ? 'Thư viện âm thanh' : 'Thư viện văn bản';

  IconData get _rightLibraryIcon =>
      _leftLibraryIsAudio
          ? Icons.menu_book_rounded
          : Icons.library_music_rounded;

  String get _rightLibraryTooltip =>
      _leftLibraryIsAudio ? 'Thư viện văn bản' : 'Thư viện âm thanh';

  Widget _buildAppBar(BuildContext context) {
    final hasMappedLibraryPair =
        _currentTab != _PrimaryTab.home &&
        _currentTab != _PrimaryTab.remember;
    final rightLibraryIsAudio =
        hasMappedLibraryPair ? !_leftLibraryIsAudio : true;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        border: Border(
          bottom: BorderSide(
            color: _isHome
                ? Colors.white.withValues(alpha: 0.06)
                : _currentAccent.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          _ShellActionButton(
            icon: _leadingIcon,
            color: _leadingColor,
            tooltip: _leadingTooltip,
            onTap: () {
              if (_currentTab == _PrimaryTab.home) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SttModelSettingsScreen(),
                  ),
                );
              } else if (_currentTab == _PrimaryTab.remember) {
                _handleTool('word_list');
              } else {
                // The left app-bar slot follows the same left drawer as the
                // Listen/Read order; it never opens the opposite library.
                _openLeftLibrary();
              }
            },
          ),
          const SizedBox(width: 8),
          Expanded(child: _buildTitleSection()),
          const SizedBox(width: 8),
          _ShellActionButton(
            icon: Icons.bolt_rounded,
            color: const Color(0xFFB388FF),
            tooltip: context.uiText('Công cụ nhanh'),
            onTap: _openQuickActions,
          ),
          const SizedBox(width: 8),
          _ShellActionButton(
            icon: hasMappedLibraryPair
                ? _rightLibraryIcon
                : Icons.library_music_rounded,
            color: rightLibraryIsAudio
                ? const Color(0xFF6C63FF)
                : const Color(0xFF2196F3),
            tooltip: context.uiText(
              hasMappedLibraryPair
                  ? _rightLibraryTooltip
                  : 'Thư viện âm thanh',
            ),
            onTap: hasMappedLibraryPair
                ? _openRightLibrary
                : _openAudioLibrary,
          ),
        ],
      ),
    );
  }

  Widget _buildTitleSection() {
    return GestureDetector(
      onTap: _showModeChip ? _handleModeChipTap : null,
      onLongPress: _hasSecondaryModes && _enableLongPressModeSwitch
          ? _toggleCurrentSecondaryMode
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _titleText,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: _isHome ? 18 : 15,
              fontWeight: FontWeight.bold,
              color: _isHome ? Colors.white : _currentAccent,
              letterSpacing: -0.3,
            ),
          ),
          Consumer<PlayerProvider>(
            builder: (_, player, __) {
              if (player.currentSongTitle == null) {
                return const SizedBox(height: 2);
              }
              return Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  player.currentSongTitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[500],
                  ),
                ),
              );
            },
          ),
          if (_hasSecondaryModes &&
              (_showModeChip || _enableLongPressModeSwitch))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: _ModeHintChip(
                label: _currentModeLabel,
                altLabel: _alternateModeLabel,
                color: _currentAccent,
                compactEnabled: _compactModeSwitch || _autoHideModeSwitch,
                longPressEnabled: _enableLongPressModeSwitch,
                expanded: _showModeSwitch,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWorkspaceHeader(BuildContext context) {
    final children = <Widget>[];

    if (_hasSecondaryModes) {
      children.add(_buildAnimatedModeSwitch(context));
    }

    switch (_currentTab) {
      case _PrimaryTab.listen:
        children.add(_buildListenContextHeader(context));
        break;
      case _PrimaryTab.read:
        children.add(_buildReadContextHeader(context));
        break;
      case _PrimaryTab.understand:
        children.add(_buildUnderstandContextHeader(context));
        break;
      case _PrimaryTab.home:
      case _PrimaryTab.remember:
        break;
    }

    if (children.isEmpty) return const SizedBox.shrink();
    return Column(mainAxisSize: MainAxisSize.min, children: children);
  }

  Widget _buildListenContextHeader(BuildContext context) {
    final actions = switch (_listenModeIndex) {
      0 => <_WorkspaceHeaderAction>[
          _WorkspaceHeaderAction(
            label: 'Mở âm thanh',
            icon: Icons.library_music_rounded,
            onPressed: () => _openListenSource(_listenSource),
          ),
          _WorkspaceHeaderAction(
            label: 'Học từ nội dung',
            icon: Icons.lightbulb_outline,
            onPressed: () => _setPrimaryTab(_PrimaryTab.understand),
          ),
        ],
      1 => <_WorkspaceHeaderAction>[
          _WorkspaceHeaderAction(
            label: 'YouGlish',
            icon: Icons.record_voice_over,
            onPressed: () => _handleTool('youglish'),
          ),
          _WorkspaceHeaderAction(
            label: 'Hỏi AI',
            icon: Icons.psychology_outlined,
            onPressed: () => _setPrimaryTab(_PrimaryTab.understand),
          ),
        ],
      _ => <_WorkspaceHeaderAction>[
          _WorkspaceHeaderAction(
            label: 'Thư viện video',
            icon: Icons.video_library_outlined,
            onPressed: () => _handleTool('video_library'),
          ),
          _WorkspaceHeaderAction(
            label: 'YouTube',
            icon: Icons.play_circle_filled,
            onPressed: () => _handleTool('youtube_downloader'),
          ),
        ],
    };

    return _WorkspaceHeaderSurface(
      accent: _currentAccent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WorkspaceHeaderLabel(
            icon: Icons.source_outlined,
            label: context.uiText('Nguồn'),
          ),
          const SizedBox(height: 8),
          WorkspaceSourcePicker<ListenContentSource>(
            items: _listenSourceItems(context),
            selectedValue: _listenSource,
            onChanged: (source) => _setListenSource(source, openSource: true),
            presentation: WorkspaceNavigationPresentation.chips,
            menuTooltip: context.uiText('Chọn nguồn'),
          ),
          const SizedBox(height: 10),
          _WorkspaceHeaderActions(actions: actions),
        ],
      ),
    );
  }

  List<WorkspaceNavigationItem<ListenContentSource>> _listenSourceItems(
    BuildContext context,
  ) {
    return [
      WorkspaceNavigationItem<ListenContentSource>(
        value: ListenContentSource.audioLibrary,
        label: context.uiText('Âm thanh'),
        icon: Icons.library_music_rounded,
      ),
      WorkspaceNavigationItem<ListenContentSource>(
        value: ListenContentSource.youtube,
        label: context.uiText('YouTube'),
        icon: Icons.play_circle_filled,
      ),
      WorkspaceNavigationItem<ListenContentSource>(
        value: ListenContentSource.videoLibrary,
        label: context.uiText('Video'),
        icon: Icons.video_library_outlined,
      ),
    ];
  }

  Widget _buildReadContextHeader(BuildContext context) {
    return _WorkspaceHeaderSurface(
      accent: _currentAccent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WorkspaceHeaderLabel(
            icon: Icons.source_outlined,
            label: context.uiText('Nguồn'),
          ),
          ReadSourcePicker(
            selectedSource: _readSource,
            onSourceChanged: (source) => _setReadSource(source),
            callbacks: ReadSourceCallbacks(
              onOpenDocumentLibrary: _openTextLibrary,
              onOpenWebReader: () => _handleTool('web_reader'),
              onOpenTipitakaLibrary: () => _handleTool('tipitaka'),
            ),
            presentation: WorkspaceNavigationPresentation.chips,
          ),
          const SizedBox(height: 6),
          // READ-ACT-001: cho biết 4 nút dưới đây đang áp dụng lên đoạn nào,
          // thay cho snackbar "Bạn cần bôi chọn một đoạn trước".
          Consumer<TextProvider>(
            builder: (context, textProvider, _) {
              final target = ReadTextActionRunner.targetFor(textProvider);
              if (target == null) return const SizedBox.shrink();
              final scope = target.fromSelection
                  ? context.uiText('đoạn đang chọn')
                  : context.uiText('dòng đang đọc');
              final preview = target.text.length > 42
                  ? '${target.text.substring(0, 42)}…'
                  : target.text;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${context.uiText('Áp dụng cho')}: $scope — $preview',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.85),
                  ),
                ),
              );
            },
          ),
          _WorkspaceHeaderActions(
            dense: true,
            actions: [
              _WorkspaceHeaderAction(
                label: 'Mở nguồn',
                icon: Icons.open_in_new_rounded,
                onPressed: () => _openReadSource(_readSource),
              ),
              _WorkspaceHeaderAction(
                label: 'Dịch',
                icon: Icons.translate,
                onPressed: () => _handleReadTextAction(ReadTextAction.translate),
              ),
              _WorkspaceHeaderAction(
                label: 'Ngữ pháp',
                icon: Icons.auto_awesome_motion,
                onPressed: () => _handleReadTextAction(ReadTextAction.grammar),
              ),
              _WorkspaceHeaderAction(
                label: 'Phát âm',
                icon: Icons.record_voice_over,
                onPressed: () => _handleReadTextAction(ReadTextAction.pronounce),
              ),
              _WorkspaceHeaderAction(
                label: 'Từ điển',
                icon: Icons.menu_book,
                onPressed: () => _handleReadTextAction(ReadTextAction.dictionary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUnderstandContextHeader(BuildContext context) {
    return _WorkspaceHeaderSurface(
      accent: _currentAccent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WorkspaceHeaderLabel(
            icon: Icons.route_outlined,
            label: context.uiText('Chế độ'),
          ),
          const SizedBox(height: 8),
          WorkspaceModeBar<UnderstandWorkspaceMode>(
            items: _understandModeItems(context),
            selectedValue: _understandMode,
            onChanged: _setUnderstandMode,
            presentation: WorkspaceNavigationPresentation.chips,
            menuTooltip: context.uiText('Chọn chế độ'),
          ),
          const SizedBox(height: 10),
          Consumer2<PlayerProvider, TextProvider>(
            builder: (context, player, textProvider, _) {
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _StatusPill(
                    icon: Icons.headphones,
                    label: 'Audio',
                    ready: player.currentSongPath != null,
                  ),
                  _StatusPill(
                    icon: Icons.menu_book,
                    label: 'Text',
                    ready: textProvider.hasLyrics,
                  ),
                  _WorkspaceHeaderActionButton(
                    action: _WorkspaceHeaderAction(
                      label: 'Hỏi AI',
                      icon: Icons.psychology_outlined,
                      onPressed: () => openUnderstandAiCoach(context),
                    ),
                    compact: true,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  List<WorkspaceNavigationItem<UnderstandWorkspaceMode>> _understandModeItems(
    BuildContext context,
  ) {
    return [
      WorkspaceNavigationItem<UnderstandWorkspaceMode>(
        value: UnderstandWorkspaceMode.sync,
        label: context.uiText('Đồng bộ'),
        icon: Icons.sync_alt_rounded,
      ),
      WorkspaceNavigationItem<UnderstandWorkspaceMode>(
        value: UnderstandWorkspaceMode.shadowing,
        label: context.uiText('Shadowing'),
        icon: Icons.record_voice_over,
      ),
    ];
  }

  // READ-ACT-001: mọi hành động văn bản của tab Đọc đi qua một bộ chạy duy
  // nhất. Không còn chặn bằng "phải bôi chọn trước" — ReadTextActionRunner
  // tự lùi về dòng đang đọc khi chưa có selection (các chế độ hiển thị theo
  // ô/interlinear không tạo được selection, xem audit 0.10.3 mục 1.b).
  void _handleReadTextAction(ReadTextAction action, {String? selectedText}) {
    unawaited(
      ReadTextActionRunner.run(
        context,
        action,
        selectedText: selectedText,
        onOpenDictionaryManager: () => unawaited(_handleTool('dict_manager')),
      ),
    );
  }

  ReadTextActionCallbacks get _readTextActionCallbacks {
    return ReadTextActionCallbacks(
      onTranslate: (text) =>
          _handleReadTextAction(ReadTextAction.translate, selectedText: text),
      onGrammar: (text) =>
          _handleReadTextAction(ReadTextAction.grammar, selectedText: text),
      onPronounce: (text) =>
          _handleReadTextAction(ReadTextAction.pronounce, selectedText: text),
      onDictionary: (text) =>
          _handleReadTextAction(ReadTextAction.dictionary, selectedText: text),
    );
  }

  void _showWorkspaceSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.uiText(message)),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildAnimatedModeSwitch(BuildContext context) {
    final show = _showModeSwitch;
    final child = show
        ? _buildModeSwitch(context)
        : const SizedBox(key: ValueKey('mode-switch-hidden'));

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: child,
      ),
    );
  }

  Widget _buildModeSwitch(BuildContext context) {
    final isListen = _showListenModes;
    final labels = isListen ? const ['Nghe', 'Nói', 'Xem'] : const ['Đọc', 'Viết'];
    final selectedIndex = isListen ? _listenModeIndex : _readModeIndex;
    final accent = _currentAccent;

    return Container(
      key: ValueKey('mode-switch-${_currentTab.name}-$selectedIndex'),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      color: const Color(0xFF111827),
      child: Row(
        children: List.generate(labels.length, (index) {
          final selected = index == selectedIndex;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: index == 0 ? 8 : 0),
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  if (isListen) {
                    _setListenMode(index);
                  } else {
                    _setReadMode(index);
                  }
                },
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? accent.withValues(alpha: 0.18)
                        : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? accent.withValues(alpha: 0.35)
                          : Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Text(
                    context.uiText(labels[index]),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected ? accent : Colors.grey[400],
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildListenNavItem(AppLocalizations l10n) {
    return Expanded(
      child: _BottomNavItem(
        label: l10n.listen,
        selected: _currentTab == _PrimaryTab.listen,
        color: _currentTab == _PrimaryTab.listen
            ? _currentAccent
            : const Color(0xFF6C63FF),
        icon: Icons.headphones_outlined,
        selectedIcon: Icons.headphones,
        showLongPressHint: _enableLongPressModeSwitch,
        onTap: () {
          HapticFeedback.selectionClick();
          _setPrimaryTab(_PrimaryTab.listen);
        },
        onLongPress: _enableLongPressModeSwitch
            ? () {
                HapticFeedback.mediumImpact();
                _setListenMode(1);
              }
            : null,
      ),
    );
  }

  Widget _buildReadNavItem(AppLocalizations l10n) {
    return Expanded(
      child: _BottomNavItem(
        label: l10n.read,
        selected: _currentTab == _PrimaryTab.read,
        color: _currentTab == _PrimaryTab.read
            ? _currentAccent
            : const Color(0xFF2196F3),
        icon: Icons.menu_book_outlined,
        selectedIcon: Icons.menu_book,
        showLongPressHint: _enableLongPressModeSwitch,
        onTap: () {
          HapticFeedback.selectionClick();
          _setPrimaryTab(_PrimaryTab.read);
        },
        onLongPress: _enableLongPressModeSwitch
            ? () {
                HapticFeedback.mediumImpact();
                _setReadMode(1);
              }
            : null,
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final orderedContentTabs = _listenFirst
        ? <Widget>[
            _buildListenNavItem(l10n),
            _buildReadNavItem(l10n),
          ]
        : <Widget>[
            _buildReadNavItem(l10n),
            _buildListenNavItem(l10n),
          ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        border: Border(
          top: BorderSide(
            color: _isHome
                ? Colors.white.withValues(alpha: 0.06)
                : _currentAccent.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
          child: Row(
            children: [
              Expanded(
                child: _BottomNavItem(
                  label: l10n.home,
                  selected: _currentTab == _PrimaryTab.home,
                  color: Colors.white,
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _setPrimaryTab(_PrimaryTab.home);
                  },
                ),
              ),
              ...orderedContentTabs,
              Expanded(
                child: _BottomNavItem(
                  label: l10n.understand,
                  selected: _currentTab == _PrimaryTab.understand,
                  color: _currentTab == _PrimaryTab.understand
                      ? _currentAccent
                      : const Color(0xFFFFB300),
                  icon: Icons.lightbulb_outline,
                  selectedIcon: Icons.lightbulb,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _setPrimaryTab(_PrimaryTab.understand);
                  },
                ),
              ),
              Expanded(
                child: Consumer<VocabularyProvider>(
                  builder: (_, vocab, __) => _BottomNavItem(
                    label: l10n.remember,
                    selected: _currentTab == _PrimaryTab.remember,
                    color: _currentTab == _PrimaryTab.remember
                        ? _currentAccent
                        : const Color(0xFF4CAF50),
                    icon: Icons.psychology_outlined,
                    selectedIcon: Icons.psychology,
                    badgeText: vocab.dueCount > 0
                        ? (vocab.dueCount > 99 ? '99+' : '${vocab.dueCount}')
                        : null,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _setPrimaryTab(_PrimaryTab.remember);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceHeaderAction {
  const _WorkspaceHeaderAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
}

class _WorkspaceHeaderSurface extends StatelessWidget {
  const _WorkspaceHeaderSurface({
    required this.accent,
    required this.child,
  });

  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('workspace-context-header'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF101827),
        border: Border(
          bottom: BorderSide(color: accent.withValues(alpha: 0.14)),
        ),
      ),
      child: child,
    );
  }
}

class _WorkspaceHeaderLabel extends StatelessWidget {
  const _WorkspaceHeaderLabel({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: Colors.white70),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }
}

class _WorkspaceHeaderActions extends StatelessWidget {
  const _WorkspaceHeaderActions({required this.actions, this.dense = false});

  final List<_WorkspaceHeaderAction> actions;

  /// READ-ACT-001 (audit 1.c): hàng nút thấp hơn và cuộn ngang trên điện
  /// thoại thay vì `Wrap` thành hai hàng cao chiếm hết màn hình đọc.
  final bool dense;

  /// Dưới bề ngang này thì cuộn ngang; từ tablet trở lên vẫn xuống dòng.
  static const double _scrollBreakpoint = 600;

  @override
  Widget build(BuildContext context) {
    if (!dense) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final action in actions)
            _WorkspaceHeaderActionButton(action: action),
        ],
      );
    }

    final buttons = [
      for (final action in actions)
        _WorkspaceHeaderActionButton(action: action, dense: true),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _scrollBreakpoint) {
          return Wrap(spacing: 8, runSpacing: 8, children: buttons);
        }
        return SizedBox(
          height: WorkspaceActionButton.denseHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: buttons.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, index) => buttons[index],
          ),
        );
      },
    );
  }
}

class _WorkspaceHeaderActionButton extends StatelessWidget {
  const _WorkspaceHeaderActionButton({
    required this.action,
    this.compact = false,
    this.dense = false,
  });

  final _WorkspaceHeaderAction action;
  final bool compact;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return WorkspaceActionButton(
      label: context.uiText(action.label),
      icon: action.icon,
      onPressed: action.onPressed,
      compact: compact,
      dense: dense,
      tooltip: context.uiText(action.label),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    required this.ready,
  });

  final IconData icon;
  final String label;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final color = ready ? const Color(0xFF66BB6A) : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            '${context.uiText(label)} · ${context.uiText(ready ? 'Sẵn sàng' : 'Chưa có')}',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolPage extends StatelessWidget {
  final String title;
  final Widget child;
  final Color color;

  const _ToolPage({
    required this.title,
    required this.child,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF080B1A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A1A2E),
          elevation: 0,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: color),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: child,
      ),
    );
  }
}

class _ShellActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ShellActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.uiText(tooltip),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}

class _ModeHintChip extends StatelessWidget {
  final String label;
  final String altLabel;
  final Color color;
  final bool compactEnabled;
  final bool longPressEnabled;
  final bool expanded;

  const _ModeHintChip({
    required this.label,
    required this.altLabel,
    required this.color,
    required this.compactEnabled,
    required this.longPressEnabled,
    required this.expanded,
  });

  @override
  Widget build(BuildContext context) {
    final suffix = compactEnabled
        ? (expanded ? 'Chạm để ẩn' : 'Chạm để hiện')
        : longPressEnabled
            ? 'Giữ để đổi'
            : altLabel;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        '${context.uiText(label)} · ${context.uiText(suffix)}',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final IconData icon;
  final IconData selectedIcon;
  final String? badgeText;
  final bool showLongPressHint;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _BottomNavItem({
    required this.label,
    required this.selected,
    required this.color,
    required this.icon,
    required this.selectedIcon,
    required this.onTap,
    this.onLongPress,
    this.badgeText,
    this.showLongPressHint = false,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = selected ? color : Colors.grey[500]!;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      hint: onLongPress != null ? 'Có thao tác nhấn giữ để đổi mode' : null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: 56,
          minHeight: kMinInteractiveDimension,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              decoration: BoxDecoration(
                color:
                    selected ? color.withValues(alpha: 0.14) : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color:
                      selected ? color.withValues(alpha: 0.24) : Colors.transparent,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(selected ? selectedIcon : icon,
                          color: activeColor, size: 22),
                      if (badgeText != null)
                        Positioned(
                          top: -6,
                          right: -14,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              badgeText!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      if (showLongPressHint)
                        Positioned(
                          bottom: -2,
                          right: -8,
                          child: Icon(
                            Icons.subdirectory_arrow_left,
                            size: 10,
                            color: activeColor.withValues(alpha: 0.8),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: activeColor,
                        fontSize: 10,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
