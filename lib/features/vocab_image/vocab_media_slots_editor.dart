// lib/features/vocab_image/vocab_media_slots_editor.dart
//
// VOCAB-MEDIA-003 (ADR-0012) — ô minh họa 2 KHUNG trong màn sửa từ / chi tiết từ:
//   • tối đa 2 ảnh/animation (slot 1 = ảnh chính, slot 2 = ảnh phụ),
//   • khung trống có nút "+" (chỉ hiện khi chưa đủ 2 ảnh),
//   • mỗi khung có menu: Đổi / Xoá / Đặt làm ảnh chính (hoán đổi slot).
//
// Nguồn chọn vẫn là [VocabImagePickerSheet] (web / máy / dán URL / animation);
// sheet trả VocabImagePickResult như hiện nay, CÒN ĐẶT VÀO SLOT NÀO do editor
// này quyết định.
//
// Khi có [wordId] → ghi thẳng VocabularyProvider (như VocabImagePicker); không
// có wordId (đang thêm/sửa nháp) → báo ra ngoài qua [onChanged] để caller tự
// lưu (vd nút Lưu của sheet sửa từ).
//
// Invariant (ADR-0012): nếu slot 2 có giá trị thì slot 1 luôn có giá trị —
// xoá ảnh chính thì ảnh phụ lên thay, không khi nào để slot 1 trống.

// localized_material = material.dart (hide Text) + Text/uiText đã locale-hóa.
// Rule #5 (AGENTS.md): chrome không được để tiếng Việt ở locale ≠ vi.
import '../../core/language/localized_material.dart';
import 'package:provider/provider.dart';

import '../../providers/vocabulary_provider.dart';
import 'vocab_image_picker_sheet.dart';
import 'vocab_media_type.dart';
import 'vocabulary_media_widget.dart';

/// Action của menu trên một khung ảnh.
enum _SlotMenuAction { change, remove, makePrimary }

/// Ô minh họa 2 khung cho một từ (ảnh chính + ảnh phụ).
class VocabMediaSlotsEditor extends StatefulWidget {
  /// Id từ trong WordList — có thì editor ghi thẳng provider; null = chỉ báo
  /// ra ngoài qua [onChanged].
  final String? wordId;

  /// Từ đang sửa — dùng làm từ khóa tìm ảnh/animation (mồi cho sheet).
  final String? word;

  /// Nghĩa của từ — ghép vào từ khóa khi từ đơn nghĩa mơ hồ.
  final String? meaning;

  /// Ảnh chính hiện tại (slot 1) — relative path local hoặc URL http(s).
  final String? primaryUrl;

  /// Ảnh phụ hiện tại (slot 2) — cùng ngữ nghĩa với [primaryUrl].
  final String? secondaryUrl;

  /// Báo ra ngoài mỗi khi 2 slot đổi (khi không có [wordId]).
  final void Function(String? primary, String? secondary)? onChanged;

  /// Kích thước mỗi khung (vuông).
  final double size;

  const VocabMediaSlotsEditor({
    super.key,
    this.wordId,
    this.word,
    this.meaning,
    this.primaryUrl,
    this.secondaryUrl,
    this.onChanged,
    this.size = 110,
  });

  @override
  State<VocabMediaSlotsEditor> createState() => _VocabMediaSlotsEditorState();
}

class _VocabMediaSlotsEditorState extends State<VocabMediaSlotsEditor> {
  String? _primary;
  String? _secondary;
  bool _busy = false;

  static String? _norm(String? v) {
    final t = (v ?? '').trim();
    return t.isEmpty ? null : t;
  }

  @override
  void initState() {
    super.initState();
    _primary = _norm(widget.primaryUrl);
    _secondary = _norm(widget.secondaryUrl);
  }

  @override
  void didUpdateWidget(covariant VocabMediaSlotsEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Đồng bộ khi dữ liệu ngoài đổi (provider notify). Không reset khi chính
    // mình vừa đổi (state == widget urls) — tránh vòng lặp.
    final p = _norm(widget.primaryUrl);
    final s = _norm(widget.secondaryUrl);
    if (p != _primary || s != _secondary) {
      setState(() {
        _primary = p;
        _secondary = s;
      });
    }
  }

  /// Ghi cả 2 slot: báo caller + (nếu có wordId) ghi provider một lần.
  void _emit() {
    widget.onChanged?.call(_primary, _secondary);
    final id = widget.wordId;
    if (id == null || id.isEmpty) return;
    context
        .read<VocabularyProvider>()
        .updateMediaSlots(id, _primary, _secondary);
  }

  /// Đặt media vào slot (1 = chính, 2 = phụ). Xoá slot 1 thì slot 2 lên thay.
  void _setSlot(int slot, String? path) {
    final value = (path ?? '').trim();
    setState(() {
      if (slot == 1) {
        if (value.isEmpty) {
          // Xoá ảnh chính: ảnh phụ lên thay (ADR-0012 — không mất dữ liệu).
          _primary = _secondary;
          _secondary = null;
        } else {
          _primary = value;
        }
      } else {
        _secondary = value.isEmpty ? null : value;
      }
    });
    _emit();
  }

