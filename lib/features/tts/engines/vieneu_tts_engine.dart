// lib/features/tts/engines/vieneu_tts_engine.dart

// VieNeu-TTS v3 Turbo engine (audio.cpp C API, GGUF, on-device, offline) cho
// TtsService (ticket TTS-VIENEU-001).
//
// PSRC-183/184/186 — một nguồn sự thật cho trạng thái model/worker:
//   * `isAvailable()` chỉ trả lời "có file model + lib native", KHÔNG cache
//     một lần `false` thành `true` như bản cũ.
//   * `getAvailableVoices()` chỉ đọc đĩa, KHÔNG nạp model 170 MB để liệt kê
//     giọng (picker Settings không được phép spawn worker).
//   * `init()` + `selectVoice()` dùng chung bản đồ giọng đã quét, nên giọng
//     mẫu đi kèm GGUF VÀ giọng clone đều được nạp đúng file.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import './tts_engine.dart';
import 'package:in4up_stt/tts/vieneu_model_files.dart';
import 'package:in4up_stt/tts/vieneu_tts_core.dart';
import 'package:in4up_stt/tts/vieneu_tts_paths.dart';

/// Câu nguồn khi thiếu `sea_g2p.bin` (key dịch 8 locale). Giữ thành hằng số
/// để test `vieneu_g2p_dictionary_test.dart` khoá được câu này, và để engine/
/// UI dùng CÙNG một câu thay vì mỗi nơi một kiểu (PSRC-216).
const String kVieneuMissingG2pNotice =
    'Thiếu từ điển phát âm sea_g2p.bin — tải trong Cài đặt › Giọng đọc';

/// Ảnh chụp ĐĨA của các thư mục giọng (không nạp model).
///
/// Dùng cho mục "Không thấy giọng vừa import?" trong Cài đặt: hiện đúng gốc
/// thư mục, file model, `sea_g2p.bin` và từng thư mục giọng kèm lý do.
class VieneuVoicesDiagnostics {
  const VieneuVoicesDiagnostics({
    required this.root,
    required this.modelPath,
    required this.hasPhonemeDictionary,
    required this.preset,
    required this.cloned,
    required this.presetsDirExists,
  });

  final String root;
  final String? modelPath;
  /// `sea_g2p.bin` có cạnh model không (lười tính — Future để không chặn
  /// việc dựng ảnh chụp).
  final Future<bool> hasPhonemeDictionary;
  final List<VieneuVoiceFolderDiagnosis> preset;
  final List<VieneuVoiceFolderDiagnosis> cloned;
  final bool presetsDirExists;

  int get usableCount =>
      preset.where((d) => d.status == VieneuVoiceFolderStatus.usable).length +
      cloned.where((d) => d.status == VieneuVoiceFolderStatus.usable).length;
}

/// Ảnh chụp "engine có chạy được không, thiếu gì" — KHÔNG nạp model.
///
/// PSRC-216: thay cho chuỗi try/catch rải rác, mọi nơi (UI, TtsService, voice
/// clone) hỏi CÙNG một hàm [VieneuTtsEngine.probe] và nhận đúng một lý do.
class VieneuEngineProbe {
  const VieneuEngineProbe({
    required this.blocker,
    this.modelPath,
    this.variant,
    this.modelProblem,
    this.modelBytes = 0,
  });

  /// `null` = đủ 3 mảnh, engine nạp được.
  final VieneuEngineBlocker? blocker;
  final String? modelPath;
  final VieneuModelVariant? variant;
  final VieneuModelFileProblem? modelProblem;
  final int modelBytes;

  bool get ready => blocker == null;

  /// Câu nguồn cho UI (rỗng khi sẵn sàng).
  String get message =>
      blocker == null ? '' : vieneuEngineBlockerMessage(blocker!);
}

/// Đường dẫn dữ liệu của một giọng đã quét được từ đĩa.
class _VoiceFiles {
  final String id;
  final String name;
  final String origin;
  final String refCodesPath;
  final String? speakerEmbeddingPath;

