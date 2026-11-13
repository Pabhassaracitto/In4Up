// ignore_for_file: deprecated_member_use, use_build_context_synchronously
// lib/features/tts/widgets/tts_settings_section.dart

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:in4up/core/language/localized_material.dart';
import 'package:in4up/l10n/app_localizations.dart';
import 'package:in4up/screens/settings/ai_providers_screen.dart';
import 'package:in4up_ai/in4up_ai.dart';

import 'package:in4up_stt/sherpa_model_manager.dart';
import 'package:in4up_stt/tts/sherpa_piper_tts_core.dart';
import 'package:in4up_stt/tts/vieneu_tts_core.dart';
import 'package:in4up_stt/tts/vieneu_tts_paths.dart';

import '../edge_voice_prefs.dart';
import '../engines/vieneu_tts_engine.dart';
import '../vieneu_g2p_dictionary.dart';
import '../engines/edge_tts_engine.dart';
import 'voice_clone_section.dart';
import '../engines/tts_engine.dart';
import '../piper_voice_prefs.dart';
import '../tts_service.dart';
import '../tts_settings.dart';

/// PSRC-187 (audit 1.27.0) — câu báo khi bản cài KHÔNG đóng gói thư viện
/// native của VieNeu-TTS (`libvieneu_tts`): model đã import cũng chưa đọc được
/// và `TtsService` sẽ chuyển sang engine kế tiếp. Trước đây màn này chỉ hiện
/// "Đã có model" nên người dùng tưởng VieNeu đang được dùng.
///
/// Là hằng số để test khoá đúng chuỗi này vào bảng dịch (rule #5).
const String kVieneuNativeMissingNotice =
    'Bản cài này chưa kèm engine VieNeu-TTS nên model đã import chưa đọc '
    'được. Khi VieNeu được ưu tiên, app sẽ đọc bằng nguồn phát kế tiếp.';

/// Widget cài đặt TTS - nhúng vào Settings sheet hiện có
class TtsSettingsSection extends StatefulWidget {
  final Color primaryColor;

  const TtsSettingsSection({
    super.key,
    this.primaryColor = const Color(0xFF6C63FF),
  });

  @override
  State<TtsSettingsSection> createState() => _TtsSettingsSectionState();
}

class _TtsSettingsSectionState extends State<TtsSettingsSection> {
  final _ttsService = TtsService();

  @override
  void initState() {
    super.initState();
    AiProviderStore.instance.ensureLoaded();
  }

