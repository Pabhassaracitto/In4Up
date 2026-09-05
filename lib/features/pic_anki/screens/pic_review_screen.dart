import 'dart:io';

import 'package:flutter/material.dart' as m show Text;
import 'package:flutter/services.dart';
import 'package:in4up/core/language/localized_material.dart';

import '../models/pic_models.dart';
import '../services/pic_anki_store.dart';

class PicReviewScreen extends StatefulWidget {
  final PicDeck deck;
  const PicReviewScreen({super.key, required this.deck});

  @override
  State<PicReviewScreen> createState() => _PicReviewScreenState();
}

class _PicReviewScreenState extends State<PicReviewScreen> {
  late PicDeck _deck;
  late List<PicMask> _queue;
  int _index = 0;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _deck = widget.deck;
    _queue = PicReviewEngine.dueQueue(_deck, DateTime.now());
  }

  PicMask? get _current =>
      _index < _queue.length ? _queue[_index] : null;

  Future<void> _grade(int quality) async {
    final cur = _current;
    if (cur == null) return;
    HapticFeedback.selectionClick();
    final updated = PicReviewEngine.applyReading(
      mask: cur,
      quality: quality,
    );
    final masks = _deck.masks
        .map((m) => m.id == updated.id ? updated : m)
        .toList();
    final nextDeck = _deck.copyWith(masks: masks);
    await PicAnkiStore.instance.save(nextDeck);
    if (!mounted) return;
    setState(() {
      _deck = nextDeck;
      _revealed = false;
      _index += 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cur = _current;
    final file = File(_deck.imagePath);
    return Scaffold(
      backgroundColor: const Color(0xFF080B1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(
          cur == null
              ? context.uiText('Xong phiên ôn')
              : '${context.uiText('Ôn')} ${_index + 1}/${_queue.length}',
        ),
      ),
      body: cur == null
          ? Center(
              child: Text(
                context.uiText('Không còn vùng đến hạn trong bộ này.'),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[400]),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: LayoutBuilder(
                      builder: (context, c) {
                        return GestureDetector(
                          onTap: () => setState(() => _revealed = true),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (file.existsSync())
                                Image.file(file, fit: BoxFit.fill)
                              else
                                Center(
                                  child: Text(
                                    context.uiText('Không tìm thấy ảnh'),
                                  ),
                                ),
                              CustomPaint(
                                painter: _ReviewPainter(
                                  masks: _deck.masks,
                                  focusId: cur.id,
                                  revealed: _revealed,
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
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Column(
                    children: [
                      _revealed
                          ? (cur.label.isEmpty
                              ? Text(
                                  context.uiText('(chưa đặt nhãn)'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                )
                              : m.Text(
                                  cur.label,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ))
                          : Text(
                              context.uiText('Chạm ảnh để hiện nhãn vùng này'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                      if (_revealed && cur.hint.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: m.Text(
                            cur.hint,
                            style: TextStyle(color: Colors.grey[400]),
                          ),
                        ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Row(
                      children: [
                        _gradeBtn(context, context.uiText('Lại'),
                            const Color(0xFFEF5350), PicReviewGrade.again),
                        _gradeBtn(context, context.uiText('Khó'),
                            const Color(0xFFFFA726), PicReviewGrade.hard),
                        _gradeBtn(context, context.uiText('Tốt'),
                            const Color(0xFF66BB6A), PicReviewGrade.good),
                        _gradeBtn(context, context.uiText('Dễ'),
                            const Color(0xFF42A5F5), PicReviewGrade.easy),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _gradeBtn(
    BuildContext context,
    String label,
    Color color,
    int q,
  ) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: color.withValues(alpha: 0.2),
            foregroundColor: color,
          ),
          onPressed: _revealed ? () => _grade(q) : null,
          child: Text(label),
        ),
      ),
    );
  }
}

class _ReviewPainter extends CustomPainter {
  final List<PicMask> masks;
  final String focusId;
  final bool revealed;

  _ReviewPainter({
    required this.masks,
    required this.focusId,
    required this.revealed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final hide = Paint()..color = const Color(0xF21A1A2E);
    final focus = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFFFFB300);

    for (final m in masks) {
      final rect = Rect.fromLTWH(
        m.rect.x * size.width,
        m.rect.y * size.height,
        m.rect.w * size.width,
        m.rect.h * size.height,
      );
      final isFocus = m.id == focusId;
      if (!isFocus || !revealed) {
        canvas.drawRect(rect, hide);
      }
      if (isFocus) {
        canvas.drawRect(rect, focus);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ReviewPainter old) =>
      old.masks != masks || old.focusId != focusId || old.revealed != revealed;
}
