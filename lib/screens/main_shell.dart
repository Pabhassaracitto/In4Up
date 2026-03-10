// lib/screens/main_shell.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../screens/tools/tools_overlay.dart';
import '../providers/player_provider.dart';
import '../screens/listen_mode/widgets/mini_player.dart';
import '../screens/understand_mode/understand_tab_connector.dart';
import 'home/home_screen.dart';
import 'listen_mode/listen_mode_screen.dart';
import 'listen_mode/widgets/audio_library_drawer.dart';
import 'memory_mode/memory_mode.dart';
import 'read_mode/read_mode_screen.dart';
import 'text_library_drawer.dart';
// CHỈ lấy PuzzleNavButton (không kéo ToolItem từ file cũ vào nữa)
import 'tools/tools_overlay.dart' show PuzzleNavButton;
// Dùng overlay V2 + ToolItem V2 với prefix để khỏi trùng tên
import 'tools/tools_overlay_v2.dart' as tools;
import 'tools/word_list/word_list_screen.dart';
import 'tools/youglish/youglish_screen.dart';
// Các màn hình tools — import khi cần
// import 'tools/word_map_screen.dart';
// import 'tools/venn_screen.dart';

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

  // ─── Navigation ──────────────────────────────────────────
  void _onTabTapped(int tappedIndex) {
    HapticFeedback.selectionClick();
    if (_currentIndex == tappedIndex) {
      _navigateTo(_kHome);
    } else {
      _navigateTo(tappedIndex);
    }
  }

  void _navigateTo(int index) {
    if (_currentIndex == index) return;
    _transitionController.reset();
    setState(() => _currentIndex = index);
    _transitionController.forward();
  }

  // ─── Tools overlay ───────────────────────────────────────
  Future<void> _openTools() async {
    final toolId = await tools.showToolsOverlayV2(
      context,
      tools: _buildToolsList(),
    );

    if (!mounted || toolId == null) return;

    _handleToolNavigation(toolId);
  }

  void _handleToolNavigation(String toolId) {
    switch (toolId) {
      case 'word_list':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WordListScreen()),
        );
        break;
      case 'youglish':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const YouGlishScreen()),
        );
        break;
      case 'word_map':
        // TODO
        break;
      case 'venn':
        // TODO
        break;
      case 'assessment':
        // TODO
        break;
      case 'stats':
        // TODO
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
        color: const Color(0xFF6C63FF),
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
        id: 'word_map',
        title: 'Bản Đồ Từ',
        subtitle: 'Biết → nhỏ · Chưa biết → to',
        icon: Icons.map_outlined,
        color: Color(0xFF26C6DA),
        isAvailable: true,
      ),
      const tools.ToolItem(
        id: 'venn',
        title: 'Biểu Đồ Venn',
        subtitle: 'Hiểu · Nghe · Đọc',
        icon: Icons.hub_outlined,
        color: Color(0xFFAB47BC),
        isAvailable: true,
      ),
      const tools.ToolItem(
        id: 'assessment',
        title: 'Đánh Giá',
        subtitle: 'Kiểm tra 3 chiều',
        icon: Icons.quiz_outlined,
        color: Color(0xFFFF7043),
        isAvailable: true,
      ),
      const tools.ToolItem(
        id: 'stats',
        title: 'Thống Kê',
        subtitle: 'Tiến trình học tập',
        icon: Icons.bar_chart_rounded,
        color: Color(0xFF42A5F5),
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
        subtitle: 'Nghe → viết lại',
        icon: Icons.edit_note_outlined,
        color: Color(0xFFFFCA28),
        isAvailable: false,
      ),
    ];
  }

  // ─── Theme ───────────────────────────────────────────────
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
        return const Color(0xFF6C63FF);
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
      body: SafeArea(
        child: Column(
          children: [
            if (!_isHome) _buildTabAppBar(),
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: _buildCurrentScreen(),
              ),
            ),
            RepaintBoundary(
              child: Consumer<PlayerProvider>(
                builder: (context, player, _) {
                  if (player.currentSongPath == null) {
                    return const SizedBox.shrink();
                  }
                  return GestureDetector(
                    onTap: _isHome ? () => _navigateTo(1) : null,
                    child: const MiniPlayer(
                      margin: EdgeInsets.fromLTRB(12, 0, 12, 8),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ─── App Bar ─────────────────────────────────────────────
  Widget _buildTabAppBar() {
    final titles = {
      0: '📖 Chế độ Đọc',
      1: '🎧 Chế độ Nghe',
      2: '💡 Chế độ Hiểu',
      3: '🧠 Vườn Trí Nhớ',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        border: Border(
          bottom: BorderSide(color: _currentColor.withOpacity(0.2)),
        ),
      ),
      child: Row(
        children: [
          _AppBarIconButton(
            icon: Icons.menu_book,
            color: const Color(0xFF2196F3),
            onTap: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titles[_currentIndex] ?? 'VipSound',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: _currentColor,
                  ),
                ),
                Consumer<PlayerProvider>(
                  builder: (context, player, _) {
                    if (player.currentSongTitle == null) {
                      return const SizedBox.shrink();
                    }
                    return Text(
                      player.currentSongTitle!,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                ),
              ],
            ),
          ),
          _AppBarIconButton(
            icon: Icons.library_music,
            color: const Color(0xFF6C63FF),
            onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
    );
  }

  // ─── Screen Router ───────────────────────────────────────
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

  // ─── Bottom Navigation ───────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        border: Border(
          top: BorderSide(
            color: _isHome
                ? Colors.white.withOpacity(0.06)
                : _currentColor.withOpacity(0.2),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              // 🏠 Home — trái nhất
              _HomeNavButton(
                isActive: _isHome,
                onTap: () {
                  if (!_isHome) {
                    HapticFeedback.selectionClick();
                    _navigateTo(_kHome);
                  }
                },
              ),

              // Divider
              Container(
                width: 1,
                height: 32,
                color: Colors.white.withOpacity(0.06),
              ),

              // Tabs giữa
              _NavButton(
                tabIndex: 0,
                currentIndex: _currentIndex,
                icon: Icons.menu_book_outlined,
                activeIcon: Icons.menu_book,
                label: 'Đọc',
                color: const Color(0xFF2196F3),
                onTap: () => _onTabTapped(0),
              ),
              _NavButton(
                tabIndex: 1,
                currentIndex: _currentIndex,
                icon: Icons.headphones_outlined,
                activeIcon: Icons.headphones,
                label: 'Nghe',
                color: const Color(0xFF6C63FF),
                onTap: () => _onTabTapped(1),
              ),
              _NavButton(
                tabIndex: 2,
                currentIndex: _currentIndex,
                icon: Icons.lightbulb_outline,
                activeIcon: Icons.lightbulb,
                label: 'Hiểu',
                color: const Color(0xFFFFB300),
                onTap: () => _onTabTapped(2),
              ),
              _NavButton(
                tabIndex: 3,
                currentIndex: _currentIndex,
                icon: Icons.psychology_outlined,
                activeIcon: Icons.psychology,
                label: 'Nhớ',
                color: const Color(0xFF4CAF50),
                onTap: () => _onTabTapped(3),
              ),

              // Divider
              Container(
                width: 1,
                height: 32,
                color: Colors.white.withOpacity(0.06),
              ),

              // 🧩 Tools — phải nhất, đối lập Home
              PuzzleNavButton(onTap: _openTools),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Nav Widgets (giữ nguyên từ file cũ) ─────────────────

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
          color: isActive ? Colors.white.withOpacity(0.08) : Colors.transparent,
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
            Text(
              'Home',
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey[600],
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
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
            color: isSelected ? color.withOpacity(0.12) : Colors.transparent,
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
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? color : Colors.grey[600],
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
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
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}
