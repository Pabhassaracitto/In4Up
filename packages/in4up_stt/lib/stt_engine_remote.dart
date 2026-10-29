// packages/in4up_stt/lib/stt_engine_remote.dart
//
// WP2 (API-003) — STT file qua API: POST /v1/audio/transcriptions
// (OpenAI-compatible: OpenAI / Groq / Speaches / whisper-server local).
//
// Vì sao cần engine này: file pháp thoại 30–60 phút bóc bằng whisper-tiny
// on-device vừa chậm vừa kém chính xác và làm nóng máy. whisper-large-v3
// trên API nhanh + chính xác hơn nhiều; kết quả ghi vào CÙNG pipeline
// LRC/cache/transcript-search như Whisper on-device (remote chỉ là nguồn
// segment — nguyên tắc MeetilyAdapter: không fake word timestamps).
//
// Thiết kế (API-003 spec):
//   1. Luôn convert → WAV 16kHz mono (AudioConverter) TRƯỚC — KHÔNG bao giờ
//      upload file lossless gốc (30p ≈ 57MB > limit 25MB; 16k mono chỉ
//      ~19MB/10 phút).
//   2. File dài → chunk ~10 phút, cắt tại giữa khoảng lặng (energy scan
//      thuần Dart stream từ đĩa — không cần model VAD onnx + không load
//      cả file vào RAM). Ghép đúng thứ tự + offset timestamp từng chunk
//      (kỷ luật hymt_chunking: không lặp, không mất đoạn).
//   3. Single-flight 1 job (mẫu hymt_slot) — request kế tiếp ⇒ mã `busy`.
//   4. Live mic KHÔNG đi qua engine này (giữ on-device như AT yêu cầu).
//
// Mọi dependency I/O inject được (wavPreparer / segmentCutter /
// silenceDetector / clientFactory / providerResolver) — test thuần không
// cần ffmpeg hay mạng.

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:in4up_ai/in4up_ai.dart';
import 'package:path/path.dart' as p;

import 'models/content_id.dart';
import 'models/stt_result.dart';
import 'stt_engine.dart';
import 'utils/audio_converter.dart';

/// Khoảng lặng phát hiện được trong file WAV 16k mono (giây).
class SttRemoteSilence {
  final double startSeconds;
  final double endSeconds;
  const SttRemoteSilence(this.startSeconds, this.endSeconds);
  double get midSeconds => (startSeconds + endSeconds) / 2;
}

// ── Injectable dependencies (cho test thuần) ──────────────────────────────

typedef SttWavPreparer = Future<String?> Function(String audioPath);
typedef SttSegmentCutter = Future<bool> Function({
  required String inputPath,
  required double startSeconds,
  required double durationSeconds,
  required String outputPath,
});
typedef SttDurationProber = Future<int?> Function(String path);
typedef SttSilenceDetector = Future<List<SttRemoteSilence>> Function(
    String wav16kPath);
typedef SttProviderResolver = AiProviderConfig? Function();
typedef SttClientFactory = OpenAiCompatClient Function(
    AiProviderConfig provider);
typedef SttCancelCheck = bool Function();

/// Callback tiến độ từng chunk (0-based index) + kết quả TÍCH LUỸ đến lúc
/// đó (partial — facade đẩy vào _partialSubject để UI live update).
typedef SttRemoteProgress = void Function(
    int chunkIndex, int chunkCount, SttResult partial);

/// Kế hoạch chunk: danh sách [startMs, endMs) contiguous phủ toàn file.
typedef SttRemoteChunk = ({int startMs, int endMs});

/// Mã lỗi cấu trúc (prefix trong message StateError) — UI phân nhánh theo
/// mã, không match chuỗi tự do (cùng khuôn mẫu HyMtErrorCode).
class SttRemoteErrorCodes {
  static const busy = '(busy)';
  static const noProvider = '(noProvider)';
  static const canceled = '(canceled)';
  static const noNetwork = '(noNetwork)';
  static const timeout = '(timeout)';
  static const unauthorized = '(unauthorized)';
  static const rateLimited = '(rateLimited)';
  static const apiError = '(apiError)';
  static const convertFailed = '(convertFailed)';
  static const cutFailed = '(cutFailed)';
  static const emptyResult = '(emptyResult)';
}

