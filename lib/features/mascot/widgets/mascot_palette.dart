// lib/features/mascot/widgets/mascot_palette.dart
//
// MASCOT-002 — Palette «Mở nhanh» của linh vật Sara (PLAN-050 §7).
//
// Một overlay tìm kiếm hợp nhất: chức năng (tool) + tab/mode + tệp gần đây +
// âm thanh — đi qua MascotSearchIndex (thuần) và trả về id hành động cho
// caller (main_shell) thực thi qua cùng cơ chế quick actions.
//
// UX: mở bằng một chạm từ quick actions; gõ không dấu vẫn khớp; bàn phím
// desktop ↑↓ chọn · Enter mở · Esc đóng; chạm để mở trên mobile.
//
// i18n: mọi nhãn chrome đi qua `context.uiText(...)` (rule #5 AGENTS.md) —
// 6 chuỗi mới đã đăng ký trong `priority_ui_overrides.dart` (en/hi/zh/zh_TW/si)
// + `generated_legacy_ui_fallbacks.dart` (en) + `legacy_ui_english_overrides.json`.

// LƯU Ý (AGENTS.md): file UI chỉ import `localized_material.dart` — nó
// re-export material.dart và SHIM `Text` (dịch chrome khi locale ≠ vi).
// Import thêm material.dart ⇒ Text ambiguous (lỗi compile đã gặp ở P0).

import 'package:flutter/services.dart';

import '../../../core/language/localized_material.dart';
import '../mascot_search_index.dart';

/// Mở palette; trả về id hành động được chọn (null nếu đóng).
Future<String?> showMascotPalette(
  BuildContext context, {
  required List<MascotSearchEntry> entries,
}) {
  HapticFeedback.lightImpact();
  return showGeneralDialog<String?>(
    context: context,
    useRootNavigator: true,
    barrierLabel: 'MascotPalette',
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (ctx, animation, secondary) {
      return MascotPaletteSheet(entries: entries);
    },
    transitionBuilder: (ctx, animation, secondary, child) {
      return FadeTransition(
        opacity: animation,
        child: child,
      );
    },
  );
}

/// Màu thương hiệu (brand/identity — Hidden Gift Quiet Reveal 04A).
const Color _kPaletteBg = Color(0xFF0B1B2B);
const Color _kIvory = Color(0xFFF8F4EA);
const Color _kJade = Color(0xFF53D6BD);
const Color _kGold = Color(0xFFF4C95D);
const double _kRowExtent = 60;

class MascotPaletteSheet extends StatefulWidget {
  final List<MascotSearchEntry> entries;

  const MascotPaletteSheet({super.key, required this.entries});

  @override
  State<MascotPaletteSheet> createState() => _MascotPaletteSheetState();
}

