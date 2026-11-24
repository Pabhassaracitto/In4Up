// lib/screens/tools/tools_overlay_v2.dart
//
// Quick Actions / Tools Overlay:
// - Mở mượt trong 220ms, đóng tức thì (≤ 100ms khi đóng thường, 0ms khi chọn tool)
//   thay vì chờ reverse tuần tự ~800ms.
// - Dùng PopScope chuẩn mới.
// - Tích hợp ô tìm kiếm tức thời để lọc nhanh danh sách công cụ.

import 'dart:async';

import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter/services.dart';

import '../../core/responsive/app_responsive.dart';

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
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 100),
    )..forward();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  List<ToolItem> get _filteredTools {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.tools;
    return widget.tools.where((t) {
      return t.title.toLowerCase().contains(q) ||
          t.subtitle.toLowerCase().contains(q) ||
          t.id.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _dismiss([String? toolId]) async {
    if (_isDismissing) return;
    _isDismissing = true;

    HapticFeedback.lightImpact();

    // Khi người dùng đã chọn công cụ, thoát ngay để mở màn hình đích không trễ.
    if (toolId == null && mounted) {
      await _ctrl.reverse();
    }
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(toolId);
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          unawaited(_dismiss(null));
        }
      },
      child: Material(
        type: MaterialType.transparency,
        child: GestureDetector(
          onTap: () => _dismiss(null),
          child: Stack(
            children: [
              // Backdrop
              AnimatedBuilder(
                animation: curved,
                builder: (_, __) => Container(
                  color: const Color(0xFF080B1A)
                      .withValues(alpha: curved.value * 0.90),
                ),
              ),

              // Content
              SafeArea(
                child: GestureDetector(
                  onTap: () {}, // block tap xuyên qua
                  child: FadeTransition(
                    opacity: curved,
                    child: Column(
                      children: [
                        _buildHeader(),
                        _buildSearchBar(),
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                            child: _buildToolsGrid(),
                          ),
                        ),
                      ],
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7C4DFF), Color(0xFFE040FB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Công Cụ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                Text(
                  context.uiText(
                    '${widget.tools.where((t) => t.isAvailable).length} tính năng',
                  ),
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: context.uiText('Đóng'),
            onPressed: () => _dismiss(null),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: Icon(Icons.close, color: Colors.grey[300], size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: SizedBox(
        height: 40,
        child: TextField(
          controller: _searchCtrl,
          onChanged: (val) => setState(() => _query = val),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: context.uiText('Tìm kiếm...'),
            hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
            prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey[400]),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: Icon(Icons.clear, size: 16, color: Colors.grey[400]),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _query = '');
                    },
                  ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF7C4DFF)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolsGrid() {
    final items = _filteredTools;
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(
            context.uiText('Không tìm thấy kết quả'),
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
        ),
      );
    }

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
      itemCount: items.length,
      itemBuilder: (_, i) {
        final tool = items[i];
        return _ToolCard(
          tool: tool,
          onTap: tool.isAvailable ? () => _dismiss(tool.id) : null,
        );
      },
    );
  }
}

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
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isAvailable
                  ? [
                      tool.color.withValues(alpha: 0.16),
                      tool.color.withValues(alpha: 0.06),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.04),
                      Colors.white.withValues(alpha: 0.02),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isAvailable
                  ? tool.color.withValues(alpha: _pressed ? 0.55 : 0.24)
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: isAvailable
                      ? tool.color.withValues(alpha: 0.18)
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      tool.title,
                      style: TextStyle(
                        color: isAvailable ? Colors.white : Colors.grey[600],
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isAvailable ? tool.subtitle : 'Sắp có',
                      style: TextStyle(
                        color: isAvailable
                            ? tool.color.withValues(alpha: 0.78)
                            : Colors.grey[700],
                        fontSize: 11,
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
