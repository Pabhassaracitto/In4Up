// B1 (Wave 2): xuất/nhập sidecar cho dữ liệu đọc của một file PDF.
//
// Vì sao tồn tại: highlight/ghi chú đang nằm trong Hive của *máy này*. Người dùng
// chuyển máy, chuyển sang điện thoại khác, hoặc muốn mở file PDF đã đánh dấu bằng
// app khác thì mất sạch. Sidecar là file `.in4up.json` đi cạnh file PDF: máy khác
// đọc lại được và **mở ra đúng trang + đúng rect**.
//
// Ba quyết định trong file này:
//  * Định danh file **không** dùng đường dẫn. `identityMatchLevel` so size+mtime
//    (đúng cái mà `PdfFileIdentity.primaryKey` băm) ⇒ copy file sang nơi khác vẫn
//    nhận ra nhau; đổi tên file thì import vẫn chạy, chỉ mất dấu "cùng nguồn".
//  * Import là MERGE một chiều, không phải replace: không bao giờ xoá highlight
//    của người dùng chỉ vì họ bấm nhầm file. Trùng vị trí ⇒ giữ bản mới hơn.
//  * Toàn bộ logic ở đây là hàm thuần (không `dart:io`, không Flutter) nên test
//    được bằng `flutter test` — CI của repo không chạy test widget.
import 'dart:convert';

import '../models/pdf_annotation.dart';

/// Tên định dạng — cũng là lá chắn: file JSON bất kỳ không được phép import.
const String kPdfAnnotationSidecarFormat = 'in4up-pdf-annotations';

/// Phiên bản schema. Tăng khi đổi nghĩa trường, không tăng khi thêm trường mới
/// ( decoder bỏ qua trường lạ ⇒ cũ đọc được file mới, mới đọc được file cũ).
const int kPdfAnnotationSidecarVersion = 1;

const String kPdfAnnotationSidecarProducer = 'in4up-pdf-reader/wave2-b1';

/// Đuôi file: `<tên pdf>.in4up.json`.
const String kPdfAnnotationSidecarSuffix = '.in4up.json';

