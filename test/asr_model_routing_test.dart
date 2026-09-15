// CABIN-ASR-002 — test mapping model/language + routing Online/Offline.
//
// Logic nằm ở `packages/in4up_stt/lib/asr_model_routing.dart` (thuần, không
// I/O) và `lib/features/cabin/services/cabin_asr_plan.dart` (thuần) nên chạy
// được trong `flutter test` không cần thiết bị.
//
// Bối cảnh: cabin từng hardcode 'en' → máy chỉ import model VI luôn bị báo
// “Chưa có model Zipformer cho EN”; và `getAsrModelPaths` từng fallback về
// profile ĐẦU TIÊN (VI) cho mọi ngôn ngữ ⇒ hỏi zh/fr lại ra model VI.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/cabin/services/cabin_asr_plan.dart';
// sherpa_model_manager re-export asr_model_routing (một import là đủ — tránh
// lint unnecessary_import).
import 'package:in4up_stt/sherpa_model_manager.dart';

/// Trạng thái cài đặt giả lập (không chạm đĩa/plugin).
bool Function(String) installedOnly(Set<String> profileIds) =>
    (String id) => profileIds.contains(id);

void main() {
  group('AsrModelRouter — mapping ngôn ngữ ↔ profile', () {
    test('chỉ có 2 profile đã verify (VI offline + EN streaming)', () {
      expect(kSherpaAsrProfiles.length, 2);
      final vi = AsrModelRouter.profileForLanguage('vi')!;
      expect(vi.id, 'asr-vi-30M-int8');
      expect(vi.isStreaming, isFalse);

      final en = AsrModelRouter.profileForLanguage('en')!;
      expect(en.id, 'asr-en-20M-streaming-int8');
      expect(en.isStreaming, isTrue);
    });

    test('normalize mã ngôn ngữ có vùng/hoa thường', () {
      expect(AsrModelRouter.normalizeLanguage('en-US'), 'en');
      expect(AsrModelRouter.normalizeLanguage('VI_vn'), 'vi');
      expect(AsrModelRouter.normalizeLanguage(' EN '), 'en');
      expect(AsrModelRouter.normalizeLanguage(''), '');
    });

    test('ngôn ngữ không có profile → null (KHÔNG bịa về profile đầu tiên)', () {
      expect(AsrModelRouter.profileForLanguage('zh'), isNull);
      expect(AsrModelRouter.profileForLanguage('fr'), isNull);
      expect(AsrModelRouter.profileForLanguage('ja-JP'), isNull);
      expect(AsrModelRouter.supportsLanguage('vi'), isTrue);
      expect(AsrModelRouter.supportsLanguage('th'), isFalse);
      expect(AsrModelRouter.supportedLanguages, ['vi', 'en']);
    });

    test('cabin KHÔNG còn hardcode EN: máy đã cài VI → mặc định VI', () {
      final installed = installedOnly({'asr-vi-30M-int8'});
      expect(AsrModelRouter.resolveDefaultLanguage(isInstalled: installed), 'vi');
    });

    test('máy chỉ cài EN streaming → mặc định EN', () {
      final installed = installedOnly({'asr-en-20M-streaming-int8'});
      expect(AsrModelRouter.resolveDefaultLanguage(isInstalled: installed), 'en');
    });

    test('máy chưa cài model nào → fallback VI (mặc định app) — có giải thích', () {
      final installed = installedOnly({});
      expect(AsrModelRouter.resolveDefaultLanguage(isInstalled: installed), 'vi');
      expect(AsrModelRouter.hasAnyInstalled(isInstalled: installed), isFalse);
    });

    test('máy chỉ có VI + user chọn EN → KHÔNG ready, gợi ý VI (không tự dùng)',
        () {
      final installed = installedOnly({'asr-vi-30M-int8'});
      final selection = AsrModelRouter.resolve('en', isInstalled: installed);

      expect(selection.isReady, isFalse);
      expect(selection.issue, AsrModelIssue.profileNotInstalled);
      expect(selection.profile?.id, 'asr-en-20M-streaming-int8');
      expect(selection.hasInstalledFallback, isTrue);
      expect(selection.fallbackLanguage, 'vi');
      // Không được tự đổi ngôn ngữ nhận diện sau lưng user.
      expect(selection.requestedLanguage, 'en');
    });

    test('chọn ngôn ngữ chưa hỗ trợ offline (zh) → noProfileForLanguage', () {
      final installed = installedOnly({'asr-vi-30M-int8'});
      final selection = AsrModelRouter.resolve('zh-CN', isInstalled: installed);
      expect(selection.isReady, isFalse);
      expect(selection.issue, AsrModelIssue.noProfileForLanguage);
      expect(selection.profile, isNull);
      // Model VI không phải là "fallback" cho zh — phải dùng engine Hệ thống.
      expect(selection.hasInstalledFallback, isFalse);
      expect(selection.fallbackLanguage, isNull);
    });

    test('máy có EN streaming + chọn EN → route OnlineRecognizer', () {
      final installed = installedOnly({'asr-en-20M-streaming-int8'});
      final selection = AsrModelRouter.resolve('en', isInstalled: installed);
      expect(selection.isReady, isTrue);
      expect(selection.issue, AsrModelIssue.none);
      expect(selection.liveRoute, AsrLiveRoute.onlineStreaming);
    });

    test('máy có VI offline + chọn VI → route simulated streaming (VAD)', () {
      final installed = installedOnly({'asr-vi-30M-int8'});
      final selection = AsrModelRouter.resolve('vi', isInstalled: installed);
      expect(selection.isReady, isTrue);
      expect(selection.liveRoute, AsrLiveRoute.simulatedOffline);
    });
  });

  group('CabinAsrPlan — kế hoạch STT cabin', () {
    test('engine Hệ thống: không cần model nào', () {
      final plan = planCabinAsr(
        engine: CabinSttEngineType.system,
        language: 'en',
        isInstalled: installedOnly({}),
      );
      expect(plan.canStart, isTrue);
      expect(plan.issue, AsrModelIssue.none);
    });

    test('máy chỉ có VI: engine Offline + ngôn ngữ mặc định VI → start được', () {
      final installed = installedOnly({'asr-vi-30M-int8'});
      final source = defaultCabinSourceLanguage(isInstalled: installed);
      final plan = planCabinAsr(
        engine: CabinSttEngineType.sherpaOffline,
        language: source,
        isInstalled: installed,
      );
      expect(source, 'vi');
      expect(plan.canStart, isTrue);
      expect(plan.hasModel, isTrue);
      expect(plan.liveRoute, AsrLiveRoute.simulatedOffline);
      expect(plan.canTranscribeFiles, isTrue);
    });

    test('máy chỉ có VI: user chọn EN → chặn + fallback VI để hỏi user', () {
      final installed = installedOnly({'asr-vi-30M-int8'});
      final plan = planCabinAsr(
        engine: CabinSttEngineType.sherpaOffline,
        language: 'EN',
        isInstalled: installed,
      );
      expect(plan.canStart, isFalse);
      expect(plan.requestedLanguage, 'en');
      expect(plan.issue, AsrModelIssue.profileNotInstalled);
      expect(plan.fallbackLanguage, 'vi');
      expect(plan.hasModel, isFalse);
    });

    test('model EN streaming KHÔNG dùng cho file/LRC', () {
      final installed = installedOnly({'asr-en-20M-streaming-int8'});
      final plan = planCabinAsr(
        engine: CabinSttEngineType.sherpaOffline,
        language: 'en',
        isInstalled: installed,
      );
      expect(plan.canStart, isTrue);
      expect(plan.liveRoute, AsrLiveRoute.onlineStreaming);
      expect(plan.canTranscribeFiles, isFalse);
    });

    test('ngôn ngữ đích mặc định: VI→EN, EN→VI', () {
      expect(defaultCabinTargetLanguageFor('vi'), 'en');
      expect(defaultCabinTargetLanguageFor('en'), 'vi');
      expect(defaultCabinTargetLanguageFor('zh'), 'vi');
    });
  });

  group('SherpaModelManager — nhận diện model & profile', () {
    test('matchAsrProfile: model streaming chỉ nhận profile EN', () {
      final en = SherpaModelManager.matchAsrProfile(
        isStreaming: true,
        encoderPath: '/models/sherpa-onnx-streaming-zipformer-en-20M/encoder.int8.onnx',
        folderName: 'sherpa-onnx-streaming-zipformer-en-20M-2023-02-17',
      );
      expect(en?.id, 'asr-en-20M-streaming-int8');
    });

    test('matchAsrProfile: streaming tên tiếng Việt → null (app không có '
        'profile VI streaming)', () {
      final profile = SherpaModelManager.matchAsrProfile(
        isStreaming: true,
        encoderPath: '/models/sherpa-onnx-streaming-zipformer-vi-30M/encoder.onnx',
        folderName: 'sherpa-onnx-streaming-zipformer-vi-30M',
      );
      expect(profile, isNull);
    });

    test('matchAsrProfile: model offline lạ → null (không nhét vào EN streaming)',
        () {
      final profile = SherpaModelManager.matchAsrProfile(
        isStreaming: false,
        encoderPath: '/models/whisper-like-zipformer/encoder.onnx',
        folderName: 'model-cua-toi',
      );
      expect(profile, isNull);
    });

    test('matchAsrProfile: VI theo tên thư mục archive đã giải nén', () {
      final vi = SherpaModelManager.matchAsrProfile(
        isStreaming: false,
        encoderPath:
            '/models/sherpa-onnx-zipformer-vi-30M-int8-2026-02-09/encoder.int8.onnx',
        folderName: 'sherpa-onnx-zipformer-vi-30M-int8-2026-02-09',
      );
      expect(vi?.id, 'asr-vi-30M-int8');
    });

    test('detectEncoderKind: metadata quyết định dù thư mục tên "streaming"', () {
      final dir = Directory.systemTemp.createTempSync('asr_kind_');
      try {
        // 1. Tên thư mục nói "streaming" nhưng nội dung là model OFFLINE →
        //    metadata thắng (không đẩy model offline vào nhánh Online).
        final streamingDir =
            Directory('${dir.path}/asr-en-20M-streaming-int8')
              ..createSync(recursive: true);
        final nonStreamingFile = File('${streamingDir.path}/encoder.int8.onnx')
          ..writeAsStringSync(
              'model_type=zipformer2;comment=non-streaming zipformer2');
        expect(
          SherpaModelManager.detectEncoderKind(nonStreamingFile.path),
          SherpaAsrEncoderKind.nonStreaming,
        );
        expect(
          SherpaModelManager.isStreamingEncoderOnnx(nonStreamingFile.path),
          isFalse,
        );

        // 2. Không có metadata, nhưng TÊN đường dẫn nói streaming (đúng cách
        //    k2-fsa đặt tên) → nhận là streaming.
        final namedStreamingDir =
            Directory('${dir.path}/sherpa-onnx-streaming-zipformer-en-20M')
              ..createSync(recursive: true);
        final namedFile = File('${namedStreamingDir.path}/encoder.int8.onnx')
          ..writeAsStringSync('model_type=zipformer2');
        expect(
          SherpaModelManager.detectEncoderKind(namedFile.path),
          SherpaAsrEncoderKind.streaming,
        );

        // 3. Chỉ có `encoder_dims` (bản int8 thật thường vậy — xem
        //    SHERPA-STREAM-001) và tên không gợi ý gì → KHÔNG đoán bừa:
        //    UNKNOWN để engine route theo PROFILE (VI → offline+VAD,
        //    EN → streaming), tránh nạp sai recognizer.
        final dimsOnlyFile = File('${dir.path}/encoder.int8.onnx')
          ..writeAsStringSync(
              'model_type=zipformer2;encoder_dims=192,256;query_head_dims=32');
        expect(
          SherpaModelManager.detectEncoderKind(dimsOnlyFile.path),
          SherpaAsrEncoderKind.unknown,
        );
        expect(
          SherpaModelManager.isStreamingEncoderOnnx(dimsOnlyFile.path),
          isFalse,
        );
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('asrTokensLookVietnamese: tokens.txt UTF-8 có dấu → VI', () {
      final dir = Directory.systemTemp.createTempSync('asr_tokens_');
      try {
        final viTokens = File('${dir.path}/tokens.txt')
          ..writeAsStringSync('việt 1\nnam 2\n');
        final enTokens = File('${dir.path}/en_tokens.txt')
          ..writeAsStringSync('hello 1\nworld 2\n');

        expect(SherpaModelManager.asrTokensLookVietnamese(viTokens.path), isTrue);
        expect(SherpaModelManager.asrTokensLookVietnamese(enTokens.path), isFalse);
        expect(SherpaModelManager.asrTokensLookVietnamese(null), isFalse);
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('SherpaAsrInfo: liệt kê ngôn ngữ đã cài (ưu tiên VI)', () {
      const info = SherpaAsrInfo(
        profileStates: {
          'asr-en-20M-streaming-int8': SherpaModelInfo(
            status: SherpaModelStatus.ready,
            localPath: '/data/asr-en',
          ),
        },
      );
      expect(info.installedLanguages, ['en']);
      expect(info.preferredInstalledLanguage, 'en');
      expect(info.isReady('asr-vi-30M-int8'), isFalse);
    });
  });
}
