// lib/screens/settings/stt_model_settings_screen.dart
// 2026-09-03: trigger CI root cho fix STT SIGSEGV crash 2 —
// ensurePluginModelFile align ggml-<level>.bin với model manager đã verify
// (packages/in4up_stt — ngoài paths của app_analyze.yml).

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart' as fp; // cho FilePicker
import 'package:path_provider/path_provider.dart';
// FIX nghiệm thu 251e (2026-08-25): bỏ import googleapis/analytics (auto-import
// nhầm — file không dùng symbol nào của googleapis) + material trực tiếp.
// localized_material đã export material (hide Text) + Text localized.
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:in4up/core/language/localized_material.dart';
import 'package:in4up/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:in4up/providers/locale_provider.dart';
import 'package:in4up_ai/in4up_ai.dart';
import 'package:in4up_stt/sherpa_model_manager.dart';
import 'package:in4up_stt/stt_model_manager.dart';
import 'package:in4up_stt/in4up_stt.dart';
import 'package:in4up_stt/tts/piper_voice_catalog.dart';
import 'package:in4up_stt/tts/sherpa_piper_tts_core.dart';

import '../../features/tts/piper_voice_prefs.dart';
import '../../features/tts/tts_service.dart';
import '../../features/screen_translate/screen_translate_card.dart';
import '../../features/translation/translation_toolbar.dart';
import '../../features/translation/translation_service.dart';

import '../../services/battery_optimization_service.dart';

import 'ai_providers_screen.dart';

import '../../core/language/app_language.dart';

class SttModelSettingsScreen extends StatelessWidget {
  const SttModelSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.uiText('Quản lý Model AI'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              context.uiText(
                'STT · VAD · TTS offline — models 1 chỗ, tinh chỉnh ở tab chức năng',
              ),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        // SETTINGS-UI-COMPACT-001: 2 ghi chú chỉ-để-đọc (tải khi bấm / pin)
        // không còn chiếm 2 thẻ lớn giữa danh sách — gom vào 1 sheet sau nút
        // "!" ở góc. Pin vẫn hiện icon trạng thái (cam = chưa cấp quyền).
        actions: const [
          _BatteryStatusAction(),
          _InfoSheetButton(),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _LanguageSettingCard(),
          const SizedBox(height: 8),
          // WP0 (API-001): entry tới màn Server & API (cloud / LAN) — tầng
          // API tuỳ chọn BYOK, tắt mặc định, offline-first giữ nguyên.
          Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.dns_outlined,
                  color: Colors.deepPurpleAccent),
              title: Text(
                  AppLocalizations.of(context).aiProvidersEntryTitle),
              subtitle: Text(
                  AppLocalizations.of(context).aiProvidersEntrySubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AiProvidersScreen()),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // ── 1. Whisper ─────────────────────────────────────────────────
          _SettingsSection(
            icon: Icons.graphic_eq_rounded,
            color: Colors.deepPurpleAccent,
            title: context.uiText('Whisper — bóc băng audio thành chữ'),
            subtitle: context.uiText(
              '2 dòng model: đa ngôn ngữ (99 ngôn ngữ) và English-only (.en)',
            ),
            initiallyExpanded: true,
            children: const [_WhisperSectionBody()],
          ),
          // ── 2. Parakeet ───────────────────────────────────────────────
          _SettingsSection(
            icon: Icons.bolt_rounded,
            color: Colors.amberAccent,
            title: context.uiText('Parakeet — 25 ngôn ngữ châu Âu'),
            subtitle: context.uiText(
              'TDT 0.6B v3 int8 · ~670MB · offline (không có tiếng Việt)',
            ),
            children: const [
              _SherpaAsrCard(profileIds: [kParakeetProfileId]),
            ],
          ),
          // ── 3. Zipformer (live STT) ────────────────────────────────────
          _SettingsSection(
            icon: Icons.sensors_rounded,
            color: Colors.tealAccent,
            title: context.uiText('Zipformer — nhận diện trực tiếp'),
            subtitle: context.uiText(
              'Tiếng Việt (offline + VAD) · English (streaming)',
            ),
            children: const [
              _SherpaAsrCard(profileIds: [
                'asr-vi-30M-int8',
                'asr-en-20M-streaming-int8',
              ]),
            ],
          ),
          // ── 4. VAD ─────────────────────────────────────────────────────
          _SettingsSection(
            icon: Icons.hearing_rounded,
            color: Colors.lightGreenAccent,
            title: context.uiText('Silero VAD — lọc khoảng lặng'),
            subtitle: context.uiText('Tạo lời file dài nhanh, không đơ UI'),
            children: const [_SileroVadCard()],
          ),
          // ── 5. Piper TTS ───────────────────────────────────────────────
          _SettingsSection(
            icon: Icons.record_voice_over_rounded,
            color: Colors.cyanAccent,
            title: context.uiText('Piper TTS — đọc chữ offline'),
            subtitle: context.uiText('Giọng neural cho cabin & tab Đọc'),
            children: const [_PiperModelCard()],
          ),
          // ── 6. Gemma ───────────────────────────────────────────────────
          _SettingsSection(
            icon: Icons.smart_toy_outlined,
            color: Colors.lightBlueAccent,
            title: context.uiText('Gemma — AI Chat offline'),
            subtitle: context.uiText('File .gguf, chạy trên máy'),
            children: const [_GemmaChatModelCard()],
          ),
          // ── 7. Dịch offline/online ─────────────────────────────────────
          _SettingsSection(
            icon: Icons.translate_rounded,
            color: Colors.teal,
            title: context.uiText('Dịch offline & online — Hy-MT & ML Kit'),
            subtitle: context.uiText('Dùng chung cho tab Đọc, Dịch Cabin, PDF'),
            children: const [_TranslationModelSettingsCard()],
          ),
          // ── 8. Dịch màn hình (Android) ─────────────────────────────────
          _SettingsSection(
            icon: Icons.bubble_chart_outlined,
            color: Colors.lightBlue,
            title: context.uiText('Dịch màn hình — bong bóng nổi'),
            subtitle: context.uiText('Chỉ Android · cần quyền chụp màn hình'),
            children: const [ScreenTranslateCard()],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Nút "!" ở góc: mở sheet chứa các ghi chú chỉ-để-đọc (tải model khi bấm,
/// quyền pin, nơi lưu model) — không chiếm chỗ trong danh sách chính.
class _InfoSheetButton extends StatelessWidget {
  const _InfoSheetButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.info_outline),
      tooltip: context.uiText('Thông tin & lưu ý'),
      onPressed: () => showModelInfoSheet(context),
    );
  }
}

/// Icon trạng thái quyền "Dừng tối ưu pin" ngay trên AppBar.
///
/// Xanh = đã cấp (chỉ còn là thông tin), cam = chưa cấp → bấm mở đúng sheet
/// để cấp quyền. Không còn thẻ pin chiếm chỗ khi mọi thứ đã ổn.
class _BatteryStatusAction extends StatefulWidget {
  const _BatteryStatusAction();

