// lib/screens/settings/stt_model_settings_screen.dart

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart' as fp; // cho FilePicker
// FIX nghiệm thu 251e (2026-08-25): bỏ import googleapis/analytics (auto-import
// nhầm — file không dùng symbol nào của googleapis) + material trực tiếp.
// localized_material đã export material (hide Text) + Text localized.
import 'package:in4up/core/language/localized_material.dart';
import 'package:provider/provider.dart';
import 'package:in4up/providers/locale_provider.dart';
import 'package:in4up_ai/in4up_ai.dart';
import 'package:in4up_stt/sherpa_model_manager.dart';
import 'package:in4up_stt/stt_model_manager.dart';
import 'package:in4up_stt/stt_service_facade.dart' as modelManager;
import 'package:in4up_stt/in4up_stt.dart';
import 'package:in4up_stt/tts/sherpa_piper_tts_core.dart';

import '../../features/tts/piper_voice_prefs.dart';
import '../../features/tts/tts_service.dart';

import '../../core/language/app_language.dart';

class SttModelSettingsScreen extends StatelessWidget {
  const SttModelSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ FIX: Không dùng subtitle, dùng Column trong title
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quản lý Model AI',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'STT · VAD · TTS offline — models 1 chỗ, tinh chỉnh ở tab chức năng',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _LanguageSettingCard(),
          const SizedBox(height: 16),
          _SourceInfoCard(),
          const SizedBox(height: 16),
          const _SectionLabel('1. STT — Whisper (bóc băng audio thành chữ)'),
          ...WhisperModelLevel.values.map(
            (level) => _ModelCard(level: level),
          ),
          const SizedBox(height: 16),
          const _SectionLabel(
              '2. VAD — Silero (loại khoảng lặng, tạo lời file dài nhanh)'),
          const _SileroVadCard(),
          const SizedBox(height: 16),
          const _SectionLabel(
              '3. TTS — Piper (đọc chữ offline, giọng neural — cabin)'),
          const _PiperModelCard(),
          const SizedBox(height: 16),
          const _SectionLabel(
              '4. Chat — Gemma (LLM trả lời cho AI Chat — file .gguf)'),
          const _GemmaChatModelCard(),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }
}