  bool _isLegacyHiddenEngine(TtsEngineInfo engine) {
    if (engine.id == 'zalo_tts') {
      return _ttsService.zaloApiKey == null ||
          _ttsService.zaloApiKey!.trim().isEmpty;
    }
    if (engine.id == 'fpt_tts') {
      return _ttsService.fptApiKey == null ||
          _ttsService.fptApiKey!.trim().isEmpty;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _ttsService,
      builder: (context, _) {
        final visibleEngines = _ttsService.engineOrder
            .where((e) => !_isLegacyHiddenEngine(e))
            .toList(growable: false);
        final hiddenEngines = _ttsService.engineOrder
            .where(_isLegacyHiddenEngine)
            .toList(growable: false);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── HEADER ──
            _SectionHeader(
              icon: Icons.record_voice_over,
              title: 'Text-to-Speech',
              color: widget.primaryColor,
            ),
            const SizedBox(height: 12),

            // ── PRIORITY MODE ──
            _PrioritySelector(
              current: _ttsService.priority,
              color: widget.primaryColor,
              onChanged: (p) {
                _ttsService.setPriority(p);
              },
            ),
            const SizedBox(height: 16),

            const _PiperVoicePicker(),
            const SizedBox(height: 16),

            // ── VIENEU MODEL IMPORT (TTS-VIENEU-IMPORT-001) ──
            // PSRC-183: không dùng const — cần rebuild khi TtsService notify sau import
            _VieneuModelImportSection(
              // Khi import xong, picker bên dưới phải reload danh sách giọng.
              onVoicesChanged: () => _ttsService.notifyVoicesChanged(),
            ),
            const SizedBox(height: 16),

            // ── VIENEU VOICE PICKER (TTS-VIENEU-VOICE-001) ──
            const _VieneuVoicePicker(),
            const SizedBox(height: 16),

            // ── VIENEU VOICE CLONE (TTS-CLONE-001) ──
            VoiceCloneSection(
              primaryColor: widget.primaryColor,
            ),
            const SizedBox(height: 16),

            // ── EDGE NEURAL VOICE (TTS-EDGE-VOICE-001 / PSRC-18) ──
            EdgeVoicePicker(
              onVoiceChanged: () async {
                if (_ttsService.isSpeaking) {
                  await _ttsService.stop();
                }
              },
            ),
            const SizedBox(height: 16),

            // ── ENGINE ORDER ──
            _EngineOrderSection(
              engines: visibleEngines,
              color: widget.primaryColor,
              onReorder: (engines) {
                _ttsService.reorderEngines([...engines, ...hiddenEngines]);
              },
              onToggle: (id, enabled) {
                _ttsService.toggleEngine(id, enabled);
              },
            ),
            const SizedBox(height: 16),

            // ── SERVER & API (PSRC-18: đồng bộ 1 nơi với Home Server & API) ──
            ServerApiSyncSection(
              color: widget.primaryColor,
              onConfiguredChanged: () {
                if (mounted) setState(() {});
              },
            ),
            const SizedBox(height: 16),

            // ── ENGINE STATUS ──
            _EngineStatusSection(color: widget.primaryColor),
            const SizedBox(height: 16),

            // ── CACHE INFO ──
            _CacheSection(color: widget.primaryColor),
            const SizedBox(height: 16),

            // ── LICENSES ──
            _LicenseSection(color: widget.primaryColor),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════
// PRIORITY SELECTOR
// ═══════════════════════════════════════════

class _PrioritySelector extends StatelessWidget {
  final TtsPriority current;
  final Color color;
  final ValueChanged<TtsPriority> onChanged;

  const _PrioritySelector({
    required this.current,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chế độ phát',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[400],
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: TtsPriority.values.map((p) {
            final isSelected = p == current;
            return GestureDetector(
              onTap: () => onChanged(p),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        isSelected ? color : Colors.grey.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          p.icon,
                          size: 14,
                          color: isSelected ? color : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          p.label,
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected ? color : Colors.grey[300],
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p.description,
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════
// ENGINE ORDER (kéo thả)
// ═══════════════════════════════════════════

class _EngineOrderSection extends StatelessWidget {
  final List<TtsEngineInfo> engines;
  final Color color;
  final ValueChanged<List<TtsEngineInfo>> onReorder;
  final void Function(String id, bool enabled) onToggle;

  const _EngineOrderSection({
    required this.engines,
    required this.color,
    required this.onReorder,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Thứ tự nguồn phát',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[400],
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              'Kéo để sắp xếp',
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: engines.length,
          onReorder: (oldIndex, newIndex) {
            final list = List<TtsEngineInfo>.from(engines);
            if (newIndex > oldIndex) newIndex--;
            final item = list.removeAt(oldIndex);
            list.insert(newIndex, item);
            onReorder(list);
          },
          itemBuilder: (context, index) {
            final engine = engines[index];
            return Container(
              key: ValueKey(engine.id),
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: engine.isEnabled
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.white.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: engine.isEnabled
                      ? color.withValues(alpha: 0.3)
                      : Colors.grey.withValues(alpha: 0.1),
                ),
              ),
              child: ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.drag_handle,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      context.uiText('${index + 1}'),
                      style: TextStyle(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                title: Text(
                  engine.name,
                  style: TextStyle(
                    fontSize: 13,
                    color: engine.isEnabled ? Colors.white : Colors.grey[600],
                  ),
                ),
                subtitle: Row(
                  children: [
                    Text(
                      engine.description,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (engine.needsApiKey) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.key,
                        size: 10,
                        color: Colors.orange[300],
                      ),
                    ],
                    if (!engine.isOnline) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.cloud_off,
                        size: 10,
                        color: Colors.grey[500],
                      ),
                    ],
                  ],
                ),
                trailing: Switch(
                  value: engine.isEnabled,
                  onChanged: (v) => onToggle(engine.id, v),
                  activeThumbColor: color,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════
// SERVER & API (PSRC-18: đồng bộ 1 nơi với Home Server & API)
// ═══════════════════════════════════════════

@visibleForTesting
class ServerApiSyncSection extends StatelessWidget {
  final Color color;
  final VoidCallback onConfiguredChanged;

  const ServerApiSyncSection({
    super.key,
    required this.color,
    required this.onConfiguredChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: AiProviderStore.instance,
      builder: (context, _) {
        final store = AiProviderStore.instance;
        final ttsProviders = store.enabledProviders
            .where((p) => p.supports(AiRouteCapability.tts))
            .toList(growable: false);
        final active = store.resolveProvider(AiRouteCapability.tts) ??
            (ttsProviders.isNotEmpty ? ttsProviders.first : null);
        final hasTtsApi = active != null;
        final summary = hasTtsApi
            ? context.uiText(
                'Đang đồng bộ TTS: ${active.label}'
                '${(active.ttsModel != null && active.ttsModel!.trim().isNotEmpty) ? ' · ${active.ttsModel}' : ''}',
              )
            : context.uiText(
                'Đồng bộ chung với Server & API ở Home — quản lý tập trung tại một nơi',
              );

        return Material(
          color: Colors.transparent,
          child: InkWell(
            key: const Key('tts-home-api-sync-card'),
            borderRadius: BorderRadius.circular(10),
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AiProvidersScreen(),
                ),
              );
              onConfiguredChanged();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: hasTtsApi
                      ? Colors.green.withValues(alpha: 0.4)
                      : color.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    hasTtsApi
                        ? Icons.cloud_done_outlined
                        : Icons.cloud_sync_outlined,
                    size: 18,
                    color: hasTtsApi ? Colors.greenAccent : color,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.aiProvidersEntryTitle,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          summary,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: hasTtsApi
                                ? Colors.green[200]
                                : Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: Colors.grey[500],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════
// ENGINE STATUS
// ═══════════════════════════════════════════

class _EngineStatusSection extends StatelessWidget {
  final Color color;
  const _EngineStatusSection({required this.color});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, bool>>(
      future: TtsService().checkEngineStatus(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox(
            height: 30,
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        return Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            ...snap.data!.entries.map((e) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (e.value ? Colors.green : Colors.red)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      e.value ? Icons.check_circle : Icons.cancel,
                      size: 12,
                      color: e.value ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      e.key,
                      style: TextStyle(
                        fontSize: 10,
                        color: e.value ? Colors.green[200] : Colors.red[200],
                      ),
                    ),
                  ],
                ),
              );
            }),
            // Piper × = có thể đã có giọng neural nhưng THIẾU phonemizer
            // (espeak-ng-data) — giải thích ngay tại đây để không hiểu
            // nhầm là model hỏng (regression TTS-PIPER-001).
            if (snap.data!.entries
                .any((e) => e.key.contains('Piper') && !e.value))
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.info_outline,
                        size: 11, color: Colors.orange),
                    const SizedBox(width: 4),
                    Text(
                      'Piper × : chưa có giọng HOẶC thiếu phonemizer '
                      '(espeak-ng-data) — cài tại TTS → Quản lý model',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.orange[200],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════
// CACHE
// ═══════════════════════════════════════════

class _CacheSection extends StatelessWidget {
  final Color color;
  const _CacheSection({required this.color});

  @override
  Widget build(BuildContext context) {
    final service = TtsService();

    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        service.getCacheSizeMB(),
        service.getCacheCount(),
      ]),
      builder: (context, snap) {
        final sizeMB = snap.data?[0] as double? ?? 0;
        final count = snap.data?[1] as int? ?? 0;

        return Row(
          children: [
            Icon(Icons.storage, size: 14, color: Colors.grey[500]),
            const SizedBox(width: 6),
            Text(
              context.uiText('Cache: $count files (${sizeMB.toStringAsFixed(1)} MB)'),
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
            const Spacer(),
            if (count > 0)
              GestureDetector(
                onTap: () async {
                  await service.clearCache();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã xóa cache TTS!')),
                  );
                },
                child: Text(
                  'Xóa',
                  style: TextStyle(fontSize: 11, color: Colors.red[300]),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════
// HEADER
// ═══════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _PiperVoicePicker extends StatefulWidget {
  const _PiperVoicePicker();

  @override
  State<_PiperVoicePicker> createState() => _PiperVoicePickerState();
}

class _PiperVoicePickerState extends State<_PiperVoicePicker> {
  Map<String, String> _selected = {};

  @override
  void initState() {
    super.initState();
    SherpaModelManager().initialize();
    PiperVoicePrefs.instance.all().then((v) {
      if (mounted) setState(() => _selected = v);
    });
  }

  String _langLabel(String code) {
    switch (code.toLowerCase()) {
      case 'vi-vn':
      case 'vi':
        return '🇻🇳 Tiếng Việt (vi-VN)';
      case 'en-us':
      case 'en':
        return '🇺🇸 Tiếng Anh (en-US)';
      case 'en-gb':
        return '🇬🇧 Tiếng Anh Anh (en-GB)';
      case 'zh-cn':
      case 'zh':
        return '🇨🇳 Tiếng Trung (zh-CN)';
      case 'fr-fr':
      case 'fr':
        return '🇫🇷 Tiếng Pháp (fr-FR)';
      case 'de-de':
      case 'de':
        return '🇩🇪 Tiếng Đức (de-DE)';
      case 'es-es':
      case 'es':
        return '🇪🇸 Tiếng Tây Ban Nha (es-ES)';
      case 'hi-in':
      case 'hi':
        return '🇮🇳 Tiếng Hindi (hi-IN)';
      case 'ja-jp':
      case 'ja':
        return '🇯🇵 Tiếng Nhật (ja-JP)';
      case 'ko-kr':
      case 'ko':
        return '🇰🇷 Tiếng Hàn (ko-KR)';
      case 'th-th':
      case 'th':
        return '🇹🇭 Tiếng Thái (th-TH)';
      case 'pi-in':
      case 'pi':
        return '🪷 Tiếng Pali (pi)';
      case 'sa-in':
      case 'sa':
        return '🕉️ Tiếng Sanskrit (sa)';
      case 'other':
        return '🌐 Khác / Tự do';
      default:
        return '🌐 $code';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SherpaPiperInfo>(
      stream: SherpaModelManager().watchPiper(),
      initialData: SherpaModelManager().piperInfo,
      builder: (context, snap) {
        final voices = snap.data?.voices ?? const <PiperTtsVoice>[];
        if (voices.isEmpty) {
          return Text(
            context.uiText(
              'Chưa có giọng Piper. Import trong Quản lý Model AI (Home).',
            ),
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          );
        }
        final byLang = <String, List<PiperTtsVoice>>{};
        for (final v in voices) {
          // PSRC-230 — ưu tiên ngôn ngữ khai báo trong `<name>.onnx.json` để
          // nhóm ĐÚNG giọng mà engine sẽ dùng (tên giọng tự đặt có thể không
          // mang mã ngôn ngữ).
          var lang = v.languageCode.isNotEmpty
              ? v.languageCode
              : SherpaPiperTtsCore.langFromVoiceName(v.name);
          if (lang.isEmpty) {
            lang = 'other';
          } else {
            lang = PiperVoicePrefs.normalizeLang(lang);
          }
          byLang.putIfAbsent(lang, () => []).add(v);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.uiText('Giọng Piper theo ngôn ngữ'),
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[400],
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.uiText(
                'Mỗi ngôn ngữ chọn 1 giọng đã import. Tự động ưu tiên phát khi dùng Sherpa TTS.',
              ),
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            for (final entry in byLang.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _langLabel(entry.key),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF80CBC4),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    for (final v in entry.value)
                      RadioListTile<String>(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: v.name,
                        groupValue: _selected[entry.key] ??
                            (entry.value.length == 1 ? v.name : null),
                        activeColor: const Color(0xFF80CBC4),
                        title: Text(
                          v.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        onChanged: (name) async {
                          if (name == null) return;
                          // PSRC-230 — chỉ lưu vào kho giọng RIÊNG của Piper
                          // theo ngôn ngữ. Bản cũ còn gọi
                          // `TtsService().configure(voiceId: name)` (singleton)
                          // ⇒ ghi giọng Việt vào `_selectedVoiceId` DÙNG CHUNG
                          // ⇒ câu tiếng Anh cũng bị đọc bằng giọng đó.
                          await PiperVoicePrefs.instance
                              .setVoiceForLang(entry.key, name);
                          setState(() => _selected[entry.key] = name);
                        },
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// TTS-EDGE-VOICE-001 — bộ chọn giọng Microsoft Edge Neural theo ngôn ngữ.
///
/// Trước đây Edge luôn dùng giọng mặc định (vi-VN → HoaiMy, nữ) vì app chỉ có
/// picker cho Piper. Widget này dùng CATALOG OFFLINE đồng bộ
/// ([EdgeTtsEngine.catalogVoices]) — KHÔNG chờ mạng — nhóm theo ngôn ngữ,
/// radio từng giọng. Lưu vào [EdgeVoicePrefs] (TtsService đọc khi phát bằng
/// Edge). KHÔNG set `_selectedVoiceId` chung để không làm bẩn playback Piper/
/// Zalo/FPT (mỗi engine một kho giọng riêng).
@visibleForTesting
class EdgeVoicePicker extends StatefulWidget {
  final Future<void> Function()? onVoiceChanged;
  final bool loadLiveVoicesOnExpand;

  const EdgeVoicePicker({
    super.key,
    this.onVoiceChanged,
    this.loadLiveVoicesOnExpand = true,
  });

  @override
  State<EdgeVoicePicker> createState() => _EdgeVoicePickerState();
}

class _EdgeVoicePickerState extends State<EdgeVoicePicker> {
  Map<String, String> _selected = {};

  /// TTS-EDGE-VOICE-003 — trạng thái GHIM (xem [EdgeVoicePrefs]).
  bool _pinAll = false;
  String? _pinnedVoice;

  /// Giọng tường minh gần nhất người dùng vừa chạm — dùng làm giá trị mặc
  /// định khi bật ghim (bật ghim rồi mà ghim giọng nữ mặc định thì lại đúng
  /// triệu chứng đang sửa).
  String? _lastExplicitVoice;

  /// PSRC-18: chỉ hiển thị 8 ngôn ngữ tiêu biểu mặc định; phần còn lại nằm
  /// trong vùng mở rộng khi người dùng bấm xem thêm.
  bool _showMoreLanguages = false;
  bool _loadingLiveVoices = false;
  List<TtsVoice> _voices = EdgeTtsEngine.mergedCatalogVoices;

  @override
  void initState() {
    super.initState();
    EdgeVoicePrefs.instance.all().then((v) {
      if (mounted) setState(() => _selected = v);
    });
    EdgeVoicePrefs.instance.pinAllLanguages.then((v) {
      if (mounted) setState(() => _pinAll = v);
    });
    EdgeVoicePrefs.instance.pinnedVoice.then((v) {
      if (mounted) setState(() => _pinnedVoice = v);
    });
  }

  Future<void> _toggleMoreLanguages() async {
    final next = !_showMoreLanguages;
    setState(() => _showMoreLanguages = next);
    if (next && widget.loadLiveVoicesOnExpand && !_loadingLiveVoices) {
      _loadingLiveVoices = true;
      try {
        final merged = await EdgeTtsEngine().loadMergedCatalogVoices();
        if (mounted) {
          setState(() => _voices = merged);
        }
      } finally {
        _loadingLiveVoices = false;
      }
    }
  }

  /// Giọng sẽ ghim: giọng vừa chạm → giọng tiếng Việt đã chọn → giọng đầu
  /// danh mục (cùng giọng mặc định của app khi chưa chọn gì).
  String _voiceToPin() {
    final recent = _lastExplicitVoice;
    if (recent != null && recent.isNotEmpty) return recent;
    for (final key in const ['vi-VN', 'vi']) {
      final stored = _selected[key];
      if (stored != null && stored.isNotEmpty) return stored;
    }
    return EdgeTtsEngine.catalogVoices.first.id;
  }

  Future<void> _togglePin(bool value) async {
    final voice = _voiceToPin();
    await EdgeVoicePrefs.instance.setPinAllLanguages(value, voiceId: voice);
    if (!mounted) return;
    setState(() {
      _pinAll = value;
      _pinnedVoice = voice;
    });
  }

  Future<void> _setPinnedVoice(String voiceId) async {
    await EdgeVoicePrefs.instance.setPinnedVoice(voiceId);
    if (!mounted) return;
    setState(() => _pinnedVoice = voiceId);
  }

  String _langLabel(String code) {
    switch (code.toLowerCase()) {
      case 'vi-vn':
      case 'vi':
        return '🇻🇳 Tiếng Việt (vi-VN)';
      case 'en-us':
      case 'en':
        return '🇺🇸 Tiếng Anh (en-US)';
      case 'en-gb':
        return '🇬🇧 Tiếng Anh Anh (en-GB)';
      case 'zh-cn':
      case 'zh':
        return '🇨🇳 Tiếng Trung (zh-CN)';
      case 'zh-tw':
        return '🇨🇳 Tiếng Trung Đài Loan (zh-TW)';
      case 'ja-jp':
      case 'ja':
        return '🇯🇵 Tiếng Nhật (ja-JP)';
      case 'ko-kr':
      case 'ko':
        return '🇰🇷 Tiếng Hàn (ko-KR)';
      case 'th-th':
      case 'th':
        return '🇹🇭 Tiếng Thái (th-TH)';
      case 'fr-fr':
      case 'fr':
        return '🇫🇷 Tiếng Pháp (fr-FR)';
      case 'de-de':
      case 'de':
        return '🇩🇪 Tiếng Đức (de-DE)';
      case 'es-es':
      case 'es':
        return '🇪🇸 Tiếng Tây Ban Nha (es-ES)';
      case 'ru-ru':
      case 'ru':
        return '🇷🇺 Tiếng Nga (ru-RU)';
      case 'pt-br':
      case 'pt':
        return '🇧🇷 Tiếng Bồ Đào Nha (pt-BR)';
      case 'id-id':
      case 'id':
        return '🇮🇩 Tiếng Indonesia (id-ID)';
      case 'hi-in':
      case 'hi':
        return '🇮🇳 Tiếng Hindi (hi-IN)';
      case 'my-mm':
      case 'my':
        return '🇲🇲 Tiếng Myanmar (my-MM)';
      case 'si-lk':
      case 'si':
        return '🇱🇰 Tiếng Sri Lanka (si-LK)';
      default:
        return '🌐 $code';
    }
  }

  /// Giọng đang chọn của nhóm [lang]: ưu tiên giọng user đã chọn; chưa chọn
  /// thì highlight giọng MẶC ĐỊNH của ngôn ngữ (vd vi-VN → HoaiMy); nhóm chỉ
  /// 1 giọng → highlight giọng đó. Trả về null nếu không có mặc định hợp lệ.
  String? _groupValueFor(String lang, List<TtsVoice> voices) {
    final sel = _selected[lang];
    if (sel != null && voices.any((v) => v.id == sel)) return sel;
    if (voices.length == 1) return voices.first.id;
    final def = EdgeTtsEngine.defaultVoiceForLanguage(lang);
    return voices.any((v) => v.id == def) ? def : null;
  }

  Future<void> _handleSelectVoice(String lang, String id) async {
    await EdgeVoicePrefs.instance.setVoiceForLang(lang, id);
    final freshSelected = await EdgeVoicePrefs.instance.all();
    await widget.onVoiceChanged?.call();
    if (!mounted) return;
    setState(() {
      _selected = freshSelected;
      _lastExplicitVoice = id;
      if (lang == 'other') {
        _pinAll = true;
        _pinnedVoice = id;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final voices = _voices;
    if (voices.isEmpty) return const SizedBox.shrink();

    TtsVoice? pinnedInCatalog;
    for (final v in voices) {
      if (v.id == _pinnedVoice) {
        pinnedInCatalog = v;
        break;
      }
    }

    // Nhóm theo ngôn ngữ (khoá chuẩn hoá), giữ thứ tự ưu tiên của catalog.
    final byLang = <String, List<TtsVoice>>{};
    final order = <String>[];
    for (final v in voices) {
      final lang = EdgeVoicePrefs.normalizeLang(v.language).isEmpty
          ? 'other'
          : EdgeVoicePrefs.normalizeLang(v.language);
      if (!byLang.containsKey(lang)) order.add(lang);
      byLang.putIfAbsent(lang, () => []).add(v);
    }

    // PSRC-18: chỉ hiển thị 8 ngôn ngữ tiêu biểu mặc định theo đúng thứ tự,
    // các quốc gia/ngôn ngữ còn lại gập gọn vào nút mở rộng.
    final featuredOrder = <String>[
      for (final lang in EdgeTtsEngine.featuredLanguages)
        if (byLang.containsKey(lang)) lang,
    ];
    final featuredSet = featuredOrder.toSet();
    final remainingOrder = <String>[
      for (final lang in order)
        if (!featuredSet.contains(lang)) lang,
    ];
    final hasExplicitRemaining =
        remainingOrder.any((lang) => _selected.containsKey(lang));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.uiText('Giọng Microsoft Edge Neural theo ngôn ngữ'),
          style: TextStyle(fontSize: 13, color: Colors.grey[400], fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          context.uiText(
            'Mỗi ngôn ngữ chọn 1 giọng Edge. Tự động áp dụng khi phát bằng '
            'engine Microsoft Edge TTS (không ảnh hưởng Piper/giọng máy).',
          ),
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
        const SizedBox(height: 4),
        // TTS-EDGE-VOICE-003 (nghiệm thu 1.g trên máy thật): tài liệu tiếng
        // Việt có câu tiếng Anh → câu đó nhận diện `en-US`, chưa được cấu
        // hình giọng ⇒ Edge đọc bằng Aria (nữ) dù người dùng đã chọn Nam
        // Minh. Công tắc này cho phép ghim một giọng dùng cho mọi ngôn ngữ
        // CHƯA chọn giọng riêng; mặc định TẮT.
        SwitchListTile(
          key: const Key('edge-voice-pin-switch'),
          dense: true,
          contentPadding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          activeColor: const Color(0xFF64B5F6),
          value: _pinAll,
          onChanged: (v) => _togglePin(v),
          title: Text(
            context.uiText('Ghim một giọng cho mọi ngôn ngữ'),
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            context.uiText(
              'Câu ngoại ngữ trong tài liệu (ví dụ dòng tiếng Anh) sẽ đọc '
              'bằng giọng ghim. Giọng riêng của từng ngôn ngữ vẫn được ưu '
              'tiên.',
            ),
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
          ),
        ),
        if (_pinAll)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    key: const Key('edge-voice-pin-dropdown'),
                    isExpanded: true,
                    // DropdownButton ném assertion nếu `value` không có trong
                    // `items` — giọng ghim có thể đến từ danh mục LIVE (đã
                    // fetch mạng) mà catalog offline không có.
                    value: pinnedInCatalog == null ? null : _pinnedVoice,
                    dropdownColor: const Color(0xFF1A1A2E),
                    underline: const SizedBox.shrink(),
                    style: const TextStyle(fontSize: 11.5, color: Colors.white),
                    items: [
                      for (final v in voices)
                        DropdownMenuItem<String>(
                          value: v.id,
                          child: Text(
                            context.uiText('${v.name} ${v.gender == 'male' ? '♂' : '♀'} · '
                            '${EdgeVoicePrefs.normalizeLang(v.language)}'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (id) {
                      if (id != null) _setPinnedVoice(id);
                    },
                  ),
                ),
                if (pinnedInCatalog == null && _pinnedVoice != null) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '${context.uiText('Đang ghim')}: ${_pinnedVoice!}',
                      style:
                          const TextStyle(fontSize: 10, color: Colors.white54),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 8),
        // TTS-EDGE-VOICE-002 (audit 1.f): trước đây đổ THẲNG toàn bộ danh
        // mục (~16 ngôn ngữ × nhiều giọng) thành một rừng RadioListTile —
        // phải cuộn rất lâu mới tới ngôn ngữ của mình. Giờ mỗi ngôn ngữ là
        // MỘT dòng gập lại, hiện đúng giọng đang chọn; bung ra mới thấy
        // danh sách giọng của riêng ngôn ngữ đó.
        for (final lang in featuredOrder)
          _EdgeVoiceLanguageTile(
            tileKey: Key('edge-voice-lang-$lang'),
            languageLabel: _langLabel(lang),
            voices: byLang[lang]!,
            selectedVoiceId: _groupValueFor(lang, byLang[lang]!),
            isExplicit: _selected.containsKey(lang),
            onSelected: (id) => _handleSelectVoice(lang, id),
          ),
        if (remainingOrder.isNotEmpty) ...[
          const SizedBox(height: 4),
          InkWell(
            key: const Key('edge-voice-more-languages-toggle'),
            borderRadius: BorderRadius.circular(8),
            onTap: _toggleMoreLanguages,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: hasExplicitRemaining
                      ? const Color(0xFF64B5F6).withValues(alpha: 0.45)
                      : Colors.white12,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _showMoreLanguages ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: const Color(0xFF64B5F6),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _showMoreLanguages
                          ? context.uiText('Thu gọn ngôn ngữ khác')
                          : context.uiText(
                              'Xem thêm ngôn ngữ khác (${remainingOrder.length})',
                            ),
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64B5F6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (hasExplicitRemaining && !_showMoreLanguages)
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF64B5F6),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_showMoreLanguages) ...[
            const SizedBox(height: 4),
            for (final lang in remainingOrder)
              _EdgeVoiceLanguageTile(
                tileKey: Key('edge-voice-lang-$lang'),
                languageLabel: _langLabel(lang),
                voices: byLang[lang]!,
                selectedVoiceId: _groupValueFor(lang, byLang[lang]!),
                isExplicit: _selected.containsKey(lang),
                onSelected: (id) => _handleSelectVoice(lang, id),
              ),
          ],
        ],
      ],
    );
  }
}

/// Một ngôn ngữ = một dòng gập (TTS-EDGE-VOICE-002 / PSRC-18).
class _EdgeVoiceLanguageTile extends StatelessWidget {
  const _EdgeVoiceLanguageTile({
    this.tileKey,
    required this.languageLabel,
    required this.voices,
    required this.selectedVoiceId,
    required this.isExplicit,
    required this.onSelected,
  });

  final Key? tileKey;
  final String languageLabel;
  final List<TtsVoice> voices;
  final String? selectedVoiceId;

  /// true = người dùng đã tự chọn; false = đang là giọng mặc định.
  final bool isExplicit;

  final Future<void> Function(String voiceId) onSelected;

  static String _genderMark(TtsVoice voice) =>
      voice.gender == 'male' ? '♂' : '♀';

  @override
  Widget build(BuildContext context) {
    TtsVoice? current;
    for (final voice in voices) {
      if (voice.id == selectedVoiceId) {
        current = voice;
        break;
      }
    }

    final summary = current == null
        ? context.uiText('Giọng mặc định')
        : '${context.uiText(current.name)} ${_genderMark(current)}'
            '${isExplicit ? '' : ' · ${context.uiText('mặc định')}'}';

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: tileKey,
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(left: 8, bottom: 4),
        dense: true,
        visualDensity: VisualDensity.compact,
        iconColor: const Color(0xFF64B5F6),
        collapsedIconColor: Colors.white38,
        title: Row(
          children: [
            Expanded(
              child: Text(
                context.uiText(languageLabel),
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF64B5F6),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              context.uiText('${voices.length}'),
              style: const TextStyle(fontSize: 10, color: Colors.white30),
            ),
          ],
        ),
        subtitle: Text(
          summary,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: Colors.white60),
        ),
        children: [
          for (final v in voices)
            InkWell(
              key: Key('edge-voice-option-${v.id}'),
              borderRadius: BorderRadius.circular(6),
              // PSRC-18: cho phép chạm vào CẢ giọng đang mặc định (vd Hoài My)
              // để ghi nhận lựa chọn tường minh vào EdgeVoicePrefs và kích hoạt
              // ưu tiên Microsoft Edge TTS ngay cả ở chế độ offlineFirst.
              onTap: () => onSelected(v.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Row(
                  children: [
                    Icon(
                      v.id == selectedVoiceId
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 18,
                      color: v.id == selectedVoiceId
                          ? const Color(0xFF64B5F6)
                          : Colors.white38,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.uiText(v.name),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _genderMark(v),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════
// VIENEU MODEL IMPORT (TTS-VIENEU-IMPORT-001)
// ════════════════════════════════════════════

class _VieneuModelImportSection extends StatefulWidget {
  /// Gọi khi danh sách giọng có thể đã đổi (import GGUF kèm voices, import
  /// thư mục voices) — parent sẽ notify để picker reload (PSRC-183/186).
  final VoidCallback? onVoicesChanged;

  const _VieneuModelImportSection({this.onVoicesChanged});

  @override
  State<_VieneuModelImportSection> createState() =>
      _VieneuModelImportSectionState();
}

/// Trạng thái import được lưu dưới dạng KEY nguồn + tham số, KHÔNG lưu chuỗi
/// đã dịch. `build()` dịch lại mỗi lần locale đổi (Rule #5) và điền giá trị
/// runtime — tránh dịch hai lần và tránh giữ tiếng Việt khi đổi sang `en`.
class _ImportStatus {
  final String key;
  final List<String> args;
  final String? suffixKey;
  final List<String> suffixArgs;

  /// Key dịch của mảnh engine còn thiếu (`sea_g2p.bin`, lib native…).
  ///
  /// PSRC-215/216: thông điệp phải nêu ĐÚNG thứ còn thiếu; giữ dạng KEY (không
  /// phải chuỗi đã dịch) để đổi locale vẫn dịch lại được.
  final String? blockerKey;

  const _ImportStatus(
    this.key, {
    this.args = const <String>[],
    this.suffixKey,
    this.suffixArgs = const <String>[],
    this.blockerKey,
  });

  String localize(BuildContext context) {
    String fill(String sourceKey, List<String> values) {
      var text = context.uiText(sourceKey);
      for (var i = 0; i < values.length; i++) {
        text = text.replaceAll('{value$i}', values[i]);
      }
      return text;
    }

    final values = <String>[...args];
    if (blockerKey != null) values.add(context.uiText(blockerKey!));
    final text = fill(key, values);
    return suffixKey == null ? text : text + fill(suffixKey!, suffixArgs);
  }
}

class _VieneuModelImportSectionState
    extends State<_VieneuModelImportSection> {
  VieneuModelVariant _selectedVariant = VieneuModelVariant.q8_0;
  bool _importing = false;
  VieneuModelVariant? _importingVariant;
  _ImportStatus? _status;
  bool _statusIsError = false;
  final Map<VieneuModelVariant, String?> _variantModelPaths = {};
  bool _engineReady = false;

  /// PSRC-187: bản cài có thư viện native của VieNeu không (`null` = chưa dò).
  bool? _nativeBundled;

  /// Lane L6 / ADR-0028 — trạng thái từ điển phát âm SEA-G2P. Model chỉ nhận
  /// phoneme, nên thiếu `sea_g2p.bin` thì engine có mặt cũng chưa đọc được.
  bool? _g2pInstalled;
  int _g2pBytes = 0;
  bool _g2pBusy = false;
  double _g2pProgress = 0;

  @override
  void initState() {
    super.initState();
    _engineReady = VieneuTtsEngine.instance.isInitialized;
    _checkAllModels();
  }

  Future<void> _checkAllModels() async {
    final paths = <VieneuModelVariant, String?>{};
    for (final v in VieneuModelVariant.values) {
      paths[v] = await VieneuTtsCore.modelPathFor(v);
    }
    final nativeBundled = await VieneuTtsCore.isNativeLibraryAvailable();
    final g2p = await VieneuG2pDictionaryService.instance.status();
    // PSRC-183: radio phải phản ánh ĐÚNG biến thể đã lưu (đã đồng bộ với
    // file thật ở TtsService), không được tự ý về Q8_0 mỗi lần mở Settings.
    final persisted = await TtsService().getSelectedVieneuModelVariant();
    if (!mounted) return;
    setState(() {
      _nativeBundled = nativeBundled;
      _g2pInstalled = g2p.installed;
      _g2pBytes = g2p.bytes;
      _variantModelPaths
        ..clear()
        ..addAll(paths);
      final imported = paths.entries
          .where((e) => e.value != null)
          .map((e) => e.key)
          .toList();
      if (paths[persisted] != null) {
        _selectedVariant = persisted;
      } else if (imported.isNotEmpty) {
        _selectedVariant = imported.first;
      }
    });
  }

  /// Lane L6 / ADR-0028 — tải `sea_g2p.bin` (≈60 MB) từ GitHub release đang
  /// ghim (v0.10.0, khớp submodule native). Tải ra `.part`, kiểm sha256 rồi
  /// mới thay file đang dùng.
  Future<void> _downloadG2p() async {
    if (_g2pBusy) return;
    setState(() {
      _g2pBusy = true;
      _g2pProgress = 0;
      _status = null;
    });
    try {
      final status = await VieneuG2pDictionaryService.instance.download(
        onProgress: (fraction) {
          if (!mounted) return;
          setState(() => _g2pProgress = fraction);
        },
      );
      if (!mounted) return;
      setState(() {
        _g2pBusy = false;
        _g2pInstalled = status.installed;
        _g2pBytes = status.bytes;
        _status = _ImportStatus(
          'Đã cài từ điển phát âm ({value0})',
          args: <String>[status.sizeLabel],
        );
        _statusIsError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _g2pBusy = false;
        _status = _ImportStatus(_g2pFailureKey(e));
        _statusIsError = true;
      });
    }
  }

  /// Chọn `sea_g2p.bin` từ máy (đã tải sẵn, thẻ nhớ, Drive…).
  Future<void> _pickG2pFile() async {
    if (_g2pBusy) return;
    final picked = await FilePicker.pickFiles(
      type: FileType.any,
      dialogTitle: context.uiText('Chọn tệp sea_g2p.bin'),
    );
    final path = picked?.files.single.path;
    if (path == null) return;

    setState(() {
      _g2pBusy = true;
      _status = null;
    });
    try {
      final status =
          await VieneuG2pDictionaryService.instance.importFromFile(path);
      if (!mounted) return;
      setState(() {
        _g2pBusy = false;
        _g2pInstalled = status.installed;
        _g2pBytes = status.bytes;
        _status = _ImportStatus(
          'Đã cài từ điển phát âm ({value0})',
          args: <String>[status.sizeLabel],
        );
        _statusIsError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _g2pBusy = false;
        _status = _ImportStatus(_g2pFailureKey(e));
        _statusIsError = true;
      });
    }
  }

  /// Dịch lỗi của service thành câu hiển thị (giữ service không phụ thuộc UI).
  String _g2pFailureKey(Object error) {
    if (error is VieneuG2pException) {
      switch (error.reason) {
        case VieneuG2pFailure.checksum:
          return 'Tệp từ điển tải về không khớp kiểm tra — thử lại sau';
        case VieneuG2pFailure.notDictionary:
          return 'Tệp không phải sea_g2p.bin hợp lệ';
        case VieneuG2pFailure.storage:
          return 'Không ghi được từ điển vào bộ nhớ app';
        case VieneuG2pFailure.network:
          return 'Không tải được từ điển — kiểm tra mạng rồi thử lại';
      }
    }
    return 'Không cài được từ điển phát âm';
  }

  Widget _buildG2pCard(BuildContext context) {
    final installed = _g2pInstalled ?? false;
    final sizeLabel = _g2pBytes > 0
        ? formatVieneuDictionarySize(_g2pBytes)
        : formatVieneuDictionarySize(vieneuG2pDictBytes);
    final accent = installed ? Colors.green : Colors.orange;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                installed ? Icons.spellcheck : Icons.report_problem_outlined,
                size: 14,
                color: accent[300],
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  context.uiText('Từ điển phát âm (SEA-G2P)'),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (_g2pInstalled != null)
                Text(
                  installed
                      ? context
                          .uiText('Đã có từ điển ({value0})')
                          .replaceAll('{value0}', sizeLabel)
                      : context.uiText('Chưa có từ điển phát âm'),
                  style: TextStyle(fontSize: 9.5, color: accent[200]),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            context.uiText(
              'Model chỉ nhận phiên âm, không nhận chữ thô — thiếu từ điển '
              'này VieNeu chưa đọc được.',
            ),
            style: TextStyle(fontSize: 9.5, color: Colors.grey[400]),
          ),
          const SizedBox(height: 8),
          if (_g2pBusy) ...[
            LinearProgressIndicator(
              value: _g2pProgress > 0 ? _g2pProgress : null,
              minHeight: 4,
            ),
            const SizedBox(height: 4),
            Text(
              context
                  .uiText('Đang tải từ điển… {value0}%')
                  .replaceAll(
                    '{value0}',
                    (_g2pProgress * 100).round().toString(),
                  ),
              style: TextStyle(fontSize: 9.5, color: Colors.grey[400]),
            ),
          ] else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: installed ? null : _downloadG2p,
                    icon: const Icon(Icons.download, size: 14),
                    label: Text(
                      context.uiText('Tải từ điển (~60 MB)'),
                      style: const TextStyle(fontSize: 10),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.grey[600]!),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickG2pFile,
                    icon: const Icon(Icons.file_open, size: 14),
                    label: Text(
                      context.uiText('Chọn tệp sea_g2p.bin'),
                      style: const TextStyle(fontSize: 10),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: BorderSide(color: Colors.grey[600]!),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// LỐI IMPORT MODEL DUY NHẤT — dùng cho cả nút trên từng dòng biến thể
  /// (mục phía trên) và nút "Import Q8_0 (~170 MB)" (mục phía dưới).
  ///
  /// PSRC-214: trước 1.29 hai nút là hai hàm khác nhau và không nút nào kiểm
  /// tệp; nút phía trên còn ghi tệp theo BIẾN THỂ CỦA DÒNG thay vì theo tệp
  /// thật ⇒ người dùng chọn đúng model mà dòng tương ứng vẫn "Chưa import".
  /// Nay mọi lối đi qua [_importModelPath] → `TtsService.importVieneuModel`
  /// (kiểm GGUF + tự nhận biến thể) và luôn kết thúc bằng một trạng thái nói
  /// thật, kể cả khi người dùng huỷ hộp chọn tệp.
  Future<void> _pickModelAndImport(VieneuModelVariant variant) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['gguf'],
      dialogTitle: context.uiText('Chọn file model VieNeu-TTS {value0}')
          .replaceAll('{value0}', variant.label),
    );
    final path = result?.files.isNotEmpty == true
        ? result!.files.first.path
        : null;
    if (path == null) {
      // Một số nền tảng (SAF/cloud) trả `path = null` và trước đây im lặng
      // tuyệt đối — người dùng bấm Import mà không thấy gì xảy ra.
      if (result != null && mounted) {
        setState(() {
          _status = const _ImportStatus(
              'Không đọc được tệp đã chọn — thử chọn lại');
          _statusIsError = true;
        });
      }
      return;
    }
    await _importModelPath(path, requested: variant);
  }

  /// Nhập một đường dẫn model đã có (chọn tệp, hoặc fallback nhiều tệp).
  Future<void> _importModelPath(
    String path, {
    required VieneuModelVariant requested,
  }) async {
    setState(() {
      _importing = true;
      _importingVariant = requested;
      _status = null;
    });

    try {
      final imported = await TtsService()
          .importVieneuModel(File(path), variant: requested);
      await _checkAllModels();
      widget.onVoicesChanged?.call();
      if (!mounted) return;
      setState(() {
        _importing = false;
        _importingVariant = null;
        _selectedVariant = imported.variant;
        _engineReady = imported.engineReady;
        // PSRC-215: KHÔNG báo "thành công" trơn khi engine còn thiếu mảnh.
        _statusIsError = !imported.engineReady;
        final name = p.basename(imported.modelPath);
        final voices = imported.importedVoices;
        // Bốn tổ hợp: có/không có giọng mẫu × engine nạp được/nạp không được.
        // Mỗi tổ hợp một KEY riêng (không ghép câu) để 8 locale dịch được.
        if (imported.engineReady) {
          _status = voices > 0
              ? _ImportStatus(
                  'Đã import {value0} · {value1} giọng mẫu · engine sẵn sàng',
                  args: <String>[name, '$voices'],
                )
              : _ImportStatus(
                  'Đã import {value0} · engine sẵn sàng',
                  args: <String>[name],
                );
        } else {
          _status = voices > 0
              ? _ImportStatus(
                  'Đã import {value0} · {value1} giọng mẫu nhưng '
                  'engine chưa sẵn sàng: {value2}',
                  args: <String>[name, '$voices'],
                  blockerKey: imported.blockerMessage,
                )
              : _ImportStatus(
                  'Đã import {value0} nhưng engine chưa sẵn sàng: {value1}',
                  args: <String>[name],
                  blockerKey: imported.blockerMessage,
                );
        }
      });
    } on VieneuModelImportException catch (e) {
      // Tệp không dùng được (không phải GGUF / tải hụt / rỗng): nói đúng lý do.
      if (!mounted) return;
      setState(() {
        _importing = false;
        _importingVariant = null;
        // `message` là KEY dịch (không nội suy) — UI dịch theo locale.
        _status = _ImportStatus(e.message);
        _statusIsError = true;
      });
    } catch (e) {
      debugPrint('⚠️ VieNeu import error: $e');
      if (!mounted) return;
      setState(() {
        _importing = false;
        _importingVariant = null;
        _status = _ImportStatus(
          'Lỗi import {value0}',
          args: <String>[requested.label],
        );
        _statusIsError = true;
      });
    }
  }

  /// PSRC-186 — import TRỌN BỘ (GGUF + voices/) từ thư mục gốc. Cần khi
  /// file_picker trả bản copy trong cache (Android/SAF) và không thể tự dò
  /// thư mục voices cạnh file GGUF.
  Future<void> _pickBundleFolder() async {
    String? dirPath;
    try {
      dirPath = await FilePicker.getDirectoryPath(
        dialogTitle: context.uiText('Chọn thư mục chứa bộ model VieNeu-TTS'),
      );
    } catch (_) {}
    setState(() {
      _importing = true;
      _status = null;
    });
    try {
      if (dirPath != null) {
        final result =
            await TtsService().importVieneuBundleFromDirectory(dirPath);
        await _afterBundleImport(
          result.modelPath,
          result.importedVoices,
          readiness: result.readiness,
        );
        return;
      }
      // Android/iOS: fallback chọn nhiều file .gguf; giọng mẫu import qua
      // nút "Import giọng từ thư mục" (có fallback chọn nhiều file).
      final picked = await FilePicker.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: const ['gguf'],
        dialogTitle: context.uiText('Chọn file model VieNeu-TTS (.gguf)'),
      );
      if (picked == null || picked.files.isEmpty) {
        if (!mounted) return;
        setState(() => _importing = false);
        return;
      }
      var voices = 0;
      String firstPath = '';
      VieneuEngineProbe? readiness;
      for (final file in picked.files) {
        final path = file.path;
        if (path == null) continue;
        final name = file.name.toLowerCase();
        final variant = name.contains('bf16') || name.contains('f16')
            ? VieneuModelVariant.bf16
            : VieneuModelVariant.q8_0;
        // PSRC-214: biến thể thật do service tự nhận từ tên tệp.
        final result =
            await TtsService().importVieneuModel(File(path), variant: variant);
        if (firstPath.isEmpty) firstPath = result.modelPath;
        readiness ??= result.readiness;
        voices += result.importedVoices;
      }
      await _afterBundleImport(firstPath, voices, readiness: readiness);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _importing = false;
        _status = _ImportStatus('Lỗi import bộ model');
        _statusIsError = true;
      });
    }
  }

  Future<void> _afterBundleImport(
    String modelPath,
    int voices, {
    VieneuEngineProbe? readiness,
  }) async {
    if (!mounted) return;
    await _checkAllModels();
    widget.onVoicesChanged?.call();
    if (!mounted) return;
    final blocker = readiness?.blocker;
    setState(() {
      _importing = false;
      _engineReady = readiness?.ready ?? _engineReady;
      // PSRC-215: import xong vẫn phải nói engine có nạp được hay không.
      _statusIsError = blocker != null;
      if (blocker != null) {
        _status = _ImportStatus(
          modelPath.isEmpty
              ? 'Đã import {value0} giọng mẫu nhưng engine chưa sẵn sàng: {value1}'
              : 'Đã import {value0} nhưng engine chưa sẵn sàng: {value1}',
          args: <String>[
            modelPath.isEmpty ? '$voices' : p.basename(modelPath),
          ],
          blockerKey: vieneuEngineBlockerMessage(blocker),
        );
      } else {
        _status = modelPath.isEmpty
            ? _ImportStatus(
                'Đã import {value0} giọng mẫu',
                args: <String>['$voices'],
              )
            : _ImportStatus(
                'Đã import {value0} · {value1} giọng mẫu',
                args: <String>[p.basename(modelPath), '$voices'],
              );
      }
    });
  }

  /// PSRC-185/186 — import giọng từ thư mục có sẵn (chứa các subfolder voice).
  Future<void> _pickVoicesFolder() async {
    String? dirPath;
    try {
      dirPath = await FilePicker.getDirectoryPath(
        dialogTitle: context.uiText('Chọn thư mục chứa giọng VieNeu-TTS'),
      );
    } catch (_) {}
    setState(() {
      _importing = true;
      _status = null;
    });
    try {
      if (dirPath == null) {
        // Fallback platform không có directory picker: chọn nhiều file dữ
        // liệu giọng (ref_codes.txt / speaker.emb.txt / ref_codes.bin).
        final picked = await FilePicker.pickFiles(
          allowMultiple: true,
          type: FileType.custom,
          allowedExtensions: const ['txt', 'bin'],
          dialogTitle: context.uiText('Chọn file dữ liệu giọng VieNeu-TTS'),
        );
        if (picked == null || picked.files.isEmpty) {
          if (!mounted) return;
          setState(() => _importing = false);
          return;
        }
        final paths = picked.files
            .map((f) => f.path)
            .whereType<String>()
            .toList();
        final count = await TtsService().importVieneuVoiceFiles(paths);
        await _afterVoicesImport(count);
        return;
      }
      final count = await TtsService().importVieneuVoicesFromDirectory(dirPath);
      await _afterVoicesImport(count);
    } on VieneuVoiceImportException catch (e) {
      // PSRC-217: nói đúng lý do (không có dữ liệu giọng / không đọc được thư
      // mục) thay vì câu chung "Lỗi import giọng" mà người dùng không hiểu.
      debugPrint('⚠️ VieNeu import giọng lỗi: $e');
      if (!mounted) return;
      setState(() {
        _importing = false;
        _status = _ImportStatus(
          vieneuVoiceImportProblemMessage(e.problem),
        );
        _statusIsError = true;
      });
    } catch (e) {
      debugPrint('⚠️ VieNeu import giọng lỗi: $e');
      if (!mounted) return;
      setState(() {
        _importing = false;
        _status = _ImportStatus('Lỗi import giọng');
        _statusIsError = true;
      });
    }
  }

  Future<void> _afterVoicesImport(int count) async {
    if (!mounted) return;
    await _checkAllModels();
    widget.onVoicesChanged?.call();
    if (!mounted) return;
    setState(() {
      _importing = false;
      // `0` = các giọng đó đã có sẵn trong app (không phải lỗi) — PSRC-217.
      _status = count == 0
          ? const _ImportStatus('Các giọng này đã có trong ứng dụng')
          : _ImportStatus(
              'Đã import {value0} giọng từ thư mục',
              args: <String>['$count'],
            );
      _statusIsError = false;
    });
  }

  /// "Khởi tạo engine" — PSRC-216.
  ///
  /// Trước 1.29 nút này gọi `init()` rồi, nếu thất bại, hiện MỘT câu chung
  /// ("kiểm tra file .gguf và thư viện native") cho mọi nguyên nhân khác nhau:
  /// chưa có model / file hỏng / bản cài thiếu lib native / thiếu
  /// `sea_g2p.bin`. Nay hỏi [VieneuTtsEngine.probe] TRƯỚC, nêu đúng mảnh còn
  /// thiếu + nút tải từ điển ngay bên dưới, và khi native báo lỗi thì hiện
  /// nguyên văn lỗi đó.
  Future<void> _initializeEngine(VieneuModelVariant variant) async {
    final engine = VieneuTtsEngine.instance;
    final probe = await engine.probe(modelVariant: variant);
    if (!mounted) return;
    if (probe.blocker != null) {
      setState(() {
        _engineReady = false;
        // `args` rỗng ⇒ mảnh còn thiếu (blockerKey) chính là {value0}.
        _status = _ImportStatus(
          'Chưa khởi tạo được engine: {value0}',
          blockerKey: probe.message,
        );
        _statusIsError = true;
      });
      return;
    }

    await engine.init(modelVariant: variant);
    if (!mounted) return;
    final nativeError = engine.lastInitError;
    setState(() {
      _engineReady = engine.isInitialized;
      if (_engineReady) {
        _status = _ImportStatus(
          'Đã khởi tạo engine VieNeu-TTS ({value0})',
          args: <String>[variant.label],
        );
      } else {
        // Lỗi native nguyên văn (nếu có) — để log/issue biết chính xác thiếu gì.
        _status = _ImportStatus(
          'Khởi tạo engine thất bại: {value0}',
          args: <String>[nativeError ?? 'native'],
        );
      }
      _statusIsError = !_engineReady;
    });
  }

  @override
  Widget build(BuildContext context) {
    final anyModel = _variantModelPaths.values.any((p) => p != null);
    final selectedPath = _variantModelPaths[_selectedVariant];
    final selectedImported = selectedPath != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Model VieNeu-TTS (.gguf)',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[400],
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (anyModel ? Colors.green : Colors.orange)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (anyModel ? Colors.green : Colors.orange)
                      .withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    anyModel ? Icons.check_circle : Icons.cloud_download,
                    size: 12,
                    color: anyModel ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    anyModel
                        ? 'Đã có model'
                        : 'Chưa có model — import để kích hoạt',
                    style: TextStyle(
                      fontSize: 10,
                      color: anyModel ? Colors.green[200] : Colors.orange[200],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // PSRC-183 — hai trạng thái TÁCH BIỆT: model đã import vs worker đã
        // nạp. Không còn badge "đã có model" đi kèm cảnh báo "chưa import".
        // PSRC-187: bản cài KHÔNG có engine native thì dòng "engine nạp khi bắt
        // đầu đọc" bên dưới là nói sai (engine không bao giờ nạp được) ⇒ thay
        // bằng câu báo thật. Nếu không, "Đã có model" khiến người dùng tưởng
        // VieNeu đang đọc.
        if (_nativeBundled == false)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.orange.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 14, color: Colors.orange[200]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    context.uiText(kVieneuNativeMissingNotice),
                    style: TextStyle(fontSize: 11, color: Colors.orange[200]),
                  ),
                ),
              ],
            ),
          )
        else
          Row(
            children: [
              Icon(
                _engineReady ? Icons.check_circle : Icons.hourglass_top,
                size: 12,
                color: _engineReady ? Colors.green[300] : Colors.orange[300],
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  context.uiText(_engineReady
                      ? 'Engine đã sẵn sàng'
                      : 'Model đã có · engine nạp khi bắt đầu đọc'),
                  style: TextStyle(fontSize: 9.5, color: Colors.grey[500]),
                ),
              ),
            ],
          ),
        const SizedBox(height: 8),
        // ── CHỌN BIẾN THỂ MÔ HÌNH (GIAI ĐOẠN 3) ──
        Text(
          context.uiText('Phiên bản mô hình'),
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        ...VieneuModelVariant.values.map((variant) {
          final imported = _variantModelPaths[variant] != null;
          final isSelected = _selectedVariant == variant;
          final isImporting = _importingVariant == variant;
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: (isSelected && imported)
                  ? Colors.green.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: (isSelected && imported)
                    ? Colors.green.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 2,
              ),
              title: Text(
                variant.label,
                style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              subtitle: Text(
                imported
                    ? context.uiText(
                        'Đã import · ${_variantModelPaths[variant]!.split('/').last}')
                    : 'Chưa import',
                style: TextStyle(
                  fontSize: 9.5,
                  color: imported ? Colors.green[300] : Colors.grey[600],
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isImporting)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (imported)
                    Icon(
                      isSelected ? Icons.check : Icons.radio_button_unchecked,
                      size: 18,
                      color: isSelected
                          ? Colors.green
                          : Colors.grey[600],
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () => _pickModelAndImport(variant),
                      icon: const Icon(Icons.file_upload, size: 14),
                      label: const Text('Import',
                          style: TextStyle(fontSize: 9.5)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.grey[600]!),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 4),
                      ),
                    ),
                  const SizedBox(width: 6),
                  Radio<VieneuModelVariant>(
                    value: variant,
                    groupValue: _selectedVariant,
                    onChanged: imported
                        ? (v) {
                            if (v != null) {
                              setState(() => _selectedVariant = v);
                              TtsService()
                                  .setSelectedVieneuModelVariant(v);
                            }
                          }
                        : null,
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        Text(
          context.uiText(
            'Q8_0 (~170 MB) là mặc định, cân bằng chất lượng và dung lượng; '
            'bf16 (~292 MB) chất lượng cao hơn, file lớn hơn.',
          ),
          style: TextStyle(fontSize: 9.5, color: Colors.grey[600]),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                    (_importing && _importingVariant == _selectedVariant)
                        ? null
                        : () => _pickModelAndImport(_selectedVariant),
                icon: _importing && _importingVariant == _selectedVariant
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.file_upload, size: 16),
                label: Text(
                  context.uiText(
                    _importing && _importingVariant == _selectedVariant
                        ? 'Đang import ${_selectedVariant.label}...'
                        : 'Import ${_selectedVariant.label}',
                  ),
                  style: const TextStyle(fontSize: 11),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.grey[600]!),
                ),
              ),
            ),
            if (selectedImported) ...[
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _initializeEngine(_selectedVariant),
                icon: const Icon(Icons.play_circle, size: 16),
                label: const Text('Khởi tạo engine',
                    style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green,
                  side: BorderSide(color: Colors.green[700]!),
                ),
              ),
            ],
          ],
        ),
        if (_status != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: (_statusIsError ? Colors.red : Colors.green)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: (_statusIsError ? Colors.red : Colors.green)
                    .withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _statusIsError ? Icons.error : Icons.info,
                  size: 14,
                  color: _statusIsError ? Colors.red[300] : Colors.green[300],
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _status!.localize(context),
                    style: TextStyle(
                      fontSize: 10,
                      color: _statusIsError ? Colors.red[200] : Colors.green[200],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (selectedImported && selectedPath != null) ...[
          const SizedBox(height: 8),
          Text(
            context.uiText('Đường dẫn: $selectedPath'),
            style: TextStyle(fontSize: 9, color: Colors.white38),
            overflow: TextOverflow.ellipsis,
          ),
        ],
        // Lane L6 / ADR-0028 — từ điển phát âm SEA-G2P (model chỉ nhận phoneme)
        _buildG2pCard(context),
        // PSRC-185/186 — import trọn bộ + import giọng từ thư mục
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _importing ? null : _pickBundleFolder,
                icon: const Icon(Icons.folder_special, size: 16),
                label: Text(
                  context.uiText('Import trọn bộ từ thư mục'),
                  style: const TextStyle(fontSize: 11),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green[200],
                  side: BorderSide(color: Colors.green[700]!),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _importing ? null : _pickVoicesFolder,
                icon: const Icon(Icons.folder_open, size: 16),
                label: Text(
                  context.uiText('Import giọng từ thư mục'),
                  style: const TextStyle(fontSize: 11),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: BorderSide(color: Colors.grey[600]!),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          context.uiText(
            'Chọn thư mục chứa các giọng (mỗi giọng là một thư mục con có ref_codes.txt). '
            'voices/ cạnh file .gguf được tự động import; nếu thiết bị chỉ cho chọn file, '
            'dùng "Import trọn bộ từ thư mục" hoặc chọn nhiều file dữ liệu giọng.',
          ),
          style: TextStyle(fontSize: 9, color: Colors.grey[600]),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════
// VIENEU VOICE PICKER (TTS-VIENEU-VOICE-001)
// ════════════════════════════════════════════

class _VieneuVoicePicker extends StatefulWidget {
  const _VieneuVoicePicker();

  @override
  State<_VieneuVoicePicker> createState() => _VieneuVoicePickerState();
}

class _VieneuVoicePickerState extends State<_VieneuVoicePicker> {
  List<TtsVoice> _voices = [];
  String? _selectedVoiceId;
  bool _loading = true;
  bool _modelMissing = false;
  String? _error;
  VieneuModelVariant? _loadedVariant;
  int _loadSeq = 0;

  @override
  void initState() {
    super.initState();
    _loadVoices();
    // PSRC-183: chỉ reload khi revision giọng đổi. Lắng nghe toàn bộ
    // TtsService (notify mỗi nhịp phát nhạc) gây reload + nạp model liên tục.
    TtsService().voicesRevision.addListener(_onVoicesRevision);
  }

  @override
  void dispose() {
    TtsService().voicesRevision.removeListener(_onVoicesRevision);
    super.dispose();
  }

  void _onVoicesRevision() => _loadVoices();

  Future<void> _loadVoices() async {
    final seq = ++_loadSeq;
    if (mounted && !_loading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final engine = VieneuTtsEngine.instance;
      final service = TtsService();
      final variant = await service.getSelectedVieneuModelVariant();
      final modelPath = await VieneuTtsCore.modelPathFor(variant);
      // PSRC-183/186/187: liệt kê giọng CHỈ đọc đĩa. Không gọi
      // `engine.init()` ở đây — nạp 170 MB GGUF chỉ để mở dropdown là nguyên
      // nhân timeout/OOM và cảnh báo "chưa import" bị kẹt lại.
      final voices = await engine.getAvailableVoices('vi-VN');
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _voices = voices;
        _loading = false;
        _error = null;
        _modelMissing = modelPath == null;
        _loadedVariant = variant;
        if (voices.isNotEmpty && _selectedVoiceId == null) {
          _selectedVoiceId = voices.first.id;
        } else if (voices.isNotEmpty &&
            _selectedVoiceId != null &&
            !voices.any((v) => v.id == _selectedVoiceId)) {
          // Giọng cũ không còn → chọn lại
          _selectedVoiceId = voices.first.id;
        }
      });
    } catch (e) {
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _loading = false;
        _error = 'Lỗi tải giọng';
      });
    }
  }

  Future<void> _selectVoice(String voiceId) async {
    try {
      await VieneuTtsEngine.instance.selectVoice(voiceId);
      if (!mounted) return;
      setState(() => _selectedVoiceId = voiceId);
      TtsService().configure(voiceId: voiceId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Lỗi chọn giọng');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Giọng đọc VieNeu-TTS',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[400],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const SizedBox(
            height: 20,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ],
      );
    }

    if (_error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Giọng đọc VieNeu-TTS',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[400],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error, size: 14, color: Colors.redAccent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    context.uiText(_error!),
                    style: TextStyle(fontSize: 10, color: Colors.red[200]),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_voices.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Giọng đọc VieNeu-TTS',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[400],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Chưa có giọng nào. Import model .gguf và khởi tạo engine ở mục trên.',
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ],
      );
    }

    // Hiển thị thông tin variant đang dùng + nút refresh (PSRC-183)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Giọng đọc VieNeu-TTS',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[400],
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (_loadedVariant != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _loadedVariant!.label,
                  style: TextStyle(fontSize: 9, color: Colors.grey[400]),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 16, color: Colors.white54),
              tooltip: context.uiText('Tải lại danh sách giọng'),
              onPressed: () {
                setState(() {
                  _loading = true;
                  _error = null;
                });
                _loadVoices();
              },
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (_loadedVariant != null)
          Text(
            context.uiText('Đang dùng model ${_loadedVariant!.label}'),
            style: TextStyle(fontSize: 9, color: Colors.grey[600]),
          ),
        if (_modelMissing)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              context.uiText('Chưa import model .gguf — giọng mẫu vẫn hiển thị, cần model để đọc'),
              style: TextStyle(fontSize: 9, color: Colors.orange[200]),
            ),
          ),
        const SizedBox(height: 8),
        DropdownButton<String>(
          isExpanded: true,
          value: _selectedVoiceId,
          dropdownColor: const Color(0xFF1A1A2E),
          underline: const SizedBox.shrink(),
          style: const TextStyle(fontSize: 11.5, color: Colors.white),
          hint: Text(
            'Chọn giọng đọc',
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
          items: [
            for (final v in _voices)
              DropdownMenuItem<String>(
                value: v.id,
                child: Row(
                  children: [
                    Text(
                      v.name,
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: (v.origin == 'cloned'
                                ? Colors.purple
                                : Colors.green)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        context.uiText(v.origin == 'cloned'
                            ? 'Đã clone'
                            : v.id == VieneuTtsCore.defaultVoiceId
                                ? 'Mặc định'
                                : 'Giọng mẫu'),
                        style: TextStyle(
                          fontSize: 8,
                          color: v.origin == 'cloned'
                              ? Colors.purple[200]
                              : Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          onChanged: (id) {
            if (id != null) _selectVoice(id);
          },
        ),
      ],
    );
  }
}

/// audio.cpp + VieNeu-TTS đều Apache-2.0 → tương thích với giấy phép
/// in4up Source-Available Non-Commercial License; credit trong Settings.
class _LicenseSection extends StatelessWidget {
  final Color color;

  const _LicenseSection({required this.color});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(
        // Dùng ĐÚNG key ARB: bản PR #133 gọi `uiText('ttsLicenseSection')` —
        // uiText() nhận câu tiếng Việt nguồn, nên nó sẽ hiện nguyên văn chuỗi
        // "ttsLicenseSection" trên UI ở mọi ngôn ngữ.
        AppLocalizations.of(context).ttsLicenseSection,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
      children: const [
        _LicenseTile(
          title: 'audio.cpp',
          subtitle: 'Runtime TTS GGUF (CPU), github.com/0xShug0/audio.cpp',
          license: 'Apache License 2.0',
        ),
        _LicenseTile(
          title: 'VieNeu-TTS v3 Turbo',
          subtitle:
              'Giọng đọc Tiếng Việt (GGUF), pnnbao-ump/VieNeu-TTS-v3-Turbo',
          license: 'Apache License 2.0',
        ),
      ],
    );
  }
}

class _LicenseTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String license;

  const _LicenseTile({
    required this.title,
    required this.subtitle,
    required this.license,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(title, style: const TextStyle(fontSize: 12)),
      subtitle: Text(
        '${context.uiText(subtitle)} · $license',
        style: const TextStyle(fontSize: 10, color: Colors.white60),
      ),
    );
  }
}
