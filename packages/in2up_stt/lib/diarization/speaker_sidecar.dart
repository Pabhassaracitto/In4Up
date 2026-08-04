// in2up v11.0 — Sidecar .spk.json (cache render, KHÔNG phải DB)

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'speaker_annotation.dart';

class SpeakerSidecar {
  SpeakerSidecar._();

  /// Đường dẫn sidecar tương ứng với file LRC
  static String getSidecarPath(String lrcPath) => lrcPath.replaceAll(
        RegExp(r'\.lrc$', caseSensitive: false),
        '.spk.json',
      );

  /// Lưu sidecar — chỉ gọi sau khi LRC đã được lưu thành công
  static Future<void> save({
    required String lrcPath,
    required String audioFingerprint,
    required List<SpeakerAnnotation> annotations,
  }) async {
    if (annotations.isEmpty) return;

    final file = File(getSidecarPath(lrcPath));
    final payload = {
      'version': 1,
      'audioFingerprint': audioFingerprint,
      'pipelineVersion': annotations.first.pipelineVersion,
      'generatedAt': DateTime.now().toIso8601String(),
      'annotations': annotations.map((a) => a.toJson()).toList(),
    };

    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );

    debugPrint('[SpeakerSidecar] Saved: ${file.path}');
  }

  /// Load speaker color map để UI dùng tại view-time
  ///
  /// Trả về Map với 2 key per annotation:
  ///   joinKey → speakerId
  ///   segmentUid → speakerId (fallback)
  static Future<Map<String, int>> loadSpeakerMap(String lrcPath) async {
    final file = File(getSidecarPath(lrcPath));
    if (!await file.exists()) return {};

    try {
      final raw = await file.readAsString();
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final list = data['annotations'] as List<dynamic>? ?? [];

      final map = <String, int>{};
      for (final item in list) {
        final a = SpeakerAnnotation.fromJson(item as Map<String, dynamic>);
        // Dual index: ưu tiên joinKey, fallback uid
        map[a.joinKey] = a.speakerId;
        map[a.segmentUid] = a.speakerId;
      }

      debugPrint('[SpeakerSidecar] Loaded ${map.length ~/ 2} annotations '
          'from ${file.path}');
      return map;
    } catch (e) {
      debugPrint('[SpeakerSidecar] Load error: $e');
      return {};
    }
  }

  /// Kiểm tra sidecar có tồn tại và hợp lệ không
  static Future<bool> exists(String lrcPath) async {
    final file = File(getSidecarPath(lrcPath));
    if (!await file.exists()) return false;
    try {
      final raw = await file.readAsString();
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return data.containsKey('annotations');
    } catch (_) {
      return false;
    }
  }
}