  /// Mẫu WAV của giọng (gói giọng upstream có `<Tên>.wav`): chưa có mã thì
  /// engine mã hoá mẫu MỘT LẦN rồi ghi `ref_codes.txt` cạnh mẫu.
  final String? samplePath;

  const _VoiceFiles({
    required this.id,
    required this.name,
    required this.origin,
    required this.refCodesPath,
    this.speakerEmbeddingPath,
    this.samplePath,
  });

  _VoiceFiles withRefCodes(String path) => _VoiceFiles(
        id: id,
        name: name,
        origin: origin,
        refCodesPath: path,
        speakerEmbeddingPath: speakerEmbeddingPath,
        samplePath: samplePath,
      );
}

/// VieNeu-TTS v3 Turbo neural TTS chạy hoàn toàn on-device (CPU, audio.cpp
/// GGUF). Không cần mạng, không cần Python runtime.
class VieneuTtsEngine implements TtsEngine {
  VieneuTtsEngine._();
  static final VieneuTtsEngine instance = VieneuTtsEngine._();

  final VieneuTtsCore _core = VieneuTtsCore.instance;

  VieneuModelVariant _modelVariant = VieneuModelVariant.q8_0;
  String? _modelPath;
  String? _voicesDir;
  String? _clonedVoicesDir;
  String? _selectedVoiceId;
  /// Giọng thực sự đang được worker native dùng (khác với giọng UI chọn).
  String? _workerVoiceId;
  bool _initialized = false;
  /// Vì sao engine CHƯA dùng được (null = không có trở ngại). UI/TtsService
  /// cần câu đúng sự thật thay vì luôn nói "chưa import model .gguf" — từ
  /// 1.29 thiếu `sea_g2p.bin` cũng là một lý do chặn.
  String? _blockingReason;
  Future<void>? _initFuture;
  final Map<String, _VoiceFiles> _voiceIndex = <String, _VoiceFiles>{};

  @override
  String get name => 'VieNeu-TTS (native)';

  @override
  String get id => 'vieneu_tts';

  @override
  int get maxCharsPerRequest => 3000; // audio.cpp tự chia đoạn dài (chunk)

  @override
  List<String> get supportedLanguages => const ['vi-VN'];

  /// Worker đã nạp model xong VÀ còn sống. UI dùng getter này để hiện
  /// trạng thái "engine" tách biệt với trạng thái "đã import model"
  /// (PSRC-183: hai badge không được mâu thuẫn nhau).
  bool get isInitialized => _initialized && _core.isInitialized;

  /// Model ưu tiên (biến thể đang chọn); nếu file biến thể đó chưa có nhưng
  /// biến thể khác đã import thì dùng biến thể có thật — picker không còn
  /// báo "Chưa import model" trong khi model Q8_0 đã sẵn sàng.
  Future<String?> _resolveModelPath() async {
    final preferred = await VieneuTtsCore.modelPathFor(_modelVariant);
    if (preferred != null) return preferred;
    for (final variant in VieneuModelVariant.values) {
      final path = await VieneuTtsCore.modelPathFor(variant);
      if (path != null) {
        _modelVariant = variant;
        return path;
      }
    }
    return null;
  }

  Future<void> _rememberPaths(String modelPath) {
    _modelPath = modelPath;
    _voicesDir = p.join(p.dirname(modelPath), 'voices');
    _clonedVoicesDir = p.join(p.dirname(modelPath), 'cloned_voices');
    return Future<void>.value();
  }

  /// Thư mục gốc chứa `voices/` + `cloned_voices/`. Vẫn trả về được khi
  /// chưa import GGUF ⇒ giọng mẫu import từ thư mục vẫn hiển thị (PSRC-186).
  Future<String> _voicesRoot() async {
    final model = await _resolveModelPath();
    if (model != null) {
      await _rememberPaths(model);
      return p.dirname(model);
    }
    final dir = await getApplicationDocumentsDirectory();
    final root = p.join(dir.path, 'vieneu_tts');
    _modelPath = null;
    _voicesDir = p.join(root, 'voices');
    _clonedVoicesDir = p.join(root, 'cloned_voices');
    return root;
  }

