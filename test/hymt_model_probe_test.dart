import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/translation/engines/hymt_engine.dart';
import 'package:in4up/features/translation/engines/hymt_model_probe.dart';
import 'package:in4up_ai/in4up_ai.dart' show GgufInfo;

/// HYMT-003 (2026-11-06) — vì sao chẩn đoán phải đọc HEADER GGUF chứ không chỉ
/// magic + kích thước:
///
/// * `Hy-MT1.5-1.8B-2bit.gguf` (601 MB) của AngelSlim/tencent dùng quant
///   `q2_0` block 512 + kernel SME2 (llama.cpp PR #19357, CHƯA MERGE). llama.cpp
///   đã pin trong repo (`third_party/llama.cpp` d7fa69b7) hiểu `q2_0` theo
///   block 64 của mainline ⇒ sai layout ⇒ `llama_model_load_from_file()` NULL.
///   Magic ĐÚNG, 601 MB ĐÚNG ⇒ mọi check cũ đều cho qua.
/// * Model không phải hunyuan ⇒ cũng NULL, nhưng câu lỗi phải khác.
void main() {
  GgufInfo info({
    String arch = 'hunyuan-dense',
    String quant = 'q4_k',
    bool supported = true,
    bool hasChatTemplate = true,
    int tensors = 292,
  }) =>
      GgufInfo(
        arch: arch,
        quant: quant,
        supported: supported,
        hasChatTemplate: hasChatTemplate,
        tensorCount: tensors,
      );

  group('HYMT/6 diagnose', () {
    test('Q4_K_M hunyuan-dense: KHÔNG báo lỗi', () {
      final d = HyMtModelProbe.diagnose(
        sizeBytes: 1150 * 1024 * 1024,
        info: info(),
      );
      expect(d.isOk, isTrue);
      expect(d.kind, isNull);
      expect(d.quantBlocked, isFalse);
    });

    test('file 2-bit 601 MB: magic đúng nhưng quant bị chặn (nguyên nhân #1)',
        () {
      final d = HyMtModelProbe.diagnose(
        sizeBytes: 601 * 1024 * 1024,
        info: info(quant: 'q2_0', supported: false),
      );
      expect(d.isOk, isFalse);
      expect(d.kind, HyMtModelIssueKind.unsupportedQuant);
      expect(d.quantBlocked, isTrue);
      expect(d.message, contains('q2_0'));
      // Câu lỗi phải chỉ đúng đường thoát: bản Q4_K_M.
      expect(d.message, contains('Q4_K_M'));
      expect(d.message, contains('19357'));
    });

    test('quant lạ (STQ1_0/UNKNOWN:43) cũng bị chặn, không im lặng', () {
      for (final quant in <String>['STQ1_0', 'UNKNOWN:43', 'q2_0c']) {
        final d = HyMtModelProbe.diagnose(
          sizeBytes: 440 * 1024 * 1024,
          info: info(quant: quant, supported: true),
        );
        expect(d.kind, HyMtModelIssueKind.unsupportedQuant, reason: quant);
        expect(d.message, contains(quant));
      }
    });

    test('sai kiến trúc: nói rõ "không phải Hy-MT" + tên kiến trúc', () {
      final d = HyMtModelProbe.diagnose(
        sizeBytes: 1150 * 1024 * 1024,
        info: info(arch: 'gemma3', quant: 'q4_k'),
      );
      expect(d.kind, HyMtModelIssueKind.wrongArchitecture);
      expect(d.message, contains('gemma3'));
      expect(d.message, contains('hunyuan-dense'));
      expect(d.quantBlocked, isFalse);
    });

    test('file < 400 MB = bị cắt (mọi bản Hy-MT 1.8B đều ≥ 440 MB)', () {
      final d = HyMtModelProbe.diagnose(sizeBytes: 100 * 1024 * 1024);
      expect(d.kind, HyMtModelIssueKind.truncated);
      expect(d.message, contains('100 MB'));
    });

    test('native cũ (không đọc được header) + size hợp lệ ⇒ KHÔNG kết luận hỏng',
        () {
      final d = HyMtModelProbe.diagnose(sizeBytes: 1150 * 1024 * 1024);
      expect(d.isOk, isTrue,
          reason: 'thiếu symbol inspect không phải lỗi của file model');
      expect(d.info, isNull);
    });
  });

  group('HYMT/6 framing needs', () {
    test('hunyuan (hoặc chưa đọc được arch) cần khung <｜hy_User｜>', () {
      expect(HyMtModelProbe.needsHunyuanFraming(null), isTrue);
      expect(HyMtModelProbe.needsHunyuanFraming(info()), isTrue);
      expect(
        HyMtModelProbe.needsHunyuanFraming(info(arch: 'hunyuan-dense')),
        isTrue,
      );
    });

    test('kiến trúc khác không bị thêm khung của Hunyuan', () {
      expect(HyMtModelProbe.needsHunyuanFraming(info(arch: 'gemma3')), isFalse);
    });
  });

  group('HYMT/6 model constants', () {
    test('tên file + URL mặc định là Q4_K_M của tencent (mainline quant)', () {
      expect(HyMtEngine.fileName, 'HY-MT1.5-1.8B-Q4_K_M.gguf');
      expect(HyMtEngine.downloadUrl, contains('tencent/HY-MT1.5-1.8B-GGUF'));
      expect(HyMtEngine.downloadUrl, contains('HY-MT1.5-1.8B-Q4_K_M.gguf'));
      // KHÔNG được quay lại bản 2-bit (kernel chưa merge).
      expect(HyMtEngine.downloadUrl.contains('2bit'), isFalse);
      expect(HyMtEngine.fileName.contains('2bit'), isFalse);
    });

    // Ngưỡng "file cắt" = 400 MB. Test cũ tự mâu thuẫn:
    //   expect(minPlausibleBytes, greaterThan(400MB))  ← cùng lúc với
    //   expect(minPlausibleBytes, lessThan(440MB))
    // trong khi hằng số CHÍNH XÁC là 400 MB ⇒ greaterThan luôn sai. Ý định
    // đúng cần kiểm: ngưỡng (a) chặn được file 100–300 MB và (b) KHÔNG chặn
    // nhầm mọi bản Hy-MT 1.8B đã phát hành (nhỏ nhất ≈ 440 MB).
    test('ngưỡng "file cắt" chặn file cắt nhưng không chặn bản 440 MB', () {
      expect(HyMtEngine.minPlausibleBytes, 400 * 1024 * 1024);
      expect(HyMtEngine.minPlausibleBytes,
          greaterThanOrEqualTo(400 * 1024 * 1024));
      // Bản nhỏ nhất từng phát hành (1.25-bit ≈ 440 MB) phải được coi là ĐỦ.
      expect(HyMtEngine.minPlausibleBytes, lessThan(440 * 1024 * 1024));
      // Model mặc định Q4_K_M ~1,13 GB.
      expect(HyMtEngine.expectedBytes, greaterThan(1024 * 1024 * 1024));
    });

    test('validateModelHeader vẫn bắt magic sai + file cắt', () {
      const magic = <int>[0x47, 0x47, 0x55, 0x46];
      expect(HyMtEngine.validateModelHeader(magic, 100 * 1024 * 1024),
          contains('bị cắt'));
      expect(
        HyMtEngine.validateModelHeader(
            <int>[0x3c, 0x68, 0x74, 0x6d], 2 * 1024 * 1024 * 1024),
        contains('magic GGUF'),
      );
      expect(
        HyMtEngine.validateModelHeader(magic, 1150 * 1024 * 1024),
        isNull,
      );
    });

    test('legacyBlockedFileName ghi nhớ tên file 2-bit cũ (để báo lỗi đúng)',
        () {
      expect(HyMtEngine.legacyBlockedFileName, 'Hy-MT1.5-1.8B-2bit.gguf');
    });

    // HYMT-003 hồi quy: đổi tên file mặc định ⇒ file 2-bit cũ phải (a) được
    // nhận diện để mời xoá và (b) bị dọn khi user bấm Xoá. Trước đây chỉ có
    // MỘT tên file nên nút Xoá xoá sạch; nay phải xoá cả hai.
    test('tên file legacy KHÁC tên file mặc định (nếu trùng sẽ mất file đang dùng)',
        () {
      expect(HyMtEngine.legacyBlockedFileName, isNot(HyMtEngine.fileName));
      expect(HyMtEngine.legacyBlockedFileName, contains('2bit'));
      expect(HyMtEngine.fileName, isNot(contains('2bit')));
    });

    test('file legacy 601 MB bị chặn bởi chẩn đoán (để UI mời xoá, không im lặng)',
        () {
      final d = HyMtModelProbe.diagnose(
        sizeBytes: 601 * 1024 * 1024,
        info: info(quant: 'q2_0', supported: false),
      );
      expect(d.quantBlocked, isTrue,
          reason: 'file 2-bit cũ phải bị nhận là quant bị chặn');
    });

    test('ngưỡng kích thước không coi file 601 MB là "đủ model mới"', () {
      // expectedBytes là 1,13 GB ⇒ 601 MB rơi dưới ngưỡng cắt của bản mới,
      // nên dù có magic đúng thì vẫn không được coi là model hoàn chỉnh.
      expect(HyMtEngine.minPlausibleBytes, lessThan(601 * 1024 * 1024));
      expect(HyMtEngine.expectedBytes, greaterThan(1024 * 1024 * 1024));
    });
  });
}