/// Tên file (bỏ thư mục, bỏ đuôi `.pdf`), lọc ký tự không an toàn cho hệ điều
/// hành. Đặt ở module nền vì cả JSON sidecar lẫn XFDF đều cần cùng một tên gốc —
/// hai file cạnh nhau phải cùng `<gốc>` để người dùng không phải đoán.
String pdfExportBaseName(String pdfPath) {
  final slash = pdfPath.replaceAll('\\', '/').lastIndexOf('/');
  var name = slash >= 0 ? pdfPath.substring(slash + 1) : pdfPath;
  final dot = name.toLowerCase().lastIndexOf('.pdf');
  if (dot > 0) name = name.substring(0, dot);
  return name
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// `<gốc>.in4up.json` — tên file để chia sẻ/ghi cạnh PDF.
String pdfSidecarFileName(String pdfPath) {
  final base = pdfExportBaseName(pdfPath);
  return base.isEmpty ? 'annotations$kPdfAnnotationSidecarSuffix'
      : '$base$kPdfAnnotationSidecarSuffix';
}

/// Lý do từ chối import — map sang một key catalog ở UI (rule #5: không nhồi
/// chuỗi tiếng Việt vào service).
enum PdfSidecarProblem { notJson, wrongFormat, newerVersion, noAnnotations }

/// Kết quả giải mã: hoặc có `sidecar`, hoặc có `problem`. Không ném exception
/// ra ngoài vì UI phải hiện thông báo khác nhau cho từng loại.
final class PdfSidecarDecoding {
  const PdfSidecarDecoding.success(this.sidecar) : problem = null;
  const PdfSidecarDecoding.failure(this.problem) : sidecar = null;

  final PdfAnnotationSidecar? sidecar;
  final PdfSidecarProblem? problem;

  bool get isSuccess => sidecar != null;

  /// Key catalog cho lý do thất bại (null khi thành công).
  String? get problemLabelKey => switch (problem) {
        PdfSidecarProblem.notJson => 'File này không phải tệp chú thích của In4Up',
        PdfSidecarProblem.wrongFormat =>
          'File này không phải tệp chú thích của In4Up',
        PdfSidecarProblem.newerVersion =>
          'Tệp chú thích này được tạo bởi bản In4Up mới hơn',
        PdfSidecarProblem.noAnnotations => 'Tệp chú thích không có gì để nhập',
        null => null,
      };
}

/// Nội dung sidecar: mô tả file PDF gốc + toàn bộ annotation + trang đọc cuối.
final class PdfAnnotationSidecar {
  const PdfAnnotationSidecar({
    required this.fileName,
    required this.fileSize,
    required this.fileModifiedMs,
    required this.pageCount,
    required this.lastPageIndex,
    required this.exportedAt,
    required this.annotations,
    this.producerVersion = kPdfAnnotationSidecarProducer,
  });

  /// Tên file lúc xuất (chỉ để hiển thị/đối chiếu — KHÔNG dùng để định danh).
  final String fileName;

  /// -1 khi máy xuất không stat được file (web/permission).
  final int fileSize;
  final int fileModifiedMs;

  /// Số trang lúc xuất — dùng để cảnh báo "PDF đã đổi trang" trước khi import.
  final int pageCount;
  final int lastPageIndex;
  final DateTime exportedAt;
  final List<PdfAnnotation> annotations;
  final String producerVersion;

  int get annotationCount => annotations.length;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'format': kPdfAnnotationSidecarFormat,
        'version': kPdfAnnotationSidecarVersion,
        'producer': producerVersion,
        'exportedAt': exportedAt.toIso8601String(),
        'file': <String, dynamic>{
          'name': fileName,
          'size': fileSize,
          'modifiedMs': fileModifiedMs,
          'pages': pageCount,
        },
        'lastPageIndex': lastPageIndex,
        'annotations': annotations.map((a) => a.toJson()).toList(growable: false),
      };

  factory PdfAnnotationSidecar.fromJson(Map<String, dynamic> json) {
    final file = json['file'];
    final fileMap = file is Map
        ? Map<String, dynamic>.from(file)
        : <String, dynamic>{};
    final rawList = json['annotations'];
    final annotations = <PdfAnnotation>[];
    if (rawList is List) {
      for (final item in rawList) {
        if (item is! Map) continue;
        try {
          annotations.add(
            PdfAnnotation.fromJson(Map<String, dynamic>.from(item)),
          );
        } catch (_) {
          // Một dòng hỏng không được làm hỏng cả tệp (người dùng đã chọn file
          // này để lấy LẠI công sức của mình).
        }
      }
    }
    return PdfAnnotationSidecar(
      fileName: fileMap['name'] as String? ?? '',
      fileSize: _asInt(fileMap['size']),
      fileModifiedMs: _asInt(fileMap['modifiedMs']),
      pageCount: _asInt(fileMap['pages']),
      lastPageIndex: _asInt(json['lastPageIndex']),
      exportedAt:
          DateTime.tryParse(json['exportedAt'] as String? ?? '') ?? DateTime(0),
      annotations: List<PdfAnnotation>.unmodifiable(annotations),
      producerVersion: json['producer'] as String? ?? '',
    );
  }

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());
}

/// Xuấtsidecar ra chuỗi. Không IO ở tầng này: caller quyết định ghi đâu
/// (mảng chia sẻ cho `share_plus`, hay tạm để mở lại).
String encodePdfAnnotationSidecar(PdfAnnotationSidecar sidecar) =>
    sidecar.encode();

/// Nhập: parse + kiểm tra định dạng. Không bao giờ ném.
PdfSidecarDecoding decodePdfAnnotationSidecar(String raw) {
  Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    return const PdfSidecarDecoding.failure(PdfSidecarProblem.notJson);
  }
  if (decoded is! Map) {
    return const PdfSidecarDecoding.failure(PdfSidecarProblem.notJson);
  }
  final json = Map<String, dynamic>.from(decoded);
  if (json['format'] != kPdfAnnotationSidecarFormat) {
    return const PdfSidecarDecoding.failure(PdfSidecarProblem.wrongFormat);
  }
  final version = _asInt(json['version']);
  if (version > kPdfAnnotationSidecarVersion) {
    return const PdfSidecarDecoding.failure(PdfSidecarProblem.newerVersion);
  }
  final sidecar = PdfAnnotationSidecar.fromJson(json);
  if (sidecar.annotations.isEmpty) {
    return const PdfSidecarDecoding.failure(PdfSidecarProblem.noAnnotations);
  }
  return PdfSidecarDecoding.success(sidecar);
}