  @override
  State<_BatteryStatusAction> createState() => _BatteryStatusActionState();
}

class _BatteryStatusActionState extends State<_BatteryStatusAction> {
  bool? _granted;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (!BatteryOptimizationService.isSupported) return;
    final ok = await BatteryOptimizationService.isIgnoringBatteryOptimizations();
    if (mounted) setState(() => _granted = ok);
  }

  @override
  Widget build(BuildContext context) {
    if (!BatteryOptimizationService.isSupported || _granted == null) {
      return const SizedBox.shrink();
    }
    final granted = _granted!;
    return IconButton(
      icon: Icon(
        granted ? Icons.battery_full_rounded : Icons.battery_alert_rounded,
      ),
      color: granted ? Colors.greenAccent : Colors.orangeAccent,
      tooltip: context.uiText(
        granted
            ? 'Pin: đã bỏ giới hạn tối ưu pin'
            : 'Pin: chưa bỏ giới hạn tối ưu pin — có thể dừng model khi chạy ngầm',
      ),
      onPressed: () => showModelInfoSheet(context),
    );
  }
}

/// Mở sheet thông tin/lưu ý dùng chung cho nút "!" và icon pin.
Future<void> showModelInfoSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const _ModelInfoSheet(),
  );
}

class _ModelInfoSheet extends StatelessWidget {
  const _ModelInfoSheet();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scroll) {
        return ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.teal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.uiText('Thông tin & lưu ý'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoNote(
              icon: Icons.cloud_download_outlined,
              title: context.uiText('Chỉ tải khi bạn bấm'),
              body: context.uiText(
                'Bấm Tải về để lấy model từ mạng (HuggingFace). '
                'App KHÔNG tự tải khi khởi động — tránh lỗi "Connection closed" '
                'trên tablet. Đã có file thì dùng Import.',
              ),
            ),
            const SizedBox(height: 8),
            const _BatteryOptimizationCard(dense: true),
            const SizedBox(height: 8),
            _InfoNote(
              icon: Icons.folder_outlined,
              title: context.uiText('Model nằm trong bộ nhớ riêng của app'),
              body: context.uiText(
                'Xoá app là mất model đã tải/import. Model không gửi dữ liệu '
                'âm thanh ra ngoài — mọi thứ chạy trên máy.',
              ),
            ),
          ],
        );
      },
    );
  }
}

class _InfoNote extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _InfoNote({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.tealAccent),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(body, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

/// Một nhóm cài đặt gập/mở được — thay cho các dòng tiêu đề toàn chữ.
class _SettingsSection extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final bool initiallyExpanded;

  const _SettingsSection({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    required this.children,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: PageStorageKey<String>('model-settings-$title'),
        initiallyExpanded: initiallyExpanded,
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: color.withValues(alpha: 0.18),
          child: Icon(icon, size: 18, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                    ),
              ),
        children: children,
      ),
    );
  }
}

/// BATTERY-OPT-001 — Thẻ cho phép người dùng bật/kiểm tra quyền
/// "Dừng tối ưu mức sử dụng pin" bất cứ lúc nào.
class _BatteryOptimizationCard extends StatefulWidget {
  /// true = bản gọn dùng trong sheet "Thông tin & lưu ý" (không chiếm chỗ
  /// trong danh sách chính khi quyền đã được cấp).
  final bool dense;

