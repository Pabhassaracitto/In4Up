import 'package:flutter/material.dart';
import 'package:in4up/features/tipitaka/models/segment.dart';
import 'package:in4up/features/tipitaka/services/db_service.dart';

class TipitakaSearchScreen extends StatefulWidget {
  const TipitakaSearchScreen({super.key});

  @override
  State<TipitakaSearchScreen> createState() => _TipitakaSearchScreenState();
}

class _TipitakaSearchScreenState extends State<TipitakaSearchScreen> {
  final TextEditingController _ctrl = TextEditingController();
  List<TipitakaSegment> results = [];
  bool searching = false;

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() => results = []);
      return;
    }
    setState(() => searching = true);
    try {
      final db = await TipitakaDb.init('/data/user/0/com.in2up/databases');
      final r = await TipitakaDb.searchSegments(db, q.trim());
      setState(() => results = r);
    } catch (_) {
      setState(() => results = []);
    } finally {
      setState(() => searching = false);
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
              controller: _ctrl,
              decoration: InputDecoration(
                hintText: 'Từ khóa Pāli / dịch thuật ...',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _search(_ctrl.text),
                ),
              ),
              onSubmitted: _search,
            ),
          ),
          Expanded(
            child: searching
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (ctx, i) {
                      final s = results[i];
                      return ListTile(
                        title: Text(s.reference),
                        subtitle: Text(s.paliText.length > 60 ? s.paliText.substring(0, 60) + '...' : s.paliText),
                        trailing: Text(s.translationVi != null && s.translationVi!.isNotEmpty ? '✓' : ''),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}