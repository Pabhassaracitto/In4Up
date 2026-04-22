import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../web_reader_controller.dart';

class WebReaderHomeView extends StatelessWidget {
  final WebReaderController controller;
  final Function(String url) onNavigate;

  const WebReaderHomeView({
    super.key,
    required this.controller,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0D1117),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroSection(),
            const SizedBox(height: 32),
            _buildSectionTitle('Gợi ý phổ biến', Icons.explore_outlined),
            _buildPresetsGrid(),
            const SizedBox(height: 32),
            _buildSectionTitle('Gần đây & Yêu thích', Icons.history),
            _buildRecentList(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Web Reader',
          style: TextStyle(
            color: Colors.blue[400],
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Khám phá kiến thức',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Nhập URL hoặc chọn một trang web bên dưới để bắt đầu trích xuất văn bản.',
          style: TextStyle(color: Colors.grey[500], fontSize: 14, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetsGrid() {
    final presets = [
      {'name': 'BBC News', 'url': 'https://www.bbc.com/news', 'icon': '🌍'},
      {'name': 'Wikipedia', 'url': 'https://en.wikipedia.org', 'icon': '📚'},
      {'name': 'CNN', 'url': 'https://edition.cnn.com', 'icon': '📺'},
      {'name': 'Medium', 'url': 'https://medium.com', 'icon': '✍️'},
      {
        'name': 'The Guardian',
        'url': 'https://www.theguardian.com',
        'icon': '📰'
      },
      {'name': 'Reuters', 'url': 'https://www.reuters.com', 'icon': '📉'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: presets.length,
      itemBuilder: (context, index) {
        final site = presets[index];
        return InkWell(
          onTap: () => onNavigate(site['url']!),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(site['icon']!, style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 8),
                Text(
                  site['name']!,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentList() {
    // Trong thực tế, bạn sẽ lấy dữ liệu này từ controller hoặc local database (Hive/Prefs)
    // Đây là ví dụ hiển thị logic Bookmark hiện có của bạn
    final bookmarks = controller.bookmarks;

    if (bookmarks.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.05),
              style: BorderStyle.solid),
        ),
        child: Column(
          children: [
            Icon(Icons.bookmark_border, color: Colors.grey[800], size: 32),
            const SizedBox(height: 12),
            Text(
              'Chưa có trang web nào được lưu',
              style: TextStyle(color: Colors.grey[700], fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: bookmarks.length,
      itemBuilder: (context, index) {
        final entry = bookmarks[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          leading: const Icon(Icons.link, color: Colors.blue, size: 20),
          title: Text(
            entry.title.isNotEmpty ? entry.title : entry.url,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            icon: const Icon(Icons.arrow_forward_ios,
                size: 12, color: Colors.grey),
            onPressed: () => onNavigate(entry.url),
          ),
          onTap: () {
            HapticFeedback.lightImpact();
            onNavigate(entry.url);
          },
        );
      },
    );
  }
}