  /// Câu giải thích vì sao engine chưa sẵn sàng (null = không có trở ngại).
  String? get blockingReason => _blockingReason;

  /// Từ điển phát âm SEA-G2P đã có cạnh model chưa?
  ///
  /// Model chỉ nhận **phoneme**, không nhận chữ thô: thiếu `sea_g2p.bin` thì
  /// audio.cpp ném lỗi ngay khi nạp — sau khi đã tốn ~170 MB RAM. Hàm này để
  /// chặn TRƯỚC và để UI nói đúng lý do (lane L6, ADR-0028).
  Future<bool> hasPhonemeDictionary() async {
    final model = await _resolveModelPath();
    final String dir;
    if (model != null) {
      dir = p.dirname(model);
    } else {
      final base = await getApplicationDocumentsDirectory();
      dir = p.join(base.path, 'vieneu_tts');
    }
    return _dictionaryExistsIn(dir);
  }

  /// Từ điển phát âm có nằm cạnh MỘT model cụ thể không (dùng cho [probe]).
  Future<bool> hasPhonemeDictionaryNextTo(String modelPath) =>
      _dictionaryExistsIn(p.dirname(modelPath));

  Future<bool> _dictionaryExistsIn(String dir) async {
    try {
      return await File(vieneuG2pDictionaryPath(dir)).exists();
    } catch (e) {
      debugPrint('⚠️ VieNeu-TTS: không kiểm được từ điển phát âm: $e');
      return false;
    }
  }

  /// Vì sao engine CHƯA chạy được, hoặc `ready` khi đủ 3 mảnh.
  ///
  /// PSRC-216: một chỗ duy nhất trả lời câu "thiếu gì?" cho UI ("Khởi tạo
  /// engine"), cho `TtsService` (import ⇒ engine sẵn sàng chưa — PSRC-215) và
  /// cho voice clone (PSRC-218). Không nạp model, không spawn worker.
  ///
  /// Thứ tự kiểm khớp [firstVieneuEngineBlocker] và [_initOnce]:
  /// model → file model dùng được → thư viện native → `sea_g2p.bin`.
  Future<VieneuEngineProbe> probe({VieneuModelVariant? modelVariant}) async {
    final requested = modelVariant ?? _modelVariant;
    var variant = requested;
    var model = await VieneuTtsCore.modelPathFor(requested);
    if (model == null) {
      for (final candidate in VieneuModelVariant.values) {
        final path = await VieneuTtsCore.modelPathFor(candidate);
        if (path != null) {
          model = path;
          variant = candidate;
          break;
        }
      }
    }
    if (model == null) {
      return const VieneuEngineProbe(blocker: VieneuEngineBlocker.noModel);
    }

    final report = await inspectVieneuModelOnDisk(model);
    final nativeBundled = await VieneuTtsCore.isNativeLibraryAvailable();
    final dictionary = await hasPhonemeDictionaryNextTo(model);
    final blocker = firstVieneuEngineBlocker(
      hasModel: true,
      nativeLibrary: nativeBundled,
      phonemeDictionary: dictionary,
      modelProblem: report.problem,
    );
    return VieneuEngineProbe(
      blocker: blocker,
      modelPath: model,
      variant: variant,
      modelProblem: report.problem,
      modelBytes: report.bytes,
    );
  }

  /// Lỗi native NGUYÊN VĂN của lần init gần nhất (null nếu không có). UI hiện
  /// câu này thay vì câu chung "kiểm tra file gguf và thư viện native" —
  /// PSRC-216 yêu cầu "báo rõ file thiếu".
  String? get lastInitError => _lastInitError;
  String? _lastInitError;

