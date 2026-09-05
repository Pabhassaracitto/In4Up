import 'dart:io';

import 'package:flutter/material.dart' as m show Text;
import 'package:in4up/core/language/localized_material.dart';

import '../models/pic_models.dart';
import '../services/pic_express_scorer.dart';

class PicExpressScreen extends StatefulWidget {
  final PicDeck deck;
  const PicExpressScreen({super.key, required this.deck});

  @override
  State<PicExpressScreen> createState() => _PicExpressScreenState();
}

class _PicExpressScreenState extends State<PicExpressScreen> {
  final _controller = TextEditingController();
  PicDescribeScore? _score;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _grade() {
    setState(() {
      _score = PicExpressScorer.score(
        entities: widget.deck.entities,
        answer: _controller.text,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final file = File(widget.deck.imagePath);
    final entities = widget.deck.entities;
    return Scaffold(
      backgroundColor: const Color(0xFF080B1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(context.uiText('Pic Express')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: file.existsSync()
                ? Image.file(file, height: 220, fit: BoxFit.cover)
                : SizedBox(
                    height: 120,
                    child: Center(
                      child: Text(context.uiText('Không tìm thấy ảnh')),
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Text(
            context.uiText(
              'Miêu tả những gì bạn thấy. Máy chấm theo entity bạn đã gắn (không cần AI nhìn ảnh).',
            ),
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
          ),
          const SizedBox(height: 8),
          if (entities.isEmpty)
            Text(
              context.uiText(
                'Chưa có entity. Mở editor → gắn nhãn vật thể trước.',
              ),
              style: const TextStyle(color: Color(0xFFFFA726)),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in entities)
                  Chip(
                    label: m.Text(e),
                    backgroundColor: const Color(0xFF1A1A2E),
                    labelStyle: const TextStyle(color: Colors.white70),
                  ),
              ],
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            minLines: 3,
            maxLines: 6,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF1A1A2E),
              hintText: context.uiText('Viết miêu tả...'),
              hintStyle: TextStyle(color: Colors.grey[600]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: entities.isEmpty ? null : _grade,
            child: Text(context.uiText('Chấm điểm')),
          ),
          if (_score != null) ...[
            const SizedBox(height: 16),
            Text(
              '${context.uiText('Phủ')} ${_score!.matched}/${_score!.total} · ${(_score!.coverage * 100).round()}%',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            if (_score!.missing.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${context.uiText('Thiếu:')} ${_score!.missing.join(', ')}',
                  style: const TextStyle(color: Color(0xFFEF5350)),
                ),
              ),
            if (_score!.hit.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${context.uiText('Đã nêu:')} ${_score!.hit.join(', ')}',
                  style: const TextStyle(color: Color(0xFF66BB6A)),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