class _SourceInfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.teal.shade900.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.cloud_download, color: Colors.teal),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tải khi bạn bấm — không tự tải lúc mở app',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Bấm Tải về để lấy model từ mạng (HuggingFace, rồi GitHub). '
                    'App không tự tải khi khởi động — tránh lỗi Connection closed '
                    'trên tablet. Import file .bin nếu bạn đã có sẵn.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelCard extends StatelessWidget {
  final WhisperModelLevel level;
  const _ModelCard({required this.level});

  @override
  Widget build(BuildContext context) {
    final manager = SttModelManager();

    return StreamBuilder<SttModelInfo>(
      stream: manager.watchModel(level),
      initialData: manager.getModelInfo(level),
      builder: (context, snapshot) {
        final info = snapshot.data!;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────────
                Row(
                  children: [
                    _StatusIcon(status: info.status),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Whisper ${level.name.toUpperCase()}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            level.description,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    _StatusBadge(status: info.status),
                  ],
                ),

                const SizedBox(height: 12),

                // ── Progress (chỉ hiện khi tải) ─────────────────────
                if (info.isDownloading) ...[
                  LinearProgressIndicator(
                    value: info.downloadProgress,
                    backgroundColor: Colors.grey.shade800,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(info.downloadProgress * 100).toStringAsFixed(1)}% '
                    '· ${(info.downloadProgress * level.sizeInMB).toStringAsFixed(0)}'
                    '/${level.sizeInMB}MB',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                ],

                // ── Error message ────────────────────────────────────
                if (info.errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade900.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      info.errorMessage!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // ── Action buttons ───────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (info.isDownloading) ...[
                      // Nút Huỷ download
                      TextButton.icon(
                        icon: const Icon(Icons.cancel, size: 16),
                        label: const Text('Huỷ'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        onPressed: () => manager.cancelDownload(level),
                      ),
                    ] else if (info.isReady) ...[
                      TextButton.icon(
                        icon: const Icon(Icons.folder_open, size: 16),
                        label: const Text('Import'),
                        onPressed: () =>
                            _importModel(context, manager, level),
                      ),
                      // Nút Xoá
                      TextButton.icon(
                        icon: const Icon(Icons.delete, size: 16),
                        label: Text(context.uiText('Xoá (${level.sizeInMB}MB)')),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        onPressed: () =>
                            _confirmDelete(context, manager, level),
                      ),
                    ] else ...[
                      TextButton.icon(
                        icon: const Icon(Icons.folder_open, size: 16),
                        label: const Text('Import'),
                        onPressed: () =>
                            _importModel(context, manager, level),
                      ),
                      // Size label + Nút Tải
                      Text(
                        '${level.sizeInMB}MB',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Tải về'),
                        onPressed: () =>
                            _handleDownload(context, manager, level),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleDownload(
    BuildContext context,
    SttModelManager manager,
    WhisperModelLevel level,
  ) async {
    if (level.sizeInMB >= 100) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Tải Whisper ${level.name.toUpperCase()}?'),
          content: Text(
            'Dung lượng khoảng ${level.sizeInMB}MB.\n\n'
            'Nên dùng Wi-Fi và giữ app mở trong lúc tải. '
            'Nếu mạng đứt, bấm Tải về lại — app thử HuggingFace rồi GitHub.\n\n'
            'Hoặc Import nếu bạn đã có file ${level.fileName}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Huỷ'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Tải về'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    manager.downloadModel(level);
  }

  Future<void> _importModel(
    BuildContext context,
    SttModelManager manager,
    WhisperModelLevel level,
  ) async {
    final result = await fp.FilePicker.pickFiles(
      type: fp.FileType.custom,
      allowedExtensions: ['bin'],
    );

    final filePath = result?.files.single.path;
    if (filePath == null || filePath.isEmpty) return;
    if (!context.mounted) return;

    final success = await manager.importModelFromPath(
      filePath,
      level: level,
    );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.uiText(success
              ? '✅ Import ${level.name.toUpperCase()} thành công!'
              : '❌ Import thất bại — sai file hoặc file bị lỗi'),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    SttModelManager manager,
    WhisperModelLevel level,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.uiText('Xoá model ${level.name.toUpperCase()}?')),
        content: Text(
          context.uiText('Sẽ giải phóng ${level.sizeInMB}MB. Bạn cần tải lại để dùng tính năng này.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (confirm == true) manager.deleteModel(level);
  }
}

// ── Helper Widgets ────────────────────────────────────────────────────────────

class _StatusIcon extends StatelessWidget {
  final ModelStatus status;
  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      ModelStatus.downloaded => const Icon(
          Icons.check_circle,
          color: Colors.green,
        ),
      ModelStatus.downloading => const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ModelStatus.corrupted => const Icon(
          Icons.warning,
          color: Colors.orange,
        ),
      ModelStatus.insufficientSpace => const Icon(
          Icons.storage,
          color: Colors.red,
        ),
      _ => const Icon(
          Icons.cloud_download_outlined,
          color: Colors.grey,
        ),
    };
  }
}

class _StatusBadge extends StatelessWidget {
  final ModelStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ModelStatus.downloaded => ('Sẵn sàng', Colors.green),
      ModelStatus.downloading => ('Đang tải', Colors.blue),
      ModelStatus.corrupted => ('Lỗi file', Colors.orange),
      ModelStatus.insufficientSpace => ('Hết bộ nhớ', Colors.red),
      _ => ('Chưa tải', Colors.grey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11),
      ),
    );
  }
}

class _LanguageSettingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final localeProvider = context.watch<LocaleProvider>();
    final currentLocale = localeProvider.locale;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.language, color: Colors.teal),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Ngôn ngữ ứng dụng',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            DropdownButton<String>(
              value: currentLocale == null
                  ? 'system'
                  : '${currentLocale.languageCode}${currentLocale.countryCode == null ? '' : '_${currentLocale.countryCode}'}',
              underline: const SizedBox(),
              items: [
                const DropdownMenuItem(
                  value: 'system',
                  child: Text('🌐 Hệ thống'),
                ),
                ...AppLanguageCatalog.languages.map(
                  (language) => DropdownMenuItem(
                    value: language.appLocaleCode,
                    child: Text(
                      '${language.flag} ${language.nativeName} '
                      '(${language.englishName})',
                    ),
                  ),
                ),
              ],
              selectedItemBuilder: (_) => [
                const Text('🌐 Auto'),
                ...AppLanguageCatalog.languages.map(
                  (language) => Text(
                    '${language.flag} ${language.translationCode}',
                  ),
                ),
              ],
              onChanged: (value) {
                if (value == null || value == 'system') {
                  localeProvider.setLocale(null);
                } else {
                  final parts = value.split('_');
                  if (parts.length == 2) {
                    localeProvider.setLocale(Locale(parts[0], parts[1]));
                  } else {
                    localeProvider.setLocale(Locale(parts[0]));
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SILERO VAD CARD — model detect khoảng lặng (tạo lời file dài nhanh)
// ═══════════════════════════════════════════════════════════════════════════

class _SileroVadCard extends StatefulWidget {
  const _SileroVadCard();

  @override
  State<_SileroVadCard> createState() => _SileroVadCardState();
}

class _SileroVadCardState extends State<_SileroVadCard> {
  final _manager = SherpaModelManager();

  @override
  void initState() {
    super.initState();
    _manager.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SherpaModelInfo>(
      stream: _manager.watchVad(),
      initialData: _manager.vadInfo,
      builder: (context, snapshot) {
        final info = snapshot.data!;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.hearing, color: Colors.teal),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Silero VAD (Silero Voice Activity)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Loại bỏ khoảng lặng — tạo lời file 30p chỉ vài phút, không đơ UI',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    _VadBadge(ready: info.isReady),
                  ],
                ),
                const SizedBox(height: 8),

                if (info.isDownloading) ...[
                  LinearProgressIndicator(
                    value: info.downloadProgress,
                    backgroundColor: Colors.grey.shade800,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(info.downloadProgress * 100).toStringAsFixed(1)}% · ~629KB',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                ],

                if (info.errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade900.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      info.errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (info.isDownloading)
                      TextButton.icon(
                        icon: const Icon(Icons.cancel, size: 16),
                        label: const Text('Huỷ'),
                        style:
                            TextButton.styleFrom(foregroundColor: Colors.red),
                        onPressed: _manager.cancelVadDownload,
                      )
                    else ...[
                      TextButton.icon(
                        icon: const Icon(Icons.folder_open, size: 16),
                        label: const Text('Import'),
                        onPressed: () => _importVad(context),
                      ),
                      if (info.isReady)
                        TextButton.icon(
                          icon: const Icon(Icons.delete, size: 16),
                          label: const Text('Xoá'),
                          style: TextButton.styleFrom(
                              foregroundColor: Colors.red),
                          onPressed: () => _manager.deleteVad(),
                        ),
                      const Text('~0.6MB',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Tải về'),
                        onPressed: info.isReady
                            ? null
                            : () => _manager.downloadVad(),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _importVad(BuildContext context) async {
    final result = await fp.FilePicker.pickFiles(
      type: fp.FileType.custom,
      allowedExtensions: ['onnx'],
    );
    final path = result?.files.single.path;
    if (path == null || path.isEmpty) return;
    final ok = await _manager.importVadFromPath(path);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? '✅ Import Silero VAD thành công!'
            : '❌ Import thất bại — cần silero_vad.onnx (k2-fsa ~629KB)'),
      ),
    );
  }
}

class _VadBadge extends StatelessWidget {
  final bool ready;
  const _VadBadge({required this.ready});

  @override
  Widget build(BuildContext context) {
    final (label, color) =
        ready ? ('Sẵn sàng', Colors.green) : ('Chưa cài', Colors.grey);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11)),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PIPER TTS CARD — giọng neural offline (cabin dịch, đọc chữ không cần mạng)
// ═══════════════════════════════════════════════════════════════════════════

class _PiperModelCard extends StatefulWidget {
  const _PiperModelCard();

  @override
  State<_PiperModelCard> createState() => _PiperModelCardState();
}

class _PiperModelCardState extends State<_PiperModelCard> {
  final _manager = SherpaModelManager();

  @override
  void initState() {
    super.initState();
    _manager.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SherpaPiperInfo>(
      stream: _manager.watchPiper(),
      initialData: _manager.piperInfo,
      builder: (context, snapshot) {
        final info = snapshot.data!;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.record_voice_over, color: Colors.teal),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Piper TTS (offline neural)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Đọc chữ offline không cần mạng — giọng neural tự nhiên',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    _PiperBadge(info: info),
                  ],
                ),

                // Trạng thái espeak-ng-data (bắt buộc cho mọi giọng)
                const SizedBox(height: 8),
                _EspeakRow(
                  installed: info.espeakInstalled,
                  onDownload: info.espeakInstalled || info.isDownloading
                      ? null
                      : () => _downloadEspeak(context),
                ),

                // Danh sách giọng đã cài
                if (info.voices.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...info.voices.map((v) => _PiperVoiceRow(
                        voice: v,
                        onDelete: () => _manager.deletePiperVoice(v.name),
                        onSelect: () async {
                          final lang = SherpaPiperTtsCore.langFromVoiceName(
                              v.name);
                          await PiperVoicePrefs.instance
                              .setVoiceForLang(lang, v.name);
                          TtsService().configure(voiceId: v.name);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                context.uiText(
                                  'Đã chọn ${v.name} cho ${lang.isEmpty ? 'mặc định' : lang}',
                                ),
                              ),
                            ),
                          );
                        },
                      )),
                ],

                const SizedBox(height: 8),

                if (info.isDownloading) ...[
                  LinearProgressIndicator(
                    value: info.downloadProgress,
                    backgroundColor: Colors.grey.shade800,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Đang tải bundle Piper… ${(info.downloadProgress * 100).toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                ],

                if (info.errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade900.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      info.errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // Hướng dẫn khi chưa có gì
                if (info.voices.isEmpty && !info.isDownloading)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade900.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.amber.shade900.withValues(alpha: 0.6),
                      ),
                    ),
                    child: const Text(
                      'Chưa có giọng Piper. Bấm "Tải giọng" — app tự tải, '
                      'giải nén và cài. Không cần ZArchiver.',
                      style: TextStyle(fontSize: 12, color: Colors.amberAccent),
                    ),
                  ),

                const SizedBox(height: 8),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (info.isDownloading)
                      TextButton.icon(
                        icon: const Icon(Icons.cancel, size: 16),
                        label: const Text('Huỷ'),
                        style:
                            TextButton.styleFrom(foregroundColor: Colors.red),
                        onPressed: _manager.cancelPiperDownload,
                      )
                    else ...[
                      TextButton.icon(
                        icon: const Icon(Icons.folder_open, size: 16),
                        label: const Text('Import thư mục'),
                        onPressed: () => _importFolder(context),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.insert_drive_file, size: 16),
                        label: const Text('Import file'),
                        onPressed: () => _importFiles(context),
                      ),
                      if (info.voices.isNotEmpty)
                        TextButton.icon(
                          icon: const Icon(Icons.delete_sweep, size: 16),
                          label: const Text('Xoá hết'),
                          style: TextButton.styleFrom(
                              foregroundColor: Colors.red),
                          onPressed: () => _confirmDeleteAll(context),
                        ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Tải giọng'),
                        onPressed: () => _downloadPiperBundle(context),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _importFolder(BuildContext context) async {
    final path = await fp.FilePicker.getDirectoryPath();
    if (path == null || path.isEmpty) return;
    final msg = await _manager.importPiperFolder(path);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _importFiles(BuildContext context) async {
    final result = await fp.FilePicker.pickFiles(
      type: fp.FileType.custom,
      allowedExtensions: ['onnx', 'json', 'txt'],
      allowMultiple: true,
    );
    final paths = result?.files.map((f) => f.path).whereType<String>().toList() ??
        [];
    if (paths.isEmpty) return;
    final msg = await _manager.importPiperFiles(paths);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _downloadPiperBundle(BuildContext context) async {
    const en = SherpaModelManager.defaultPiperVoice;
    const enLessac = 'en_US-lessac-medium';
    const vi = 'vi_VN-vais1000-medium';

    final voice = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Tải giọng Piper (~75MB, tự cài)'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, en),
            child: const Text('en_US-libritts_r-medium (Anh, nữ)'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, enLessac),
            child: const Text('en_US-lessac-medium (Anh, nữ)'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, vi),
            child: const Text('vi_VN-vais1000-medium (Việt, nữ)'),
          ),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'App tự tải, giải nén và cài. Giữ Wi-Fi, đợi thanh tiến độ xong '
              'là dùng được — không cần giải nén tay.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
    if (voice == null || !mounted) return;

    final installedDir = await _manager.downloadPiperBundle(voice: voice);
    if (!mounted) return;

    if (installedDir != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã cài giọng $voice — dùng được ngay.'),
        ),
      );
    }
  }

  Future<void> _confirmDeleteAll(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xoá toàn bộ model Piper?'),
        content: const Text(
            'Sẽ xoá mọi giọng + espeak-ng-data. Cần tải lại để dùng TTS offline.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xoá hết'),
          ),
        ],
      ),
    );
    if (confirm == true) _manager.deletePiperAll();
  }
}

