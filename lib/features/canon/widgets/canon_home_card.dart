// lib/features/canon/widgets/canon_home_card.dart
//
// Card hiển thị trên Home — truy cập nhanh Kho Kinh Chuẩn.
// Đặt vào HomeScreen SliverList để demo PoC.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/interfaces/canon_repository.dart';
import 'canon_search_sheet.dart';

class CanonHomeCard extends StatelessWidget {
  const CanonHomeCard({super.key});

  @override
  Widget build(BuildContext context) {
    // Lấy repo từ Provider, nếu chưa init thì init lazy
    final repo = context.read<CanonRepository>();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B2838), Color(0xFF2D1B2D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD54F).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.menu_book_rounded, color: Color(0xFFFFD54F), size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Kho Kinh Chuẩn',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                    Text('Offline 100% • .md + FTS',
                        style: TextStyle(color: Colors.white54, fontSize: 11)),
                  ],
                ),
              ),
              FutureBuilder(
                future: repo.isReady ? Future.value(null) : repo.init(),
                builder: (ctx, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24),
                    );
                  }
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(20)),
                    child: Text('${repo.count} bài',
                        style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Kinh Pháp Cú, Kinh Niệm Xứ, Kinh Chuyển Pháp Luân và nhiều hơn nữa — tìm kiếm tức thì, có dấu/không dấu, Pali/Việt.',
            style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD54F),
                    foregroundColor: const Color(0xFF1A1A2E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () async {
                    if (!repo.isReady) await repo.init();
                    if (!context.mounted) return;
                    CanonSearchSheet.show(context, repo);
                  },
                  icon: const Icon(Icons.search, size: 16),
                  label: const Text('Tìm kiếm FTS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () async {
                    if (!repo.isReady) await repo.init();
                    if (!context.mounted) return;
                    final all = repo.getAll();
                    if (all.isEmpty) return;
                    // mở bài đầu tiên để demo duyệt kho
                    final first = all.first;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CanonReaderScreen(repository: repo, canonId: first.id),
                      ),
                    );
                  },
                  icon: const Icon(Icons.auto_stories, size: 16),
                  label: const Text('Duyệt kho', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Thử gõ: "niệm xứ", "niem xu" (không dấu), "chanh niem", "khổ", "trung đạo", "dhammapada"',
            style: TextStyle(color: Colors.white24, fontSize: 10, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}