  /// Có thể dùng ngay bây giờ? (lib native + ít nhất một file .gguf)
  ///
  /// Không yêu cầu worker đã init: model import xong là "available"; việc nạp
  /// 170 MB diễn ra lazy khi synthesize / bấm "Khởi tạo engine".
  @override
  Future<bool> isAvailable() async {
    final model = await _resolveModelPath();
    if (model == null) {
      _modelPath = null;
      _voicesDir = null;
      _clonedVoicesDir = null;
      _initialized = false;
      _blockingReason = 'Chưa import model VieNeu-TTS (.gguf)';
      return false;
    }
    await _rememberPaths(model);
    // Bản cũ cache `_modelResolved = true` ngay cả khi lib native thiếu,
    // rồi lần gọi SAU trả true ⇒ trạng thái engine/model không nhất quán.
    return VieneuTtsCore.isNativeLibraryAvailable();
  }

  Future<Map<String, String>> _readManifest(Directory voicesDir) async {
    final manifest = File(p.join(voicesDir.path, 'manifest.json'));
    if (!await manifest.exists()) return <String, String>{};
    try {
      return parseVieneuVoiceNames(await manifest.readAsString());
    } catch (_) {
      return <String, String>{};
    }
  }

  Future<void> _scanVoiceDirectory(
    Directory parent,
    Map<String, _VoiceFiles> index,
    Map<String, String> names, {
    required String origin,
  }) async {
    if (!await parent.exists()) return;
    await for (final entity in parent.list()) {
      if (entity is! Directory) continue;
      final voiceId = p.basename(entity.path);
      if (voiceId.startsWith('_') ||
          voiceId == vieneuTempSamplesDirName ||
          index.containsKey(voiceId)) {
        continue;
      }
      // Một nguồn sự thật cho "thư mục này có dữ liệu giọng không": nhận theo
      // tên chuẩn (ref_codes.txt/.bin, speaker.emb.txt) RỒI theo nội dung.
      // Mirror cộng đồng đặt tên file khác gói gốc (codes.txt, embedding.txt…)
      // ⇒ trước đây import báo thành công nhưng giọng KHÔNG hiện trong danh
      // sách; nay nhận ra bằng nội dung và truyền thẳng đường dẫn xuống native
      // (audio.cpp không quan tâm tên file).
      final resolved = await resolveVieneuVoiceFiles(entity);
      if (!resolved.usable) continue;
      if (resolved.resolvedByContent) {
        debugPrint('ℹ️ VieNeu: giọng "$voiceId" nhận theo nội dung '
            '(ref=${resolved.refCodesPath == null ? '-' : p.basename(resolved.refCodesPath!)}, '
            'emb=${resolved.speakerEmbeddingPath == null ? '-' : p.basename(resolved.speakerEmbeddingPath!)})');
      }
      index[voiceId] = _VoiceFiles(
        id: voiceId,
        name: names[voiceId] ?? voiceId.replaceAll('_', ' '),
        origin: origin,
        refCodesPath: resolved.refCodesPath ?? '',
        speakerEmbeddingPath: resolved.speakerEmbeddingPath,
        samplePath: resolved.samplePath,
      );
    }
  }