/// Lập kế hoạch chunk cho file dài — HÀM THUẦN (test trực tiếp không I/O).
///
/// Chiến lược: chia đều theo [targetChunkMs], rồi SNAP mỗi biên giới vào
/// trung tâm khoảng lặng gần nhất trong cửa sổ ±[maxSnapMs] (cắt tại chỗ
/// im lặng ⇒ không chém giữa từ). Ràng buộc:
///   - mỗi chunk ≥ [minChunkMs] (tránh nát file thành mảnh vụn);
///   - các biên strictly increasing, KHÔNG dùng lại 1 khoảng lặng;
///   - phủ kín [0, durationMs], không chồng lấn (offset stitch dựa vào đó).
///
/// Trả [SttRemoteChunk.empty] khi không cần chia (duration ≤ target).
List<SttRemoteChunk> planRemoteChunks({
  required int durationMs,
  required int targetChunkMs,
  required List<SttRemoteSilence> silences,
  int minChunkMs = 60 * 1000,
  int maxSnapMs = 90 * 1000,
}) {
  if (durationMs <= 0 || targetChunkMs <= 0) return const [];
  if (durationMs <= targetChunkMs) {
    return [(startMs: 0, endMs: durationMs)];
  }

  // Trung tâm các khoảng lặng (đã sort, không trùng).
  final mids = silences.map((s) => (s.midSeconds * 1000).round()).toList()
    ..sort();
  final usedMids = <int>{};

  final borders = <int>[];
  var start = 0;
  while (durationMs - start > targetChunkMs) {
    var border = start + targetChunkMs;
    // Snap vào khoảng lặng gần ideal nhất trong cửa sổ, chưa dùng.
    int? best;
    var bestDist = 1 << 60;
    for (final mid in mids) {
      if (usedMids.contains(mid)) continue;
      final dist = (mid - border).abs();
      if (dist <= maxSnapMs && dist < bestDist) {
        best = mid;
        bestDist = dist;
      }
    }
    if (best != null) {
      usedMids.add(best);
      border = best;
    }
    // Ràng buộc độ dài tối thiểu 2 phía.
    final minBorder = start + minChunkMs;
    final maxBorder = durationMs - minChunkMs;
    border = border.clamp(minBorder, math.max(minBorder, maxBorder)).toInt();
    if (border <= start) break; // bảo vệ vô hạn (không xảy ra khi min ≤ target/2).
    borders.add(border);
    start = border;
    // Còn lại quá ngắn so với minChunkMs × 2 → dừng, phần cuối 1 chunk.
    if (durationMs - start < minChunkMs * 2) break;
  }

  final chunks = <SttRemoteChunk>[];
  var from = 0;
  for (final b in borders) {
    chunks.add((startMs: from, endMs: b));
    from = b;
  }
  chunks.add((startMs: from, endMs: durationMs));
  return chunks;
}

