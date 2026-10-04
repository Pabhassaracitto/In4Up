// B1+B2 (Wave 2) — chỗ duy nhất chạm đĩa/plugin cho việc xuất/nhập chú thích.
//
// Tách mỏng nhất có thể: mọi quyết định (schema JSON, escape XML, lật trục, nén
// PDF) nằm ở các service thuần đã có test. File này chỉ còn: stat file, render
// trang, ghi tạm, mở hộp chia sẻ, chọn tệp. Nó KHÔNG có test đơn vị (cần thiết bị
// + plugin) nên phải giữ càng ít logic càng tốt.
//
// Ghi vào thư mục tạm chứ không ghi cạnh file PDF: trên Android app không được
// quyền tuỳ ý ghi ngoài app-specific dir, còn hộp chia sẻ mới là nơi người dùng
// chọn đích thật (Drive/Files/Bluetooth...).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart' hide PdfAnnotation;
import 'package:share_plus/share_plus.dart';

import '../models/pdf_annotation.dart';
import 'pdf_annotation_sidecar.dart';
import 'pdf_file_identity.dart';
import 'pdf_snapshot_burn.dart';
import 'pdf_snapshot_pdf_writer.dart';
import 'pdf_xfdf_export.dart';

/// Ba kiểu xuất, đúng 3 nút trong UI.
enum PdfExportKind { sidecarJson, xfdf, snapshotPdf }

/// Số trang tối đa cho bản chụp: mỗi trang 150dpi ~ 1-2MB RAM ảnh thô; 24 trang
/// là ngưỡng giữ được trên điện thoại tầm trung mà không nổ bộ nhớ.
const int kPdfSnapshotMaxPages = 24;

/// Những key báo hiệu THÀNH CÔNG. Đặt ở service để UI không phải so chuỗi tiếng
/// Việt (kiểu `messageKey.startsWith('Đã xuất')` sẽ vỡ ngay khi đổi câu chữ).
const Set<String> kPdfExportSuccessMessageKeys = <String>{
  'Đã xuất tệp',
  'Đã xuất bản chụp PDF',
};

final class PdfExportOutcome {
  const PdfExportOutcome({
    required this.messageKey,
    this.count = 0,
    this.detail,
  });

  /// Key catalog — UI dịch, service không nhồi chuỗi hiển thị (rule #5).
  final String messageKey;

  /// Số mục/số trang đã xuất (để UI nói con số).
  final int count;

  /// Đường dẫn tệp đã ghi, phục vụ debug; không bao giờ hiện cho người dùng.
  final String? detail;

  bool get isSuccess => kPdfExportSuccessMessageKeys.contains(messageKey);

  /// `true` khi tệp chỉ xuất một phần (số trang vượt [kPdfSnapshotMaxPages]).
  bool get isTruncated => detail != null && detail!.startsWith('limited:');

}

/// Nền trắng cho bản in — không dùng màu tối của app (in ra giấy tốn mực và
/// highlight vàng trên nền đen thành một mảng bùn).
const int kPdfSnapshotBackgroundArgb = 0xFFFFFFFF;

/// Xuất + (tuỳ chọn) mở hộp chia sẻ. Không ném: mọi lỗi quy về một messageKey.
Future<PdfExportOutcome> exportPdfReaderData({
  required PdfExportKind kind,
  required String pdfPath,
  required List<PdfAnnotation> annotations,
  required int lastPageIndex,
  required PdfDocument? document,
  bool share = true,
}) async {
  try {
    switch (kind) {
      case PdfExportKind.sidecarJson:
        return _exportSidecar(
          pdfPath: pdfPath,
          annotations: annotations,
          lastPageIndex: lastPageIndex,
          document: document,
          share: share,
        );
      case PdfExportKind.xfdf:
        return _exportXfdf(
          pdfPath: pdfPath,
          annotations: annotations,
          share: share,
        );
      case PdfExportKind.snapshotPdf:
        return _exportSnapshot(
          pdfPath: pdfPath,
          annotations: annotations,
          document: document,
          share: share,
        );
    }
  } on FileSystemException catch (e) {
    return PdfExportOutcome(messageKey: 'Không xuất được tệp này', detail: '${e.osError?.errorCode}');
  } catch (e) {
    return PdfExportOutcome(messageKey: 'Không xuất được tệp này', detail: '$e');
  }
}

