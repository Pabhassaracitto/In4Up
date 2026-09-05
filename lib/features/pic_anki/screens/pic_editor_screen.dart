import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' as m show Text;
import 'package:flutter/services.dart';
import 'package:in4up/core/language/localized_material.dart';
import 'package:uuid/uuid.dart';

import '../../../knowledge/models/learning_state.dart';
import '../models/pic_models.dart';
import '../services/pic_anki_store.dart';

class PicEditorScreen extends StatefulWidget {
  final PicDeck deck;
  const PicEditorScreen({super.key, required this.deck});

  @override
  State<PicEditorScreen> createState() => _PicEditorScreenState();
}

class _PicEditorScreenState extends State<PicEditorScreen> {
  static const _uuid = Uuid();
  late PicDeck _deck;
  Offset? _dragStart;
  Offset? _dragCurrent;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _deck = widget.deck;
  }

  Size _boxSize(BoxConstraints c) {
    return Size(c.maxWidth, c.maxHeight);
  }

  NormRect? _draftRect(Size size) {
    final a = _dragStart;
    final b = _dragCurrent;
    if (a == null || b == null || size.width <= 0 || size.height <= 0) {
      return null;
    }
    return NormRect.fromCorners(
      a.dx / size.width,
      a.dy / size.height,
      b.dx / size.width,
      b.dy / size.height,
    );
  }

  Future<void> _persist(PicDeck deck) async {
    await PicAnkiStore.instance.save(deck);
    if (!mounted) return;
    setState(() => _deck = deck);
  }

  Future<void> _labelMask(PicMask mask) async {
    final controller = TextEditingController(text: mask.label);
    final hint = TextEditingController(text: mask.hint);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(ctx.uiText('Nhãn vùng che')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: ctx.uiText('Nhãn (đáp án)'),
                labelStyle: TextStyle(color: Colors.grey[400]),
              ),
            ),
            TextField(
              controller: hint,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: ctx.uiText('Gợi ý (tuỳ chọn)'),
                labelStyle: TextStyle(color: Colors.grey[400]),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.uiText('Hủy')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.uiText('Lưu')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final next = _deck.masks
        .map((m) => m.id == mask.id
            ? m.copyWith(label: controller.text.trim(), hint: hint.text.trim())
            : m)
        .toList();
    await _persist(_deck.copyWith(masks: next));
  }

  Future<void> _finishDrag(Size size) async {
    final rect = _draftRect(size);
    setState(() {
      _dragStart = null;
      _dragCurrent = null;
    });
    if (rect == null || !rect.isUsable) return;
    HapticFeedback.selectionClick();
    final mask = PicMask(
      id: _uuid.v4(),
      rect: rect,
      reading: SM2Snapshot.initial(),
    );
    await _persist(_deck.copyWith(masks: [..._deck.masks, mask]));
    await _labelMask(mask);
  }

  Future<void> _editEntities() async {
    final controller = TextEditingController(text: _deck.entities.join(', '));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(ctx.uiText('Entity Pic Express')),
        content: TextField(
          controller: controller,
          maxLines: 4,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: ctx.uiText('bát, tăng, cây, trời...'),
            hintStyle: TextStyle(color: Colors.grey[600]),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.uiText('Hủy')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.uiText('Lưu')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final entities = controller.text
        .split(RegExp(r'[,;\n]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    await _persist(_deck.copyWith(entities: entities));
  }

  Future<void> _rename() async {
    final controller = TextEditingController(text: _deck.title);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(ctx.uiText('Đổi tên bộ ảnh')),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.uiText('Hủy')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.uiText('Lưu')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _persist(_deck.copyWith(title: controller.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final file = File(_deck.imagePath);
    return Scaffold(
      backgroundColor: const Color(0xFF080B1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: _deck.title.isEmpty
            ? Text(context.uiText('Pic Anki'))
            : m.Text(_deck.title),
        actions: [
          IconButton(
            tooltip: context.uiText('Entity miêu tả'),
            onPressed: _editEntities,
            icon: const Icon(Icons.sell_outlined),
          ),
          IconButton(
            tooltip: context.uiText('Đổi tên'),
            onPressed: _rename,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Text(
              context.uiText(
                'Kéo trên ảnh để che một vùng. Mỗi vùng là một thẻ ôn riêng.',
              ),
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = _boxSize(constraints);
                  return GestureDetector(
                    onPanStart: (d) => setState(() {
                      _dragStart = d.localPosition;
                      _dragCurrent = d.localPosition;
                    }),
                    onPanUpdate: (d) =>
                        setState(() => _dragCurrent = d.localPosition),
                    onPanEnd: (_) => _finishDrag(size),
                    onTapUp: (d) {
                      final nx = d.localPosition.dx / size.width;
                      final ny = d.localPosition.dy / size.height;
                      final hit = PicReviewEngine.hitTest(_deck.masks, nx, ny);
                      setState(() => _selectedId = hit?.id);
                      if (hit != null) _labelMask(hit);
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (file.existsSync())
                          Image.file(file, fit: BoxFit.fill)
                        else
                          Center(child: Text(context.uiText('Không tìm thấy ảnh'))),
                        CustomPaint(
                          painter: _MaskPainter(
                            masks: _deck.masks,
                            draft: _draftRect(size),
                            selectedId: _selectedId,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: Row(
              children: [
                Text(
                  '${_deck.masks.length} ${context.uiText('vùng che')}',
                  style: TextStyle(color: Colors.grey[400]),
                ),
                const Spacer(),
                if (_selectedId != null)
                  TextButton(
                    onPressed: () async {
                      final next = _deck.masks
                          .where((m) => m.id != _selectedId)
                          .toList();
                      await _persist(_deck.copyWith(masks: next));
                      setState(() => _selectedId = null);
                    },
                    child: Text(context.uiText('Xóa vùng')),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MaskPainter extends CustomPainter {
  final List<PicMask> masks;
  final NormRect? draft;
  final String? selectedId;

  _MaskPainter({required this.masks, this.draft, this.selectedId});

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = const Color(0xCC1A1A2E);
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF66BB6A);
    final selected = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFFFFB300);

    void drawRect(NormRect r, {bool hi = false}) {
      final rect = Rect.fromLTWH(
        r.x * size.width,
        r.y * size.height,
        r.w * size.width,
        r.h * size.height,
      );
      canvas.drawRect(rect, fill);
      canvas.drawRect(rect, hi ? selected : border);
    }

    for (final m in masks) {
      drawRect(m.rect, hi: m.id == selectedId);
    }
    if (draft != null) drawRect(draft!, hi: true);
  }

  @override
  bool shouldRepaint(covariant _MaskPainter old) =>
      old.masks != masks || old.draft != draft || old.selectedId != selectedId;
}

Future<String?> pickPicAnkiImage() async {
  final result = await FilePicker.pickFiles(type: FileType.image);
  return result?.files.single.path;
}
