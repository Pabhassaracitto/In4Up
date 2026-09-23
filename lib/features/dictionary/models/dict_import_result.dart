// lib/features/dictionary/models/dict_import_result.dart
// Kết quả import từ điển.
//
// Tách riêng để cả `dictionary_service.dart` (nơi sinh ra) và
// `dict_import_service.dart` (nơi trả về cho UI) dùng chung mà không import
// vòng tròn.

import 'dict_info.dart';

/// Kết quả một lần import .mdx.
///
/// UI CẦN giá trị này để hiện lỗi thật: trước đây import lỗi trả `null`
/// im lặng ⇒ người dùng chỉ thấy "Chưa có từ điển nào" mà không biết vì sao.
class DictImportResult {
  /// Từ điển vừa import (null = thất bại hoặc bị huỷ).
  final DictInfo? info;

  /// Thông báo lỗi có thể đưa thẳng lên UI (null = không lỗi).
  final String? error;

  /// Người dùng huỷ trình chọn file (KHÔNG phải lỗi — đừng hiện thông báo).
  final bool cancelled;

  const DictImportResult._({this.info, this.error, this.cancelled = false});

  const DictImportResult.success(DictInfo info) : this._(info: info);

  const DictImportResult.failure(String message) : this._(error: message);

  const DictImportResult.cancelled() : this._(cancelled: true);

  bool get isSuccess => info != null;
  bool get isCancelled => cancelled;
}