Future<PdfExportOutcome> _exportSidecar({
  required String pdfPath,
  required List<PdfAnnotation> annotations,
  required int lastPageIndex,
  required PdfDocument? document,
  required bool share,
}) async {
  if (annotations.isEmpty) {
    return const PdfExportOutcome(messageKey: 'Không có highlight hoặc ghi chú nào để xuất');
  }
  final identity = await PdfFileIdentity.resolve(pdfPath);
  final sidecar = PdfAnnotationSidecar(
    fileName: pdfPath.split(RegExp(r'[/\\]')).last,
    fileSize: identity.fileSize,
    fileModifiedMs: identity.fileModifiedMs,
    pageCount: document?.pages.length ?? 0,
    lastPageIndex: lastPageIndex,
    exportedAt: DateTime.now(),
    annotations: annotations,
  );
  final bytes = utf8.encode(sidecar.encode());
  await _writeAndShare(
    fileName: pdfSidecarFileName(pdfPath),
    bytes: bytes,
    share: share,
  );
  return PdfExportOutcome(
    messageKey: 'Đã xuất tệp',
    count: annotations.length,
    detail: pdfSidecarFileName(pdfPath),
  );
}

Future<PdfExportOutcome> _exportXfdf({
  required String pdfPath,
  required List<PdfAnnotation> annotations,
  required bool share,
}) async {
  final exportable = pdfXfdfExportableCount(annotations);
  if (exportable == 0) {
    return const PdfExportOutcome(messageKey: 'Không có highlight hoặc ghi chú nào để xuất');
  }
  final xml = buildPdfXfdfExport(
    pdfFileName: pdfPath.split(RegExp(r'[/\\]')).last,
    annotations: annotations,
    exportedAt: DateTime.now(),
  );
  await _writeAndShare(
    fileName: pdfXfdfFileName(pdfPath),
    bytes: utf8.encode(xml),
    share: share,
  );
  return PdfExportOutcome(
    messageKey: 'Đã xuất tệp',
    count: exportable,
    detail: pdfXfdfFileName(pdfPath),
  );
}

Future<PdfExportOutcome> _exportSnapshot({
  required String pdfPath,
  required List<PdfAnnotation> annotations,
  required PdfDocument? document,
  required bool share,
}) async {
  if (document == null) {
    return const PdfExportOutcome(messageKey: 'Chưa mở xong tệp PDF');
  }
  final pages = document.pages;
  final wanted = <int>{
    for (final a in annotations)
      if (a.type != AnnotationType.bookmark &&
          a.rectsForPainting.isNotEmpty)
        a.pageIndex,
  }.toList()
    ..sort();
  if (wanted.isEmpty) {
    return const PdfExportOutcome(messageKey: 'Không có highlight hoặc ghi chú nào để xuất');
  }
  final capped = wanted.length > kPdfSnapshotMaxPages
      ? wanted.sublist(0, kPdfSnapshotMaxPages)
      : wanted;

  final frames = <PdfSnapshotFrame>[];
  for (final pageIndex in capped) {
    if (pageIndex < 0 || pageIndex >= pages.length) continue;
    final page = pages[pageIndex];
    final pageWidthPts = page.width.toDouble();
    final pageHeightPts = page.height.toDouble();
    final size = pdfSnapshotRenderSize(
      pageWidthPts: pageWidthPts,
      pageHeightPts: pageHeightPts,
    );
    if (size.width <= 0 || size.height <= 0) continue;
    final image = await page.render(
      fullWidth: size.width.toDouble(),
      fullHeight: size.height.toDouble(),
      backgroundColor: kPdfSnapshotBackgroundArgb,
    );
    if (image == null) continue;
    // Copy trước khi dispose: `pixels` là bộ nhớ của engine, dùng lại sau
    // dispose là UB (may thì rác, xui thì crash giữa lúc đang ghi tệp).
    final Uint8List pixels;
    try {
      pixels = Uint8List.fromList(image.pixels);
    } finally {
      image.dispose();
    }
    if (pixels.length != image.width * image.height * 4) continue;
    burnPdfAnnotationsIntoBgra(
      pixels,
      imageWidth: image.width,
      imageHeight: image.height,
      pageWidthPts: pageWidthPts,
      pageHeightPts: pageHeightPts,
      annotations: [
        for (final a in annotations)
          if (a.pageIndex == pageIndex) a,
      ],
    );
    frames.add(PdfSnapshotFrame(
      pixelWidth: image.width,
      pixelHeight: image.height,
      pageWidthPts: pageWidthPts,
      pageHeightPts: pageHeightPts,
      bgra: pixels,
    ));
  }
  if (frames.isEmpty) {
    return const PdfExportOutcome(messageKey: 'Không xuất được tệp này');
  }
  final pdf = buildPdfFromSnapshotFrames(
    frames: frames,
    title: pdfExportBaseName(pdfPath),
    createdAt: DateTime.now(),
  );
  await _writeAndShare(
    fileName: '${pdfExportBaseName(pdfPath)}.in4up.pdf',
    bytes: pdf,
    share: share,
  );
  return PdfExportOutcome(
    messageKey: 'Đã xuất bản chụp PDF',
    count: frames.length,
    detail: wanted.length > capped.length
        ? 'limited:${wanted.length - capped.length}'
        : null,
  );
}

