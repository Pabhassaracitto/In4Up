// lib/screens/tools/tools_overlay.dart
//
// 🧩 TOOLS OVERLAY
// Nhấn nút Puzzle → màn hình mờ dần, các công cụ nổi lên
// với animation mảnh ghép rơi vào từng ô một (stagger)

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../screens/tools/youglish/youglish_screen.dart';

// ─── Model cho từng tool ─────────────────────────────────
class ToolItem {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isAvailable;
  final VoidCallback? onTap;

  const ToolItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.isAvailable = true,
    this.onTap,
  });
}

// ─── Entry point: gọi hàm này để mở overlay ─────────────
Future<void> showToolsOverlay(
  BuildContext context, {
  required List<ToolItem> tools,
}) {
  HapticFeedback.mediumImpact();
  return Navigator.of(context).push(
    _ToolsOverlayRoute(tools: tools),
  );
}

// ─── Custom Route: không push page mới, overlay trong suốt
class _ToolsOverlayRoute extends PageRoute<void> {
  @override
  bool get maintainState => true;
  final List<ToolItem> tools;

  _ToolsOverlayRoute({required this.tools}) : super(fullscreenDialog: false);

  @override
  bool get opaque => false; // Không che nền

  @override
  bool get barrierDismissible => true;

  @override
  Color get barrierColor => Colors.transparent;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 400);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    return _ToolsOverlayScreen(
      tools: tools,
      animation: animation,
    );
  }
}

// ─── Màn hình overlay chính ──────────────────────────────
class _ToolsOverlayScreen extends StatefulWidget {
  final List<ToolItem> tools;
  final Animation<double> animation;

  const _ToolsOverlayScreen({
    required this.tools,
    required this.animation,
  });

  @override
  State<_ToolsOverlayScreen> createState() => _ToolsOverlayScreenState();
}