  /// Giọng preset (voices/) + giọng đã clone (cloned_voices/).
  ///
  /// KHÔNG gọi `_core.init()` ở đây: Settings chỉ cần đọc đĩa, không nạp
  /// model 170 MB (nguyên nhân văng app / timeout khi mở cài đặt — PSRC-187).
  /// Placeholder `ref_codes.txt` chỉ chứa comment bị bỏ qua (PSRC-186/187).
  @override
  Future<List<TtsVoice>> getAvailableVoices(String language) async {
    if (!language.startsWith('vi')) return <TtsVoice>[];
    final root = await _voicesRoot();
    final voicesDir = Directory(p.join(root, 'voices'));
    final clonedDir = Directory(p.join(root, 'cloned_voices'));
    final index = <String, _VoiceFiles>{};

    await _scanVoiceDirectory(
      voicesDir,
      index,
      await _readManifest(voicesDir),
      origin: 'preset',
    );
    await _scanVoiceDirectory(
      clonedDir,
      index,
      const <String, String>{},
      origin: 'cloned',
    );

    // Chưa có giọng nào (chỉ import .gguf): vẫn hiện giọng mặc định embed
    // trong GGUF. audio.cpp nhận refCodes=nullptr và dùng giọng của model.
    if (index.isEmpty) {
      index[VieneuTtsCore.defaultVoiceId] = _VoiceFiles(
        id: VieneuTtsCore.defaultVoiceId,
        name: VieneuTtsCore.defaultVoiceId.replaceAll('_', ' '),
        origin: 'default',
        refCodesPath: '',
        speakerEmbeddingPath: null,
      );
    }

    _voiceIndex
      ..clear()
      ..addAll(index);
    final sorted = index.values.toList()
      ..sort((a, b) {
        final aDefault = a.id == VieneuTtsCore.defaultVoiceId ? 0 : 1;
        final bDefault = b.id == VieneuTtsCore.defaultVoiceId ? 0 : 1;
        return aDefault.compareTo(bDefault);
      });
    return sorted
        .map((v) => TtsVoice(
              id: v.id,
              name: v.name,
              language: 'vi-VN',
              gender: 'unknown',
              engine: id,
              isNeural: true,
              origin: v.origin,
            ))
        .toList();
  }

  /// Ảnh chụp đĩa để trả lời "tôi đã import giọng mà sao không thấy".
  ///
  /// Chỉ đọc đĩa (không nạp model): gốc thư mục, file model, `sea_g2p.bin`, và
  /// từng thư mục giọng kèm lý do dùng được/không. UI hiện nguyên văn — nhờ
  /// vậy người dùng không phải đoán, còn agent thì có dữ liệu thật thay vì
  /// phải hỏi lại.
  Future<VieneuVoicesDiagnostics> diagnoseVoices() async {
    final root = await _voicesRoot();
    final presetDir = Directory(p.join(root, 'voices'));
    final clonedDir = Directory(p.join(root, 'cloned_voices'));
    return VieneuVoicesDiagnostics(
      root: root,
      modelPath: _modelPath,
      hasPhonemeDictionary: _dictionaryExistsIn(root),
      preset: await diagnoseVieneuVoiceFolders(presetDir),
      cloned: await diagnoseVieneuVoiceFolders(clonedDir),
      presetsDirExists: await presetDir.exists(),
    );
  }

  /// Giọng lấy từ manifest nhưng KHÔNG có thư mục dữ liệu — thường là dấu
  /// hiệu người dùng chỉ copy `voices/manifest.json` mà bỏ quên thư mục con.
  Future<List<String>> manifestOnlyVoiceIds() async {
    final root = await _voicesRoot();
    final voicesDir = Directory(p.join(root, 'voices'));
    final names = await _readManifest(voicesDir);
    if (names.isEmpty) return const <String>[];
    final index = <String, _VoiceFiles>{};
    await _scanVoiceDirectory(voicesDir, index, names, origin: 'preset');
    return names.keys.where((id) => !index.containsKey(id)).toList();
  }

  /// Khởi tạo worker (nạp model vào native isolate). Gọi từ TtsService trước
  /// lần synthesize đầu tiên; thất bại thì engine remains unavailable và
  /// TtsService fallback bình thường.
  Future<void> init({String? voiceId, VieneuModelVariant? modelVariant}) {
    final requestedVariant = modelVariant ?? _modelVariant;
    final requestedVoice =
        voiceId ?? _selectedVoiceId ?? VieneuTtsCore.defaultVoiceId;
    final inFlight = _initFuture;
    if (inFlight != null) {
      return inFlight.catchError((_) {}).then((_) => init(
            voiceId: requestedVoice,
            modelVariant: requestedVariant,
          ));
    }
    final future = _initOnce(
      voiceId: requestedVoice,
      modelVariant: requestedVariant,
    );
    _initFuture = future;
    future.whenComplete(() {
      if (identical(_initFuture, future)) _initFuture = null;
    });
    return future;
  }