/// Scan khoảng lặng bằng năng lượng — thuần Dart, STREAM từ đĩa (không load
/// cả file vào RAM), chỉ đọc đúng phần `data` của WAV PCM 16-bit.
///
/// Không dùng SherpaVadCore ở đây: VAD cần model onnx + FFI init + readWave
/// load toàn bộ samples vào RAM — quá nặng chỉ để tìm chỗ cắt chunk. Energy
/// scan 100ms/cửa sổ là đủ (chunk border chỉ CẦN GẦN chỗ im lặng, độ chính
/// xác timestamp không phụ thuộc nó).
///
/// Buffer byte dư giữa các block là LOCAL carry (< 1 window = 3200 byte) —
/// window không bao giờ lệch mốc, hàm reentrant-safe.
Future<List<SttRemoteSilence>> scanSilenceGaps(
  String wav16kPath, {
  int windowMs = 100,
  int minSilenceMs = 400,
  int rmsThreshold = 120,
}) async {
  final file = File(wav16kPath);
  if (!await file.exists()) return const [];

  // ── Parse header RIFF: tìm offset chunk 'data' (header có thể dài hơn
  //    44 byte nếu có LIST/metadata — đọc chunk table cho đúng).
  final raf = await file.open();
  var dataStart = -1;
  try {
    final head = await raf.read(1024);
    if (head.length < 12) return const [];
    if (String.fromCharCodes(head, 0, 4) != 'RIFF') return const [];
    var offset = 12;
    while (offset + 8 <= head.length) {
      final id = String.fromCharCodes(head, offset, offset + 4);
      final size = head[offset + 4] |
          (head[offset + 5] << 8) |
          (head[offset + 6] << 16) |
          (head[offset + 7] << 24);
      if (id == 'data') {
        dataStart = offset + 8;
        break;
      }
      if (size < 0) break; // size âm = corrupt → thôi.
      offset += 8 + size + (size & 1); // chunk align chẵn byte (RIFF spec).
    }
  } finally {
    await raf.close();
  }
  if (dataStart < 0) return const []; // không tìm thấy chunk 'data'.

  final samplesPerWindow = 16000 * windowMs ~/ 1000; // 16k mono
  final bytesPerWindow = samplesPerWindow * 2; // 16-bit

  final gaps = <SttRemoteSilence>[];
  var silenceStartMs = -1;
  var windowIndex = 0;

  void processWindow(List<int> buf, int pos) {
    var sumSq = 0;
    for (var i = pos; i < pos + bytesPerWindow; i += 2) {
      final s = (buf[i] | (buf[i + 1] << 8)).toSigned(16);
      sumSq += s * s;
    }
    final rms = math.sqrt(sumSq / samplesPerWindow);
    final windowStartMs = windowIndex * windowMs;
    if (rms < rmsThreshold) {
      silenceStartMs = silenceStartMs < 0 ? windowStartMs : silenceStartMs;
    } else {
      if (silenceStartMs >= 0 &&
          windowStartMs - silenceStartMs >= minSilenceMs) {
        gaps.add(SttRemoteSilence(
          silenceStartMs / 1000.0,
          windowStartMs / 1000.0,
        ));
      }
      silenceStartMs = -1;
    }
    windowIndex++;
  }

  var carry = <int>[];
  await for (final block in file.openRead(dataStart)) {
    final buf = carry.isEmpty ? block : [...carry, ...block];
    var pos = 0;
    while (pos + bytesPerWindow <= buf.length) {
      processWindow(buf, pos);
      pos += bytesPerWindow;
    }
    carry = (pos < buf.length) ? buf.sublist(pos) : const <int>[];
  }

  return gaps;
}

/// Engine STT qua API OpenAI-compatible.
class SttEngineRemote implements SttEngine {
  @override
  String get engineName => 'remote';

  /// Target ~10 phút/chunk: WAV 16k mono 16-bit ≈ 1.92MB/phút → 10 phút
  /// ≈ 19.2MB, an toàn dưới limit upload 25MB của OpenAI/Groq/Speaches.
  static const defaultTargetChunkMs = 10 * 60 * 1000;

  /// Limit upload phổ biến (OpenAI/Groq free tier, whisper-server default).
  static const defaultMaxUploadBytes = 24 * 1024 * 1024;

  /// Single-flight (mẫu hymt_slot): 1 job remote tại 1 thời điểm.
  static bool _busy = false;

  final SttProviderResolver providerResolver;
  final SttClientFactory clientFactory;
  final SttWavPreparer wavPreparer;
  final SttSegmentCutter segmentCutter;
  final SttDurationProber durationProber;
  final SttSilenceDetector silenceDetector;
  final int targetChunkMs;
  final int maxUploadBytes;
  final Duration responseTimeout;

