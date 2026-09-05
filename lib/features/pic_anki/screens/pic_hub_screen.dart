import 'dart:io';

import 'package:flutter/material.dart' as m show Text;
import 'package:in4up/core/language/localized_material.dart';

import '../models/pic_models.dart';
import '../services/pic_anki_store.dart';
import 'pic_editor_screen.dart';
import 'pic_express_screen.dart';
import 'pic_review_screen.dart';

class PicHubScreen extends StatefulWidget {
  const PicHubScreen({super.key});

  @override
  State<PicHubScreen> createState() => _PicHubScreenState();
}

class _PicHubScreenState extends State<PicHubScreen> {
  final _store = PicAnkiStore.instance;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onChange);
    _store.ensureInit();
  }

  @override
  void dispose() {
    _store.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _import() async {
    final path = await pickPicAnkiImage();
    if (path == null || !mounted) return;
    final deck = await _store.importImage(path);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PicEditorScreen(deck: deck)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final decks = _store.decks;
    return Scaffold(
      backgroundColor: const Color(0xFF080B1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(context.uiText('Pic Anki & Express')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _import,
        backgroundColor: const Color(0xFF66BB6A),
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: Text(context.uiText('Thêm ảnh')),
      ),
      body: decks.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  context.uiText(
                    'Chưa có bộ ảnh. Thêm hình, che vùng để đố, gắn entity để miêu tả.',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              itemCount: decks.length,
              itemBuilder: (context, i) {
                final d = decks[i];
                final due = d.dueCount(now);
                return Card(
                  color: const Color(0xFF1A1A2E),
                  child: ListTile(
                    leading: _thumb(d),
                    title: m.Text(
                      d.title,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      '${d.masks.length} ${context.uiText('vùng')} · ${d.entities.length} entity · $due ${context.uiText('đến hạn')}',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PicEditorScreen(deck: d),
                      ),
                    ),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          tooltip: context.uiText('Ôn che hình'),
                          onPressed: d.masks.isEmpty
                              ? null
                              : () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => PicReviewScreen(deck: d),
                                    ),
                                  ),
                          icon: Badge(
                            isLabelVisible: due > 0,
                            label: Text('$due'),
                            child: const Icon(Icons.visibility_off_outlined,
                                color: Color(0xFF66BB6A)),
                          ),
                        ),
                        IconButton(
                          tooltip: context.uiText('Miêu tả'),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PicExpressScreen(deck: d),
                            ),
                          ),
                          icon: const Icon(Icons.record_voice_over_outlined,
                              color: Color(0xFF42A5F5)),
                        ),
                        IconButton(
                          tooltip: context.uiText('Xóa'),
                          onPressed: () => _store.delete(d.id),
                          icon: const Icon(Icons.delete_outline,
                              color: Color(0xFFEF5350)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _thumb(PicDeck d) {
    final f = File(d.imagePath);
    if (!f.existsSync()) {
      return const Icon(Icons.broken_image_outlined, color: Colors.white54);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(f, width: 48, height: 48, fit: BoxFit.cover),
    );
  }
}
