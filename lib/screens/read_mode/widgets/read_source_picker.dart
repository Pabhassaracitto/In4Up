// lib/screens/read_mode/widgets/read_source_picker.dart
import 'package:in4up/core/language/localized_material.dart';

import '../../../models/read_content_source.dart';
import '../../../widgets/workspace_navigation/workspace_navigation.dart';

/// Hợp đồng callback để nối [ReadSourcePicker] với các màn hình nguồn thật.
///
/// Mỗi callback ứng với đúng một giá trị trong [ReadContentSource], và được
/// đặt tên theo đích điều hướng để agent tích hợp biết chính xác phải nối
/// vào đâu:
/// - [onOpenDocumentLibrary] → mở `TextLibraryDrawer`.
/// - [onOpenWebReader] → mở `WebReaderScreen`.
/// - [onOpenTipitakaLibrary] → mở `TipitakaLibraryScreen`.
///
/// Tất cả đều optional. Nếu route hiện tại chưa thể giữ nguồn trong cùng một
/// reader surface, nơi gọi có thể để trống (null) — `ReadSourcePicker` vẫn
/// cập nhật lựa chọn hiển thị bình thường, không throw và không tự ý điều
/// hướng thay.
@immutable
class ReadSourceCallbacks {
  const ReadSourceCallbacks({
    this.onOpenDocumentLibrary,
    this.onOpenWebReader,
    this.onOpenTipitakaLibrary,
  });

  /// Mở nguồn Tài liệu — dự kiến nối vào `TextLibraryDrawer`.
  final VoidCallback? onOpenDocumentLibrary;

  /// Mở nguồn Web — dự kiến nối vào `WebReaderScreen`.
  final VoidCallback? onOpenWebReader;

  /// Mở nguồn Tam tạng — dự kiến nối vào `TipitakaLibraryScreen`.
  final VoidCallback? onOpenTipitakaLibrary;

  /// Trả về callback điều hướng tương ứng với [source], nếu có.
  VoidCallback? forSource(ReadContentSource source) {
    switch (source) {
      case ReadContentSource.document:
        return onOpenDocumentLibrary;
      case ReadContentSource.web:
        return onOpenWebReader;
      case ReadContentSource.tipitaka:
        return onOpenTipitakaLibrary;
    }
  }
}

/// Source picker riêng biệt cho tab Đọc.
///
/// Đây là lớp Source (nguồn nội dung) trong mô hình
/// Mode → Source → Tool → Settings — KHÔNG gộp chung với Mode (Đọc/Viết) và
/// KHÔNG gộp chung với Tool (Dịch/Ngữ pháp/Phát âm/Từ điển). Nơi dùng
/// widget này chịu trách nhiệm hiển thị Mode và Tool ở chỗ khác.
class ReadSourcePicker extends StatelessWidget {
  const ReadSourcePicker({
    super.key,
    required this.selectedSource,
    required this.onSourceChanged,
    this.callbacks = const ReadSourceCallbacks(),
    this.enabled = true,
    this.presentation = WorkspaceNavigationPresentation.adaptive,
  });

  /// Nguồn đang được chọn để hiển thị (state do nơi gọi sở hữu).
  final ReadContentSource selectedSource;

  /// Luôn được gọi khi người dùng chọn một nguồn khác — dùng để cập nhật
  /// trạng thái hiển thị, tách biệt khỏi việc điều hướng thật sự.
  final ValueChanged<ReadContentSource> onSourceChanged;

  /// Hợp đồng điều hướng tới từng màn hình nguồn tương ứng.
  final ReadSourceCallbacks callbacks;

  final bool enabled;
  final WorkspaceNavigationPresentation presentation;

  // Nhãn gốc là tiếng Việt (giống quy ước ColorMode/IpaDisplayMode); dịch
  // qua `context.uiText(...)` ngay tại nơi hiển thị để tuân Quy tắc vàng #5
  // (AGENTS.md) — chrome UI không còn tiếng Việt khi locale khác vi.
  // WorkspaceNavigationItem là component dữ liệu thuần (không tự dịch), nên
  // việc dịch phải xảy ra ở đây trước khi đưa label vào item.
  List<WorkspaceNavigationItem<ReadContentSource>> _items(
    BuildContext context,
  ) {
    return [
      for (final source in ReadContentSource.values)
        WorkspaceNavigationItem<ReadContentSource>(
          value: source,
          label: context.uiText(source.label),
          icon: source.icon,
        ),
    ];
  }

  void _handleSelected(ReadContentSource source) {
    // Cập nhật state hiển thị trước — độc lập với việc có mở được màn hình
    // nguồn thật hay không.
    onSourceChanged(source);
    callbacks.forSource(source)?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('read-source-picker'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: WorkspaceSourcePicker<ReadContentSource>(
        items: _items(context),
        selectedValue: selectedSource,
        onChanged: enabled ? _handleSelected : null,
        enabled: enabled,
        presentation: presentation,
        menuTooltip: context.uiText('Chọn nguồn'),
      ),
    );
  }
}