  SttEngineRemote({
    SttProviderResolver? providerResolver,
    SttClientFactory? clientFactory,
    SttWavPreparer? wavPreparer,
    SttSegmentCutter? segmentCutter,
    SttDurationProber? durationProber,
    SttSilenceDetector? silenceDetector,
    this.targetChunkMs = defaultTargetChunkMs,
    this.maxUploadBytes = defaultMaxUploadBytes,
    this.responseTimeout = const Duration(minutes: 10),
  })  : providerResolver = providerResolver ?? _defaultProviderResolver,
        clientFactory = clientFactory ?? _defaultClientFactory,
        wavPreparer = wavPreparer ?? AudioConverter.convertToWhisperCompatible,
        segmentCutter = segmentCutter ?? AudioConverter.cutSegment,
        durationProber = durationProber ?? AudioConverter.probeDurationMs,
        silenceDetector = silenceDetector ?? scanSilenceGaps;

  static AiProviderConfig? _defaultProviderResolver() {
    final store = AiProviderStore.instance;
    if (!store.isLoaded) return null; // chưa load xong ⇒ coi như chưa cấu hình
    return store.resolveProvider(AiRouteCapability.sttFile);
  }

  static OpenAiCompatClient _defaultClientFactory(AiProviderConfig provider) =>
      OpenAiCompatClient(baseUrl: provider.baseUrl, apiKey: provider.apiKey);

  @override
  SttEngineCapabilities get capabilities => const SttEngineCapabilities(
        supportsFileTranscription: true,
        supportsLiveMic: false, // live mic LUÔN on-device (AT API-003).
        supportsOffline: false, // cần mạng — facade không chọn khi offline.
        supportsWordTimestamps: true, // verbose_json words (nếu server trả).
        supportsChunking: true,
      );

  @override
  Future<void> initialize() async {}

  /// Engine FILE qua API — không live mic (AT API-003: live mic giữ
  /// on-device). Implement tường minh như WhisperSttEngine.
  @override
  Stream<SttResult> get liveResultStream => const Stream.empty();

  @override
  Future<bool> startListening({String language = 'en-US'}) async => false;

  @override
  Future<void> stopListening() async {}

  @override
  Future<void> dispose() async {}

  /// Transcribe file qua API.
  ///
  /// [options]:
  ///  - `language` (String, BCP-47 vd 'en-US' → bỏ region thành 'en').
  ///  - `audioFingerprint` (String) — tính UID segment đúng mốc file gốc.
  ///  - `onProgress` (SttRemoteProgress) — gọi sau mỗi chunk xong.
  ///  - `shouldCancel` (SttCancelCheck) — true ⇒ dừng sạch, throw `canceled`.
  ///
  /// Throw [StateError] với prefix mã lỗi (SttRemoteErrorCodes) — facade
  /// catch và trả SttTranscribeOutput.failure (không fake success).
  @override
  Future<SttResult> transcribeFile(
    String audioPath, {
    Map<String, dynamic>? options,
  }) async {
    if (_busy) {
      throw StateError(
          '${SttRemoteErrorCodes.busy} Đang có một lần bóc băng qua API '
          'chạy — chờ nó xong rồi thử lại.');
    }
    _busy = true;
    try {
      return await _transcribeLocked(audioPath, options ?? const {});
    } finally {
      _busy = false;
    }
  }