  const _BatteryOptimizationCard({this.dense = false});

  @override
  State<_BatteryOptimizationCard> createState() =>
      _BatteryOptimizationCardState();
}

class _BatteryOptimizationCardState extends State<_BatteryOptimizationCard> {
  bool? _granted;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final ok = await BatteryOptimizationService.isIgnoringBatteryOptimizations();
    if (mounted) setState(() => _granted = ok);
  }

  @override
  Widget build(BuildContext context) {
    if (!BatteryOptimizationService.isSupported) {
      return const SizedBox.shrink();
    }
    final granted = _granted ?? false;
    return Card(
      margin: widget.dense ? EdgeInsets.zero : const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        dense: widget.dense,
        contentPadding:
            widget.dense ? const EdgeInsets.symmetric(horizontal: 4) : null,
        leading: Icon(
          granted
              ? Icons.battery_charging_full_rounded
              : Icons.battery_alert_rounded,
          color: granted ? Colors.green : Colors.orangeAccent,
        ),
        title: Text(
          context.uiText('Dừng tối ưu mức sử dụng pin'),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        subtitle: Text(
          context.uiText(
            granted
                ? 'Đã cho phép — In4Up có thể chạy ngầm, pin không bị hạn chế.'
                : 'Chưa cho phép — hệ thống có thể tạm dừng model STT/AI khi '
                    'app chạy ngầm.',
          ),
          style: const TextStyle(fontSize: 11),
        ),
        trailing: granted
            ? const Icon(Icons.check_circle, color: Colors.green)
            : FilledButton(
                onPressed: () async {
                  await BatteryOptimizationService.requestWithDialog(context);
                  await _refresh();
                },
                child: Text(context.uiText('Cho phép')),
              ),
      ),
    );
  }
}

/// Bộ chọn dòng model Whisper: đa ngôn ngữ ↔ English-only.
///
/// WHISPER-VARIANT-001 — cùng một kích thước có 2 bản (`ggml-base.bin` đa ngữ
/// và `ggml-base.en.bin` chỉ tiếng Anh). Người dùng chọn dòng trước, rồi mới
/// chọn kích thước ⇒ danh sách gọn, không phải cuộn 9 thẻ cùng lúc.
class _WhisperSectionBody extends StatefulWidget {
  const _WhisperSectionBody();

  @override
  State<_WhisperSectionBody> createState() => _WhisperSectionBodyState();
}

class _WhisperSectionBodyState extends State<_WhisperSectionBody> {
  bool _englishOnly = false;

