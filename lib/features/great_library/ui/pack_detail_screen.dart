// lib/features/great_library/ui/pack_detail_screen.dart
//
// GLIB-004 — Thư Viện Chung I4U (PLAN-049).
// Chi tiết pack: metadata đầy đủ (tác giả, trình độ, ngôn ngữ, giấy phép,
// version, dung lượng, lượt tải) + nút Tải về với progress + trạng thái đã tải.
// GLIB-005: sau khi tải xong → nút "Nhập vào Studio" (route theo loại pack qua
// PackImportService; web stub tắt → hiện ghi chú).

import 'package:flutter/material.dart';
import 'package:in4up/l10n/app_localizations.dart';

import '../great_library_controller.dart';
import '../models/gl_pack_entry.dart';
import '../models/pack_manifest.dart';
import '../services/pack_download_manager.dart';

class PackDetailScreen extends StatelessWidget {
  const PackDetailScreen({
    super.key,
    required this.entry,
    required this.controller,
  });

  final GlPackEntry entry;
  final GreatLibraryController controller;

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final manifest = entry.manifest;
    return Scaffold(
      // Tên pack = user content → nguyên gốc.
      appBar: AppBar(title: Text(manifest.title)),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final progress = controller.downloadStates[entry.packId];
          final downloaded = controller.downloadedIds.contains(entry.packId);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildMeta(context, manifest),
              const SizedBox(height: 16),
              if (manifest.description.isNotEmpty) ...[
                Text(manifest.description),
                const SizedBox(height: 16),
              ],
              if (manifest.tags.isNotEmpty) _buildTags(manifest),
              const SizedBox(height: 24),
              _buildDownloadArea(context, progress, downloaded),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMeta(BuildContext context, PackManifest manifest) {
    final rows = <String>[
      if (manifest.author.displayName.isNotEmpty)
        manifest.author.displayName +
          (manifest.author.verified ? ' ✓' : ''),
      '${manifest.srcLang} → ${manifest.dstLang} · ${manifest.level}',
      '${AppLocalizations.of(context)!.glLicenseLabel}: ${manifest.license?.wire ?? '-'}',
      'v${manifest.version} · ${_formatBytes(entry.fileBytes)} · '
          '${manifest.stats.downloads}↓',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(line),
          ),
      ],
    );
  }

  Widget _buildTags(PackManifest manifest) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final tag in manifest.tags)
          Chip(label: Text(tag), visualDensity: VisualDensity.compact),
      ],
    );
  }

  Widget _buildDownloadArea(
      BuildContext context, PackDownloadProgress? progress, bool downloaded) {
    final l10n = AppLocalizations.of(context)!;
    if (downloaded) {
      final importing = controller.importingIds.contains(entry.packId);
      final result = controller.importResults[entry.packId];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.green),
              const SizedBox(width: 8),
              Text(l10n.glDownloaded),
            ],
          ),
          if (controller.hasUpdate(entry)) ...[
            const SizedBox(height: 8),
            Chip(
              avatar: const Icon(Icons.system_update_alt_rounded, size: 18),
              label: Text(l10n.glUpdateAvailable),
              visualDensity: VisualDensity.compact,
            ),
          ],
          const SizedBox(height: 12),
          // GLIB-005: nhập pack vào Studio (vocab/audio/ảnh). Web stub tắt.
          if (controller.canImport) ...[
            FilledButton.icon(
              onPressed: importing
                  ? null
                  : () => controller.importDownloaded(entry.packId),
              icon: const Icon(Icons.input_rounded),
              label: Text(importing ? l10n.glImporting : l10n.glImport),
            ),
            if (result != null) ...[
              const SizedBox(height: 8),
              Text(
                result.isSuccess
                    ? l10n.glImportedCount(result.affected)
                    : l10n.glImportFailed,
              ),
            ],
          ] else ...[
            const SizedBox(height: 8),
            Text(l10n.glImportNextUpdate),
          ],
        ],
      );
    }
    final downloading = progress != null &&
        progress.state != PackDownloadState.completed &&
        progress.state != PackDownloadState.failed &&
        progress.state != PackDownloadState.canceled;
    if (downloading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(value: progress.fraction),
          const SizedBox(height: 8),
          Text(l10n.glDownloading),
        ],
      );
    }
    final canDownload = entry.manifest.storage != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilledButton.icon(
          onPressed: canDownload ? () => controller.download(entry) : null,
          icon: const Icon(Icons.download_rounded),
          label: Text(l10n.glDownload),
        ),
        if (progress != null && progress.state == PackDownloadState.failed)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(l10n.glDownloadFailed),
          ),
      ],
    );
  }
}
