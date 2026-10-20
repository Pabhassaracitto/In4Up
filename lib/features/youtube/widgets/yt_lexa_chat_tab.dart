// YT-LR-002 / IN4-87 — Tab `Lexa AI Chat` trong màn học video YouTube.
//
// Người dùng hỏi đáp về từ vựng / cấu trúc câu / ngữ pháp của video đang xem
// mà không rời màn học.
//
// • Local-first: mọi suy luận chạy trên máy qua `AiServiceFacade` (single entry
//   point của module AI). KHÔNG gọi server trực tiếp từ đây.
// • Ngữ cảnh tự động: tiêu đề video + câu phụ đề đang phát + từ vừa bấm.
// • Không RAG / embedding / vector DB — chỉ cửa sổ ngữ cảnh nhỏ quanh vị trí
//   phát (theo `PROMPT_AGENT_YOUTUBE_LANGUA.md`).
//
// Hội thoại hiển thị ở tab này là **phiên riêng**: lưu chỉ số (index) của câu
// trả lời trong lịch sử của facade, nên "Cuộc trò chuyện mới" chỉ đổi góc nhìn
// cục bộ — không xoá lịch sử AI chung của app.

import 'package:flutter/material.dart';
import 'package:in4up/core/language/localized_material.dart' hide Text;
import 'package:in4up_ai/in4up_ai.dart';
import 'package:provider/provider.dart';

class YtLexaChatTab extends StatefulWidget {
  final String videoTitle;
  final String videoId;

  /// Câu phụ đề đang phát (để làm ngữ cảnh).
  final String? currentSentence;

  /// Từ người dùng vừa bấm (nếu có).
  final String? selectedWord;

  const YtLexaChatTab({
    super.key,
    required this.videoTitle,
    required this.videoId,
    this.currentSentence,
    this.selectedWord,
  });

  @override
  State<YtLexaChatTab> createState() => _YtLexaChatTabState();
}

/// Một lượt hỏi–đáp: câu hỏi gốc + vị trí câu trả lời trong lịch sử facade.
class _Turn {
  final String question;
  final int answerIndex;
  const _Turn(this.question, this.answerIndex);
}

class _YtLexaChatTabState extends State<YtLexaChatTab> {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<_Turn> _turns = [];
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Prompt gửi xuống model — VIẾT BẰNG TIẾNG ANH để không rơi vào gate i18n
  /// (mọi literal có dấu trong file presentation phải được phân loại) và để
  /// model local xử lý ổn định hơn. Model được yêu cầu trả lời cùng ngôn ngữ
  /// với câu hỏi.
  String _buildPrompt(String question) {
    final buffer = StringBuffer();
    buffer.writeln('You are Lexa, an offline language-learning assistant inside the In4Up app.');
    buffer.writeln('The user is watching this YouTube video:');
    buffer.writeln('Title: ${widget.videoTitle}');
    buffer.writeln('Video id: ${widget.videoId}');
    final sentence = widget.currentSentence;
    if (sentence != null && sentence.trim().isNotEmpty) {
      buffer.writeln('Subtitle line currently playing: "$sentence"');
    }
    final word = widget.selectedWord;
    if (word != null && word.trim().isNotEmpty) {
      buffer.writeln('Word the user last tapped: "$word"');
    }
    buffer.writeln(
      'Rules: answer in the same language as the question; be concise; use the '
      'subtitle line above as the main context; give the Vietnamese meaning '
      'when explaining a word or phrase.',
    );
    buffer.writeln('Question: $question');
    return buffer.toString();
  }

