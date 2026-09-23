// lib/screens/home/quick_capture/quick_capture_sheet.dart
//
// HOME-QUICK-001 — sheet "Nạp tri thức nhanh" (thay `_SttDialog` giả).
//
// Một flow duy nhất cho FAB microphone ở Home VÀ nút "Ghi chú nói" trong
// card: mở sheet → tự bật engine STT (ưu tiên Sherpa offline) → transcript
// realtime → dừng sạch → lưu vào WordList hoặc ghi chú nói.

import 'dart:async';

import 'package:in4up/core/language/localized_material.dart';

import 'quick_capture_controller.dart';
import 'quick_capture_repository.dart';
import 'quick_capture_stt_sources.dart';

class QuickCaptureSheet extends StatefulWidget {
  const QuickCaptureSheet({super.key, required this.appLanguage});

  /// Ngôn ngữ UI hiện tại — dùng làm căn cứ chọn ngôn ngữ nhận diện.
  final String appLanguage;

  static Future<void> show(BuildContext context, {String? appLanguage}) {
    final language =
        appLanguage ?? Localizations.localeOf(context).languageCode;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => QuickCaptureSheet(appLanguage: language),
    );
  }

  @override
  State<QuickCaptureSheet> createState() => _QuickCaptureSheetState();
}

class _QuickCaptureSheetState extends State<QuickCaptureSheet> {
  static const Color _accent = Color(0xFF6C63FF);
  static const Color _micRed = Color(0xFFFF4848);

