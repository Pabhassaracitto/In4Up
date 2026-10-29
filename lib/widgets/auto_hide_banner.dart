import 'dart:async';

import 'package:in4up/core/language/localized_material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Banner thông minh: hiện vài giây rồi tự ẩn, có thể vuốt để tắt,
/// và có tùy chọn tắt luôn (lưu vào SharedPreferences).
class AutoHideInfoBanner extends StatefulWidget {
  final String storageKey; // key để lưu "don't show again"
  final Widget child;
  final Duration autoHideAfter;
  final bool showDontShowAgain;

  const AutoHideInfoBanner({
    super.key,
    required this.storageKey,
    required this.child,
    this.autoHideAfter = const Duration(seconds: 5),
    this.showDontShowAgain = true,
  });

  @override
  State<AutoHideInfoBanner> createState() => _AutoHideInfoBannerState();
}

class _AutoHideInfoBannerState extends State<AutoHideInfoBanner>
    with SingleTickerProviderStateMixin {
  bool _visible = true;
  bool _dontShowAgain = false;
  Timer? _timer;
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
    _checkShouldShow();
  }

  Future<void> _checkShouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    final hidden = prefs.getBool('${widget.storageKey}_hidden') ?? false;
    if (hidden && mounted) {
      setState(() => _visible = false);
      return;
    }
    // Auto hide after duration
    _timer = Timer(widget.autoHideAfter, () {
      if (mounted && _visible) {
        _hide();
      }
    });
  }

  void _hide() {
    _controller.reverse().then((_) {
      if (mounted) {
        setState(() => _visible = false);
      }
    });
  }

  Future<void> _setDontShowAgain(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${widget.storageKey}_hidden', value);
    setState(() => _dontShowAgain = value);
    if (value) {
      _hide();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    return SizeTransition(
      sizeFactor: _animation,
      axis: Axis.vertical,
      child: Dismissible(
        key: ValueKey(widget.storageKey),
        direction: DismissDirection.vertical,
        onDismissed: (_) => setState(() => _visible = false),
        child: Stack(
          children: [
            widget.child,
            // Close button top right
            Positioned(
              top: 4,
              right: 4,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.showDontShowAgain)
                    GestureDetector(
                      onTap: () => _setDontShowAgain(!_dontShowAgain),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _dontShowAgain
                                  ? Icons.check_box
                                  : Icons.check_box_outline_blank,
                              size: 12,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 3),
                            const Text(
                              'Không hiện lại',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 9),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: _hide,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          size: 14, color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