/// Mức khớp giữa sidecar và file PDF đang mở — để UI cảnh báo trước khi import.
enum PdfSidecarFileMatch { sameFile, contentChanged, pageChanged, unknown }

PdfSidecarFileMatch compareSidecarToFile({
  required PdfAnnotationSidecar sidecar,
  required int fileSize,
  required int fileModifiedMs,
  required int pageCount,
}) {
  final sidecarKnowsStats = sidecar.fileSize >= 0 && sidecar.fileModifiedMs >= 0;
  final localKnowsStats = fileSize >= 0 && fileModifiedMs >= 0;
  if (!sidecarKnowsStats || !localKnowsStats) {
    return PdfSidecarFileMatch.unknown;
  }
  if (sidecar.fileSize != fileSize ||
      sidecar.fileModifiedMs != fileModifiedMs) {
    return PdfSidecarFileMatch.contentChanged;
  }
  if (sidecar.pageCount > 0 && pageCount > 0 &&
      sidecar.pageCount != pageCount) {
    return PdfSidecarFileMatch.pageChanged;
  }
  return PdfSidecarFileMatch.sameFile;
}

/// Chìa khoá để nhận diện "cùng một chỗ" giữa hai annotation.
/// Ưu tiên offset ký tự (bền hơn toạ độ), rồi mới tới rect làm tròn 0.5pt.
String pdfAnnotationPositionKey(PdfAnnotation a) {
  if (a.textStartOffset != null && a.textEndOffset != null) {
    return '${a.pageIndex}#${a.textStartOffset}-${a.textEndOffset}';
  }
  if (a.hasValidBounds) {
    String q(double v) => (v * 2).roundToDouble().toStringAsFixed(1);
    return '${a.pageIndex}@'
        '${q(a.bounds.left)},${q(a.bounds.top)},'
        '${q(a.bounds.right)},${q(a.bounds.bottom)}';
  }
  // Bookmark/annotation không có hình học: coi như trùng theo trang + loại.
  return '${a.pageIndex}~${a.type.name}';
}

/// Gộp sidecar vào dữ liệu đang có. Giữ nguyên thứ tự của `local`, phần chỉ có
/// trong `imported` được nối vào cuối theo thứ tự trang.
///
/// Khi trùng vị trí: giữ annotation có `createdAt` mới hơn, và **luôn** giữ ghi
/// chú dài hơn nếu hai bên cùng một thời điểm (đề phòng đồng hồ máy lệch).
List<PdfAnnotation> mergeSidecarAnnotations({
  required List<PdfAnnotation> local,
  required List<PdfAnnotation> imported,
}) {
  final byKey = <String, PdfAnnotation>{};
  final order = <String>[];

  void put(PdfAnnotation a) {
    final key = pdfAnnotationPositionKey(a);
    final existing = byKey[key];
    if (existing == null) {
      byKey[key] = a;
      order.add(key);
      return;
    }
    byKey[key] = _prefer(existing, a);
  }

  for (final a in local) {
    put(a);
  }
  for (final a in imported) {
    put(a);
  }
  final out = <PdfAnnotation>[
    for (final key in order) byKey[key]!,
  ];
  out.sort((x, y) {
    if (x.pageIndex != y.pageIndex) return x.pageIndex.compareTo(y.pageIndex);
    return _topOf(y).compareTo(_topOf(x));
  });
  return List<PdfAnnotation>.unmodifiable(out);
}

PdfAnnotation _prefer(PdfAnnotation a, PdfAnnotation b) {
  final ta = a.createdAt, tb = b.createdAt;
  if (tb.isAfter(ta)) return b;
  if (ta.isAfter(tb)) return a;
  return (b.note?.length ?? 0) > (a.note?.length ?? 0) ? b : a;
}

/// `bounds.top` trong không gian PDF là cạnh CAO hơn (gốc dưới-trái).
double _topOf(PdfAnnotation a) => a.hasValidBounds ? a.bounds.top : -1;

/// Số thứ tự an toàn cho `dart:convert` (JSON có thể trả về double hoặc int,
/// hoặc null nếu file bị sửa tay).
int _asInt(Object? raw) => raw is num ? raw.toInt() : -1;
