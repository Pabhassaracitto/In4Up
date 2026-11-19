import 'package:in4up/core/language/localized_material.dart';

/// Honest failure state for shadowing analysis: missing/silent recordings,
/// permission failures, and speech-recognition failures have distinct guidance.
class ShadowingAnalysisNotice extends StatelessWidget {
  const ShadowingAnalysisNotice({super.key, required this.code});

  final String code;

  String get _message {
    switch (code) {
      case 'permission_denied':
        return 'Chưa được cấp quyền micro. Hãy cho phép ứng dụng dùng micro rồi thử lại.';
      case 'no_audio':
        return 'Không thu được âm thanh từ micro. Hãy kiểm tra đầu vào âm thanh rồi ghi lại.';
      case 'unrecognized':
        return 'Đã thu được âm thanh nhưng nhận dạng không tạo ra bản chép lời. Hãy đọc lại rõ hơn hoặc thử ngôn ngữ khác.';
      case 'recognition_error':
        return 'Không thể chạy nhận dạng giọng nói cho bản ghi này. Hãy thử lại.';
      case 'recording_failed':
        return 'Không thể bắt đầu hoặc lưu bản ghi âm. Hãy thử lại.';
      case 'no_reference':
        return 'Chưa có câu mẫu để chấm điểm. Hãy chọn một câu có lời.';
      case 'analysis_failed':
        return 'Chưa phân tích được bản ghi. Hãy thử ghi âm lại.';
      default:
        return 'Chưa phân tích được bản ghi. Hãy thử ghi âm lại.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.uiText(_message),
              style: const TextStyle(color: Colors.orange, fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