  Future<void> _send(AiServiceFacade facade, String question) async {
    final text = question.trim();
    if (text.isEmpty || _busy) return;

    final answerIndex = facade.chatMessages.length + 1;
    setState(() {
      _turns.add(_Turn(text, answerIndex));
      _busy = true;
      _ctrl.clear();
    });
    _scrollToEnd();

    try {
      await facade.sendMessage(_buildPrompt(text));
    } finally {
      if (mounted) setState(() => _busy = false);
      _scrollToEnd();
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  List<String> _suggestions() {
    final word = widget.selectedWord?.trim();
    final list = <String>[
      context.uiText('Giải thích câu này'),
      context.uiText('Phân tích ngữ pháp câu này'),
    ];
    if (word != null && word.isNotEmpty) {
      list.insert(0, context.uiText('Từ "$word" nghĩa là gì ở đây?'));
    }
    return list.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AiServiceFacade>(
      builder: (context, facade, _) {
        final messages = facade.chatMessages;

        if (!facade.hasModel) return _buildNoModel(facade);

        return Column(
          children: [
            if (_turns.isEmpty) _buildSuggestions(),
            Expanded(
              child: _turns.isEmpty
                  ? _buildEmpty()
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      itemCount: _turns.length,
                      itemBuilder: (_, i) {
                        final turn = _turns[i];
                        final answered = turn.answerIndex < messages.length;
                        final answerText = answered
                            ? messages[turn.answerIndex].text
                            : context.uiText('Đang suy nghĩ…');
                        return Column(
                          children: [
                            _bubble(
                              turn.question,
                              alignRight: true,
                              color: const Color(0xFF9C27B0),
                            ),
                            _bubble(
                              answerText,
                              alignRight: false,
                              color: const Color(0xFF21262D),
                              isError: answered &&
                                  messages[turn.answerIndex].isError,
                              dim: !answered,
                            ),
                          ],
                        );
                      },
                    ),
            ),
            _buildComposer(facade),
          ],
        );
      },
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          context.uiText('Hỏi Lexa về từ vựng, cấu trúc câu hoặc ngữ pháp của video này.'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.uiText('Gợi ý'),
            style: const TextStyle(
              color: Color(0xFF9C27B0),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _suggestions()
                .map(
                  (s) => ActionChip(
                    label: Text(s, style: const TextStyle(fontSize: 12)),
                    backgroundColor: const Color(0xFF21262D),
                    onPressed: () => _send(
                      context.read<AiServiceFacade>(),
                      s,
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildNoModel(AiServiceFacade facade) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
          ),
          child: Text(
            context.uiText('Chưa cài model AI. Cài để hỏi đáp về video.'),
            style: const TextStyle(color: Colors.amber, fontSize: 13),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF9C27B0),
          ),
          onPressed: () async {
            await facade.importModelFromUser();
            if (mounted) setState(() {});
          },
          icon: const Icon(Icons.download, size: 16),
          label: Text(context.uiText('Cài AI')),
        ),
      ],
    );
  }

  Widget _bubble(
    String text, {
    required bool alignRight,
    required Color color,
    bool isError = false,
    bool dim = false,
  }) {
    return Align(
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: isError
              ? Colors.red.withValues(alpha: 0.18)
              : color.withValues(alpha: dim ? 0.45 : 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isError ? Colors.redAccent : Colors.white,
            fontSize: 13,
            height: 1.45,
          ),
        ),
      ),
    );
  }

  Widget _buildComposer(AiServiceFacade facade) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
        child: Row(
          children: [
            IconButton(
              tooltip: context.uiText('Cuộc trò chuyện mới'),
              icon: const Icon(Icons.add_comment_outlined,
                  size: 18, color: Colors.grey),
              onPressed:
                  _turns.isEmpty ? null : () => setState(() => _turns.clear()),
            ),
            Expanded(
              child: TextField(
                controller: _ctrl,
                minLines: 1,
                maxLines: 4,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: context.uiText('Hỏi Lexa về video này…'),
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFF21262D),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                ),
                onSubmitted: (v) => _send(facade, v),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send, size: 18, color: Color(0xFF9C27B0)),
              onPressed: _busy ? null : () => _send(facade, _ctrl.text),
            ),
          ],
        ),
      ),
    );
  }
}
