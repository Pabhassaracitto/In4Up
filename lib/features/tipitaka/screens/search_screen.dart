import 'package:in4up/core/language/localized_material.dart';

import 'package:in4up/features/tipitaka/models/segment.dart';
import 'package:in4up/features/tipitaka/screens/download_screen.dart';
import 'package:in4up/features/tipitaka/services/db_service.dart';

class TipitakaSearchScreen extends StatefulWidget {
  const TipitakaSearchScreen({super.key});

  @override
  State<TipitakaSearchScreen> createState() => _TipitakaSearchScreenState();
}

class _TipitakaSearchScreenState extends State<TipitakaSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List<TipitakaSegment> results = [];
  bool searching = false;
  String? error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        results = [];
        error = null;
      });
      return;
    }
    setState(() {
      searching = true;
      error = null;
    });
    try {
      final db = await TipitakaDb.openReady();
      final found = await TipitakaDb.searchSegments(db, trimmed);
      if (mounted) setState(() => results = found);
    } catch (e) {
      if (mounted) {
        setState(() {
          results = [];
          error = e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tìm kiếm Tipiṭaka')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Từ khóa Pāli / bản dịch…',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _search(_controller.text),
                ),
              ),
              onSubmitted: _search,
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    context.uiText('Không thể mở cơ sở dữ liệu Tipiṭaka.'),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TipitakaDownloadScreen(),
                      ),
                    ),
                    child: const Text('Import hoặc tải dữ liệu'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: searching
                ? const Center(child: CircularProgressIndicator())
                : results.isEmpty && error == null
                    ? const Center(child: Text('Nhập từ khóa để tìm trong Tipiṭaka'))
                    : ListView.builder(
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          final segment = results[index];
                          final pali = segment.paliText;
                          return ListTile(
                            title: Text(segment.reference),
                            subtitle: Text(
                              pali.length > 120 ? '${pali.substring(0, 120)}…' : pali,
                            ),
                            trailing: segment.translationVi?.isNotEmpty == true
                                ? const Icon(Icons.translate)
                                : null,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