class _ToolsOverlayScreenState extends State<_ToolsOverlayScreen>
    with TickerProviderStateMixin {
  late AnimationController _masterCtrl;
  late List<AnimationController> _cardCtrls;
  late Animation<double> _backdropAnim;
  late Animation<double> _headerAnim;

  @override
  void initState() {
    super.initState();

    // Controller tổng — backdrop + header
    _masterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _backdropAnim = CurvedAnimation(
      parent: _masterCtrl,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );

    _headerAnim = CurvedAnimation(
      parent: _masterCtrl,
      curve: const Interval(0.1, 0.6, curve: Curves.easeOutBack),
    );

    // Controller riêng cho từng card — staggered
    _cardCtrls = List.generate(
      widget.tools.length,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 550),
      ),
    );

    // Chạy animation theo thứ tự
    _masterCtrl.forward().then((_) {
      for (int i = 0; i < _cardCtrls.length; i++) {
        Future.delayed(Duration(milliseconds: i * 65), () {
          if (mounted) _cardCtrls[i].forward();
        });
      }
    });
  }

  @override
  void dispose() {
    _masterCtrl.dispose();
    for (final c in _cardCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _dismiss() async {
    HapticFeedback.lightImpact();
    // Reverse theo thứ tự ngược lại
    for (int i = _cardCtrls.length - 1; i >= 0; i--) {
      _cardCtrls[i].reverse();
      await Future.delayed(const Duration(milliseconds: 35));
    }
    await _masterCtrl.reverse();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _dismiss,
      child: Stack(
        children: [
          // ── Backdrop mờ dần ──
          AnimatedBuilder(
            animation: _backdropAnim,
            builder: (_, __) => Container(
              color: const Color(0xFF080B1A)
                  .withValues(alpha: _backdropAnim.value * 0.88),
            ),
          ),

          // ── Noise texture overlay (depth) ──
          AnimatedBuilder(
            animation: _backdropAnim,
            builder: (_, __) => Opacity(
              opacity: _backdropAnim.value * 0.03,
              child: const _NoiseTexture(),
            ),
          ),

          // ── Content ──
          SafeArea(
            child: Column(
              children: [
                // Header
                _buildHeader(),

                // Grid công cụ
                Expanded(
                  child: GestureDetector(
                    onTap: () {}, // Chặn tap xuyên qua grid
                    child: _buildToolsGrid(),
                  ),
                ),

                // Footer
                _buildFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Header: title + close ──────────────────────────────
  Widget _buildHeader() {
    return AnimatedBuilder(
      animation: _headerAnim,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, -24 * (1 - _headerAnim.value)),
        child: Opacity(
          opacity: _headerAnim.value.clamp(0.0, 1.0),
          child: child,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
        child: Row(
          children: [
            // Puzzle icon + title
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
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C4DFF).withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.extension, // Puzzle icon
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Công Cụ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  '${widget.tools.where((t) => t.isAvailable).length} tính năng',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),

            const Spacer(),

            // Close button
            GestureDetector(
              onTap: _dismiss,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Icon(
                  Icons.close,
                  color: Colors.grey[400],
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Grid công cụ ──────────────────────────────────────
  Widget _buildToolsGrid() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.55,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: widget.tools.length,
        itemBuilder: (_, i) {
          return _buildToolCard(widget.tools[i], i);
        },
      ),
    );
  }

  Widget _buildToolCard(ToolItem tool, int index) {
    // Mỗi card có animation riêng: scale từ 0 + slide từ dưới
    final ctrl = _cardCtrls[index];

    final scaleAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: ctrl, curve: Curves.easeOutBack),
    );
    final slideAnim = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(parent: ctrl, curve: Curves.easeOutCubic),
    );
    final fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: ctrl,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, slideAnim.value),
        child: Transform.scale(
          scale: scaleAnim.value,
          child: Opacity(
            opacity: fadeAnim.value.clamp(0.0, 1.0),
            child: _ToolCard(
              tool: tool,
              onTap: tool.isAvailable
                  ? () async {
                      await _dismiss();
                      tool.onTap?.call();
                    }
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  // ── Footer ────────────────────────────────────────────
  Widget _buildFooter() {
    return AnimatedBuilder(
      animation: _masterCtrl,
      builder: (_, child) => Opacity(
        opacity: (_masterCtrl.value - 0.5).clamp(0.0, 1.0) * 2,
        child: child,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 16, 28, 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.extension, size: 12, color: Colors.grey[700]),
            const SizedBox(width: 6),
            Text(
              'Tính năng sẽ tiếp tục được thêm vào',
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tool Card ────────────────────────────────────────────
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
            borderRadius: BorderRadius.circular(18),
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
          padding: const EdgeInsets.all(14),
          child: Stack(
            children: [
              // Background decorative icon
              Positioned(
                right: -4,
                bottom: -4,
                child: Icon(
                  tool.icon,
                  size: 44,
                  color: isAvailable
                      ? tool.color.withValues(alpha: 0.07)
                      : Colors.white.withValues(alpha: 0.03),
                ),
              ),

              // Content
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon badge
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

                  const Spacer(),

                  // Title
                  Text(
                    tool.title,
                    style: TextStyle(
                      color: isAvailable ? Colors.white : Colors.grey[600],
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isAvailable ? tool.subtitle : 'Sắp có',
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

              // "Sắp có" badge
              if (!isAvailable)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'SOON',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Noise texture (depth effect) ────────────────────────
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
        Offset(
          _rng.nextDouble() * size.width,
          _rng.nextDouble() * size.height,
        ),
        0.6,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Nút Puzzle trong bottom nav ─────────────────────────
// Dùng widget này trong _buildBottomNav() của main_shell.dart
class PuzzleNavButton extends StatefulWidget {
  final VoidCallback onTap;

  const PuzzleNavButton({super.key, required this.onTap});

  @override
  State<PuzzleNavButton> createState() => _PuzzleNavButtonState();
}

class _PuzzleNavButtonState extends State<PuzzleNavButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _glowAnim = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _glowAnim,
              builder: (_, child) => Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C4DFF), Color(0xFFE040FB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C4DFF)
                          .withValues(alpha: _glowAnim.value),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.extension,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(height: 4),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF7C4DFF), Color(0xFFE040FB)],
              ).createShader(bounds),
              child: const Text(
                'Tools',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