  Future<void> _initOnce({
    required String voiceId,
    required VieneuModelVariant modelVariant,
  }) async {
    final changedVariant = modelVariant != _modelVariant;
    _modelVariant = modelVariant;
    if (changedVariant) {
      _modelPath = null;
      _voicesDir = null;
      _clonedVoicesDir = null;
      _initialized = false;
      _workerVoiceId = null;
    }
    _lastInitError = null;
    final model = await VieneuTtsCore.modelPathFor(modelVariant);
    if (model == null) {
      _initialized = false;
      _workerVoiceId = null;
      // PSRC-216: MỌI nhánh thoát phải để lại lý do. Trước 1.29 nhánh này
      // `return` im lặng ⇒ UI hiện lý do CŨ (hoặc câu chung vô nghĩa).
      _blockingReason =
          vieneuEngineBlockerMessage(VieneuEngineBlocker.noModel);
      if (_core.isInitialized) await _core.dispose();
      return;
    }
    await _rememberPaths(model);

    // PSRC-187 (audit 1.27.0): bản cài KHÔNG có thư viện native thì dừng ở
    // đây — không quét thư mục giọng và không gọi `_core.init` ở mỗi câu đọc;
    // `TtsService` chuyển sang engine kế tiếp. (`VieneuTtsCore.init` cũng tự
    // chặn trước khi spawn worker; kết quả dò thư viện được nhớ nên phép hỏi
    // này không tốn gì.)
    if (!await VieneuTtsCore.isNativeLibraryAvailable()) {
      _initialized = false;
      _workerVoiceId = null;
      _blockingReason = vieneuEngineBlockerMessage(
          VieneuEngineBlocker.noNativeLibrary);
      return;
    }

    // PSRC-216: file model có THẬT SỰ dùng được không (đuôi, dung lượng, chữ
    // ký GGUF)? Trước 1.29 bước này không tồn tại ⇒ người dùng import một file
    // hỏng/tải hụt, engine trả về lỗi native khó hiểu ở tận audio.cpp. Kiểm ở
    // đây rẻ (đọc 4 byte) và nói được đúng việc cần làm.
    final modelReport = await inspectVieneuModelOnDisk(model);
    if (!modelReport.ok) {
      _initialized = false;
      _workerVoiceId = null;
      _blockingReason =
          vieneuModelFileProblemMessage(modelReport.problem!);
      debugPrint('⚠️ VieNeu-TTS: model không dùng được '
          '(${modelReport.problem!.name}, ${modelReport.bytes} byte): $model');
      if (_core.isInitialized) await _core.dispose();
      return;
    }

    // Lane L6 / ADR-0028: thiếu `sea_g2p.bin` thì model KHÔNG đọc được câu
    // nào (audio.cpp ném lỗi ở bước nạp, sau khi đã cấp ~170 MB). Chặn trước
    // và ghi lý do để UI/TtsService nói đúng sự thật.
    if (!await hasPhonemeDictionary()) {
      _initialized = false;
      _workerVoiceId = null;
      _blockingReason =
          vieneuEngineBlockerMessage(VieneuEngineBlocker.noPhonemeDictionary);
      debugPrint('⚠️ VieNeu-TTS: thiếu ${vieneuG2pDictFileName} cạnh model');
      if (_core.isInitialized) await _core.dispose();
      return;
    }

    // Bản đồ giọng phải được quét TRƯỚC khi init để worker nhận đúng
    // ref_codes/speaker.emb của giọng mẫu hoặc giọng clone.
    await getAvailableVoices('vi-VN');
    final files = _voiceIndex[voiceId];

    try {
      await _core.init(
        modelPath: model,
        voiceId: voiceId,
        refCodesFile: (files?.refCodesPath.isNotEmpty ?? false)
            ? files!.refCodesPath
            : null,
        speakerEmbeddingFile: files?.speakerEmbeddingPath,
        clonedVoicesDir: _clonedVoicesDir,
      );
      _initialized = _core.isInitialized;
      if (_initialized) {
        _blockingReason = null;
        _lastInitError = null;
        _selectedVoiceId = voiceId;
        // Worker có thể đã init từ trước với giọng khác ⇒ áp lại giọng đang
        // chọn, tránh "UI chọn giọng A nhưng native đọc giọng B".
        await selectVoice(voiceId);
      } else {
        // Native trả "ok" nhưng worker vẫn chưa sẵn sàng — hiếm, nhưng im
        // lặng ở đây là đúng kiểu "khởi tạo không được mà không nói vì sao".
        _blockingReason =
            vieneuEngineBlockerMessage(VieneuEngineBlocker.engineLoadFailed);
      }
    } catch (e) {
      // PSRC-216: giữ NGUYÊN VĂN lỗi native để UI/log nói đúng việc cần làm
      // thay vì câu chung "kiểm tra file gguf và thư viện native".
      //
      // PSRC-171: lỗi nạp model phải được PHÂN LOẠI. Trước đây nhánh này để
      // `_blockingReason = null` ⇒ UI rơi về câu chung "Không thể tạo giọng.
      // Hãy kiểm tra mô hình TTS và mẫu thu âm", đổ lỗi cả cho mẫu thu âm
      // trong khi nguyên nhân thật là thiếu model spec của engine.
      debugPrint('⚠️ VieNeu-TTS init error: $e');
      _initialized = false;
      _workerVoiceId = null;
      _lastInitError = e.toString();
      if (e is VieneuEngineNotReadyException) {
        _blockingReason = e.message;
      } else {
        final blocker = classifyVieneuNativeLoadError(_lastInitError!);
        _blockingReason = vieneuEngineBlockerMessage(blocker);
      }
    }
  }

