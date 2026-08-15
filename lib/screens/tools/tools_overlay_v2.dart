// lib/screens/tools/tools_overlay_v2.dart
//
// ★ FIX SCROLL: bọc GridView trong SingleChildScrollView thay vì Column.Expanded
// ★ FIX BOX HEIGHT: childAspectRatio tăng từ 1.55 → 2.2 (box thấp hơn)
// ★ FIX: physics cuộn bình thường cho grid

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/responsive/app_responsive.dart';
import 'package:in4up/core/language/tr_extension.dart';

class ToolItem {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isAvailable;

  const ToolItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.isAvailable = true,
  });
}

/// Mở overlay và nhận toolId (null nếu đóng)
Future<String?> showToolsOverlayV2(
  BuildContext context, {
  required List<ToolItem> tools,
}) {
  HapticFeedback.mediumImpact();

  return showGeneralDialog<String?>(
    context: context,
    useRootNavigator: true,
    barrierLabel: 'Tools',
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    transitionDuration: Duration.zero,
    pageBuilder: (ctx, a1, a2) {
      return _ToolsOverlayScreenV2(tools: tools);
    },
  );
}

class _ToolsOverlayScreenV2 extends StatefulWidget {
  final List<ToolItem> tools;
  const _ToolsOverlayScreenV2({required this.tools});

  @override
  State<_ToolsOverlayScreenV2> createState() => _ToolsOverlayScreenV2State();
}

