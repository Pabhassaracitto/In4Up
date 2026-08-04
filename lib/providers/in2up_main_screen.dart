import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/listen_mode/listen_mode_screen.dart'; // Correct path
import '../screens/listen_mode/widgets/mini_player.dart'; // Correct path
import 'player_provider.dart'; // Correct path

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // Danh sách các màn hình.
  // Lưu ý: Không khởi tạo trước ở đây để tránh chiếm RAM.
  Widget _buildTabContent(int index) {
    switch (index) {
      case 0:
        return const Center(child: Text('Home Screen (Nhẹ)'));
      case 1:
        // Khi chuyển sang Tab khác, ListenModeScreen sẽ bị dispose hoàn toàn
        return const ListenModeScreen();
      case 2:
        return const Center(child: Text('Read Mode (PDF - Nặng)'));
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1520),
      body: Stack(
        children: [
          // Sử dụng AnimatedSwitcher để tạo hiệu ứng chuyển Tab mượt mà
          // đồng thời đảm bảo Widget cũ bị unmount và gọi dispose()
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: KeyedSubtree(
                key: ValueKey<int>(_currentIndex),
                child: _buildTabContent(_currentIndex),
              ),
            ),
          ),

          // MiniPlayer luôn nổi lên trên, nhưng nó chỉ là UI control nhẹ
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Consumer<PlayerProvider>(
              builder: (context, player, _) {
                if (player.currentSongPath == null) {
                  return const SizedBox.shrink();
                }
                return const MiniPlayer();
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        backgroundColor: const Color(0xFF16162A),
        selectedItemColor: const Color(0xFF6C63FF),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.headphones), label: 'Nghe'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Đọc'),
        ],
      ),
    );
  }
}
