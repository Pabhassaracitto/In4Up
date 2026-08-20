import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:in4up/l10n/app_localizations.dart';

import '../features/pdf_reader/pdf_reader_screen.dart';
import '../features/web_reader/web_reader_screen.dart';
import '../features/youtube/youtube_explorer_screen.dart';
import '../providers/player_provider.dart';
import '../providers/vocabulary_bridge.dart';
import '../providers/vocabulary_provider.dart';
import '../services/storage_service.dart';
import 'home/home_screen.dart';
import 'listen_mode/listen_mode_screen.dart';
import 'listen_mode/speak_mode_screen.dart';
import 'listen_mode/widgets/audio_library_drawer.dart';
import 'listen_mode/widgets/mini_player.dart';
import 'memory_mode/remember_workspace_screen.dart';
import 'read_mode/read_mode_screen.dart';
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
import 'tools/youglish/youglish_screen.dart';
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

  _PrimaryTab _currentTab = _PrimaryTab.home;
  int _listenModeIndex = 0;
  int _readModeIndex = 0;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vocabProvider = context.read<VocabularyProvider>();
      VocabularyBridge.init(vocabProvider);
      _scheduleShellHintIfNeeded();
    });
  }

  @override
  void dispose() {
    _modeSwitchHideTimer?.cancel();
    _shellHintTimer?.cancel();
    super.dispose();
  }

  bool get _isHome => _currentTab == _PrimaryTab.home;
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
      return _listenModeIndex == 0 ? 'Nghe' : 'Nói';
    }
    if (_showReadModes) {
      return _readModeIndex == 0 ? 'Đọc' : 'Viết';
    }
    return '';
  }

  String get _alternateModeLabel {
    if (_showListenModes) {
      return _listenModeIndex == 0 ? 'Nói' : 'Nghe';
    }
    if (_showReadModes) {
      return _readModeIndex == 0 ? 'Viết' : 'Đọc';
    }
    return '';
  }

  void _loadShellUiSettings() {
    _compactModeSwitch = _storage.getShellCompactMode();
    _autoHideModeSwitch = _storage.getShellAutoHideModeSwitch();
    _enableLongPressModeSwitch = _storage.getShellLongPressModeSwitch();
    _rememberLastSubMode = _storage.getShellRememberLastSubMode();
    _listenModeIndex =
        ((_rememberLastSubMode ? _storage.getShellListenSubMode() : 0)
                .clamp(0, 1))
            .toInt();
    _readModeIndex =
        ((_rememberLastSubMode ? _storage.getShellReadSubMode() : 0)
                .clamp(0, 1))
            .toInt();
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
    HapticFeedback.selectionClick();
    if (_showListenModes) {
      _setListenMode(_listenModeIndex == 0 ? 1 : 0);
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
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ShellUiSettingsScreen()),
    );
    if (!mounted) return;
    setState(() {
      _loadShellUiSettings();
    });
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _scheduleShellHintIfNeeded());
  }

  Color get _currentAccent {
    switch (_currentTab) {
      case _PrimaryTab.home:
        return Colors.white;
      case _PrimaryTab.listen:
        return _listenModeIndex == 0
            ? const Color(0xFF6C63FF)
            : const Color(0xFFB388FF);
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
        return _listenModeIndex == 0 ? '🎧 Nghe' : '🎙️ Nói';
      case _PrimaryTab.read:
        return _readModeIndex == 0 ? '📖 Đọc' : '✍️ Viết';
      case _PrimaryTab.understand:
        return '💡 Hiểu';
      case _PrimaryTab.remember:
        return '🧠 Nhớ';
    }
  }

  bool get _shouldShowShellMiniPlayer {
    // Fix audit: mini gây vướng, nhất là ở Understand khi đã có trình phát riêng + lyric
    // => Ẩn mini ở tất cả tab có player riêng (Nghe, Đọc, Hiểu)
    // Chỉ hiện ở Remember (và có thể Home nếu muốn quick control)
    // Ngoài ra, nếu đang không phát và user đã gạt tắt, thì ẩn
    if (_currentTab == _PrimaryTab.home) return false;
    if (_currentTab == _PrimaryTab.listen) return false;
    if (_currentTab == _PrimaryTab.read) return false;
    if (_currentTab == _PrimaryTab.understand) return false;
    return true;
  }

  IconData get _leadingIcon {
    if (_currentTab == _PrimaryTab.home) return Icons.smart_toy_outlined;
    if (_currentTab == _PrimaryTab.remember) return Icons.format_list_bulleted;
    return Icons.menu_book_rounded;
  }

  Color get _leadingColor {
    if (_currentTab == _PrimaryTab.home) return const Color(0xFFFF9800);
    if (_currentTab == _PrimaryTab.remember) return const Color(0xFF66BB6A);
    return const Color(0xFF2196F3);
  }

  String get _leadingTooltip {
    if (_currentTab == _PrimaryTab.home) return 'Quản lý Model AI';
    if (_currentTab == _PrimaryTab.remember) return 'Danh sách từ';
    return 'Thư viện văn bản';
  }

  void _setPrimaryTab(_PrimaryTab tab) {
    if (_currentTab == tab) {
      if ((tab == _PrimaryTab.listen || tab == _PrimaryTab.read) &&
          (_compactModeSwitch || _autoHideModeSwitch)) {
        _handleModeChipTap();
      }
      return;
    }

    setState(() {
      _currentTab = tab;
      if (!_rememberLastSubMode) {
        if (tab == _PrimaryTab.listen) {
          _listenModeIndex = 0;
          _storage.saveShellListenSubMode(0);
        } else if (tab == _PrimaryTab.read) {
          _readModeIndex = 0;
          _storage.saveShellReadSubMode(0);
        }
      }
      _syncModeSwitchVisibility();
    });
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _scheduleShellHintIfNeeded());
  }

  void _setListenMode(int index) {
    setState(() {
      _currentTab = _PrimaryTab.listen;
      _listenModeIndex = index;
      _storage.saveShellListenSubMode(index);
      _syncModeSwitchVisibility();
    });
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _scheduleShellHintIfNeeded());
  }

  void _setReadMode(int index) {
    setState(() {
      _currentTab = _PrimaryTab.read;
      _readModeIndex = index;
      _storage.saveShellReadSubMode(index);
      _syncModeSwitchVisibility();
    });
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _scheduleShellHintIfNeeded());
  }

  Future<void> _openQuickActions() async {
    final toolId = await tools.showToolsOverlayV2(
      context,
      tools: _buildQuickActions(context),
    );

    if (!mounted || toolId == null) return;
    await _storage.recordQuickActionUsage(toolId);
    await _handleTool(toolId);
  }

  List<tools.ToolItem> _buildQuickActions(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final contentTools = <tools.ToolItem>[
      tools.ToolItem(
        id: 'youtube_downloader',
        title: l10n.youtube,
        subtitle: l10n.youtubeSubtitle,
        icon: Icons.play_circle_filled,
        color: const Color(0xFFFF0000),
      ),
      tools.ToolItem(
        id: 'web_reader',
        title: l10n.webReader,
        subtitle: l10n.webReaderSubtitle,
        icon: Icons.language,
        color: const Color(0xFF26A69A),
      ),
      tools.ToolItem(
        id: 'pdf_reader',
        title: l10n.pdfReader,
        subtitle: l10n.pdfReaderSubtitle,
        icon: Icons.picture_as_pdf,
        color: const Color(0xFFEF5350),
      ),
      tools.ToolItem(
        id: 'youglish',
        title: l10n.youglish,
        subtitle: l10n.youglishSubtitle,
        icon: Icons.record_voice_over,
        color: const Color(0xFF00BCD4),
      ),
    ];

    final shellSettingsTool = tools.ToolItem(
      id: 'shell_ui_settings',
      title: 'Giao diện shell',
      subtitle: 'Compact mode, auto-hide, long-press đổi mode',
      icon: Icons.tune_rounded,
      color: const Color(0xFF90CAF9),
    );

    final rememberTools = <tools.ToolItem>[
      tools.ToolItem(
        id: 'review',
        title: l10n.review,
        subtitle: l10n.reviewSubtitle,
        icon: Icons.school,
        color: const Color(0xFF66BB6A),
      ),
      tools.ToolItem(
        id: 'word_list',
        title: l10n.wordList,
        subtitle: l10n.wordListSubtitle,
        icon: Icons.format_list_bulleted,
        color: const Color(0xFF6C63FF),
      ),
      tools.ToolItem(
        id: 'sound_list',
        title: 'Âm mục',
        subtitle: 'Điểm, đoạn & mục lục âm thanh',
        icon: Icons.menu_book_outlined,
        color: const Color(0xFF26C6DA),
      ),
      tools.ToolItem(
        id: 'timeline',
        title: l10n.timeline,
        subtitle: l10n.timelineSubtitle,
        icon: Icons.timeline,
        color: const Color(0xFF9C27B0),
      ),
      tools.ToolItem(
        id: 'wordlist_stats',
        title: l10n.wordListStats,
        subtitle: l10n.wordListStatsSubtitle,
        icon: Icons.analytics_outlined,
        color: const Color(0xFF42A5F5),
      ),
      tools.ToolItem(
        id: 'stats',
        title: l10n.overview,
        subtitle: l10n.overviewSubtitle,
        icon: Icons.bar_chart_rounded,
        color: const Color(0xFF42A5F5),
      ),
      tools.ToolItem(
        id: 'word_map',
        title: l10n.wordMap,
        subtitle: l10n.wordMapSubtitle,
        icon: Icons.map_outlined,
        color: const Color(0xFF26C6DA),
      ),
      tools.ToolItem(
        id: 'triangle',
        title: l10n.triangle,
        subtitle: l10n.triangleSubtitle,
        icon: Icons.change_history_rounded,
        color: const Color(0xFFFFA726),
      ),
      tools.ToolItem(
        id: 'venn',
        title: l10n.vennDiagram,
        subtitle: l10n.vennDiagramSubtitle,
        icon: Icons.hub_outlined,
        color: const Color(0xFFAB47BC),
      ),
    ];

    final raw = switch (_currentTab) {
      _PrimaryTab.home => [
          tools.ToolItem(
            id: 'speak_mode',
            title: 'Nói',
            subtitle: 'Luyện shadowing và phát âm',
            icon: Icons.mic_rounded,
            color: const Color(0xFFB388FF),
          ),
          tools.ToolItem(
            id: 'write_mode',
            title: 'Viết',
            subtitle: 'Bài tập chép và recall theo nội dung',
            icon: Icons.edit_square,
            color: const Color(0xFF26C6DA),
          ),
          shellSettingsTool,
          ...contentTools,
          ...rememberTools,
        ],
      _PrimaryTab.listen => [
          tools.ToolItem(
            id: 'speak_mode',
            title: 'Nói',
            subtitle: 'Nhảy nhanh sang speaking studio',
            icon: Icons.mic_rounded,
            color: const Color(0xFFB388FF),
          ),
          tools.ToolItem(
            id: 'understand_tab',
            title: 'Hiểu',
            subtitle: 'Qua không gian đồng bộ audio-text',
            icon: Icons.lightbulb,
            color: const Color(0xFFFFB300),
          ),
          shellSettingsTool,
          contentTools[0],
          contentTools[3],
        ],
      _PrimaryTab.read => [
          tools.ToolItem(
            id: 'write_mode',
            title: 'Viết',
            subtitle: 'Nhảy nhanh sang writing studio',
            icon: Icons.edit_square,
            color: const Color(0xFF26C6DA),
          ),
          shellSettingsTool,
          contentTools[1],
          contentTools[2],
          rememberTools[1],
        ],
      _PrimaryTab.understand => [
          tools.ToolItem(
            id: 'speak_mode',
            title: 'Nói',
            subtitle: 'Qua speaking studio để luyện shadowing',
            icon: Icons.mic_rounded,
            color: const Color(0xFFB388FF),
          ),
          shellSettingsTool,
          contentTools[3],
          rememberTools[0],
          rememberTools[1],
        ],
      _PrimaryTab.remember => [shellSettingsTool, ...rememberTools],
    };

    return _rankQuickActions(raw);
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
      'speak_mode': 95,
      'write_mode': 94,
      'shell_ui_settings': 92,
      'youtube_downloader': 90,
      'web_reader': 88,
      'pdf_reader': 87,
      'review': 86,
      'word_list': 85,
    };
    const listen = {
      'speak_mode': 100,
      'youtube_downloader': 96,
      'youglish': 95,
      'understand_tab': 92,
      'shell_ui_settings': 88,
    };
    const read = {
      'write_mode': 100,
      'web_reader': 96,
      'pdf_reader': 95,
      'word_list': 90,
      'shell_ui_settings': 88,
    };
    const understand = {
      'speak_mode': 98,
      'youglish': 96,
      'review': 94,
      'word_list': 92,
      'shell_ui_settings': 88,
    };
    const remember = {
      'review': 100,
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
    final l10n = AppLocalizations.of(context)!;

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
      case 'speak_mode':
        _setListenMode(1);
        return;
      case 'write_mode':
        _setReadMode(1);
        return;
      case 'understand_tab':
        _setPrimaryTab(_PrimaryTab.understand);
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
        nav.push(MaterialPageRoute(builder: (_) => const WebReaderScreen()));
        return;
      case 'youtube_downloader':
        nav.push(
          MaterialPageRoute(
            builder: (_) => const YoutubeExplorerScreen(
              apiKey: 'AIzaSy...YOUR_KEY_HERE',
            ),
          ),
        );
        return;
      case 'pdf_reader':
        final result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
        );
        if (!mounted) return;
        if (result != null && result.files.single.path != null) {
          nav.push(
            MaterialPageRoute(
              builder: (_) =>
                  PdfReaderScreen(pdfPath: result.files.single.path!),
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
      case 'shell_ui_settings':
        await _openShellUiSettings();
        return;
    }
  }

  Widget _buildCurrentScreen() {
    switch (_currentTab) {
      case _PrimaryTab.home:
        return HomeScreen(
          onNavigateToListen: () => _setListenMode(0),
          onNavigateToRead: () => _setReadMode(0),
          onNavigateToUnderstand: () => _setPrimaryTab(_PrimaryTab.understand),
          onNavigateToMemory: () => _setPrimaryTab(_PrimaryTab.remember),
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
          ],
        );
      case _PrimaryTab.read:
        return IndexedStack(
          index: _readModeIndex,
          children: [
            const ReadModeScreen(),
            WriteStudioScreen(
              onOpenWebReader: () => _handleTool('web_reader'),
              onOpenPdfReader: () => _handleTool('pdf_reader'),
              onOpenQuickActions: _openQuickActions,
            ),
          ],
        );
      case _PrimaryTab.understand:
        return UnderstandWorkspaceScreen(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF080B1A),
      drawer: const TextLibraryDrawer(),
      endDrawer: const AudioLibraryDrawer(),
      drawerEnableOpenDragGesture: !_isHome,
      endDrawerEnableOpenDragGesture: !_isHome,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildAppBar(context),
            _buildAnimatedModeSwitch(context),
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
                  // Audit fix: khi đang không phát và user chuyển tab, ẩn mini để đỡ vướng
                  // Cho phép vuốt để tắt/ẩn
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
                          Icon(Icons.close, color: Colors.redAccent, size: 18),
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
                          Icon(Icons.close, color: Colors.redAccent, size: 18),
                        ],
                      ),
                    ),
                    onDismissed: (_) {
                      // Khi vuốt ẩn, xóa bài hiện tại để mini biến mất hoàn toàn, tránh lỗi
                      // "A dismissed Dismissible widget is still part of the tree"
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
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildAppBar(BuildContext context) {
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
                _scaffoldKey.currentState?.openDrawer();
              }
            },
          ),
          const SizedBox(width: 8),
          Expanded(child: _buildTitleSection()),
          const SizedBox(width: 8),
          _ShellActionButton(
            icon: Icons.bolt_rounded,
            color: const Color(0xFFB388FF),
            tooltip: 'Công cụ nhanh',
            onTap: _openQuickActions,
          ),
          const SizedBox(width: 8),
          _ShellActionButton(
            icon: Icons.library_music_rounded,
            color: const Color(0xFF6C63FF),
            tooltip: 'Thư viện âm thanh',
            onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
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
    final labels = isListen ? const ['Nghe', 'Nói'] : const ['Đọc', 'Viết'];
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
                    labels[index],
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

  Widget _buildBottomNav(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

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
              Expanded(
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
              ),
              Expanded(
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
              ),
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
      message: tooltip,
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
        '$label · $suffix',
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

    return Padding(
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
    );
  }
}
