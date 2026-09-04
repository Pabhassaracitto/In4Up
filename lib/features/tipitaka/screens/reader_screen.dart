import 'package:in4up/core/language/localized_material.dart';

import 'package:in4up/features/tipitaka/models/segment.dart';
import 'package:in4up/features/tipitaka/screens/download_screen.dart';
import 'package:in4up/features/tipitaka/services/db_service.dart';

class TipitakaReaderScreen extends StatefulWidget {
  final int bookId;
  final String bookCode;

  const TipitakaReaderScreen({
    super.key,
    required this.bookId,
    required this.bookCode,
  });

  @override
  State<TipitakaReaderScreen> createState() => _TipitakaReaderScreenState();
}

class _TipitakaReaderScreenState extends State<TipitakaReaderScreen> {
  List<TipitakaSegment> segments = [];
  int currentIndex = 0;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() {
      loading = true;
      error = null;
    });
    try {
      final db = await TipitakaDb.openReady();
      final loaded = await TipitakaDb.getSegmentsByBook(
        db,
        widget.bookId,
        limit: 50,
      );
      if (!mounted) return;
      setState(() {
        segments = loaded;
        currentIndex = 0;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        segments = [];
        loading = false;
        error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: Text('${widget.bookCode} — Tipiṭaka')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.uiText('Không thể mở cơ sở dữ liệu Tipiṭaka.'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TipitakaDownloadScreen(),
                    ),
                  ),
                  child: const Text('Quản lý dữ liệu'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final segment = segments.isNotEmpty ? segments[currentIndex] : null;
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.bookCode} — ${segment?.reference ?? ''}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_border),
            tooltip: context.uiText('Đánh dấu'),
            onPressed: segment == null
                ? null
                : () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Tính năng đánh dấu sẽ lưu trong DB người dùng.'),
                      ),
                    ),
          ),
          IconButton(
            icon: const Icon(Icons.note_add),
            tooltip: context.uiText('Ghi chú'),
            onPressed: segment == null ? null : () {},
          ),
        ],
      ),
      body: segment == null
          ? const Center(child: Text('Sách này chưa có đoạn kinh.'))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Chip(label: Text(segment.reference)),
                  const SizedBox(height: 12),
                  Text('Pāli', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  SelectableText(
                    segment.paliText,
                    style: const TextStyle(
                      fontFamily: 'NotoSerifPali',
                      fontSize: 18,
                    ),
                  ),
                  const Divider(height: 24),
                  Text(
                    'Bản dịch tiếng Việt',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  SelectableText(segment.translationVi ?? '—'),
                  const SizedBox(height: 12),
                  Text('English', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  SelectableText(segment.translationEn ?? '—'),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        onPressed: currentIndex > 0
                            ? () => setState(() => currentIndex--)
                            : null,
                        child: const Text('Trước'),
                      ),
                      ElevatedButton(
                        onPressed: currentIndex < segments.length - 1
                            ? () => setState(() => currentIndex++)
                            : null,
                        child: const Text('Tiếp'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
