//main_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../widgets/mini_player.dart';
import 'read_mode/read_mode_screen.dart';
import 'listen_mode_screen.dart';
import 'understand_mode_screen.dart';
import 'text_library_drawer.dart';
import 'audio_library_drawer.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with TickerProviderStateMixin {
  int _currentIndex = 1; // Mặc định vào NGHE

  // Keys cho Scaffold để control Drawers
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Animation controller cho smooth transitions
  late AnimationController _transitionController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _transitionController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _transitionController, curve: Curves.easeInOut),
    );
    _transitionController.forward();
  }

  @override
  void dispose() {
    _transitionController.dispose();
    super.dispose();
  }

  // Lấy màu theme theo tab
  Color get _currentColor {
    switch (_currentIndex) {
      case 0:
        return const Color(0xFF2196F3); // Đọc - Blue
      case 1:
        return const Color(0xFF6C63FF); // Nghe - Purple
      case 2:
        return const Color(0xFFFFB300); // Hiểu - Amber
      case 3:
        return const Color(0xFF4CAF50); // Quick - Green
      default:
        return const Color(0xFF6C63FF);
    }
  }

  String get _currentTitle {
    switch (_currentIndex) {
      case 0:
        return '📖 Chế độ Đọc';
      case 1:
        return '🎧 Chế độ Nghe';
      case 2:
        return '💡 Chế độ Hiểu';
      case 3:
        return '⚡ Luyện tập nhanh';
      default:
        return 'VipSound';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF0F0F23),

      // LEFT DRAWER: Text Library
      drawer: const TextLibraryDrawer(),

      // RIGHT DRAWER: Audio Library
      endDrawer: const AudioLibraryDrawer(),

      // Cho phép vuốt để mở drawer
      drawerEnableOpenDragGesture: true,
      endDrawerEnableOpenDragGesture: true,

      body: SafeArea(
        child: Column(
          children: [
            // Custom App Bar
            _buildAppBar(),

            // Main Content
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: _buildCurrentScreen(),
              ),
            ),

            // Mini Player (luôn hiện khi có audio)
            Consumer<PlayerProvider>(
              builder: (context, player, _) {
                if (player.currentSongPath == null) {
                  return const SizedBox.shrink();
                }
                return const MiniPlayer(
                  margin: EdgeInsets.fromLTRB(12, 0, 12, 8),
                );
              },
            ),
          ],
        ),
      ),

      // Bottom Navigation
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        border: Border(
          bottom: BorderSide(
            color: _currentColor.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          // Menu button (mở Text Library)
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _scaffoldKey.currentState?.openDrawer();
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.menu_book,
                color: Color(0xFF2196F3),
                size: 20,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentTitle,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _currentColor,
                  ),
                ),
                Consumer<PlayerProvider>(
                  builder: (context, player, _) {
                    return Text(
                      player.currentSongTitle ?? 'Chưa chọn audio',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                ),
              ],
            ),
          ),

          // Mode indicator
          Consumer<PlayerProvider>(
            builder: (context, player, _) {
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  // Cycle modes
                  final modes = VipMode.values;
                  final idx = modes.indexOf(player.currentMode);
                  player.setMode(modes[(idx + 1) % modes.length]);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getModeColor(player.currentMode).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _getModeColor(player.currentMode).withOpacity(0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getModeIcon(player.currentMode),
                        size: 14,
                        color: _getModeColor(player.currentMode),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _getModeName(player.currentMode),
                        style: TextStyle(
                          color: _getModeColor(player.currentMode),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(width: 12),

          // Audio Library button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _scaffoldKey.currentState?.openEndDrawer();
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.library_music,
                color: Color(0xFF6C63FF),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentScreen() {
    switch (_currentIndex) {
      case 0:
        return const ReadModeScreen();
      case 1:
        return const ListenModeScreen();
      case 2:
        return const UnderstandModeScreen();
      case 3:
        return const QuickPracticeScreen();
      default:
        return const ListenModeScreen();
    }
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        border: Border(
          top: BorderSide(
            color: _currentColor.withOpacity(0.2),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(0, Icons.menu_book_outlined, Icons.menu_book, 'Đọc',
                  const Color(0xFF2196F3)),
              _buildNavItem(1, Icons.headphones_outlined, Icons.headphones,
                  'Nghe', const Color(0xFF6C63FF)),
              _buildNavItem(2, Icons.psychology_outlined, Icons.psychology,
                  'Hiểu', const Color(0xFFFFB300)),
              _buildNavItem(3, Icons.flash_on_outlined, Icons.flash_on, 'Quick',
                  const Color(0xFF4CAF50)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon,
      String label, Color color) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () {
        if (_currentIndex != index) {
          HapticFeedback.selectionClick();
          _transitionController.reset();
          setState(() => _currentIndex = index);
          _transitionController.forward();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? color : Colors.grey,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.grey,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getModeColor(VipMode mode) {
    switch (mode) {
      case VipMode.buddhism:
        return const Color(0xFFFFB300);
      case VipMode.english:
        return const Color(0xFF2196F3);
      case VipMode.music:
        return const Color(0xFF6C63FF);
    }
  }

  IconData _getModeIcon(VipMode mode) {
    switch (mode) {
      case VipMode.buddhism:
        return Icons.self_improvement;
      case VipMode.english:
        return Icons.school;
      case VipMode.music:
        return Icons.music_note;
    }
  }

  String _getModeName(VipMode mode) {
    switch (mode) {
      case VipMode.buddhism:
        return 'Phật Pháp';
      case VipMode.english:
        return 'Tiếng Anh';
      case VipMode.music:
        return 'Âm Nhạc';
    }
  }
}

// Placeholder screen - Quick Practice
class QuickPracticeScreen extends StatelessWidget {
  const QuickPracticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.flash_on,
                size: 64,
                color: Color(0xFF4CAF50),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Luyện tập nhanh',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ôn tập các đoạn đã lưu',
              style: TextStyle(color: Colors.grey[500]),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _FeatureRow(
                      icon: Icons.loop,
                      text: 'Lặp lại các segment đã đánh dấu'),
                  const SizedBox(height: 12),
                  _FeatureRow(
                      icon: Icons.shuffle, text: 'Ngẫu nhiên hoặc theo thứ tự'),
                  const SizedBox(height: 12),
                  _FeatureRow(
                      icon: Icons.timer, text: 'Theo dõi thời gian luyện tập'),
                  const SizedBox(height: 12),
                  _FeatureRow(
                      icon: Icons.trending_up, text: 'Thống kê tiến bộ'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Coming Soon',
                style: TextStyle(
                  color: Color(0xFF4CAF50),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF4CAF50), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey[400]),
          ),
        ),
      ],
    );
  }
}
