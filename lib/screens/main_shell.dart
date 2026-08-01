import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../features/pdf_reader/pdf_reader_screen.dart';
import '../features/web_reader/web_reader_screen.dart';
import '../features/youtube/youtube_explorer_screen.dart';
import '../providers/player_provider.dart';
import '../providers/vocabulary_bridge.dart';
import '../providers/vocabulary_provider.dart';
import 'home/home_screen.dart';
import 'listen_mode/listen_mode_screen.dart';
import 'listen_mode/speak_mode_screen.dart';
import 'listen_mode/widgets/audio_library_drawer.dart';
import 'listen_mode/widgets/mini_player.dart';
import 'memory_mode/memory_tab_connector.dart';
import 'read_mode/read_mode_screen.dart';
import 'read_mode/write_studio_screen.dart';
import 'settings/stt_model_settings_screen.dart';
import 'text_library_drawer.dart';
import 'tools/map_tab.dart';
import 'tools/review_tab.dart';
import 'tools/stats_tab.dart';
import 'tools/tools_overlay_v2.dart' as tools;
import 'tools/triangle_tab.dart';
import 'tools/venn_tab.dart';
import 'tools/word_list/stats_dashboard.dart';
import 'tools/word_list/timeline_view.dart';
import 'tools/word_list/word_list_screen.dart';
import 'tools/youglish/youglish_screen.dart';
import 'understand_mode/understand_tab_connector.dart';

enum _PrimaryTab { home, listen, read, understand, remember }

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  _PrimaryTab _currentTab = _PrimaryTab.home;
  int _listenModeIndex = 0;
  int _readModeIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vocabProvider = context.read<VocabularyProvider>();
      VocabularyBridge.init(vocabProvider);
    });
  }

  bool get _isHome => _currentTab == _PrimaryTab.home;
  bool get _showListenModes => _currentTab == _PrimaryTab.listen;
  bool get _showReadModes => _currentTab == _PrimaryTab.read;
  bool get _showModeSwitch => _showListenModes || _showReadModes;

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
        return 'VipSound';
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
    if (_currentTab == _PrimaryTab.home) return false;
    if (_currentTab == _PrimaryTab.listen && _listenModeIndex == 0) {
      return false;
    }
    return true;
  }

  void _setPrimaryTab(_PrimaryTab tab) {
    if (_currentTab == tab) return;
    setState(() => _currentTab = tab);
  }

  void _setListenMode(int index) {
    setState(() {
      _currentTab = _PrimaryTab.listen;
      _listenModeIndex = index;
    });
  }

  void _setReadMode(int index) {
    setState(() {
      _currentTab = _PrimaryTab.read;
      _readModeIndex = index;
    });
  }

  Future<void> _openQuickActions() async {
    final toolId = await tools.showToolsOverlayV2(
      context,
      tools: _buildQuickActions(context),
    );

    if (!mounted || toolId == null) return;
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

    switch (_currentTab) {
      case _PrimaryTab.home:
        return [
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
          ...contentTools,
          ...rememberTools,
        ];
      case _PrimaryTab.listen:
        return [
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
          contentTools[0],
          contentTools[3],
        ];
      case _PrimaryTab.read:
        return [
          tools.ToolItem(
            id: 'write_mode',
            title: 'Viết',
            subtitle: 'Nhảy nhanh sang writing studio',
            icon: Icons.edit_square,
            color: const Color(0xFF26C6DA),
          ),
          contentTools[1],
          contentTools[2],
          rememberTools[1],
        ];
      case _PrimaryTab.understand:
        return [
          tools.ToolItem(
            id: 'speak_mode',
            title: 'Nói',
            subtitle: 'Qua speaking studio để luyện shadowing',
            icon: Icons.mic_rounded,
            color: const Color(0xFFB388FF),
          ),
          contentTools[3],
          rememberTools[0],
          rememberTools[1],
        ];
      case _PrimaryTab.remember:
        return rememberTools;
    }
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
              builder: (_) => PdfReaderScreen(pdfPath: result.files.single.path!),
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
        return const UnderstandTabConnector();
      case _PrimaryTab.remember:
        return const MemoryTabConnector();
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
            if (_showModeSwitch) _buildModeSwitch(context),
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
                  return MiniPlayer(
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    onTap: () => _setListenMode(0),
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
            icon: _isHome ? Icons.smart_toy_outlined : Icons.menu_book_rounded,
            color: _isHome ? const Color(0xFFFF9800) : const Color(0xFF2196F3),
            tooltip: _isHome ? 'Quản lý Model AI' : 'Thư viện văn bản',
            onTap: () {
              if (_isHome) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SttModelSettingsScreen(),
                  ),
                );
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
    return Column(
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
      ],
    );
  }

  Widget _buildModeSwitch(BuildContext context) {
    final isListen = _showListenModes;
    final labels = isListen
        ? const ['Nghe', 'Nói']
        : const ['Đọc', 'Viết'];
    final selectedIndex = isListen ? _listenModeIndex : _readModeIndex;
    final accent = _currentAccent;

    return Container(
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
      child: NavigationBar(
        selectedIndex: _currentTab.index,
        backgroundColor: const Color(0xFF111827),
        indicatorColor: _currentAccent.withValues(alpha: 0.2),
        onDestinationSelected: (index) {
          HapticFeedback.selectionClick();
          _setPrimaryTab(_PrimaryTab.values[index]);
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l10n.home,
          ),
          NavigationDestination(
            icon: const Icon(Icons.headphones_outlined),
            selectedIcon: const Icon(Icons.headphones),
            label: l10n.listen,
          ),
          NavigationDestination(
            icon: const Icon(Icons.menu_book_outlined),
            selectedIcon: const Icon(Icons.menu_book),
            label: l10n.read,
          ),
          NavigationDestination(
            icon: const Icon(Icons.lightbulb_outline),
            selectedIcon: const Icon(Icons.lightbulb),
            label: l10n.understand,
          ),
          NavigationDestination(
            icon: Consumer<VocabularyProvider>(
              builder: (_, vocab, __) => _RememberNavIcon(
                dueCount: vocab.dueCount,
                filled: false,
              ),
            ),
            selectedIcon: Consumer<VocabularyProvider>(
              builder: (_, vocab, __) => _RememberNavIcon(
                dueCount: vocab.dueCount,
                filled: true,
              ),
            ),
            label: l10n.remember,
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
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
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

class _RememberNavIcon extends StatelessWidget {
  final int dueCount;
  final bool filled;

  const _RememberNavIcon({
    required this.dueCount,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(filled ? Icons.psychology : Icons.psychology_outlined),
        if (dueCount > 0)
          Positioned(
            top: -4,
            right: -10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                dueCount > 99 ? '99+' : '$dueCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