class _ToolsOverlayScreenV2State extends State<_ToolsOverlayScreenV2>
    with TickerProviderStateMixin {
  late final AnimationController _masterCtrl;
  late final List<AnimationController> _cardCtrls;

  final List<Timer> _timers = [];
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();

    _masterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _cardCtrls = List.generate(
      widget.tools.length,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 550),
      ),
    );

    _masterCtrl.forward();

    for (int i = 0; i < _cardCtrls.length; i++) {
      _timers.add(
        Timer(Duration(milliseconds: 120 + i * 55), () {
          if (!mounted || _isDismissing) return;
          _cardCtrls[i].forward();
        }),
      );
    }
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _masterCtrl.stop();
    _masterCtrl.dispose();
    for (final c in _cardCtrls) {
      c.stop();
      c.dispose();
    }
    super.dispose();
  }

  double _backdropT() => const Interval(0.0, 0.5, curve: Curves.easeOut)
      .transform(_masterCtrl.value);

  double _headerT() => const Interval(0.1, 0.6, curve: Curves.easeOutBack)
      .transform(_masterCtrl.value);

  Future<void> _dismiss([String? toolId]) async {
    if (_isDismissing) return;
    _isDismissing = true;

    HapticFeedback.lightImpact();

    for (final t in _timers) {
      t.cancel();
    }

    for (int i = _cardCtrls.length - 1; i >= 0; i--) {
      _cardCtrls[i].reverse();
      await Future.delayed(const Duration(milliseconds: 20));
    }
    await _masterCtrl.reverse();

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(toolId);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _dismiss(null);
        return false;
      },
      child: Material(
        type: MaterialType.transparency,
        child: GestureDetector(
          onTap: () => _dismiss(null),
          child: Stack(
            children: [
              // Backdrop
              AnimatedBuilder(
                animation: _masterCtrl,
                builder: (_, __) => Container(
                  color: const Color(0xFF080B1A)
                      .withValues(alpha: _backdropT() * 0.88),
                ),
              ),

              // Noise texture
              AnimatedBuilder(
                animation: _masterCtrl,
                builder: (_, __) => Opacity(
                  opacity: _backdropT() * 0.03,
                  child: const _NoiseTexture(),
                ),
              ),

              // Content — scrollable
              SafeArea(
                child: GestureDetector(
                  onTap: () {}, // block tap xuyên qua
                  child: Column(
                    children: [
                      _buildHeader(),
                      // ★ FIX: Expanded + SingleChildScrollView thay vì Expanded + GridView(NeverScroll)
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                          child: _buildToolsGrid(),
                        ),
                      ),
                      _buildFooter(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return AnimatedBuilder(
      animation: _masterCtrl,
      builder: (_, child) {
        final h = _headerT();
        return Transform.translate(
          offset: Offset(0, -24 * (1 - h)),
          child: Opacity(opacity: h.clamp(0.0, 1.0), child: child),
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C4DFF), Color(0xFFE040FB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.extension, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(context.l10n.toolsTitle, style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  '${widget.tools.where((t) => t.isAvailable).length} Feature',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => _dismiss(null),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Icon(Icons.close, color: Colors.grey[400], size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolsGrid() {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = AppResponsive.adaptiveGridColumns(
      width,
      compact: width < 380 ? 1 : 2,
      medium: 2,
      expanded: 3,
      large: 4,
    );
    final childAspectRatio = width < 380
        ? 3.4
        : width < 600
            ? 2.2
            : width < 1024
                ? 2.0
                : 2.15;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: widget.tools.length,
      itemBuilder: (_, i) => _buildToolCard(widget.tools[i], i),
    );
  }

  Widget _buildToolCard(ToolItem tool, int index) {
    final ctrl = index < _cardCtrls.length
        ? _cardCtrls[index]
        : AnimationController(vsync: this);

    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) {
        final t = ctrl.value;
        final scale = 0.6 + 0.4 * Curves.easeOutBack.transform(t);
        final slideY = 30.0 * (1.0 - Curves.easeOutCubic.transform(t));
        final fade = Curves.easeOut.transform((t / 0.6).clamp(0.0, 1.0));

        return Transform.translate(
          offset: Offset(0, slideY),
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: fade.clamp(0.0, 1.0),
              child: _ToolCard(
                tool: tool,
                onTap: tool.isAvailable ? () => _dismiss(tool.id) : null,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFooter() {
    return AnimatedBuilder(
      animation: _masterCtrl,
      builder: (_, child) => Opacity(
        opacity: ((_masterCtrl.value - 0.5) * 2).clamp(0.0, 1.0),
        child: child,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 12, 28, 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.extension, size: 12, color: Colors.grey[700]),
            const SizedBox(width: 6),
            Text(context.l10n.toolsMoreComing, style: TextStyle(color: Colors.grey[700], fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tool Card ───────────────────────────────────────────
class _ToolCard extends StatefulWidget {
  final ToolItem tool;
  final VoidCallback? onTap;

  const _ToolCard({required this.tool, this.onTap});

  @override
  State<_ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<_ToolCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final tool = widget.tool;
    final isAvailable = tool.isAvailable;

    return GestureDetector(
      onTapDown: isAvailable ? (_) => setState(() => _pressed = true) : null,
      onTapUp: isAvailable
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap?.call();
            }
          : null,
      onTapCancel: isAvailable ? () => setState(() => _pressed = false) : null,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isAvailable
                  ? [
                      tool.color.withValues(alpha: 0.18),
                      tool.color.withValues(alpha: 0.08),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.04),
                      Colors.white.withValues(alpha: 0.02),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isAvailable
                  ? tool.color.withValues(alpha: _pressed ? 0.6 : 0.25)
                  : Colors.white.withValues(alpha: 0.06),
              width: 1.2,
            ),
            boxShadow: isAvailable && _pressed
                ? [
                    BoxShadow(
                      color: tool.color.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              // Icon box — nhỏ gọn
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: isAvailable
                      ? tool.color.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  tool.icon,
                  size: 16,
                  color: isAvailable ? tool.color : Colors.grey[600],
                ),
              ),
              const SizedBox(width: 10),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      tool.title,
                      style: TextStyle(
                        color: isAvailable ? Colors.white : Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isAvailable ? tool.subtitle: context.l10n.commonComingSoon,
                      style: TextStyle(
                        color: isAvailable
                            ? tool.color.withValues(alpha: 0.7)
                            : Colors.grey[700],
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Noise Texture ───────────────────────────────────────
class _NoiseTexture extends StatelessWidget {
  const _NoiseTexture();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _NoisePainter(),
      size: Size.infinite,
    );
  }
}

class _NoisePainter extends CustomPainter {
  static final _rng = math.Random(42);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    for (int i = 0; i < 3000; i++) {
      canvas.drawCircle(
        Offset(_rng.nextDouble() * size.width, _rng.nextDouble() * size.height),
        0.6,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}