// lib/features/mascot/widgets/mascot_bubble.dart
//
// MASCOT-004 — Bong bóng nổi của linh vật Sara trong MainShell (PLAN-050 §10,
// ADR-0036 D1). Overlay trong Stack của body — KHÔNG phải màn push.
//
// Hình mẫu (owner chốt 2026-11-25): lá bồ đề — icon lá + tông Bodhi gold,
// nền Midnight, viền Jade. 2 trạng thái bong bóng: nổi (nhớ tương tác 12 s)
// và autohide (thu nhỏ + mờ đi) — chạm là phục hồi. Đang trả lời ⇒ vành jade
// nhấp nháy nhẹ (không animation nặng, không thêm dependency).
//
// File UI: chỉ import `localized_material.dart` (shim Text — rule #5).

import 'dart:async';

import 'package:in4up_ai/in4up_ai.dart';

import '../../../core/language/localized_material.dart';

/// Bán kính "đang bận" — vành jade quanh lá.
class MascotBubble extends StatefulWidget {
  final VoidCallback onTap;

  const MascotBubble({
    super.key,
    required this.onTap,
  });

  @override
  State<MascotBubble> createState() => _MascotBubbleState();
}

class _MascotBubbleState extends State<MascotBubble> {
  static const Duration _autohideAfter = Duration(seconds: 12);

  Timer? _timer;
  bool _shrunk = false;

  @override
  void initState() {
    super.initState();
    _scheduleAutohide();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _scheduleAutohide() {
    _timer?.cancel();
    _timer = Timer(_autohideAfter, () {
      if (!mounted || AiServiceFacade().isChatLoading) return;
      setState(() => _shrunk = true);
    });
  }

  void _handleTap() {
    setState(() => _shrunk = false);
    _scheduleAutohide();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    // Tự lắng nghe facade qua SINGLETON (không phụ thuộc Provider — môi
    // trường widget test pump MainShell không có Provider AiServiceFacade;
    // lỗi linux_shell_regression run 45577189591).
    return AnimatedBuilder(
      animation: AiServiceFacade(),
      builder: (context, _) => _buildBubble(context),
    );
  }

  Widget _buildBubble(BuildContext context) {
    final busy = AiServiceFacade().isChatLoading;
    if (busy && _shrunk) _shrunk = false;
    final size = _shrunk ? 40.0 : 54.0;
    return Semantics(
      button: true,
      label: context.uiText('Hỏi Sara'),
      child: GestureDetector(
        onTap: _handleTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF163148), Color(0xFF06121E)],
            ),
            border: Border.all(
              color: busy
                  ? const Color(0xFF53D6BD)
                  : const Color(0xFFF4C95D).withValues(
                      alpha: _shrunk ? 0.35 : 0.75),
              width: busy ? 2 : 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(
            Icons.eco_outlined, // lá bồ đề cách điệu
            size: size * 0.52,
            color: const Color(0xFFF4C95D)
                .withValues(alpha: _shrunk ? 0.55 : 1.0),
          ),
        ),
      ),
    );
  }
}
