import 'package:flutter/material.dart';
import 'package:in4up/features/tipitaka/screens/language_pack_screen.dart';
import 'package:in4up/features/tipitaka/screens/library_screen.dart';


class TipitakaDownloadScreen extends StatelessWidget {
  const TipitakaDownloadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tipiṭaka — Tải dữ liệu'),
        backgroundColor: const Color(0xFF1A1A2E),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dữ liệu kinh điển chưa sẵn sàng.',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            const Text(
              'Bạn có 2 cách để tích hợp Tam Tạng:',
              style: TextStyle(fontSize: 15, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Card(
              color: const Color(0xFF1A1A2E),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Cách 1 — Lập trình viên (Build)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFFF9800))),
                    const SizedBox(height: 8),
                    const Text('Đặt file tipitaka.sqlite (đã import từ nguồn) vào thư mục assets/db/ rồi rebuild app. Khi build có sẵn DB, app sẽ mở trực tiếp.', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: const Color(0xFF1A1A2E),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Cách 2 — Người dùng tải trong app (Settings)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFFF9800))),
                    const SizedBox(height: 8),
                    const Text('Tải file .db từ đường dẫn dưới, rồi chép vào thư mục ứng dụng hoặc qua Settings > Import DB.', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 12),
                    const Text('Nguồn tải:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 4),
                    SelectableText('https://dhamma.paauksociety.org/Root/Tipitaka/SqlLite%20Database/pali%20text/tipitaka-roman-pali.db.zip', style: const TextStyle(fontSize: 12, color: Colors.lightBlue)),
                    const SizedBox(height: 4),
                    SelectableText('https://dhamma.paauksociety.org/Root/Tipitaka/SqlLite%20Database/vietnamese_tipitaka_translation_data-2026-04-29.db.zip', style: const TextStyle(fontSize: 12, color: Colors.lightBlue)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TipsLanguagePackScreen()),
                );
              },
              icon: const Icon(Icons.language),
              label: const Text('Chọn gói ngôn ngữ / Language Packs'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TipitakaLibraryScreen()),
                );
              },
              icon: const Icon(Icons.menu_book_rounded),
              label: const Text('Thử mở thư viện (nếu DB đã có)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9800),
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}