Future<void> _writeAndShare({
  required String fileName,
  required List<int> bytes,
  required bool share,
}) async {
  final dir = await getTemporaryDirectory();
  final safeName = fileName.replaceAll(RegExp(r'[/\\:*?"<>|\x00-\x1F]'), '_');
  final file = File('${dir.path}/$safeName');
  await file.writeAsBytes(bytes, flush: true);
  if (!share) return;
  await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path)]),
  );
}

/// Kết quả chọn + đọc một tệp sidecar (chưa nhập gì cả — UI mới là chỗ quyết
/// định có chắc chắn nhập hay không).
final class PdfSidecarPickResult {
  const PdfSidecarPickResult({
    this.sidecar,
    this.problemKey,
    this.match,
    this.pickedName,
  });

  static const PdfSidecarPickResult cancelled = PdfSidecarPickResult();

  final PdfAnnotationSidecar? sidecar;
  final String? problemKey;
  final PdfSidecarFileMatch? match;
  final String? pickedName;

  bool get canImport => sidecar != null;
  bool get isCancelled => sidecar == null && problemKey == null;

  /// Key catalog mô tả mức khớp tệp, để người dùng tự quyết trước khi nhập.
  String get matchLabelKey => switch (match) {
        PdfSidecarFileMatch.sameFile => 'Cùng một tệp PDF',
        PdfSidecarFileMatch.contentChanged =>
          'Tệp PDF đã thay đổi sau khi xuất',
        PdfSidecarFileMatch.pageChanged => 'Số trang khác với lúc xuất',
        PdfSidecarFileMatch.unknown =>
          'Không kiểm tra được tệp PDF có trùng không',
        null => 'Không kiểm tra được tệp PDF có trùng không',
      };
}

/// Chọn tệp `.in4up.json` và kiểm tra nó khớp với file PDF đang mở tới đâu.
/// [dialogTitle] do UI đưa vào vì đó là chuỗi hiển thị (đã dịch ở tầng widget).
Future<PdfSidecarPickResult> pickAndReadSidecar({
  required int fileSize,
  required int fileModifiedMs,
  required int pageCount,
  String? dialogTitle,
}) async {
  FilePickerResult? picked;
  try {
    picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      dialogTitle: dialogTitle,
    );
  } catch (_) {
    return const PdfSidecarPickResult(
      problemKey: 'Không mở được trình chọn tệp',
    );
  }
  final file = picked?.files.isNotEmpty ?? false ? picked!.files.first : null;
  if (file == null) return PdfSidecarPickResult.cancelled;

  String? raw;
  try {
    final Uint8List? data = file.bytes;
    if (data != null) {
      raw = utf8.decode(data, allowMalformed: true);
    } else if (file.path != null) {
      raw = await File(file.path!).readAsString();
    }
  } catch (_) {
    return PdfSidecarPickResult(
      problemKey: 'Không đọc được tệp này',
      pickedName: file.name,
    );
  }
  if (raw == null) {
    return PdfSidecarPickResult(
      problemKey: 'Không đọc được tệp này',
      pickedName: file.name,
    );
  }
  final decoding = decodePdfAnnotationSidecar(raw);
  if (!decoding.isSuccess) {
    return PdfSidecarPickResult(
      problemKey: decoding.problemLabelKey ?? 'File này không phải tệp chú thích của In4Up',
      pickedName: file.name,
    );
  }
  final sidecar = decoding.sidecar!;
  return PdfSidecarPickResult(
    sidecar: sidecar,
    pickedName: file.name,
    match: compareSidecarToFile(
      sidecar: sidecar,
      fileSize: fileSize,
      fileModifiedMs: fileModifiedMs,
      pageCount: pageCount,
    ),
  );
}