class _MascotPaletteSheetState extends State<MascotPaletteSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  late final MascotSearchIndex _index = MascotSearchIndex(widget.entries);
  List<MascotSearchResult> _results = const <MascotSearchResult>[];
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    _results = _index.search('');
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    setState(() {
      _results = _index.search(query);
      _selected = 0;
    });
  }

  void _move(int delta) {
    if (_results.isEmpty) return;
    setState(() {
      _selected = (_selected + delta).clamp(0, _results.length - 1);
    });
    _ensureVisible();
  }

  void _ensureVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final target = _selected * _kRowExtent;
      final viewport = _scrollController.position.viewportDimension;
      final current = _scrollController.offset;
      if (target < current) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
        );
      } else if (target + _kRowExtent > current + viewport) {
        _scrollController.animateTo(
          target + _kRowExtent - viewport,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _close([String? result]) {
    Navigator.of(context, rootNavigator: true).pop(result);
  }

  void _executeAt(int index) {
    if (index < 0 || index >= _results.length) return;
    HapticFeedback.selectionClick();
    _close(_results[index].entry.id);
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      _move(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _move(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.select) {
      _executeAt(_selected);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      _close();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 560, maxHeight: 520),
              decoration: BoxDecoration(
                color: _kPaletteBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _kJade.withValues(alpha: 0.25)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(),
                    _buildSearchField(),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: Colors.white.withValues(alpha: 0.07),
                    ),
                    Flexible(
                      child: _results.isEmpty
                          ? _buildEmpty()
                          : ListView.builder(
                              controller: _scrollController,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 4),
                              itemExtent: _kRowExtent,
                              itemCount: _results.length,
                              itemBuilder: (ctx, i) => _buildRow(i),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, size: 18, color: _kGold),
          const SizedBox(width: 8),
          Text(
            context.uiText('Mở nhanh'),
            style: const TextStyle(
              color: _kIvory,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => _close(),
            icon: Icon(Icons.close_rounded,
                size: 20, color: Colors.white.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    // Focus (không KeyboardListener): handler cần trả KeyEventResult để chặn
    // ↑↓/Enter/Esc trước TextField (KeyboardListener chỉ nhận void callback).
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKey,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        autofocus: true,
        onChanged: _onQueryChanged,
        textInputAction: TextInputAction.go,
        onSubmitted: (_) => _executeAt(_selected),
        style: const TextStyle(color: _kIvory, fontSize: 16),
        cursorColor: _kJade,
        decoration: InputDecoration(
          hintText: context.uiText('Tìm chức năng, tệp hoặc lệnh…'),
          hintStyle:
              TextStyle(color: Colors.white.withValues(alpha: 0.35)),
          prefixIcon: const Icon(Icons.manage_search_rounded,
              color: _kJade, size: 22),
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _controller.clear();
                    _onQueryChanged('');
                  },
                  icon: Icon(Icons.close_rounded,
                      size: 18, color: Colors.white.withValues(alpha: 0.5)),
                ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded,
              size: 32, color: Colors.white.withValues(alpha: 0.3)),
          const SizedBox(height: 10),
          Text(
            context.uiText('Không có kết quả khớp'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(int index) {
    final result = _results[index];
    final entry = result.entry;
    final selected = index == _selected;
    return SizedBox(
      height: _kRowExtent,
      child: InkWell(
        onTap: () => _executeAt(index),
        child: Container(
          color: selected
              ? _kJade.withValues(alpha: 0.10)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _kindColor(entry.kind).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_kindIcon(entry.kind),
                    size: 20, color: _kindColor(entry.kind)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _kIvory,
                        fontSize: 15,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    if (entry.subtitle != null &&
                        entry.subtitle!.trim().isNotEmpty)
                      Text(
                        entry.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _kindLabel(entry.kind),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _kindLabel(MascotSearchKind kind) {
    switch (kind) {
      case MascotSearchKind.tab:
      case MascotSearchKind.mode:
        return context.uiText('Đi đến');
      case MascotSearchKind.tool:
        return context.uiText('Chức năng');
      case MascotSearchKind.file:
      case MascotSearchKind.audio:
      case MascotSearchKind.note:
        return context.uiText('Tệp & âm thanh');
    }
  }

  IconData _kindIcon(MascotSearchKind kind) {
    switch (kind) {
      case MascotSearchKind.tab:
        return Icons.layers_rounded;
      case MascotSearchKind.mode:
        return Icons.swap_horiz_rounded;
      case MascotSearchKind.tool:
        return Icons.extension_outlined;
      case MascotSearchKind.file:
        return Icons.description_outlined;
      case MascotSearchKind.audio:
        return Icons.audiotrack_rounded;
      case MascotSearchKind.note:
        return Icons.sticky_note_2_outlined;
    }
  }

  Color _kindColor(MascotSearchKind kind) {
    switch (kind) {
      case MascotSearchKind.tab:
        return const Color(0xFF90CAF9);
      case MascotSearchKind.mode:
        return const Color(0xFFFFB300);
      case MascotSearchKind.tool:
        return _kJade;
      case MascotSearchKind.file:
        return const Color(0xFFB388FF);
      case MascotSearchKind.audio:
        return const Color(0xFF26C6DA);
      case MascotSearchKind.note:
        return const Color(0xFF6C63FF);
    }
  }
}