  /// Mã hoá MẪU WAV của một giọng thành `ref_codes.txt` (một lần duy nhất).
  ///
  /// Gói giọng của upstream (và các mirror) đóng gói `<Tên>.pt` + `<Tên>.txt`
  /// + `<Tên>.wav`. Ba file đó **không** phải `ref_codes.txt`, nên trước đây
  /// thư mục bị coi là rỗng và giọng không hiện. Nay: nếu giọng chỉ có mẫu,
  /// engine dùng CHÍNH đường `encode_reference_only` của tính năng tạo giọng
  /// (native đã có) để sinh mã ngay tại `<thư mục giọng>/ref_codes.txt`, rồi
  /// dùng như một giọng bình thường (lần sau không phải mã hoá lại).
  Future<_VoiceFiles?> _materializeSample(_VoiceFiles? files) async {
    if (files == null) return files;
    if (files.refCodesPath.isNotEmpty) return files;
    final sample = files.samplePath;
    if (sample == null) return files;
    if (!_core.isInitialized) return files;
    final voiceDir = p.dirname(sample);
    final tempDir = Directory(p.join(voiceDir, '_encode_sample'));
    try {
      await tempDir.create(recursive: true);
      await File(sample).copy(p.join(tempDir.path, p.basename(sample)));
      final out = await _core.cloneVoice(
        voiceId: files.id,
        samplesDir: tempDir.path,
      );
      final resolved = _voiceIndex[files.id];
      if (resolved != null) _voiceIndex[files.id] = resolved.withRefCodes(out);
      debugPrint('✅ VieNeu: đã mã hoá mẫu của giọng "${files.id}" → $out');
      return _voiceIndex[files.id] ?? files.withRefCodes(out);
    } catch (e) {
      // Không chặn giọng khác: giọng này sẽ báo lỗi đúng lúc đọc.
      debugPrint('⚠️ VieNeu: không mã hoá được mẫu của giọng "${files.id}": $e');
      return files;
    } finally {
      try {
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  }

  /// Đổi giọng đọc. Truyền đường dẫn file tuyệt đối đã quét được, kể cả
  /// giọng nằm ở `cloned_voices/` (PSRC-184/186).
  Future<void> selectVoice(String voiceId) async {
    _selectedVoiceId = voiceId;
    // Chọn giọng khi worker chưa nạp model là hợp lệ (Settings mở trước khi
    // phát). Lưu lựa chọn; `_initOnce` sẽ áp nó ngay sau khi worker sẵn sàng.
    if (!_core.isInitialized) return;
    final root = await _voicesRoot();
    if (_voiceIndex.isEmpty) await getAvailableVoices('vi-VN');
    final files = await _materializeSample(_voiceIndex[voiceId]);
    try {
      await _core.selectVoice(
        voiceId,
        p.join(root, 'voices'),
        clonedVoicesDir: p.join(root, 'cloned_voices'),
        refCodesFile: (files?.refCodesPath.isNotEmpty ?? false)
            ? files!.refCodesPath
            : null,
        speakerEmbeddingFile: files?.speakerEmbeddingPath,
      );
      _selectedVoiceId = voiceId;
      _workerVoiceId = voiceId;
    } catch (e) {
      debugPrint('⚠️ VieNeu-TTS selectVoice error: $e');
      _workerVoiceId = null;
      rethrow;
    }
  }

  @override
  Future<TtsResult> synthesize({
    required String text,
    required String language,
    double speed = 1.0,
    double pitch = 1.0,
    String? voiceId,
  }) async {
    // Chỉ đọc tiếng Việt — guard phòng hộ cho read mode đa ngôn ngữ
    // (Tipiṭaka: Pali = 'hi', Anh = 'en' đọc bằng engine khác).
    if (!language.startsWith('vi')) {
      return TtsResult.failure(
        error: 'VieNeu-TTS chỉ hỗ trợ tiếng Việt ($language)',
        engine: name,
      );
    }

    await init(voiceId: voiceId ?? _selectedVoiceId, modelVariant: _modelVariant);
    if (!_initialized) {
      return TtsResult.failure(
        error: _blockingReason ??
            'VieNeu-TTS chưa sẵn sàng (chưa import model .gguf)',
        engine: name,
      );
    }

    try {
      final desiredVoice =
          voiceId ?? _selectedVoiceId ?? VieneuTtsCore.defaultVoiceId;
      if (desiredVoice != _workerVoiceId) {
        await selectVoice(desiredVoice);
      }
      final result = await _core.synthesize(
        text: text,
        language: language,
        speed: speed,
        pitch: pitch,
        voiceId: desiredVoice,
      );
      if (result == null) {
        return TtsResult.failure(
          error: 'VieNeu-TTS không tổng hợp được âm thanh',
          engine: name,
        );
      }
      return TtsResult.successBytes(data: result.wavBytes, engine: name);
    } catch (e) {
      debugPrint('⚠️ VieNeu-TTS synthesize error: $e');
      return TtsResult.failure(error: 'VieNeu-TTS lỗi: $e', engine: name);
    }
  }

  /// Sau khi import/đổi model: dọn worker cũ để lần phát tới nạp ĐÚNG file
  /// vừa import (PSRC-183). Không gọi init ở đây — tránh nạp 170 MB ngay
  /// trong lúc người dùng còn đang ở màn cài đặt.
  Future<void> invalidate() async {
    await _core.dispose();
    _initialized = false;
    _blockingReason = null;
    _lastInitError = null;
    _workerVoiceId = null;
    _modelPath = null;
    _voicesDir = null;
    _clonedVoicesDir = null;
    _voiceIndex.clear();
  }

  void dispose() {
    _core.dispose();
    _initialized = false;
    _workerVoiceId = null;
  }
}