  Future<SttResult> _transcribeLocked(
    String audioPath,
    Map<String, dynamic> options,
  ) async {
    final sw = Stopwatch()..start();
    // ── 0. Resolve provider MỖI LẦN gọi (routing đổi runtime) ────────────
    final provider = providerResolver();
    if (provider == null) {
      throw StateError(
          '${SttRemoteErrorCodes.noProvider} Chưa cấu hình server AI cho '
          'bóc băng file — mở Server & API, thêm provider có model STT '
          '(vd whisper-large-v3), hoặc chuyển về engine offline.');
    }
    final model = provider.sttModel;
    if (model == null || model.isEmpty) {
      throw StateError(
          '${SttRemoteErrorCodes.noProvider} Provider "${provider.label}" '
          'chưa đặt model STT — mở Server & API để chọn model.');
    }

    final languageRaw = options['language'] as String?;
    final language = _toIsoLanguage(languageRaw);
    final fingerprint = (options['audioFingerprint'] as String?) ?? '';
    final onProgress = options['onProgress'] as SttRemoteProgress?;
    final shouldCancel = options['shouldCancel'] as SttCancelCheck?;

    // ── 1. Convert → WAV 16k mono (KHÔNG upload lossless gốc) ────────────
    String? convertedPath;
    try {
      convertedPath = await wavPreparer(audioPath);
      if (convertedPath == null) {
        throw StateError(
            '${SttRemoteErrorCodes.convertFailed} Không chuyển được audio '
            'sang WAV 16k mono cho upload.');
      }

      // ── 2. Thời lượng + kích thước → có cần chunk không ────────────────
      var durationMs = await durationProber(convertedPath);
      final sizeBytes = await File(convertedPath).length();
      if (durationMs == null || durationMs <= 0) {
        // 16k mono 16-bit = 32000 byte/s — ước lượng từ size.
        durationMs = (sizeBytes / 32).round();
      }
      // Nếu cả 1 chunk cũng vượt limit upload → siết target theo size thật.
      var effectiveTarget = targetChunkMs;
      if (sizeBytes > 0 && durationMs > 0) {
        final bytesPerMs = sizeBytes / durationMs;
        final maxMsByUpload = (maxUploadBytes / bytesPerMs).floor();
        if (maxMsByUpload < effectiveTarget) {
          effectiveTarget = math.max(60 * 1000, maxMsByUpload);
        }
      }

      final chunks = planRemoteChunks(
        durationMs: durationMs,
        targetChunkMs: effectiveTarget,
        silences: await (durationMs > effectiveTarget
            ? silenceDetector(convertedPath)
            : Future.value(const <SttRemoteSilence>[])),
      );
      if (chunks.isEmpty) {
        throw StateError(
            '${SttRemoteErrorCodes.convertFailed} Không xác định được thời '
            'lượng audio ($durationMs ms).');
      }

      final client = clientFactory(provider);
      final tmpDir = Directory.systemTemp.path;
      final baseName = AudioConverter.sanitizeFileName(
          p.basenameWithoutExtension(audioPath));
      final chunkFiles = <String>[];
      final allSegments = <SttSegment>[];
      final languages = <String>{};
      var sawWords = false;

      try {
        for (var i = 0; i < chunks.length; i++) {
          if (shouldCancel != null && shouldCancel()) {
            throw StateError(
                '${SttRemoteErrorCodes.canceled} Đã dừng bóc băng qua API '
                'theo yêu cầu.');
          }

          final chunk = chunks[i];
          String uploadPath;
          if (chunks.length == 1) {
            uploadPath = convertedPath!; // file ngắn: upload thẳng.
          } else {
            final chunkPath = p.join(
                tmpDir, '${baseName}_rchunk_$i.wav');
            final ok = await segmentCutter(
              inputPath: convertedPath!,
              startSeconds: chunk.startMs / 1000.0,
              durationSeconds: (chunk.endMs - chunk.startMs) / 1000.0,
              outputPath: chunkPath,
            );
            if (!ok) {
              throw StateError(
                  '${SttRemoteErrorCodes.cutFailed} Không cắt được chunk '
                  '${i + 1}/${chunks.length} — kiểm tra ffmpeg.');
            }
            chunkFiles.add(chunkPath);
            uploadPath = chunkPath;
          }

          // Upload + transcribe 1 chunk (429/5xx đã backoff-retry trong
          // client — hết retry vẫn lỗi thì bắn mã tương ứng).
          final ai = await _callTranscriber(
            client,
            filePath: uploadPath,
            model: model,
            language: language,
          );

          // Offset stitch: timestamp chunk-relative → mốc file gốc.
          final offsetMs = chunk.startMs;
          for (final seg in ai.segments) {
            final startMs = (seg.start * 1000).round() + offsetMs;
            if (seg.words.isNotEmpty) sawWords = true;
            allSegments.add(SttSegment(
              id: allSegments.length,
              uid: ContentId.segmentUid(
                audioFingerprint: fingerprint,
                startMs: startMs,
                text: seg.text,
              ),
              startSeconds: startMs / 1000.0,
              endSeconds: seg.end + offsetMs / 1000.0,
              text: seg.text,
              avgConfidence: 1.0,
              words: [
                for (final w in seg.words)
                  SttWord(
                    word: w.word,
                    startSeconds: w.start + offsetMs / 1000.0,
                    endSeconds: w.end + offsetMs / 1000.0,
                  ),
              ],
            ));
          }
          if (ai.language.isNotEmpty) languages.add(ai.language);

          // Partial tích luỹ — facade đẩy vào _partialSubject (như
          // transcribeMobileChunked của Whisper).
          onProgress?.call(
            i,
            chunks.length,
            SttResult(
              fullText: allSegments.map((s) => s.text).join(' '),
              segments: List.of(allSegments),
              engineUsed: SttEngineType.remote,
              language: languages.isNotEmpty
                  ? languages.first
                  : (language ?? ''),
              processingTime: sw.elapsed,
              audioFingerprint: fingerprint,
              hasWordTimestamps: sawWords,
              isFinal: false,
            ),
          );
        }
      } finally {
        // Dọn chunk tạm bằng File.delete trực tiếp — cleanupConvertedFile
        // của AudioConverter chỉ xóa file '*_converted.wav', còn
        // cleanupChunkFiles chỉ xóa '*_chunk_*' (của Whisper on-device).
        for (final f in chunkFiles) {
          try {
            final file = File(f);
            if (await file.exists()) await file.delete();
          } catch (_) {}
        }
      }

      if (allSegments.isEmpty) {
        throw StateError(
            '${SttRemoteErrorCodes.emptyResult} Server không trả về đoạn '
            'văn bản nào cho file này.');
      }

      sw.stop();
      return SttResult(
        fullText: allSegments.map((s) => s.text).join(' '),
        segments: allSegments,
        engineUsed: SttEngineType.remote,
        language: languages.isNotEmpty
            ? languages.first
            : (language ?? (languageRaw ?? '')),
        processingTime: sw.elapsed,
        audioFingerprint: fingerprint,
        hasWordTimestamps: sawWords,
        isFinal: true,
      );
    } finally {
      if (convertedPath != null) {
        await AudioConverter.cleanupConvertedFile(convertedPath);
      }
    }
  }

