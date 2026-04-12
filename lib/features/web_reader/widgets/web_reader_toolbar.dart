import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/color_mode.dart';
import '../web_reader_controller.dart';

class WebReaderToolbar extends StatefulWidget {
  final WebReaderController controller;
  final Function(String url) onNavigate;
  final VoidCallback onExtractText;

  const WebReaderToolbar({
    super.key,
    required this.controller,
    required this.onNavigate,
    required this.onExtractText,
  });

  @override
  State<WebReaderToolbar> createState() => _WebReaderToolbarState();
}

class _WebReaderToolbarState extends State<WebReaderToolbar> {
  final _urlCtrl = TextEditingController();
  bool _isEditing = false;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerUpdate);
  }

  void _onControllerUpdate() {
    if (!_isEditing && mounted) {
      _urlCtrl.text = widget.controller.currentUrl;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    _urlCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final url = WebReaderController.normalizeUrl(_urlCtrl.text.trim());
    if (url.isEmpty) return;
    _isEditing = false;
    _focusNode.unfocus();
    widget.onNavigate(url);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 4,
        left: 8,
        right: 8,
        bottom: 6,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.07)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Row 1: Back/Forward + URL bar + actions ──────
          Row(
            children: [
              // Back
              _ToolbarBtn(
                icon: Icons.home_outlined,
                size: 20,
                enabled: true,
                onTap: () => widget.onNavigate(''), // Rỗng để về Dashboard
                tooltip: 'Trang chủ Dashboard',
              ),
              const SizedBox(width: 2),

              _ToolbarBtn(
                icon: Icons.arrow_back_ios_new,
                size: 16,
                enabled: ctrl.canGoBack,
                onTap: () => widget.onNavigate('__back__'),
              ),

              // Forward
              _ToolbarBtn(
                icon: Icons.arrow_forward_ios,
                size: 16,
                enabled: ctrl.canGoForward,
                onTap: () => widget.onNavigate('__forward__'),
              ),

              const SizedBox(width: 4),

              // ── URL Bar ─────────────────────────────────
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _isEditing = true);
                    _urlCtrl.selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: _urlCtrl.text.length,
                    );
                    _focusNode.requestFocus();
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _isEditing
                            ? const Color(0xFF2196F3).withOpacity(0.5)
                            : Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Lock/Globe icon
                        Icon(
                          ctrl.currentUrl.startsWith('https')
                              ? Icons.lock_outline
                              : Icons.public,
                          size: 12,
                          color: ctrl.currentUrl.startsWith('https')
                              ? const Color(0xFF4CAF50)
                              : Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            controller: _urlCtrl,
                            focusNode: _focusNode,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                            decoration: const InputDecoration(
                              hintText: 'URL hoặc tìm kiếm...',
                              hintStyle:
                                  TextStyle(color: Colors.grey, fontSize: 12),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onTap: () => setState(() => _isEditing = true),
                            onChanged: (_) => setState(() => _isEditing = true),
                            onSubmitted: (_) => _submit(),
                            textInputAction: TextInputAction.go,
                          ),
                        ),
                        if (_isEditing)
                          GestureDetector(
                            onTap: () {
                              _urlCtrl.clear();
                              setState(() => _isEditing = true);
                            },
                            child: const Icon(Icons.close,
                                size: 14, color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 4),

              // Color mode cycle
              _ColorModeButton(controller: ctrl),

              // Extract text → Text Studio
              _ToolbarBtn(
                icon: Icons.text_fields,
                size: 18,
                enabled: ctrl.state == WebReaderState.ready,
                onTap: widget.onExtractText,
                tooltip: 'Mở trong Text Studio',
                activeColor: const Color(0xFF2196F3),
              ),

              // Bookmark
              _ToolbarBtn(
                icon: ctrl.isBookmarked(ctrl.currentUrl)
                    ? Icons.bookmark
                    : Icons.bookmark_border,
                size: 18,
                enabled: ctrl.state == WebReaderState.ready,
                onTap: ctrl.toggleBookmark,
                activeColor: Colors.amber,
                isActive: ctrl.isBookmarked(ctrl.currentUrl),
              ),
            ],
          ),

          // ── Loading bar ───────────────────────────────────
          if (ctrl.state == WebReaderState.loading)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: LinearProgressIndicator(
                value: ctrl.loadingProgress < 1.0 ? ctrl.loadingProgress : null,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation(Color(0xFF2196F3)),
                minHeight: 2,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Color Mode Button ────────────────────────────────────

class _ColorModeButton extends StatelessWidget {
  final WebReaderController controller;
  const _ColorModeButton({required this.controller});

  @override
  Widget build(BuildContext context) {
    final isActive = controller.colorMode != ColorMode.none;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        controller.cycleColorMode();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF2196F3).withOpacity(0.2)
              : Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(8),
          border: isActive
              ? Border.all(color: const Color(0xFF2196F3).withOpacity(0.4))
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              controller.colorMode.icon,
              size: 13,
              color: isActive ? const Color(0xFF2196F3) : Colors.grey,
            ),
            if (isActive) ...[
              const SizedBox(width: 3),
              Text(
                controller.colorMode.label,
                style: const TextStyle(
                    color: Color(0xFF2196F3),
                    fontSize: 10,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Toolbar Button ───────────────────────────────────────

class _ToolbarBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  final bool enabled;
  final bool isActive;
  final VoidCallback? onTap;
  final String? tooltip;
  final Color? activeColor;

  const _ToolbarBtn({
    required this.icon,
    required this.size,
    this.enabled = true,
    this.isActive = false,
    this.onTap,
    this.tooltip,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveActiveColor = activeColor ?? const Color(0xFF2196F3);
    final color = !enabled
        ? Colors.grey[700]!
        : isActive
            ? effectiveActiveColor
            : Colors.white70;

    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: isActive
                ? effectiveActiveColor.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: size, color: color),
        ),
      ),
    );
  }
}
