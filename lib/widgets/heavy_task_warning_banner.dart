// lib/widgets/heavy_task_warning_banner.dart
//
// QA-PERF-001 — Banner cảnh báo khi ≥2 tác vụ "nặng" (AI chat local, dịch
// Hy-MT offline, Whisper on-device…) đang chạy CHỒNG LÊN NHAU — mỗi engine
// tự spawn 1 isolate llama.cpp/whisper riêng, cộng dồn CPU/RAM. Vì app xin
// miễn "tối ưu pin" (BATTERY-OPT-001) nên hệ thống KHÔNG tự bóp/giết các
// tiến trình này — banner là lớp cảnh báo DUY NHẤT cho người dùng biết máy
// có thể nóng/tốn pin hơn bình thường, để họ chủ động chờ bớt một tác vụ.
//
// Thiết kế CỐ Ý không chứa bất kỳ chuỗi hiển thị cố định nào — nội dung do
// nơi gọi truyền vào (tham số [message]) để đi đúng luật i18n của app
// (AGENTS.md mục 5: chrome UI ARB/uiText, không hard-code tiếng Việt). Đây
// là component ĐỘC LẬP, CHƯA được gắn vào `main_shell.dart` — xem
// `docs/qa_heavy_task_thermal_audit.md` mục "Cách tích hợp" trước khi gắn
// vào UI thật (nên thêm key ARB cho [message] theo đúng lộ trình T2/T3).
//
// Chỉ quan sát [HeavyTaskMonitor] (không chặn/can thiệp tác vụ nào) nên an
// toàn để thêm vào bất kỳ màn hình nào mà không đổi hành vi engine.
library heavy_task_warning_banner;

import 'package:flutter/material.dart';
import 'package:in4up_core/heavy_task_monitor.dart';

/// Banner mảnh, không chặn tương tác — tự ẩn/hiện theo
/// `HeavyTaskMonitor.instance.hasOverlappingHeavyTasks`.
class HeavyTaskWarningBanner extends StatelessWidget {
  const HeavyTaskWarningBanner({
    super.key,
    required this.message,
    this.icon = Icons.device_thermostat_outlined,
    this.backgroundColor,
    this.foregroundColor,
    this.onDismiss,
  });

  /// Nội dung hiển thị — TRUYỀN TỪ NƠI GỌI đã qua i18n (uiText/ARB), KHÔNG
  /// hard-code tại đây.
  final String message;

  final IconData icon;
  final Color? backgroundColor;
  final Color? foregroundColor;

  /// Nút "x" tuỳ chọn — null thì không hiện nút tắt (banner tự ẩn khi hết
  /// chồng chéo tác vụ).
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: HeavyTaskMonitor.instance,
      builder: (context, _) {
        final visible = HeavyTaskMonitor.instance.hasOverlappingHeavyTasks;
        return AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: visible ? _buildBanner(context) : const SizedBox.shrink(),
        );
      },
    );
  }

  Widget _buildBanner(BuildContext context) {
    final theme = Theme.of(context);
    final bg = backgroundColor ?? theme.colorScheme.errorContainer;
    final fg = foregroundColor ?? theme.colorScheme.onErrorContainer;
    return Material(
      color: bg,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(color: fg),
              ),
            ),
            if (onDismiss != null)
              IconButton(
                icon: Icon(Icons.close, size: 16, color: fg),
                onPressed: onDismiss,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
          ],
        ),
      ),
    );
  }
}
