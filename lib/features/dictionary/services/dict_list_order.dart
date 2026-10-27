// DICT-STATE-001 (owner 2026-10-27) — hai lỗi trạng thái ở màn "Tải bộ từ điển"
// và "Quản lý từ điển":
//
// 1. **"Đã tải về báo thành công nhưng nút 'Tải & cài' vẫn xanh"** ⇒ người dùng
//    không biết đã cài chưa, bấm tải lại. Nguyên nhân: `_isInstalled()` chỉ so
//    TÊN (`pack.name` với `dict.name`) — sau khi cài, tên bộ lấy từ header .mdx
//    chứ không phải từ `packs.json` (`Simple English Dictionary(EN-EN)` vs
//    `Anh → Anh (Simple English Wiktionary)`) ⇒ không khớp ⇒ luôn hiện "chưa
//    cài". Sửa gốc: lưu **pack id** vào manifest của từ điển lúc cài.
// 2. **Không đổi được thứ tự ưu tiên** ⇒ bộ nào gộp nghĩa trước là do thứ tự
//    import, người dùng không can thiệp được. Nay thứ tự trong manifest LÀ
//    thứ tự ưu tiên và kéo thả được.
//
// Lớp này THUẦN Dart (không Flutter/I-O) để CI test được không cần máy ảo.

import '../models/dict_info.dart';
import '../models/dict_pack.dart';

/// Bộ từ điển trong danh mục đã cài trên máy chưa?
///
/// Ưu tiên [DictInfo.packId] (đúng danh tính, bền qua các lần khởi động).
/// Các phép so tên chỉ là **đường lùi** cho những bộ đã cài bằng bản ≤ 1.17.0
/// (manifest cũ chưa có `packId`) — nhờ vậy người dùng đang có từ điển không
/// bị hiện "chưa cài" sau khi cập nhật app.
bool isPackInstalled(DictPack pack, List<DictInfo> installed) {
  for (final dict in installed) {
    if ((dict.packId ?? '').trim() == pack.id) return true;
  }
  // Đường lùi mạnh nhất cho bản cài CŨ: so tên file nguồn. Bộ trong danh mục
  // tải về đúng tên file trong `downloadUrl` (`simple-en.mdx`) và
  // `DictInfo.sourceFileName` đang giữ chính tên đó ⇒ khớp dù tiêu đề .mdx
  // đặt tên gì đi nữa.
  final fileName = packSourceFileName(pack.downloadUrl);
  if (fileName.isNotEmpty) {
    for (final dict in installed) {
      final existing = dict.sourceFileName;
      if (existing == null) continue;
      if (existing.toLowerCase().trim() == fileName) return true;
    }
  }
  final name = pack.name.toLowerCase().trim();
  final id = pack.id.toLowerCase().trim();
  for (final dict in installed) {
    final dictName = dict.name.toLowerCase();
    if (name.isNotEmpty && dictName == name) return true;
    // `en-vi-ovdp` → "en-vi-ovdp" (id có gạch nối, tên file thì có gạch dưới).
    if (id.isNotEmpty && dictName.contains(id)) return true;
    if (id.isNotEmpty && dictName.contains(id.replaceAll('-', ' '))) {
      return true;
    }
  }
  return false;
}

/// Basename chữ thường của file mà `downloadUrl` trỏ tới (`simple-en.mdx`);
/// rỗng khi URL không có phần tên file.
String packSourceFileName(String downloadUrl) {
  var path = downloadUrl.trim();
  if (path.isEmpty) return '';
  final cut = path.indexOf('?');
  if (cut >= 0) path = path.substring(0, cut);
  final hash = path.indexOf('#');
  if (hash >= 0) path = path.substring(0, hash);
  final slash = path.lastIndexOf('/');
  final base = slash >= 0 ? path.substring(slash + 1) : path;
  return base.toLowerCase().trim();
}

/// Dịch một thao tác kéo-thả của `ReorderableListView` thành chỉ số mới.
///
/// `ReorderableListView.onReorder` đưa `newIndex` theo kiểu "chèn TRƯỚC vị trí
/// đó" **trước khi** lấy phần tử ra, nên khi kéo XUỐNG thì `newIndex` lớn hơn
/// chỉ số thật 1. Công thức dưới đây là công thức chuẩn của Flutter; tách ra
/// thành hàm thuần để test không cần widget.
int reorderTargetIndex(int oldIndex, int newIndex) {
  if (newIndex > oldIndex) return newIndex - 1;
  return newIndex;
}

/// Trả danh sách mới sau khi chuyển [oldIndex] → [newIndex] (đã chuẩn hoá).
List<T> applyReorder<T>(List<T> items, int oldIndex, int newIndex) {
  if (items.isEmpty) return List<T>.from(items);
  if (oldIndex < 0 || oldIndex >= items.length) return List<T>.from(items);
  final raw = reorderTargetIndex(oldIndex, newIndex);
  // `int.clamp` trả `num` ⇒ không truyền thẳng vào `List.insert(int)`.
  final target = raw < 0
      ? 0
      : (raw > items.length - 1 ? items.length - 1 : raw);
  final next = List<T>.from(items);
  final moved = next.removeAt(oldIndex);
  next.insert(target, moved);
  return next;
}

/// Sắp lại danh sách từ điển theo thứ tự id cho trước.
///
/// Id **không có** trong [orderedIds] giữ nguyên ở cuối theo thứ tự cũ — nếu
/// người dùng cài thêm bộ mới trong lúc danh sách cũ đang được giữ, bộ mới
/// không bị mất. Id lạ (đã bị xoá) bị bỏ qua.
List<DictInfo> applyDictOrder(
  List<DictInfo> dicts,
  List<String> orderedIds,
) {
  final byId = <String, DictInfo>{for (final d in dicts) d.id: d};
  final out = <DictInfo>[];
  final used = <String>{};
  for (final id in orderedIds) {
    final dict = byId[id];
    if (dict == null || !used.add(id)) continue;
    out.add(dict);
  }
  for (final dict in dicts) {
    if (used.add(dict.id)) out.add(dict);
  }
  return out;
}
