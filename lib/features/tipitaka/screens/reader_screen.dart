import 'package:flutter/material.dart';
import 'package:in4up/features/tipitaka/models/segment.dart';
import 'package:in4up/features/tipitaka/services/db_service.dart';

class TipitakaReaderScreen extends StatefulWidget {
  final int bookId;
  final String bookCode;
  const TipitakaReaderScreen({super.key, required this.bookId, required this.bookCode});

  @override
  State<TipitakaReaderScreen> createState() => _TipitakaReaderScreenState();
}

class _TipitakaReaderScreenState extends State<TipitakaReaderScreen> {
  List<TipitakaSegment> segments = [];
  int currentIndex = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final db = await TipitakaDb.init('/data/user/0/com.in2up/databases');
      final segs = await TipitakaDb.getSegmentsByBook(db, widget.bookId, limit: 50);
      setState(() {
        segments = segs;
        loading = false;
      });
    } catch (_) {
      // Placeholder segments for demonstration
      setState(() {
        segments = [
          const TipitakaSegment(
            id: 1,
            bookId: 1,
            reference: 'DN 1.1',
            paragraphNo: 1,
            paliText: 'Evaṃ me sutaṃ — ekaṃ samayaṃ bhagavā ...',
            translationEn: 'Thus have I heard — on one occasion the Blessed One ...',
            translationVi: 'Như vầy tôi nghe — một thời Thế Tôn ...',
            orderIndex: 1,
          ),
          const TipitakaSegment(
            id: 2,
            bookId: 1,
            reference: 'DN 1.2',
            paragraphNo: 2,
            paliText: 'So evaṃ jānāti: “Yaṃ kiñci samudayadhammaṃ ...”',
            translationEn: 'He knows thus: “Whatever is subject to origination ...”',
            translationVi: 'Người ấy biết như vậy: “Pháp gì là pháp có điều kiện sanh khởi ...”',
            orderIndex: 2,
          ),
        ];
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final seg = segments.isNotEmpty ? segments[currentIndex] : null;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.bookCode} — ${seg?.reference ?? ''}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_border),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.note_add),
            onPressed: () {},
          ),
        ],
      ),
      body: seg == null
          ? const Center(child: Text('Chưa có dữ liệu segment'))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Chip(label: Text(seg.reference)),
                  const SizedBox(height: 12),
                  Text('Pāli', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  SelectableText(
                    seg.paliText,
                    style: const TextStyle(fontFamily: 'NotoSerifPali', fontSize: 18),
                  ),
                  const Divider(height: 24),
                  Text('Bản dịch tiếng Việt', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  SelectableText(seg.translationVi ?? '—'),
                  const SizedBox(height: 12),
                  Text('English', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  SelectableText(seg.translationEn ?? '—'),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        onPressed: currentIndex > 0 ? () => setState(() => currentIndex--) : null,
                        child: const Text('Trước'),
                      ),
                      ElevatedButton(
                        onPressed: currentIndex < segments.length - 1 ? () => setState(() => currentIndex++) : null,
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