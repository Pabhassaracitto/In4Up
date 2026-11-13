// lib/screens/listen_mode/widgets/playback_problem_snack.dart
//
// PSRC-219 (audit 1.28.0) — Linux vẫn báo "could not play this track".
//
// Trước đây MỌI lỗi nạp audio đều hiện đúng một câu "Không phát được bài
// này" (3 nơi: ngăn kéo thư viện, danh sách thư viện, danh sách phát). Câu đó
// gộp ba chuyện khác hẳn nhau:
//   • file bị hệ thống dọn cache/xoá      → chọn lại file,
//   • file tồn tại nhưng codec hỏng       → đổi định dạng/nguồn khác,
//   • NỀN TẢNG không có bộ phát trong app → mở bằng trình phát của hệ thống.
// Với ca thứ ba (Linux), người dùng còn tưởng file hỏng nên thử lại nhiều lần.
//
// File này là MỘT chỗ duy nhất ánh xạ loại lỗi → câu nói + hành động thay
// thế, để ba bề mặt không trôi khỏi nhau (bài học ADR-0024).

import 'dart:io';

import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter/material.dart' hide Text;

import '../../../audio/audio_backend_support.dart';
import '../../../providers/player_provider.dart';
import '../../../services/external_open_service.dart';

/// Câu thông điệp (khoá tiếng Việt nguồn, đi qua `context.uiText`) cho một
/// loại lỗi nạp audio. `null` = dùng câu chung.
String? playbackFailureMessageKey(AudioLoadErrorKind kind) {
  switch (kind) {
    case AudioLoadErrorKind.backendUnsupported:
      // Một nguồn duy nhất với `AudioPlaybackSupport` (không chép câu chữ).
      return AudioPlaybackSupport.unsupportedReasonKey;
    case AudioLoadErrorKind.missingFile:
      return 'Tệp đã bị xoá hoặc bị hệ thống dọn cache — hãy chọn lại tệp.';
    case AudioLoadErrorKind.loadFailed:
    case AudioLoadErrorKind.none:
      return null;
  }
}

/// Loại lỗi này có đường thay thế "mở bằng trình phát ngoài" không.
bool playbackFailureOffersExternalPlayer(AudioLoadErrorKind kind) =>
    kind == AudioLoadErrorKind.backendUnsupported;

/// Hiện lỗi nạp audio với đúng nguyên nhân + nút mở ngoài khi có.
///
/// [path] là tệp vừa cố nạp (dùng cho nút "Mở bằng trình phát ngoài").
void showPlaybackProblemSnack(
  BuildContext context,
  AudioLoadErrorKind kind, {
  String? path,
}) {
  final messageKey =
      playbackFailureMessageKey(kind) ?? 'Không phát được bài này';
  final canOpenOutside = playbackFailureOffersExternalPlayer(kind) &&
      path != null &&
      path.isNotEmpty &&
      currentExternalOpenPlatform != ExternalOpenPlatform.android &&
      currentExternalOpenPlatform != ExternalOpenPlatform.iOS &&
      currentExternalOpenPlatform != ExternalOpenPlatform.web;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(context.uiText(messageKey)),
      backgroundColor: Colors.orange,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: Duration(seconds: canOpenOutside ? 8 : 3),
      action: canOpenOutside
          ? SnackBarAction(
              label: context.uiText('Mở bằng trình phát ngoài'),
              textColor: Colors.white,
              onPressed: () async {
                final opened = await openFileExternally(path);
                if (!opened && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        context.uiText('Không mở được trình phát hệ thống'),
                      ),
                    ),
                  );
                }
              },
            )
          : null,
    ),
  );
}

/// `true` khi tệp còn trên đĩa — dùng trước khi mời "mở ngoài".
Future<bool> playbackFileExists(String path) async {
  try {
    return await File(path).exists();
  } catch (_) {
    return false;
  }
}
