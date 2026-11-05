// lib/screens/listen_mode/widgets/listen_live_offline_mic.dart
//
// M4U-IMPORT-003 — nút mic OFFLINE (sherpa-onnx) cho tab Nghe.
//
// Dùng model ASR offline đã cài trên máy:
//   * Parakeet TDT 0.6B v3 (NVIDIA, int8) — 25 ngôn ngữ châu Âu, ~670MB;
//   * Zipformer VI 30M int8 — tiếng Việt offline.
//
// Cả hai đều là model OFFLINE (không có bản streaming của sherpa-onnx) ⇒
// live đi đường "simulated streaming": `OfflineRecognizer` + Silero VAD —
// giống hệt đường live STT của Cabin (CABIN-ASR-002 / PARAKEET-002).
//
// Widget TỰ QUẢN LÝ state (phiên mic + danh sách ngôn ngữ + transcript) để
// nhúng được ở bất kỳ đâu trong tab Nghe mà không phải ràng buộc dữ liệu từ
// màn (tab Nghe có nhiều nơi render phần "tạo LRC").
//
// localized_material export material (hide Text) + Text localized + uiText
// (rule 5: chrome không tiếng Việt khi locale ≠ vi) — KHÔNG import material
// trực tiếp (conflict tên Text).
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:in4up/core/language/localized_material.dart';
import 'package:in4up/utils/safe_set_state.dart';
import 'package:in4up_stt/models/stt_result.dart';
import 'package:in4up_stt/sherpa_model_manager.dart';

import '../services/listen_live_offline_stt.dart';

/// Nút bật/tắt ghi âm offline + khung transcript live.
class ListenLiveOfflineMic extends material.StatefulWidget {
  const ListenLiveOfflineMic({super.key});

  @override
  material.State<ListenLiveOfflineMic> createState() =>
      _ListenLiveOfflineMicState();
}

class _ListenLiveOfflineMicState extends material.State<ListenLiveOfflineMic>
    with SafeSetStateMixin<ListenLiveOfflineMic> {
  final ListenLiveOfflineStt _stt = ListenLiveOfflineStt();
  final SherpaModelManager _manager = SherpaModelManager();

  StreamSubscription<SttResult>? _resultSub;
  StreamSubscription<SherpaAsrInfo>? _infoSub;

  /// Ngôn ngữ nào có model OFFLINE đã cài (Parakeet 25 ngôn ngữ + VI).
  List<String> _languages = const [];
  String _text = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Model có thể vừa được import/tải ⇒ quét lại state trước khi kết luận
    // "chưa có model" (CABIN-ASR-002).
    unawaited(_bootstrap());
    _infoSub = _manager.watchAsr().listen((_) {
      if (!mounted) return;
      safeSetState(_refreshLanguages);
    });
  }

  Future<void> _bootstrap() async {
    try {
      await _manager.ensureFresh();
    } catch (e) {
      debugPrint('⚠️ Nghe: quét model ASR lỗi: $e');
    }
    if (!mounted) return;
    safeSetState(_refreshLanguages);
  }

  @override
  void dispose() {
    _resultSub?.cancel();
    _resultSub = null;
    _infoSub?.cancel();
    _infoSub = null;
    // Nhả mic + recognizer khi rời màn (không giữ model ~670MB trong RAM).
    unawaited(_stt.dispose());
    super.dispose();
  }

  void _refreshLanguages() {
    _languages = AsrModelRouter.installedOfflineLanguages(
      isInstalled: (profileId) {
        final profile = AsrModelRouter.profileById(profileId);
        if (profile == null || profile.isStreaming) return false;
        return _manager.isAsrProfileInstalled(profileId);
      },
    );
  }

  Future<void> _toggle() async {
    if (_stt.isListening) {
      await _stt.stop();
      if (!mounted) return;
      safeSetState(() => _text = '');
      return;
    }

    if (_languages.isEmpty) {
      _showMessage(
        context.uiText('Chưa có model nhận diện offline — hãy tải hoặc import '
            'Parakeet / Zipformer VI trong Quản lý Model AI.'),
      );
      return;
    }

    final language = await _pickLanguage();
    if (language == null || !mounted) return;

    safeSetState(() => _busy = true);
    final ok = await _stt.start(language);
    if (!mounted) return;
    safeSetState(() {
      _busy = false;
      if (ok) _text = '';
    });
    if (!ok) {
      debugPrint('⚠️ Nghe: live offline lỗi — ${_stt.lastError}');
      _showMessage(
        context.uiText('Không khởi động được nhận diện offline.'),
      );
      return;
    }

    _resultSub ??= _stt.results.listen((result) {
      if (!mounted) return;
      safeSetState(() => _text = result.fullText);
    });
  }

  /// Bottom sheet chọn ngôn ngữ (Parakeet phục vụ 25 ngôn ngữ châu Âu).
  Future<String?> _pickLanguage() {
    return material.showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => material.SafeArea(
        child: material.ListView(
          shrinkWrap: true,
          children: [
            material.Padding(
              padding: const material.EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                sheetContext.uiText('Ngôn ngữ'),
                style: material.Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            for (final language in _languages)
              material.ListTile(
                leading: const material.Icon(material.Icons.record_voice_over,
                    size: 20),
                title: Text(AsrModelRouter.languageDisplayName(language)),
                onTap: () => material.Navigator.of(sheetContext).pop(language),
              ),
          ],
        ),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    material.ScaffoldMessenger.of(context).showSnackBar(
      material.SnackBar(content: Text(message)),
    );
  }

  @override
  material.Widget build(material.BuildContext context) {
    if (_languages.isEmpty) return const material.SizedBox.shrink();

    final live = _stt.isListening;
    return material.Column(
      mainAxisSize: material.MainAxisSize.min,
      crossAxisAlignment: material.CrossAxisAlignment.start,
      children: [
        if (live || _text.isNotEmpty)
          material.Container(
            constraints: const material.BoxConstraints(maxWidth: 320),
            margin: const material.EdgeInsets.only(bottom: 6),
            padding: const material.EdgeInsets.all(8),
            decoration: material.BoxDecoration(
              color: material.Colors.blue.withValues(alpha: 0.12),
              borderRadius: material.BorderRadius.circular(10),
              border: material.Border.all(
                color: material.Colors.blue.withValues(alpha: 0.35),
              ),
            ),
            child: Text(
              _text,
              style: const material.TextStyle(
                color: material.Colors.white,
                fontSize: 13,
              ),
            ),
          ),
        material.ElevatedButton.icon(
          onPressed: _busy ? null : () => _toggle(),
          icon: material.Icon(
            live ? material.Icons.stop_circle : material.Icons.mic,
          ),
          label: Text(
            context.uiText(
              live ? 'Dừng ghi offline' : 'Ghi âm offline (Parakeet)',
            ),
          ),
          style: live
              ? material.ElevatedButton.styleFrom(
                  backgroundColor: material.Colors.red,
                )
              : null,
        ),
      ],
    );
  }
}