  /// Gọi client.transcribeAudio, map AiApiException → StateError có mã.
  Future<AiTranscription> _callTranscriber(
    OpenAiCompatClient client, {
    required String filePath,
    required String model,
    required String? language,
  }) async {
    try {
      return await client.transcribeAudio(
        filePath: filePath,
        model: model,
        language: language,
        responseTimeout: responseTimeout,
      );
    } on AiApiException catch (e) {
      switch (e.code) {
        case AiApiErrorCode.noNetwork:
          throw StateError(
              '${SttRemoteErrorCodes.noNetwork} Mất kết nối tới server '
              'trong lúc bóc băng — kiểm tra mạng rồi chạy lại (có thể chạy '
              'tạm bằng engine offline).');
        case AiApiErrorCode.timeout:
          throw StateError(
              '${SttRemoteErrorCodes.timeout} Server xử lý quá lâu '
              '(${responseTimeout.inMinutes} phút) — thử lại hoặc dùng file '
              'ngắn hơn.');
        case AiApiErrorCode.unauthorized:
          throw StateError(
              '${SttRemoteErrorCodes.unauthorized} API key không hợp lệ — '
              'kiểm tra lại trong Server & API.');
        case AiApiErrorCode.rateLimited:
          throw StateError(
              '${SttRemoteErrorCodes.rateLimited} Server đang giới hạn tốc '
              'độ (429) — đợi ít phút rồi chạy lại.');
        case AiApiErrorCode.cleartextBlocked:
        case AiApiErrorCode.invalidBaseUrl:
        case AiApiErrorCode.invalidResponse:
        case AiApiErrorCode.httpError:
          throw StateError('${SttRemoteErrorCodes.apiError} ${e.message}');
      }
    }
  }

  /// 'en-US'/'vi-VN' → 'en'/'vi' (API whisper nhận ISO-639-1);
  /// 'auto'/null → null (server tự nhận diện).
  static String? _toIsoLanguage(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'auto') return null;
    final base = trimmed.split('-').first.toLowerCase();
    return base.isEmpty ? null : base;
  }
}