  late final QuickCaptureController _controller;
  late final QuickCaptureSaver _saver;
  List<QuickCaptureNote> _notes = const <QuickCaptureNote>[];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _saver = QuickCaptureSaver(
      notes: QuickCaptureNoteStore.onStorageService(),
    );
    _notes = _saver.notes.load();
    _controller = QuickCaptureController(
      sources: buildQuickCaptureSources(appLanguage: widget.appLanguage),
      ensureMicrophonePermission: requestQuickCaptureMicPermission,
    );
    // FAB mic = "ghi ngay": bật phiên sau frame đầu (không chặn build).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_controller.start());
    });
  }

  @override
  void dispose() {
    // Dừng sạch: huỷ subscription + tắt engine + nhả recorder/model.
    _controller.dispose();
    super.dispose();
  }

  String get _captureLanguage =>
      _controller.engineLanguage ?? widget.appLanguage;

  Future<void> _toggleMic() async {
    if (_controller.isListening) {
      await _controller.stop();
      return;
    }
    _controller.acknowledgeFailure();
    await _controller.start();
  }

  Future<void> _saveToWordList() async {
    final text = _controller.transcript;
    if (text.isEmpty || _saving) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);

    // Lưu = kết thúc phiên (một lần nói → một entry).
    await _controller.stop();
    final result = _saver.saveToWordList(
      text: text,
      language: _captureLanguage,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (!result.success) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(context.uiText('Chưa lưu được vào WordList')),
          backgroundColor: const Color(0xFF7F1D1D),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final entry = result.entry;
    final label = result.isNewEntry
        ? context.uiText('Đã lưu vào WordList')
        : context.uiText('Từ đã có — đã bổ sung ngữ cảnh');
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          entry == null || entry.word.trim().isEmpty
              ? label
              : '$label · ${entry.word}',
        ),
        backgroundColor: const Color(0xFF1E5F3A),
        behavior: SnackBarBehavior.floating,
      ),
    );
    _controller.clearTranscript();
  }

  Future<void> _saveNote() async {
    final text = _controller.transcript;
    if (text.isEmpty || _saving) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);

    await _controller.stop();
    final note = await _saver.saveNote(
      text: text,
      language: _captureLanguage,
    );

    if (!mounted) return;
    setState(() {
      _saving = false;
      _notes = _saver.notes.load();
    });

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          note == null
              ? context.uiText('Chưa lưu được ghi chú')
              : context.uiText('Đã lưu ghi chú'),
        ),
        backgroundColor:
            note == null ? const Color(0xFF7F1D1D) : const Color(0xFF1E5F3A),
        behavior: SnackBarBehavior.floating,
      ),
    );
    if (note != null) _controller.clearTranscript();
  }

  Future<void> _deleteNote(QuickCaptureNote note) async {
    await _saver.notes.delete(note.id);
    if (!mounted) return;
    setState(() => _notes = _saver.notes.load());
  }

  void _reuseNote(QuickCaptureNote note) {
    // Nạp lại nội dung ghi chú vào khung transcript để lưu tiếp.
    setState(() => _controller.restoreTranscript(note.text));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return FractionallySizedBox(
          heightFactor: 0.92,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _buildHeader(context),
                const SizedBox(height: 14),
                if (_controller.failure != QuickCaptureFailure.none) ...[
                  _buildErrorBanner(context),
                  const SizedBox(height: 12),
                ],
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTranscriptBox(context),
                        const SizedBox(height: 10),
                        _buildStatusLine(context),
                        const SizedBox(height: 16),
                        _buildControls(context),
                        const SizedBox(height: 20),
                        _buildRecentNotes(context),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.graphic_eq, color: _accent, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.uiText('NẠP TRI THỨC NHANH'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _engineLabel(),
                style: TextStyle(color: Colors.grey[400], fontSize: 11),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.white70),
          tooltip: context.uiText('Đóng'),
          onPressed: () async {
            // Dừng sạch trước khi đóng (barrier/drag vẫn có dispose làm lưới).
            await _controller.stop();
            if (!mounted) return;
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }

  String _engineLabel() {
    final lang = (_captureLanguage).toUpperCase();
    switch (_controller.engineKind) {
      case QuickCaptureEngineKind.sherpaOffline:
        return 'Sherpa offline · $lang';
      case QuickCaptureEngineKind.system:
        return 'System STT · ${QuickCaptureLanguagePolicy.toSystemLocale(_captureLanguage)}';
      case null:
        return context.uiText('Engine nhận diện sẽ chọn khi bật mic');
    }
  }

  Widget _buildErrorBanner(BuildContext context) {
    final detail = _controller.failureDetail;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFF4848).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFF4848).withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFFF8A80), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _failureMessage(context),
                  style: const TextStyle(
                    color: Color(0xFFFFCDD2),
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
                if (detail != null && detail.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _failureMessage(BuildContext context) {
    switch (_controller.failure) {
      case QuickCaptureFailure.microphonePermission:
        return context.uiText(
          'Chưa cấp quyền microphone. Vào Cài đặt → Ứng dụng → In4Up → Quyền → cho phép "Microphone" rồi thử lại.',
        );
      case QuickCaptureFailure.noEngineAvailable:
        return context.uiText(
          'Chưa có engine nhận diện giọng nói sẵn sàng. Import model Sherpa trong Quản lý Model AI, hoặc kiểm tra dịch vụ nhận diện giọng nói của hệ thống.',
        );
      case QuickCaptureFailure.startFailed:
        return context.uiText(
          'Không khởi động được nhận diện giọng nói. Thử lại, hoặc import model Sherpa offline trong Quản lý Model AI.',
        );
      case QuickCaptureFailure.streamFailed:
        return context.uiText(
          'Phiên nghe bị gián đoạn. Phần đã nhận vẫn được giữ — bấm mic để ghi tiếp.',
        );
      case QuickCaptureFailure.none:
        return '';
    }
  }

  Widget _buildTranscriptBox(BuildContext context) {
    final finals = _controller.finalSegments;
    final partial = _controller.partialText.trim();
    final isEmpty = finals.isEmpty && partial.isEmpty;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 150),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: isEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.mic_none, color: Colors.grey[600], size: 26),
                const SizedBox(height: 10),
                Text(
                  context.uiText(
                    'Nhấn nút mic và nói một câu — transcript sẽ hiện ở đây.',
                  ),
                  style: TextStyle(color: Colors.grey[500], height: 1.5),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (finals.isNotEmpty)
                  Text(
                    finals.join(' '),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15.5,
                      height: 1.55,
                    ),
                  ),
                if (partial.isNotEmpty)
                  Text(
                    finals.isEmpty ? partial : ' $partial',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 15.5,
                      height: 1.55,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildStatusLine(BuildContext context) {
    final IconData icon;
    final String label;
    final Color color;

    switch (_controller.status) {
      case QuickCaptureStatus.starting:
        icon = Icons.hourglass_top;
        label = context.uiText('Đang bật micro…');
        color = const Color(0xFFFFB74D);
      case QuickCaptureStatus.listening:
        icon = Icons.fiber_manual_record;
        label = context.uiText('Đang nghe — nói ngay…');
        color = _micRed;
      case QuickCaptureStatus.stopping:
        icon = Icons.hourglass_bottom;
        label = context.uiText('Đang dừng…');
        color = const Color(0xFFFFB74D);
      case QuickCaptureStatus.error:
        icon = Icons.warning_amber_rounded;
        label = context.uiText('Đã dừng — cần xử lý lỗi ở trên');
        color = const Color(0xFFFF8A80);
      case QuickCaptureStatus.idle:
        icon = Icons.check_circle_outline;
        label = _controller.hasTranscript
            ? context.uiText('Đã dừng — sẵn sàng lưu')
            : context.uiText('Sẵn sàng ghi âm');
        color = const Color(0xFF81C784);
    }

    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: color, fontSize: 12, height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _buildControls(BuildContext context) {
    final listening = _controller.isListening;
    final canSave = _controller.hasTranscript && !_saving;

    return Column(
      children: [
        Center(
          child: SizedBox(
            width: 72,
            height: 72,
            child: FloatingActionButton(
              heroTag: 'home_quick_capture_mic',
              onPressed: _controller.isBusy ? null : _toggleMic,
              backgroundColor: listening ? _micRed : _accent,
              child: Icon(
                listening ? Icons.stop : Icons.mic,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          listening
              ? context.uiText('Nhấn để dừng')
              : context.uiText('Nhấn để ghi âm'),
          style: TextStyle(color: Colors.grey[500], fontSize: 11),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: canSave ? _saveToWordList : null,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00D1FF).withValues(alpha: 0.16),
                  foregroundColor: const Color(0xFF00D1FF),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: const Color(0xFF00D1FF).withValues(alpha: 0.3),
                    ),
                  ),
                ),
                icon: const Icon(Icons.bookmark_added_outlined, size: 18),
                label: Text(
                  context.uiText('Lưu vào WordList'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: canSave ? _saveNote : null,
                style: FilledButton.styleFrom(
                  backgroundColor: _accent.withValues(alpha: 0.16),
                  foregroundColor: _accent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: _accent.withValues(alpha: 0.3)),
                  ),
                ),
                icon: const Icon(Icons.sticky_note_2_outlined, size: 18),
                label: Text(
                  context.uiText('Lưu ghi chú'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
        if (_controller.hasTranscript)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _controller.isBusy
                  ? null
                  : () => setState(_controller.clearTranscript),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: Text(context.uiText('Xoá transcript')),
            ),
          ),
      ],
    );
  }

  Widget _buildRecentNotes(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.sticky_note_2_outlined, size: 16, color: Colors.grey[500]),
            const SizedBox(width: 6),
            Text(
              context.uiText('Ghi chú gần đây'),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${_notes.length}',
              style: TextStyle(color: Colors.grey[600], fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_notes.isEmpty)
          Text(
            context.uiText('Chưa có ghi chú nói nào.'),
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          )
        else
          ..._notes.take(5).map(_buildNoteTile),
      ],
    );
  }

  Widget _buildNoteTile(QuickCaptureNote note) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatNoteTime(note.createdAt),
                  style: TextStyle(color: Colors.grey[600], fontSize: 10.5),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.playlist_add, color: Colors.white54, size: 20),
            tooltip: context.uiText('Dùng lại transcript này'),
            onPressed: () => _reuseNote(note),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white54, size: 20),
            tooltip: context.uiText('Xoá ghi chú'),
            onPressed: () => _deleteNote(note),
          ),
        ],
      ),
    );
  }

  String _formatNoteTime(DateTime time) {
    final local = time.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.day}/${local.month}/${local.year} $hh:$mm';
  }
}
