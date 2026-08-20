// lib/screens/settings/stt_model_settings_screen.dart

import 'package:file_picker/file_picker.dart' as fp; // cho FilePicker
import 'package:flutter/foundation.dart'; // cho kDebugMode
import 'package:in4up/core/language/localized_material.dart';
import 'package:provider/provider.dart';
import 'package:in4up/providers/locale_provider.dart';
import 'package:in4up_stt/stt_model_manager.dart';
import 'package:in4up_stt/stt_service_facade.dart' as modelManager;
import 'package:in4up_stt/in4up_stt.dart';

import '../../core/language/app_language.dart';

class SttModelSettingsScreen extends StatelessWidget {
  const SttModelSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ FIX: Không dùng subtitle, dùng Column trong title
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quản lý Model AI',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Whisper Speech-to-Text',
              style: TextStyle(
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
          ...WhisperModelLevel.values.map(
            (level) => _ModelCard(level: level),
          ),
        ],
      ),
    );
  }
}

class _SourceInfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.orange.shade900.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.folder_special, color: Colors.orange),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Chế độ Local Only (Fix HttpException)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Auto-download từ HuggingFace đã TẮT theo Handover Rule 2 '
                    'để tránh Connection closed trên Android Tablet. '
                    'Hãy chép file .bin thủ công vào Documents/in4up_whisper_models/ '
                    'và đảm bảo size >1MB (Rule 3).',
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
                      // Nút Import (chỉ debug)
                      if (kDebugMode)
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
                      // Nút Import (chỉ debug)
                      if (kDebugMode)
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
    // Rule 2: Auto-download disabled — hướng dẫn chép thủ công
    await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Auto-download đã tắt (Fix HttpException)'),
        content: Text(
          'Theo handover SECTION 1 Rule 2, auto-download từ HuggingFace CDN đã bị '
          'tắt để tránh lỗi HttpException: Connection closed trên Android Tablet.\n\n'
          'Cách đúng:\n'
          '1. Dùng path_provider: getApplicationDocumentsDirectory()\n'
          '2. Chép file ${level.fileName} hoặc ggml-tiny-q4_0.bin vào:\n'
          '   Documents/in4up_whisper_models/\n'
          '3. Đảm bảo File.existsSync() && lengthSync() > 1_000_000\n'
          '4. App sẽ tự scan và dùng luôn, không tải lại.\n\n'
          'Nút Import bên dưới vẫn hoạt động để chọn file .bin từ bộ nhớ.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Đã hiểu'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, true);
              // Mở picker import thay vì download
              _importModel(context, manager, level);
            },
            child: const Text('Chọn file thủ công'),
          ),
        ],
      ),
    );
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
