import 'package:animations/animations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../features/pdf_reader/pdf_reader_screen.dart';
import '../features/web_reader/web_reader_screen.dart';
import '../features/youtube/youtube_explorer_screen.dart';
import '../providers/player_provider.dart';
import '../providers/vocabulary_bridge.dart';
import '../providers/vocabulary_provider.dart';
import 'home/home_screen.dart';
import 'settings/stt_model_settings_screen.dart';
import 'listen_mode/listen_mode_screen.dart';
import 'listen_mode/widgets/audio_library_drawer.dart';
import 'listen_mode/widgets/mini_player.dart';
import 'memory_mode/memory_mode.dart';
import 'read_mode/read_mode_screen.dart';
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

const int _kHome = -1;

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with TickerProviderStateMixin {
  int _currentIndex = _kHome;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late AnimationController _transitionController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // ✅ Init VocabularyBridge với provider từ context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vocabProvider = context.read<VocabularyProvider>();
      VocabularyBridge.init(vocabProvider);
    });

    _transitionController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _transitionController, curve: Curves.easeOut),
    );
    _transitionController.forward();
  }

  @override
  void dispose() {
    _transitionController.dispose();
    super.dispose();
  }

  void _onTabTapped(int idx) {
    HapticFeedback.selectionClick();
    if (_currentIndex == idx) {
      _navigateTo(_kHome);
    } else {
      _navigateTo(idx);
    }
  }

  void _navigateTo(int index) {
    if (_currentIndex == index) return;
    _transitionController.reset();
    setState(() => _currentIndex = index);
    _transitionController.forward();
  }

  bool get _isHome => _currentIndex == _kHome;

  Color get _currentColor {
    switch (_currentIndex) {
      case 0:
        return const Color(0xFF2196F3);
      case 1:
        return const Color(0xFF6C63FF);
      case 2:
        return const Color(0xFFFFB300);
      case 3:
        return const Color(0xFF4CAF50);
      default:
        return Colors.white;
    }
  }

  // ─── Tools ───────────────────────────────────────────────
  Future<void> _openTools() async {
    final nav = Navigator.of(context);
    final vocabProvider = context.read<VocabularyProvider>();

    final toolId = await tools.showToolsOverlayV2(
      context,
      tools: _buildToolsList(),
    );

    if (toolId == null) return;

    void pushVocab(String title, Color color, Widget child) {
      nav.push(MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<VocabularyProvider>.value(
          value: vocabProvider,
          child: _ToolPage(title: title, color: color, child: child),
        ),
      ));
    }

    switch (toolId) {
      case 'word_list':
        nav.push(MaterialPageRoute(builder: (_) => const WordListScreen()));
        break;

      case 'timeline':
        nav.push(MaterialPageRoute(builder: (_) => const TimelineView()));
        break;

      case 'wordlist_stats':
        nav.push(MaterialPageRoute(builder: (_) => const StatsDashboard()));
        break;

      case 'web_reader':
        nav.push(MaterialPageRoute(builder: (_) => const WebReaderScreen()));
        break;

      // ★ FIX: YouTube Explorer thay vì sheet
      case 'youtube_downloader':
        nav.push(MaterialPageRoute(
          builder: (_) => const YoutubeExplorerScreen(
            apiKey: 'AIzaSy...YOUR_KEY_HERE', // ← dán key vào đây
          ),
        ));
        break;

      case 'pdf_reader':
        final result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
        );
        if (result != null && result.files.single.path != null) {
          nav.push(MaterialPageRoute(
            builder: (_) => PdfReaderScreen(pdfPath: result.files.single.path!),
          ));
        }
        break;

      case 'youglish':
        nav.push(MaterialPageRoute(builder: (_) => const YouGlishScreen()));
        break;

      case 'stats':
        pushVocab('Tổng quan', const Color(0xFF42A5F5), const StatsTab());
        break;

      case 'word_map':
        pushVocab('Bản đồ từ', const Color(0xFF26C6DA), const MapTab());
        break;

      case 'triangle':
        pushVocab(
            'Tam giác kỹ năng', const Color(0xFFFFA726), const TriangleTab());
        break;

      case 'venn':
        pushVocab('Biểu đồ Venn', const Color(0xFFAB47BC), const VennTab());
        break;

      case 'review':
        pushVocab('Ôn tập', const Color(0xFF66BB6A), const ReviewTab());
        break;
    }
  }

  List<tools.ToolItem> _buildToolsList() {
    return [
      const tools.ToolItem(
        id: 'word_list',
        title: 'Word List',
        subtitle: 'Danh sách từ vựng',
        icon: Icons.format_list_bulleted,
        color: Color(0xFF6C63FF),
        isAvailable: true,
      ),
      const tools.ToolItem(
        id: 'timeline',
        title: 'Timeline',
        subtitle: 'Hành trình học từ theo thời gian',
        icon: Icons.timeline,
        color: Color(0xFF9C27B0),
        isAvailable: true,
      ),
      const tools.ToolItem(
        id: 'wordlist_stats',
        title: 'Wordlist Stats',
        subtitle: 'Thống kê từ vựng chi tiết',
        icon: Icons.analytics_outlined,
        color: Color(0xFF42A5F5),
        isAvailable: true,
      ),

      const tools.ToolItem(
        id: 'web_reader',
        title: 'Web Reader',
        subtitle: 'Đọc web + highlight CEFR',
        icon: Icons.language,
        color: Color(0xFF26A69A),
        isAvailable: true,
      ),
      // ★ YouTube Explorer — title thay đổi để rõ hơn
      const tools.ToolItem(
        id: 'youtube_downloader',
        title: 'YouTube',
        subtitle: 'Khám phá kênh học tiếng Anh',
        icon: Icons.play_circle_filled,
        color: Color(0xFFFF0000),
        isAvailable: true,
      ),
      const tools.ToolItem(
        id: 'pdf_reader',
        title: 'PDF Reader',
        subtitle: 'Mở và đọc file PDF',
        icon: Icons.picture_as_pdf,
        color: Color(0xFFEF5350),
        isAvailable: true,
      ),
      const tools.ToolItem(
        id: 'youglish',
        title: 'YouGlish',
        subtitle: 'Nghe phát âm chuẩn',
        icon: Icons.record_voice_over,
        color: Color(0xFF00BCD4),
        isAvailable: true,
      ),
      const tools.ToolItem(
        id: 'stats',
        title: 'Tổng Quan',
        subtitle: 'Tiến trình học tập',
        icon: Icons.bar_chart_rounded,
        color: Color(0xFF42A5F5),
        isAvailable: true,
      ),
      const tools.ToolItem(
        id: 'word_map',
        title: 'Bản Đồ Từ',
        subtitle: 'Biết → nhỏ · Chưa biết → to',
        icon: Icons.map_outlined,
        color: Color(0xFF26C6DA),
        isAvailable: true,
      ),
      const tools.ToolItem(
        id: 'triangle',
        title: 'Tam Giác',
        subtitle: 'Bản đồ + Đánh giá nhanh',
        icon: Icons.change_history_rounded,
        color: Color(0xFFFFA726),
        isAvailable: true,
      ),
      const tools.ToolItem(
        id: 'venn',
        title: 'Biểu Đồ Venn',
        subtitle: 'Phân vùng kỹ năng',
        icon: Icons.hub_outlined,
        color: Color(0xFFAB47BC),
        isAvailable: true,
      ),
      const tools.ToolItem(
        id: 'review',
        title: 'Ôn Tập',
        subtitle: 'SM-2 Spaced Repetition',
        icon: Icons.school,
        color: Color(0xFF66BB6A),
        isAvailable: true,
      ),
      const tools.ToolItem(
        id: 'shadowing',
        title: 'Shadowing',
        subtitle: 'Luyện nói theo bóng',
        icon: Icons.record_voice_over_outlined,
        color: Color(0xFF66BB6A),
        isAvailable: false,
      ),
      const tools.ToolItem(
        id: 'dictation',
        title: 'Chính Tả',
        subtitle: 'Nghe và gõ lại',
        icon: Icons.edit_note,
        color: Color(0xFFFF7043),
        isAvailable: false,
      ),
    ];
  }

  // ─── Screen router ───────────────────────────────────────
  Widget _buildCurrentScreen() {
    switch (_currentIndex) {
      case _kHome:
        return HomeScreen(
          onNavigateToListen: () => _navigateTo(1),
          onNavigateToRead: () => _navigateTo(0),
          onNavigateToUnderstand: () => _navigateTo(2),
          onNavigateToMemory: () => _navigateTo(3),
        );
      case 0:
        return const ReadModeScreen();
      case 1:
        return const ListenModeScreen();
      case 2:
        return const UnderstandTabConnector();
      case 3:
        return const MemoryTabConnector();
      default:
        return HomeScreen(
          onNavigateToListen: () => _navigateTo(1),
          onNavigateToRead: () => _navigateTo(0),
          onNavigateToUnderstand: () => _navigateTo(2),
          onNavigateToMemory: () => _navigateTo(3),
        );
    }
  }

  // ─── Build ───────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF080B1A),
      drawer: const TextLibraryDrawer(),
      endDrawer: const AudioLibraryDrawer(),
      drawerEnableOpenDragGesture: !_isHome,
      endDrawerEnableOpenDragGesture: !_isHome,
      body: Column(
        children: [
          _buildAppBar(),
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: _buildCurrentScreen(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildAppBar() {
    final titles = {
      0: 'Chế độ Đọc',
      1: 'Chế độ Nghe',
      2: 'Chế độ Hiểu',
      3: 'Vườn Trí Nhớ',
    };

    final tabColors = {
      0: const Color(0xFF2196F3),
      1: const Color(0xFF6C63FF),
      2: const Color(0xFFFFB300),
      3: const Color(0xFF4CAF50),
    };

    final String titleText =
        _isHome ? 'VipSound' : (titles[_currentIndex] ?? 'VipSound');

    final Color titleColor =
        _isHome ? Colors.white : (tabColors[_currentIndex] ?? Colors.white);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        border: Border(
          bottom: BorderSide(
            color: _isHome
                ? Colors.white.withValues(alpha: 0.06)
                : titleColor.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          // ── Trái: Text Library / Model AI button ──────────────────────────
          if (_isHome)
            _LibraryButton(
              icon: Icons.smart_toy_outlined,
              color: const Color(0xFFFF9800),
              tooltip: 'Quản lý Model AI',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SttModelSettingsScreen()),
                );
              },
            )
          else
            _LibraryButton(
              icon: Icons.menu_book_rounded,
              color: const Color(0xFF2196F3),
              tooltip: 'Thư viện văn bản',
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
            ),

          // ── Giữa: Tab title ────────────────────────────────────
          Expanded(
            child: GestureDetector(
              // Tap vào title khi ở Home → không làm gì
              // Tap khi ở tab → cũng không làm gì (title thuần display)
              onTap: () {},
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon + tên tab
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      _isHome ? '🎵 VipSound' : _tabEmoji + titleText,
                      key: ValueKey(_currentIndex),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: _isHome ? 18 : 15,
                        fontWeight: FontWeight.bold,
                        color: titleColor,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  // Song đang phát (nhỏ bên dưới)
                  Consumer<PlayerProvider>(
                    builder: (_, player, __) {
                      if (player.currentSongTitle == null) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.music_note,
                              size: 9,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                player.currentSongTitle!,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // ── Phải: Audio Library button ─────────────────────────
          _LibraryButton(
            icon: Icons.library_music_rounded,
            color: const Color(0xFF6C63FF),
            tooltip: 'Thư viện âm thanh',
            onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
    );
  }

// ★ THÊM: Helper lấy emoji theo tab
  String get _tabEmoji {
    switch (_currentIndex) {
      case 0:
        return '📖 ';
      case 1:
        return '🎧 ';
      case 2:
        return '💡 ';
      case 3:
        return '🧠 ';
      default:
        return '';
    }
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        border: Border(
          top: BorderSide(
            color: _isHome
                ? Colors.white.withValues(alpha: 0.06)
                : _currentColor.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: NavigationBar(
        selectedIndex: _currentIndex == _kHome ? 0 : _currentIndex + 1,
        onDestinationSelected: (idx) {
          if (idx == 0) {
            _navigateTo(_kHome);
          } else if (idx <= 4)
            _onTabTapped(idx - 1);
          else if (idx == 5) _openTools();
        },
        backgroundColor: const Color(0xFF111827),
        indicatorColor: _currentColor.withValues(alpha: 0.2),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Đọc',
          ),
          const NavigationDestination(
            icon: Icon(Icons.headphones_outlined),
            selectedIcon: Icon(Icons.headphones),
            label: 'Nghe',
          ),
          const NavigationDestination(
            icon: Icon(Icons.lightbulb_outline),
            selectedIcon: Icon(Icons.lightbulb),
            label: 'Hiểu',
          ),
          const NavigationDestination(
            icon: Icon(Icons.psychology_outlined),
            selectedIcon: Icon(Icons.psychology),
            label: 'Nhớ',
          ),
          NavigationDestination(
            icon: Consumer<VocabularyProvider>(
              builder: (_, vocab, __) {
                final due = vocab.dueCount;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.extension_outlined), // ★ Icon thường
                    /*const IgnorePointer(
                        child: PuzzleNavButton(
                            onTap: null)),*/ // UI placeholder inside Nav
                    if (due > 0)
                      Positioned(
                        top: -2,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            due > 99 ? '99+' : '$due',
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
              },
            ),
            label: 'Tools',
          ),
        ],
      ),
    );
  }
}

// ─── Tool Page Wrapper ───────────────────────────────────
class _ToolPage extends StatelessWidget {
  final String title;
  final Widget child;
  final Color color;

  const _ToolPage(
      {required this.title, required this.child, required this.color});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF080B1A),
        appBarTheme:
            const AppBarTheme(backgroundColor: Color(0xFF1A1A2E), elevation: 0),
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

// ─── Nav Widgets ─────────────────────────────────────────
class _HomeNavButton extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;
  const _HomeNavButton({required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 56,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.transparent,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isActive ? Icons.home : Icons.home_outlined,
                key: ValueKey(isActive),
                color: isActive ? Colors.white : Colors.grey[600],
                size: 22,
              ),
            ),
            const SizedBox(height: 4),
            Text('Home',
                style: TextStyle(
                    color: isActive ? Colors.white : Colors.grey[600],
                    fontSize: 10,
                    fontWeight:
                        isActive ? FontWeight.w700 : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final int tabIndex, currentIndex;
  final IconData icon, activeIcon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _NavButton({
    required this.tabIndex,
    required this.currentIndex,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  bool get isSelected => currentIndex == tabIndex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color:
                isSelected ? color.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  isSelected ? activeIcon : icon,
                  key: ValueKey(isSelected),
                  color: isSelected ? color : Colors.grey[600],
                  size: 22,
                ),
              ),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      color: isSelected ? color : Colors.grey[600],
                      fontSize: 10,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppBarIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _AppBarIconButton(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

// ── Library Button — dùng cho cả Text và Audio library ───────
class _LibraryButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _LibraryButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: color.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ≡ menu lines
              Icon(
                Icons.menu_rounded,
                size: 13,
                color: color.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 4),
              // Main icon
              Icon(
                icon,
                size: 18,
                color: color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