  /// Hoán đổi slot 1 ↔ slot 2 ("Đặt làm ảnh chính").
  void _swapSlots() {
    if (_secondary == null) return;
    setState(() {
      final a = _primary;
      _primary = _secondary;
      _secondary = a;
    });
    _emit();
  }

  /// Mở sheet chọn media nhắm vào [slot].
  Future<void> _pickForSlot(int slot) async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await VocabImagePickerSheet.show(
      context,
      word: widget.word,
      meaning: widget.meaning,
      hasExistingImage: slot == 1 ? _primary != null : _secondary != null,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (result == null) return;
    if (result.removed) {
      _setSlot(slot, null);
      return;
    }
    final path = result.imagePath;
    if (path == null || path.isEmpty) return;
    _setSlot(slot, path);
  }

  void _onSlotMenu(_SlotMenuAction action, int slot) {
    switch (action) {
      case _SlotMenuAction.change:
        _pickForSlot(slot);
      case _SlotMenuAction.remove:
        _setSlot(slot, null);
      case _SlotMenuAction.makePrimary:
        _swapSlots();
    }
  }

  @override
  Widget build(BuildContext context) {
    final slots = <Widget>[];
    if (_primary != null) {
      slots.add(_buildFilledSlot(context, slot: 1, url: _primary!));
    } else {
      slots.add(_buildAddSlot(context, slot: 1));
    }
    if (_secondary != null) {
      slots.add(const SizedBox(width: 10));
      slots.add(_buildFilledSlot(context, slot: 2, url: _secondary!));
    } else if (_primary != null) {
      // Khung "+" thứ hai chỉ hiện khi chưa đủ 2 ảnh (và slot 1 đã có —
      // giữ invariant slot 1 không trống trong khi slot 2 có ảnh).
      slots.add(const SizedBox(width: 10));
      slots.add(_buildAddSlot(context, slot: 2));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: slots,
    );
  }

  /// Khung đã có ảnh/animation: preview (đứng frame đầu — 0 ticker) + badge
  /// + menu Đổi/Xoá/Đặt làm ảnh chính.
  Widget _buildFilledSlot(
    BuildContext context, {
    required int slot,
    required String url,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final isPrimary = slot == 1;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: VocabularyMediaWidget(
              imageUrl: url,
              width: widget.size,
              height: widget.size,
              fit: BoxFit.cover,
              // Ô sửa từ không phải danh sách: đứng frame đầu, 0 ticker
              // (quy tắc hiệu năng blueprint lottie_flashcard_plan.md).
              animate: false,
              repeat: false,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isPrimary
                      ? scheme.primary.withValues(alpha: 0.65)
                      : scheme.outlineVariant.withValues(alpha: 0.8),
                  width: isPrimary ? 2 : 1.5,
                ),
              ),
            ),
          ),
          Positioned(
            top: 4,
            left: 4,
            child: _badge(
              icon: isPrimary ? Icons.star : Icons.filter_2,
              label: context.uiText(isPrimary ? 'Ảnh chính' : 'Ảnh phụ'),
            ),
          ),
          if (isLottieMediaUrl(url))
            Positioned(
              bottom: 4,
              left: 4,
              child: _badge(
                icon: Icons.animation_outlined,
                label: 'Lottie',
              ),
            ),
          Positioned(
            top: 2,
            right: 2,
            child: Material(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(10),
              child: PopupMenuButton<_SlotMenuAction>(
                tooltip: context.uiText('Tùy chọn ảnh'),
                icon: const Icon(Icons.more_vert, size: 16, color: Colors.white),
                padding: EdgeInsets.zero,
                itemBuilder: (menuCtx) => [
                  PopupMenuItem(
                    value: _SlotMenuAction.change,
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.edit_outlined, size: 16),
                      title: Text(menuCtx.uiText('Đổi ảnh'),
                          style: const TextStyle(fontSize: 13)),
                    ),
                  ),
                  PopupMenuItem(
                    value: _SlotMenuAction.remove,
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.delete_outline,
                          size: 16, color: Colors.redAccent),
                      title: Text(menuCtx.uiText('Xoá ảnh này'),
                          style: const TextStyle(fontSize: 13)),
                    ),
                  ),
                  // "Đặt làm ảnh chính" chỉ có nghĩa ở slot 2 (slot 1 đã là chính).
                  if (!isPrimary)
                    PopupMenuItem(
                      value: _SlotMenuAction.makePrimary,
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.swap_horiz, size: 16),
                        title: Text(menuCtx.uiText('Đặt làm ảnh chính'),
                            style: const TextStyle(fontSize: 13)),
                      ),
                    ),
                ],
                onSelected: (action) => _onSlotMenu(action, slot),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Khung trống: nút "+" mở sheet chọn media cho slot này.
  Widget _buildAddSlot(BuildContext context, {required int slot}) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _busy ? null : () => _pickForSlot(slot),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.8),
              width: 1.5,
            ),
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_photo_alternate_outlined,
                  size: 26, color: scheme.onSurfaceVariant),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  context.uiText(
                      slot == 1 ? 'Thêm ảnh' : 'Thêm ảnh thứ hai'),
                  style: TextStyle(
                    fontSize: 10.5,
                    color: scheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