class _PiperBadge extends StatelessWidget {
  final SherpaPiperInfo info;
  const _PiperBadge({required this.info});

  @override
  Widget build(BuildContext context) {
    final ready = info.isReady;
    final (label, color) = ready
        ? ('${info.voices.length} giọng', Colors.green)
        : ('Chưa cài', Colors.grey);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11)),
    );
  }
}

class _EspeakRow extends StatelessWidget {
  final bool installed;
  final VoidCallback? onDownload;
  const _EspeakRow({required this.installed, this.onDownload});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          installed ? Icons.check_circle : Icons.error_outline,
          size: 16,
          color: installed ? Colors.green : Colors.orange,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            installed
                ? 'espeak-ng-data (phonemizer) — đã có'
                : 'espeak-ng-data — CHƯA có (bắt buộc, đi kèm trong bundle tải về)',
            style: TextStyle(
              fontSize: 12,
              color: installed ? Colors.green : Colors.orange,
            ),
          ),
        ),
        if (!installed && onDownload != null)
          TextButton(
            onPressed: onDownload,
            child: const Text('Tải phonemizer'),
          ),
      ],
    );
  }
}

class _PiperVoiceRow extends StatelessWidget {
  final PiperTtsVoice voice;
  final VoidCallback onDelete;
  final VoidCallback onSelect;
  const _PiperVoiceRow({
    required this.voice,
    required this.onDelete,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final lang = SherpaPiperTtsCore.langFromVoiceName(voice.name);
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Row(
        children: [
          const Icon(Icons.mic, size: 16, color: Colors.teal),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(voice.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  'language: ${lang.isEmpty ? 'auto' : lang} · '
                  '${voice.sampleRate}Hz',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onSelect,
            child: const Text('Dùng'),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

/// Model Gemma GGUF cho AI Chat (LLM offline).
/// Reuse AiServiceFacade + AiModelLoader (import .gguf / tải từ URL / xóa)
/// — cùng 1 nơi quản lý model với STT/VAD/TTS ở trên.
class _GemmaChatModelCard extends StatelessWidget {
  const _GemmaChatModelCard();

  @override
  Widget build(BuildContext context) {
    return Consumer<AiServiceFacade>(
      builder: (context, facade, _) {
        final hasModel = facade.hasModel;
        final name = facade.modelFileName ?? '';
        final sizeMb = facade.modelSizeBytes != null
            ? (facade.modelSizeBytes! / (1024 * 1024)).toStringAsFixed(0)
            : null;
        final busy = facade.isImportActive;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────────
                Row(
                  children: [
                    Icon(
                      hasModel
                          ? Icons.check_circle
                          : busy
                              ? Icons.sync
                              : Icons.cloud_off,
                      color: hasModel
                          ? Colors.green
                          : busy
                              ? Colors.blue
                              : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Gemma — AI Chat (LLM offline)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            hasModel
                                ? 'Model: $name${sizeMb != null ? ' · ${sizeMb}MB' : ''} · ${facade.modelSourceLabel}'
                                : 'Chưa có model — import file .gguf hoặc tải về (~1.5GB, Gemma-2B Q4)',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // ── Progress (import/download) ──────────────────────
                if (busy) ...[
                  LinearProgressIndicator(
                    value: facade.importStage == AiImportStage.loading
                        ? null
                        : facade.importProgress,
                    backgroundColor: Colors.grey.shade800,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    facade.importStage == AiImportStage.copying
                        ? 'Đang copy model… '
                            '${(facade.importProgress * 100).toStringAsFixed(0)}%'
                        : facade.importStage == AiImportStage.downloading
                            ? 'Đang tải model… '
                                '${(facade.importProgress * 100).toStringAsFixed(0)}%'
                            : 'Đang nạp model vào bộ nhớ — có thể mất 1–2 phút',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                ],

                // ── Error message ────────────────────────────────────
                if (facade.importStage == AiImportStage.failed &&
                    facade.importError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade900.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      facade.importError!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // ── Action buttons ──────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.folder_open, size: 16),
                      label: const Text('Import'),
                      onPressed: busy
                          ? null
                          : () => _importModel(context, facade),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      icon: const Icon(Icons.cloud_download, size: 16),
                      label: const Text('Tải về'),
                      onPressed: busy
                          ? null
                          : () => _showDownloadUrlDialog(context, facade),
                    ),
                    if (hasModel)
                      TextButton.icon(
                        icon: const Icon(Icons.delete, size: 16),
                        label: const Text('Xóa'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        onPressed: busy
                            ? null
                            : () => _confirmRemove(context, facade),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _importModel(
      BuildContext context, AiServiceFacade facade) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await facade.importModelFromUser();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'AI local đã sẵn sàng'
                  '${facade.modelFileName != null ? " — ${facade.modelFileName}" : ''}'
              : (facade.importError ?? 'Chưa import được model .gguf.'),
        ),
      ),
    );
  }

  Future<void> _showDownloadUrlDialog(
      BuildContext context, AiServiceFacade facade) async {
    final controller =
        TextEditingController(text: AiModelConfig.defaultDownloadUrl);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tải model Gemma từ URL'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'https://.../*.gguf',
            helperText:
                'Mặc định: Gemma-2-2B-it Q4_K_M từ HuggingFace (~1.5GB). Chỉ tải trên WiFi.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Huỷ'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Tải về'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (confirmed != true) return;

    final ok = await facade.downloadModel(controller.text);
    final modelNote =
        facade.modelFileName != null ? ' — ${facade.modelFileName}' : '';
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? context.uiText('Model đã tải và nạp xong') + modelNote
              : (facade.importError ?? 'Download thất bại'),
        ),
      ),
    );
  }

  Future<void> _confirmRemove(
      BuildContext context, AiServiceFacade facade) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xóa model Gemma?'),
        content: const Text(
            'File .gguf sẽ bị xóa khỏi thiết bị. AI Chat quay về chế độ mock.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Huỷ'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await facade.removeModel();
  }
}
