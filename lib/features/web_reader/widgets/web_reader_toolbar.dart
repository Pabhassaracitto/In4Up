import 'package:flutter/services.dart';
import 'package:in4up/core/language/localized_material.dart';

import '../../../models/color_mode.dart';
import '../web_reader_controller.dart';

class WebReaderToolbar extends StatefulWidget {
  final WebReaderController controller;
  final VoidCallback onExit;
  final Function(String url) onNavigate;
  final VoidCallback onRefresh;
  final VoidCallback onTranslatePage;
  final VoidCallback onExtractText;
  final VoidCallback onSavePageToCollection;
  final VoidCallback onOpenGrammarSettings;
  final VoidCallback onListenArticle;
  final ValueChanged<String> onPageAction;
  final bool showingDashboard;
  final bool writingMode;

  const WebReaderToolbar({
    super.key,
    required this.controller,
    required this.onExit,
    required this.onNavigate,
    required this.onRefresh,
    required this.onTranslatePage,
    required this.onExtractText,
    required this.onSavePageToCollection,
    required this.onOpenGrammarSettings,
    required this.onListenArticle,
    required this.onPageAction,
    required this.showingDashboard,
    this.writingMode = false,
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
    _urlCtrl.text = widget.controller.currentUrl;
    widget.controller.addListener(_onControllerUpdate);
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    if (!_isEditing && _urlCtrl.text != widget.controller.currentUrl) {
      _urlCtrl.text = widget.controller.currentUrl;
    }
    // Toolbar actions, history buttons, and the load indicator are all driven
    // by controller state, so refresh this compact row on controller updates.
    setState(() {});
  }

  @override
  void didUpdateWidget(covariant WebReaderToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerUpdate);
      widget.controller.addListener(_onControllerUpdate);
      if (!_isEditing) _urlCtrl.text = widget.controller.currentUrl;
    }
    if (!oldWidget.showingDashboard &&
        widget.showingDashboard &&
        !_isEditing &&
        widget.controller.currentUrl.isEmpty) {
      _urlCtrl.clear();
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
    final pageActionsEnabled =
        !widget.showingDashboard && ctrl.state == WebReaderState.ready;

    return Container(
      // The old screen AppBar is folded into this one compact row. Keep the
      // status-bar inset here so the browser still respects mobile safe areas.
      padding: EdgeInsets.fromLTRB(
        6,
        MediaQuery.of(context).padding.top + 2,
        6,
        4,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _ToolbarBtn(
                icon: Icons.close_rounded,
                size: 19,
                enabled: true,
                onTap: widget.onExit,
                tooltip: context.uiText('Quay lại'),
              ),
              _ToolbarBtn(
                icon: Icons.arrow_back_rounded,
                size: 18,
                enabled: !widget.showingDashboard && ctrl.canGoBack,
                onTap: () => widget.onNavigate('__back__'),
                tooltip: context.uiText('Trang trước'),
              ),
              const SizedBox(width: 2),
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
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: _isEditing
                            ? const Color(0xFF2196F3).withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          ctrl.currentUrl.startsWith('https')
                              ? Icons.lock_outline
                              : Icons.public,
                          size: 12,
                          color: ctrl.currentUrl.startsWith('https')
                              ? const Color(0xFF4CAF50)
                              : Colors.grey,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: TextField(
                            controller: _urlCtrl,
                            focusNode: _focusNode,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                            decoration: InputDecoration(
                              hintText: context.uiText(
                                widget.showingDashboard
                                    ? 'URL hoặc tìm kiếm để mở nhanh...'
                                    : 'URL hoặc tìm kiếm...',
                              ),
                              hintStyle: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
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
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 2),
              _ColorModeButton(
                controller: ctrl,
                enabled: pageActionsEnabled,
              ),
              _ToolbarBtn(
                icon: Icons.translate_rounded,
                size: 18,
                enabled: pageActionsEnabled,
                onTap: widget.onTranslatePage,
                activeThumbColor: const Color(0xFF66BB6A),
                tooltip: context.uiText('Dịch trang'),
              ),
              PopupMenuButton<String>(
                tooltip: context.uiText('Tác vụ bài đọc'),
                color: const Color(0xFF151B26),
                icon: const Icon(Icons.more_vert, color: Colors.white70, size: 21),
                onSelected: _handleMenuAction,
                itemBuilder: _buildMenuItems,
              ),
            ],
          ),
          if (ctrl.state == WebReaderState.loading && !widget.showingDashboard)
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

  List<PopupMenuEntry<String>> _buildMenuItems(BuildContext context) {
    final ctrl = widget.controller;
    final pageActionsEnabled =
        !widget.showingDashboard && ctrl.state == WebReaderState.ready;
    final items = <PopupMenuEntry<String>>[
      _menuItem(context, '__home__', Icons.home_outlined, 'Trang chủ Dashboard'),
      if (ctrl.canGoForward)
        _menuItem(context, '__forward__', Icons.arrow_forward_rounded, 'Trang sau'),
      if (!widget.showingDashboard)
        _menuItem(context, '__refresh__', Icons.refresh_rounded, 'Tải lại trang'),
      const PopupMenuDivider(),
      _menuItem(
        context,
        '__recall__',
        ctrl.showRecallMarkers ? Icons.visibility : Icons.visibility_outlined,
        'Đánh dấu từ đã lưu (bật/tắt marker: xanh = đã lưu, vàng = có ghi chú, đỏ = đến kỳ ôn)',
        enabled: !widget.showingDashboard,
      ),
      if (pageActionsEnabled && ctrl.colorMode == ColorMode.wordType)
        _menuItem(
          context,
          '__grammar__',
          Icons.auto_awesome_motion,
          'Cài đặt từ loại chuyên sâu',
        ),
      _menuItem(
        context,
        '__listen__',
        ctrl.isSpeaking ? Icons.headphones : Icons.headphones_outlined,
        ctrl.isSpeaking ? 'Mở điều khiển nghe bài' : 'Nghe bài web',
        enabled: pageActionsEnabled,
      ),
      _menuItem(
        context,
        '__extract__',
        widget.writingMode ? Icons.edit_square : Icons.text_fields,
        widget.writingMode
            ? 'Dùng cả bài làm nguồn luyện Viết'
            : 'Mở trong Text Studio',
        enabled: pageActionsEnabled,
      ),
      _menuItem(
        context,
        '__collection__',
        Icons.playlist_add,
        'Lưu trang hiện tại vào nhóm',
        enabled: pageActionsEnabled,
      ),
      _menuItem(
        context,
        '__bookmark__',
        ctrl.isBookmarked(ctrl.currentUrl)
            ? Icons.bookmark
            : Icons.bookmark_border,
        ctrl.isBookmarked(ctrl.currentUrl)
            ? 'Bỏ bookmark trang hiện tại'
            : 'Bookmark trang hiện tại',
        enabled: pageActionsEnabled,
      ),
    ];

    if (pageActionsEnabled) {
      items.add(const PopupMenuDivider());
      items.add(_menuItem(
        context,
        'pinArticle',
        Icons.push_pin_outlined,
        ctrl.isArticlePinned(ctrl.currentUrl)
            ? 'Bỏ ghim bài này'
            : 'Ghim bài này',
      ));
      items.add(_menuItem(
        context,
        'toggleCompleted',
        Icons.check_circle_outline,
        ctrl.isArticleCompleted(ctrl.currentUrl)
            ? 'Đánh dấu chưa đọc xong'
            : 'Đánh dấu đọc xong',
      ));
      items.add(_menuItem(
        context,
        'editNote',
        Icons.sticky_note_2_outlined,
        ctrl.hasArticleNote(ctrl.currentUrl)
            ? 'Sửa ghi chú bài này'
            : 'Thêm ghi chú bài này',
      ));
      items.add(_menuItem(
        context,
        'batchPage',
        Icons.playlist_add_check,
        'Tạo batch WordList từ bài này',
      ));
      items.add(_menuItem(
        context,
        'saveAudio',
        Icons.audio_file_outlined,
        'Lưu bài đọc thành âm thanh',
      ));
    }
    return items;
  }

  PopupMenuItem<String> _menuItem(
    BuildContext context,
    String value,
    IconData icon,
    String label, {
    bool enabled = true,
  }) {
    final itemWidth =
        (MediaQuery.sizeOf(context).width - 64).clamp(180.0, 280.0).toDouble();
    return PopupMenuItem<String>(
      value: value,
      enabled: enabled,
      child: SizedBox(
        width: itemWidth,
        child: Row(
          children: [
            Icon(icon, size: 18, color: enabled ? Colors.white70 : Colors.grey),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.uiText(label),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: enabled ? Colors.white : Colors.grey,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleMenuAction(String value) {
    switch (value) {
      case '__home__':
        widget.onNavigate('');
        break;
      case '__forward__':
        widget.onNavigate('__forward__');
        break;
      case '__refresh__':
        widget.onRefresh();
        break;
      case '__recall__':
        HapticFeedback.selectionClick();
        widget.controller.toggleRecallMarkers();
        break;
      case '__grammar__':
        widget.onOpenGrammarSettings();
        break;
      case '__listen__':
        widget.onListenArticle();
        break;
      case '__extract__':
        widget.onExtractText();
        break;
      case '__collection__':
        widget.onSavePageToCollection();
        break;
      case '__bookmark__':
        widget.controller.toggleBookmark();
        break;
      default:
        widget.onPageAction(value);
        break;
    }
  }
}

class _ColorModeButton extends StatelessWidget {
  final WebReaderController controller;
  final bool enabled;

  const _ColorModeButton({required this.controller, required this.enabled});

  @override
  Widget build(BuildContext context) {
    final isActive = enabled && controller.colorMode != ColorMode.none;
    final showLabel = isActive && MediaQuery.of(context).size.width >= 430;
    final showGrammarBadge = isActive &&
        controller.colorMode == ColorMode.wordType &&
        controller.grammarSettings.enabled;
    return GestureDetector(
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              controller.cycleColorMode();
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: EdgeInsets.symmetric(
          horizontal: showLabel ? 8 : 7,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF2196F3).withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: isActive
              ? Border.all(
                  color: const Color(0xFF2196F3).withValues(alpha: 0.4))
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              controller.colorMode.icon,
              size: 13,
              color: enabled
                  ? (isActive ? const Color(0xFF2196F3) : Colors.grey)
                  : Colors.grey[700],
            ),
            if (showLabel) ...[
              const SizedBox(width: 3),
              Text(
                context.uiText(controller.colorMode.label),
                style: const TextStyle(
                  color: Color(0xFF2196F3),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (showGrammarBadge && MediaQuery.of(context).size.width >= 520) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  controller.activeGrammarPreset.name,
                  style: const TextStyle(
                    color: Color(0xFFB8B5FF),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ToolbarBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  final bool enabled;
  final bool isActive;
  final VoidCallback? onTap;
  final String? tooltip;
  final Color? activeThumbColor;

  const _ToolbarBtn({
    required this.icon,
    required this.size,
    this.enabled = true,
    this.isActive = false,
    this.onTap,
    this.tooltip,
    this.activeThumbColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveActiveColor =
        activeThumbColor ?? const Color(0xFF2196F3);
    final color = !enabled
        ? Colors.grey[700]!
        : isActive
            ? effectiveActiveColor
            : Colors.white70;

    return Tooltip(
      message: context.uiText(tooltip ?? ''),
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