  @override
  Widget build(BuildContext context) {
    final levels = _englishOnly
        ? kWhisperEnglishOnlyLevels
        : kWhisperMultilingualLevels;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<bool>(
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: [
            ButtonSegment<bool>(
              value: false,
              icon: const Icon(Icons.public, size: 16),
              label: Text(context.uiText('Đa ngôn ngữ')),
            ),
            ButtonSegment<bool>(
              value: true,
              icon: const Icon(Icons.text_fields_rounded, size: 16),
              label: Text(context.uiText('Chỉ tiếng Anh')),
            ),
          ],
          selected: {_englishOnly},
          onSelectionChanged: (selection) =>
              setState(() => _englishOnly = selection.first),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _englishOnly
                  ? Icons.info_outline_rounded
                  : Icons.language_rounded,
              size: 14,
              color: Colors.grey,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                context.uiText(
                  _englishOnly
                      ? 'English-only (.en): chính xác hơn cho audio tiếng Anh, '
                          'cùng dung lượng với bản đa ngữ. KHÔNG nhận tiếng Việt '
                          'hay ngôn ngữ khác.'
                      : 'Đa ngôn ngữ: nhận diện 99 ngôn ngữ (kể cả tiếng Việt) '
                          'bằng cùng một file model.',
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...levels.map((level) => _ModelCard(level: level)),
      ],
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
                          Row(
                            children: [
                              Text(
                                context.uiText('Whisper ${level.displayLabel}'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              if (level.isEnglishOnly) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.lightBlue.withValues(
                                      alpha: 0.18,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    context.uiText('English-only'),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.lightBlueAccent,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            context.uiText(level.description),
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
                    context.uiText('${(info.downloadProgress * 100).toStringAsFixed(1)}% '
                    '· ${(info.downloadProgress * level.sizeInMB).toStringAsFixed(0)}'
                    '/${level.sizeInMB}MB'),
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
                        context.uiText('${level.sizeInMB}MB'),
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
          title: Text(
            context.uiText('Tải Whisper ${level.displayLabel}?'),
          ),
          // Ghép từ các câu ĐỘC LẬP (không nội suy nhiều tầng) để mỗi câu
          // khớp đúng 1 key dịch — trước đây cả khối là 1 chuỗi nội suy nên
          // locale ≠ vi không tra được bản dịch nào.
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.uiText('Dung lượng khoảng ${level.sizeInMB}MB.'),
              ),
              const SizedBox(height: 8),
              if (level.isEnglishOnly) ...[
                Text(
                  context.uiText(
                    'Bản English-only CHỈ nhận tiếng Anh — audio tiếng Việt/'
                    'ngôn ngữ khác sẽ ra sai.',
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                context.uiText(
                  'Nên dùng Wi-Fi và giữ app mở trong lúc tải. Nếu mạng đứt, '
                  'bấm Tải về lại — app thử lại từ HuggingFace.',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.uiText(
                  'Hoặc Import nếu bạn đã có file ${level.fileName}.',
                ),
              ),
            ],
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
        title: Text(context.uiText('Xoá model ${level.displayLabel}?')),
        content: Text(
          context.uiText(
            'Sẽ giải phóng ${level.sizeInMB}MB. Bạn cần tải lại để dùng tính năng này.',
          ),
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
                      context.uiText('${language.flag} ${language.nativeName} '
                      '(${language.englishName})'),
                    ),
                  ),
                ),
              ],
              selectedItemBuilder: (_) => [
                const Text('🌐 Auto'),
                ...AppLanguageCatalog.languages.map(
                  (language) => Text(
                    context.uiText('${language.flag} ${language.translationCode}'),
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
                    context.uiText('${(info.downloadProgress * 100).toStringAsFixed(1)}% · ~629KB'),
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
        content: Text(context.uiText(ok
            ? '✅ Import Silero VAD thành công!'
            : '❌ Import thất bại — cần silero_vad.onnx (k2-fsa ~629KB)')),
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
                    context.uiText(
                      'Đang tải bundle Piper… ${(info.downloadProgress * 100).toStringAsFixed(1)}%',
                    ),
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
    if (msg.startsWith(SherpaModelManager.safEmptyPrefix)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.uiText('Thư mục không thể mở trực tiếp (SAF). Vui lòng chọn file trong thư mục.'),
          ),
        ),
      );
      await _importFiles(context);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.uiText(msg))));
  }

  Future<void> _importFiles(BuildContext context) async {
    // I4U18-MODEL-IMPORT-001 (C2.1) — FileType.any: file espeak-ng-data
    // (phontab/phonindex/phondata/intonations/*_dict) KHÔNG có extension nên
    // filter cũ không bao giờ chọn được → "kèm thư mục espeak nhưng app
    // không tự nhận". Manager tự lọc file hợp lệ (scanner thống nhất).
    final result = await fp.FilePicker.pickFiles(
      type: fp.FileType.any,
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final named = <String, Uint8List>{};
    final paths = <String>[];
    for (final f in result.files) {
      final bytes = f.bytes;
      if (bytes != null && bytes.isNotEmpty) {
        named[f.name] = bytes;
      } else if (f.path != null && f.path!.isNotEmpty) {
        paths.add(f.path!);
      }
    }
    final String msg;
    if (named.isNotEmpty) {
      msg = await _manager.importPiperNamedBytes(named);
    } else if (paths.isNotEmpty) {
      msg = await _manager.importPiperFiles(paths);
    } else {
      msg = 'Không đọc được file (SAF). Thử chọn lại hoặc Tải phonemizer.';
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.uiText(msg))),
    );
  }

  Future<void> _downloadEspeak(BuildContext context) async {
    final msg = await _manager.downloadEspeakData();
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
          content: Text(
            context.uiText('Đã cài giọng $voice — dùng được ngay.'),
          ),
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

class _PiperVoiceDownloadSheet extends StatefulWidget {
  const _PiperVoiceDownloadSheet();

  @override
  State<_PiperVoiceDownloadSheet> createState() =>
      _PiperVoiceDownloadSheetState();
}

class _PiperVoiceDownloadSheetState extends State<_PiperVoiceDownloadSheet> {
  bool _showMore = false;

  @override
  Widget build(BuildContext context) {
    final featured = PiperVoiceCatalog.featured();
    final extra = PiperVoiceCatalog.more();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scroll) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: ListView(
            controller: scroll,
            children: [
              Text(
                context.uiText('Download Piper voice (~75MB, auto-install)'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                context.uiText(
                  'Priority: Vietnamese, English, Chinese, Hindi. '
                  'More languages below. Source: HuggingFace rhasspy/piper-voices '
                  '(k2-fsa bundle first). Sinhala is not in this catalog yet.',
                ),
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              const SizedBox(height: 12),
              ..._groupTiles(context, featured),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => setState(() => _showMore = !_showMore),
                icon: Icon(
                  _showMore ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                ),
                label: Text(
                  context.uiText(
                    _showMore ? 'Hide extra languages' : 'Show more languages',
                  ),
                ),
              ),
              if (_showMore) ..._groupTiles(context, extra),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _groupTiles(BuildContext context, List<PiperVoiceOffer> voices) {
    final byLang = <String, List<PiperVoiceOffer>>{};
    for (final v in voices) {
      byLang.putIfAbsent(v.languageCode, () => []).add(v);
    }
    final out = <Widget>[];
    for (final entry in byLang.entries) {
      out.add(
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Text(
            context.uiText('${entry.value.first.languageLabelEn} (${entry.key})'),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF80CBC4),
            ),
          ),
        ),
      );
      for (final v in entry.value) {
        out.add(
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(v.id, style: const TextStyle(fontSize: 13)),
            subtitle: Text(
              context.uiText('${v.speaker} · ${v.quality} · ~${v.approxSizeMB}MB'),
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
            trailing: const Icon(Icons.download, size: 18),
            onTap: () => Navigator.pop(context, v.id),
          ),
        );
      }
    }
    return out;
  }
}

class _PiperBadge extends StatelessWidget {
  final SherpaPiperInfo info;
  const _PiperBadge({required this.info});

  @override
  Widget build(BuildContext context) {
    final ready = info.isReady;
    final (label, color) = ready
        ? (context.uiText('${info.voices.length} giọng'), Colors.green)
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
                  context.uiText('Ngôn ngữ: ${lang.isEmpty ? 'Tự do / Mặc định' : lang} · '
                  '${voice.sampleRate}Hz'),
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
        // AI-CHAT-01 (audit B3): engine thật có thể chết vì OOM/thu hồi — hiện
        // lỗi engine (nếu có) thay vì nói "chưa có model" khi file vẫn còn.
        final engineError = facade.engineError;
        final errorText = engineError ??
            (facade.importStage == AiImportStage.failed
                ? facade.importError
                : null);

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
                          : engineError != null
                              ? Icons.error_outline
                              : busy
                                  ? Icons.sync
                                  : Icons.cloud_off,
                      color: hasModel
                          ? Colors.green
                          : engineError != null
                              ? Colors.red
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
                                ? context.uiText(
                                    'Model: $name${sizeMb != null ? ' · ${sizeMb}MB' : ''} · ${facade.modelSourceLabel}',
                                  )
                                : facade.hasModelFile
                                    // Có file model nhưng engine chưa sẵn sàng
                                    // (đang nạp / vừa hồi phục sau OOM).
                                    ? context.uiText(
                                        'Đang nạp model vào bộ nhớ — có thể mất 1–2 phút cho file lớn',
                                      )
                                    : context.uiText(
                                        'Chưa có model — import file .gguf hoặc tải về (~1.5GB, Gemma-2B Q4)',
                                      ),
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
                    context.uiText(
                      facade.importStage == AiImportStage.copying
                          ? 'Đang copy model… '
                              '${(facade.importProgress * 100).toStringAsFixed(0)}%'
                          : facade.importStage == AiImportStage.downloading
                              ? 'Đang tải model… '
                                  '${(facade.importProgress * 100).toStringAsFixed(0)}%'
                              : 'Đang nạp model vào bộ nhớ — có thể mất 1–2 phút',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                ],

                // ── Error message ────────────────────────────────────
                if (errorText != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade900.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      errorText,
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
          context.uiText(
            ok
                ? 'AI local đã sẵn sàng'
                    '${facade.modelFileName != null ? " — ${facade.modelFileName}" : ''}'
                : (facade.importError ?? 'Chưa import được model .gguf.'),
          ),
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
          decoration: InputDecoration(
            hintText: 'https://.../*.gguf',
            helperText: context.uiText(
              'Mặc định: Gemma-2-2B-it Q4_K_M từ HuggingFace (~1.5GB). Chỉ tải trên WiFi.',
            ),
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

// ═══════════════════════════════════════════════════════════════════════════
// ZIPFORMER ASR CARD — nhận diện giọng nói trực tiếp offline (PLAN-023 / WP4)
// ═══════════════════════════════════════════════════════════════════════════

class _SherpaAsrCard extends StatefulWidget {
  /// Chỉ hiện các profile này (null = tất cả). Nhờ vậy 1 manager dùng chung
  /// vẫn tách được "Parakeet" và "Zipformer" thành 2 nhóm gập/mở riêng.
  final List<String>? profileIds;

  const _SherpaAsrCard({this.profileIds});

  @override
  State<_SherpaAsrCard> createState() => _SherpaAsrCardState();
}

class _SherpaAsrCardState extends State<_SherpaAsrCard> {
  final _manager = SherpaModelManager();
  bool _showAllLanguages = false;

  @override
  void initState() {
    super.initState();
    _manager.initialize();
  }

  @override
  Widget build(BuildContext context) {
    final profiles = SherpaModelManager.predefinedAsrProfiles
        .where((profile) =>
            widget.profileIds == null ||
            widget.profileIds!.contains(profile.id))
        .toList();

    return StreamBuilder<SherpaAsrInfo>(
      stream: _manager.watchAsr(),
      initialData: _manager.asrInfo,
      builder: (context, snapshot) {
        final asrInfo = snapshot.data!;

        return Column(
          children: profiles.map((profile) {
            final info = asrInfo.stateFor(profile.id);
            final isParakeet = profile.family == SherpaAsrFamily.parakeet;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ──────────────────────────────────────────
                    Row(
                      children: [
                        Icon(
                          info.isReady
                              ? Icons.check_circle
                              : info.isDownloading
                                  ? Icons.sync
                                  : isParakeet
                                      ? Icons.bolt_rounded
                                      : profile.isStreaming
                                          ? Icons.sensors_rounded
                                          : Icons.keyboard_voice_rounded,
                          color: info.isReady
                              ? Colors.green
                              : info.isDownloading
                                  ? Colors.blue
                                  : isParakeet
                                      ? Colors.amberAccent
                                      : Colors.teal,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.uiText('${profile.name}  ·  ${profile.languageLabel}'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                context.uiText(
                                  isParakeet
                                      ? 'Offline đa ngữ — Parakeet TDT 0.6B v3 int8 (NVIDIA)'
                                      : profile.isStreaming
                                          ? 'Nhận diện trực tiếp (streaming) — Zipformer 20M int8'
                                          : 'Nhận diện offline kèm VAD — Zipformer 30M int8',
                                ),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        _AsrBadge(info: info),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // ── Model này dùng ở đâu (mapping rõ cho Cabin) ─────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          isParakeet
                              ? Icons.public_rounded
                              : profile.isStreaming
                                  ? Icons.wifi_tethering_rounded
                                  : Icons.offline_bolt_outlined,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            context.uiText(
                              isParakeet
                                  ? 'Cabin (offline + VAD) và bóc băng file/LRC. '
                                      'Bao 25 ngôn ngữ châu Âu (Anh, Pháp, Đức, Tây Ban Nha…), '
                                      'KHÔNG có tiếng Việt — tiếng Việt dùng Zipformer VI.'
                                  : profile.isStreaming
                                      ? 'Cabin (live, token-by-token). KHÔNG dùng cho file/LRC — model streaming chỉ chạy OnlineRecognizer.'
                                      : 'Cabin (offline + VAD) và bóc băng file/LRC.',
                            ),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontSize: 11),
                          ),
                        ),
                      ],
                    ),

                    // ── Cảnh báo model lớn (Parakeet ~670MB) ────────────
                    if (profile.isLargeDownload) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              size: 14, color: Colors.orangeAccent),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '~${profile.approxSizeMB}MB · '
                              '${context.uiText('nên tải bằng Wi-Fi · cần ~1GB RAM trống khi nạp')}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.orangeAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    // ── Ngôn ngữ model hỗ trợ (sổ ra khi cần) ────────────
                    if (profile.isMultilingual) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          for (final language in (_showAllLanguages
                              ? profile.languages
                              : profile.languages.take(5)))
                            Chip(
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              avatar: const Icon(Icons.language, size: 12),
                              label: Text(
                                language.toUpperCase(),
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                          if (profile.languages.length > 5)
                            ActionChip(
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              avatar: Icon(
                                _showAllLanguages
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                size: 14,
                              ),
                              label: Text(
                                _showAllLanguages
                                    ? context.uiText('Thu gọn')
                                    : '+${profile.languages.length - 5}',
                                style: const TextStyle(fontSize: 10),
                              ),
                              onPressed: () => setState(
                                  () => _showAllLanguages = !_showAllLanguages),
                            ),
                        ],
                      ),
                    ],

                    if (!info.isReady) ...[
                      const SizedBox(height: 6),
                      Text(
                        context.uiText(
                          isParakeet
                              ? 'Chưa cài model — Cabin chọn ngôn ngữ Pháp/Đức/… sẽ báo thiếu model (không tự nhận bằng model khác).'
                              : 'Chưa cài model — Cabin chọn ngôn ngữ này sẽ báo thiếu model (không tự nhận bằng model ngôn ngữ khác).',
                        ),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orangeAccent.shade200,
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    // ── Progress ────────────────────────────────────────
                    if (info.isDownloading) ...[
                      LinearProgressIndicator(
                        value: info.downloadProgress > 0
                            ? info.downloadProgress
                            : null,
                        backgroundColor: Colors.grey.shade800,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.uiText('${(info.downloadProgress * 100).toStringAsFixed(1)}% · '
                        '${(info.downloadProgress * profile.approxSizeMB).toStringAsFixed(0)}/${profile.approxSizeMB}MB'),
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
                        if (info.isDownloading)
                          TextButton.icon(
                            icon: const Icon(Icons.cancel, size: 16),
                            label: const Text('Huỷ'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            onPressed: () =>
                                _manager.cancelAsrDownload(profile.id),
                          )
                        else if (info.isReady) ...[
                          TextButton.icon(
                            icon: const Icon(Icons.folder_open, size: 16),
                            label: const Text('Import thư mục'),
                            onPressed: () =>
                                _importFolder(context, profile),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.insert_drive_file, size: 16),
                            label: const Text('Import file'),
                            onPressed: () =>
                                _importFiles(context, profile),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.delete, size: 16),
                            label: Text(
                              context.uiText('Xoá (${profile.approxSizeMB}MB)'),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            onPressed: () =>
                                _confirmDelete(context, profile),
                          ),
                        ] else ...[
                          TextButton.icon(
                            icon: const Icon(Icons.folder_open, size: 16),
                            label: const Text('Import thư mục'),
                            onPressed: () =>
                                _importFolder(context, profile),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.insert_drive_file, size: 16),
                            label: const Text('Import file'),
                            onPressed: () =>
                                _importFiles(context, profile),
                          ),
                          Text(
                            context.uiText('${profile.approxSizeMB}MB'),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.download, size: 16),
                            label: const Text('Tải về'),
                            onPressed: () =>
                                _handleDownload(context, profile),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _handleDownload(
    BuildContext context,
    SherpaAsrProfile profile,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          context.uiText('Tải model ${profile.name}?'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.uiText(
                'Dung lượng khoảng ${profile.approxSizeMB}MB (archive tar.bz2).',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.uiText(
                'App tự động tải archive, giải nén và cấu hình model.',
              ),
            ),
            if (profile.isLargeDownload) ...[
              const SizedBox(height: 8),
              Text(
                context.uiText(
                  'Model lớn: nên dùng Wi-Fi, giữ app mở, và cần ~1GB RAM '
                  'trống khi nạp.',
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(context.uiText('Nên dùng Wi-Fi trong khi tải.')),
          ],
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

    await _manager.downloadAsrModel(profile.id);
  }

  Future<void> _importFolder(
    BuildContext context,
    SherpaAsrProfile profile,
  ) async {
    final path = await fp.FilePicker.getDirectoryPath();
    if (path == null || path.isEmpty) return;
    final result =
        await _manager.importAsrFolderResult(path, targetProfileId: profile.id);
    if (!mounted) return;
    // IN4-16 (MODELIMPORT-001) — 2 trường hợp app KHÔNG đọc được thư mục:
    // (a) SAF trả URI `content://`; (b) đường dẫn THẬT trên thẻ nhớ ngoài
    //     bị scoped storage chặn (log 18/10: /storage/3033-3963/…) →
    //     `sourceFileCount == 0` (không đọc được file nào). Cả hai đều dẫn
    //     user tới đường BYTES (chọn nhiều file) — đường duy nhất chắc chắn
    //     đọc được trên Android.
    final unreadableFolder =
        result.status == SherpaAsrImportStatus.sourceMissing ||
            (result.sourceFileCount == 0 &&
                result.status != SherpaAsrImportStatus.sourceEmpty);
    if (unreadableFolder) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.uiText(
              'Không đọc trực tiếp thư mục trên thiết bị này (SAF/thẻ nhớ). Hãy chọn các file trong thư mục: encoder/decoder/joiner (.onnx) + tokens.txt.')),
        ),
      );
      await _importFiles(context, profile);
      return;
    }
    _showAsrImportResult(context, profile, result);
  }

  /// Hiện kết quả import bằng chuỗi đã bản địa hoá (không hiện chuỗi tiếng
  /// Việt thô từ package).
  void _showAsrImportResult(
    BuildContext context,
    SherpaAsrProfile profile,
    SherpaAsrImportResult result,
  ) {
    final message = switch (result.status) {
      SherpaAsrImportStatus.imported =>
        context.uiText('✅ Đã import model ASR: ${profile.name}'),
      SherpaAsrImportStatus.unknownProfile => context.uiText(
          'Không nhận diện được model này — hãy bấm Import ở đúng thẻ model '
          '(Parakeet, VI offline hoặc EN streaming).'),
      SherpaAsrImportStatus.profileMismatch => context.uiText(
          'Model không khớp profile đã chọn: Zipformer VI là offline, '
          'Zipformer EN là streaming, Parakeet là offline đa ngữ — '
          'không trộn được.'),
      SherpaAsrImportStatus.incompleteFiles => result.missingRoles.isNotEmpty
          // I4U18-MODEL-IMPORT-001 — nêu ĐÚNG file cần bổ sung.
          ? '${context.uiText('Thiếu file model:')} '
              '${result.missingRoles.join(', ')}. '
              '${context.uiText('Bổ sung file rồi bấm Import lại.')}'
          : context.uiText(
              'Thiếu file model: cần encoder, decoder, joiner (.onnx) và tokens.txt.'),
      SherpaAsrImportStatus.sourceMissing =>
        context.uiText('Không đọc được thư mục đã chọn.'),
      SherpaAsrImportStatus.sourceEmpty =>
        context.uiText('Chưa chọn file/thư mục nào.'),
      // PARAKEET-002: file model quá lớn cho đường đọc-bytes (encoder
      // Parakeet ~624MB) — nếu cố nạp thì Android kill app.
      SherpaAsrImportStatus.fileTooLarge => context.uiText(
          'File model quá lớn để đọc trực tiếp. Hãy dùng "Import thư mục" '
          'hoặc chọn file có đường dẫn thật (không qua SAF).'),
      SherpaAsrImportStatus.failed => context.uiText(
          'Import thất bại. Hãy kiểm tra file model rồi thử lại.'),
    };
    if (result.detail != null) {
      debugPrint('⚠️ ASR import detail: ${result.detail}');
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// Import nhiều FILE model — PARAKEET-002.
  ///
  /// Bản cũ dùng `withData: true` (IN4-16) vì trên Android SAF `f.path` có
  /// thể là URI `content://` mà `dart:io` không đọc được. Nhưng `withData`
  /// nạp bytes của TOÀN BỘ file đã chọn vào RAM trước khi trả về — với
  /// Parakeet (`encoder.int8.onnx` ~624MB) cộng thêm archive `.tar.bz2`
  /// 487MB đang được giải nén thì đỉnh bộ nhớ vượt 1GB ⇒ Android kill tiến
  /// trình: đúng hiện tượng "import Parakeet một chặng thì app văng".
  ///
  /// Nay dùng `withReadStream: true` (cùng cách từ điển MDX đã dùng):
  /// - có `path` thật → để manager copy theo luồng;
  /// - chỉ có stream → ghi từng khối ra file tạm rồi cũng đi đường path;
  /// - không có cả hai → báo lỗi, TUYỆT ĐỐI không nạp cả model vào RAM.
  Future<void> _importFiles(
    BuildContext context,
    SherpaAsrProfile profile,
  ) async {
    final picked = await fp.FilePicker.pickFiles(
      type: fp.FileType.custom,
      allowedExtensions: const ['onnx', 'txt', 'bz2', 'zip', 'vocab', 'json'],
      allowMultiple: true,
      withData: false,
      withReadStream: true,
    );
    if (picked == null || picked.files.isEmpty) return;

    final paths = <String>[];
    final skipped = <String>[];
    // File nào không có path thật (SAF content://) mới phải ghi tạm theo
    // stream — bản tạm bị xoá trong `finally`.
    final streamOnly = <fp.PlatformFile>[];
    for (final f in picked.files) {
      final path = f.path;
      if (path != null && path.isNotEmpty && !path.startsWith('content://')) {
        paths.add(path);
      } else if (f.readStream != null) {
        streamOnly.add(f);
      } else {
        skipped.add(f.name);
      }
    }
    Directory? staging;
    try {
      if (streamOnly.isNotEmpty) {
        final stagingDir = await Directory(
          '${(await getTemporaryDirectory()).path}/in4up_asr_import_'
          '${DateTime.now().microsecondsSinceEpoch}',
        ).create(recursive: true);
        staging = stagingDir;
        for (final f in streamOnly) {
          final target = File('${stagingDir.path}/${_pickedLeafName(f.name)}');
          final sink = target.openWrite();
          try {
            await for (final chunk in f.readStream!) {
              sink.add(chunk);
            }
            await sink.flush();
            await sink.close();
            paths.add(target.path);
          } catch (e) {
            await sink.close();
            skipped.add(f.name);
            debugPrint('⚠️ ASR stream stage ${f.name}: $e');
          }
        }
      }
      if (skipped.isNotEmpty) {
        debugPrint('⚠️ ASR import bỏ qua file không đọc được: ${skipped.join(', ')}');
      }

      if (!mounted) return;
      if (paths.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.uiText(
                'Không đọc được file (SAF). Vui lòng chọn lại các file model.')),
          ),
        );
        return;
      }
      final result = await _manager.importAsrFilesResult(
        paths,
        targetProfileId: profile.id,
      );
      if (!mounted) return;
      _showAsrImportResult(context, profile, result);
    } finally {
      // Giải phóng bản sao tạm (có thể là ~624MB encoder) ngay sau khi copy.
      if (staging != null) {
        try {
          if (await staging.exists()) await staging.delete(recursive: true);
        } catch (_) {
          // Dọn cache là best-effort.
        }
      }
    }
  }

  /// Tên file an toàn cho bản sao tạm (bỏ mọi thành phần đường dẫn).
  static String _pickedLeafName(String name) {
    final leaf = name.replaceAll('\\', '/').split('/').last.trim();
    if (leaf.isEmpty || leaf == '.' || leaf == '..') {
      return 'picked_${DateTime.now().microsecondsSinceEpoch}';
    }
    return leaf;
  }

  Future<void> _confirmDelete(
    BuildContext context,
    SherpaAsrProfile profile,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.uiText('Xoá model ${profile.name}?')),
        content: Text(
          context.uiText(
            'Sẽ giải phóng ${profile.approxSizeMB}MB. Cần tải lại để dùng nhận diện offline.',
          ),
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
    if (confirm == true) await _manager.deleteAsrModel(profile.id);
  }
}

class _AsrBadge extends StatelessWidget {
  final SherpaModelInfo info;
  const _AsrBadge({required this.info});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (info.status) {
      SherpaModelStatus.ready => ('Sẵn sàng', Colors.green),
      SherpaModelStatus.downloading => ('Đang tải', Colors.blue),
      SherpaModelStatus.error => ('Lỗi file', Colors.red),
      _ => ('Chưa tải', Colors.grey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        context.uiText(label),
        style: TextStyle(color: color, fontSize: 11),
      ),
    );
  }
}


class _TranslationModelSettingsCard extends StatelessWidget {
  const _TranslationModelSettingsCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.translate_rounded, color: Colors.teal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.uiText('Model Dịch Thuật (Hy-MT & ML Kit)'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              context.uiText(
                'Quản lý gói dịch offline Google ML Kit và mô hình dịch câu Hy-MT (GGUF ~600MB). Cấu hình đồng bộ với tab Đọc sách và Dịch Cabin.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.settings_suggest_rounded),
                label: Text(context.uiText('Cấu hình Engine Dịch & Tải gói Offline')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade700,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: const Color(0xFF1A1A2E),
                    isScrollControlled: true,
                    useSafeArea: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (ctx) => TranslationEngineSettingsSheet(
                      service: TranslationService(),
                      accentColor: Colors.teal,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
