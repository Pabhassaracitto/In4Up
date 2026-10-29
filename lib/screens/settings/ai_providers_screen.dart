// lib/screens/settings/ai_providers_screen.dart
//
// WP0 (API-001) — Màn "Server & API": cấu hình nhà cung cấp AI
// (cloud: Gemini/Groq/OpenRouter/OpenAI… hoặc server nhà: Ollama/LM Studio)
// + chính sách định tuyến offline/online cho từng năng lực.
//
// Nguyên tắc:
// - Chuỗi UI 100% qua AppLocalizations (rule vàng #5 — không literal vi).
// - Tên preset là proper noun (không dịch).
// - KHÔNG log/hiển thị apiKey ở dạng rõ (obscure text field).
// - Chưa cấu hình gì → app hành xử y hệt trước khi có tầng API.

import 'package:flutter/material.dart';
// localized_material = material.dart (hide Text) + extension uiText đã locale-hóa.
// `hide Text` để không đụng `Text` của material (dùng trong file này).
import 'package:in4up/core/language/localized_material.dart' hide Text;
import 'package:in4up/l10n/app_localizations.dart';
import 'package:in4up/services/ai_settings_cloud_sync.dart';
import 'package:in4up_ai/in4up_ai.dart';

/// Preset nhà cung cấp — chỉ là gợi ý điền nhanh form (KHÔNG kèm key).
class _Preset {
  final String name;
  final String baseUrl;
  const _Preset(this.name, this.baseUrl);
}

const _kPresets = <_Preset>[
  _Preset('Gemini', 'https://generativelanguage.googleapis.com/v1beta/openai'),
  _Preset('Groq', 'https://api.groq.com/openai/v1'),
  _Preset('OpenRouter', 'https://openrouter.ai/api/v1'),
  _Preset('OpenAI', 'https://api.openai.com/v1'),
  _Preset('Ollama (LAN)', 'http://192.168.1.10:11434'),
  _Preset('LM Studio (LAN)', 'http://192.168.1.10:1234'),
];

class AiProvidersScreen extends StatefulWidget {
  const AiProvidersScreen({super.key});

  @override
  State<AiProvidersScreen> createState() => _AiProvidersScreenState();
}

class _AiProvidersScreenState extends State<AiProvidersScreen> {
  final _store = AiProviderStore.instance;

  @override
  void initState() {
    super.initState();
    _store.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.aiProvidersTitle),
      ),
      body: ListenableBuilder(
        listenable: _store,
        builder: (context, _) {
          final providers = _store.providers;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.dns_outlined,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.aiProvidersSubtitle,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.aiProvidersPrivacy,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (providers.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.cloud_off_outlined),
                        const SizedBox(width: 12),
                        Expanded(child: Text(l10n.aiProvidersEmpty)),
                      ],
                    ),
                  ),
                )
              else
                ...providers.map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ProviderCard(
                      config: p,
                      onChanged: (next) => _store.upsert(next),
                      onEdit: () => _openForm(p),
                      onDeleted: () => _confirmDelete(p),
                    ),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: () => _openForm(null),
                icon: const Icon(Icons.add),
                label: Text(l10n.aiProviderAdd),
              ),
              const SizedBox(height: 24),
              const _CloudSyncSection(),
              const SizedBox(height: 24),
              _RuntimeReportSection(store: _store),
              const SizedBox(height: 24),
              _RoutingSection(store: _store),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openForm(AiProviderConfig? existing) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ProviderFormDialog(existing: existing),
    );
    if (saved == true && mounted) {
      await _store.ensureLoaded();
    }
  }

  Future<void> _confirmDelete(AiProviderConfig config) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.aiProviderDelete),
        content: Text(l10n.aiProviderDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.aiProviderCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.aiProviderDelete),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _store.remove(config.id);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Card 1 provider
// ═══════════════════════════════════════════════════════════════════════════

class _ProviderCard extends StatefulWidget {
  final AiProviderConfig config;
  final ValueChanged<AiProviderConfig> onChanged;
  final VoidCallback onEdit;
  final VoidCallback onDeleted;

  const _ProviderCard({
    required this.config,
    required this.onChanged,
    required this.onEdit,
    required this.onDeleted,
  });

  @override
  State<_ProviderCard> createState() => _ProviderCardState();
}

class _ProviderCardState extends State<_ProviderCard> {
  AiProviderHealth? _health;
  bool _testing = false;

  AiProviderConfig get _config => widget.config;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final modelChips = <Widget>[
      if (_config.chatModel != null)
        Chip(label: Text(context.uiText('${l10n.aiProviderChatModel}: ${_config.chatModel}'))),
      // API-DIAG-001: model dịch RIÊNG (nếu chưa chọn thì dịch dùng chat
      // model — chip bên dưới nói rõ để không tưởng là đã cấu hình).
      if (_config.translationModel != null)
        Chip(label: Text(context.uiText('${l10n.aiRoutingTranslation}: ${_config.translationModel}'))),
      if (_config.sttModel != null)
        Chip(label: Text(context.uiText('${l10n.aiProviderSttModel}: ${_config.sttModel}'))),
      if (_config.ttsModel != null)
        Chip(label: Text(context.uiText('${l10n.aiProviderTtsModel}: ${_config.ttsModel}'))),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _config.enabled
                      ? Icons.cloud_done_outlined
                      : Icons.cloud_off_outlined,
                  color: _config.enabled
                      ? Colors.green
                      : theme.disabledColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_config.label,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      Text(_config.baseUrl,
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                Semantics(
                  label: l10n.aiProviderEnabled,
                  child: Switch(
                    value: _config.enabled,
                    onChanged: (v) =>
                        widget.onChanged(_config.copyWith(enabled: v)),
                  ),
                ),
              ],
            ),
            if (modelChips.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 4, children: modelChips),
            ],
            if (_health != null) ...[
              const SizedBox(height: 8),
              Text(
                _healthText(l10n),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _health!.ok ? Colors.green : Colors.red,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _testing ? null : _testConnection,
                  icon: _testing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_tethering),
                  label: Text(l10n.aiProviderTestConnection),
                ),
                TextButton.icon(
                  onPressed: widget.onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(l10n.aiProviderEdit),
                ),
                TextButton.icon(
                  onPressed: widget.onDeleted,
                  icon: const Icon(Icons.delete_outline),
                  label: Text(l10n.aiProviderDelete),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _healthText(AppLocalizations l10n) {
    final h = _health!;
    if (h.ok) {
      return '${l10n.aiProviderConnectionOk} · '
          '${h.latency.inMilliseconds} ms · '
          '${h.modelCount ?? 0} ${l10n.aiProviderModelsLabel}';
    }
    final err = h.error;
    return '${l10n.aiProviderConnectionFail}'
        '${err != null ? ' (${err.code.name})' : ''}';
  }

  Future<void> _testConnection() async {
    setState(() => _testing = true);
    final client = OpenAiCompatClient(
      baseUrl: _config.baseUrl,
      apiKey: _config.apiKey,
    );
    final health = await client.healthCheck();
    if (!mounted) return;
    setState(() {
      _testing = false;
      _health = health;
    });
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Form thêm/sửa provider (dialog)
// ═══════════════════════════════════════════════════════════════════════════

class _ProviderFormDialog extends StatefulWidget {
  final AiProviderConfig? existing;
  const _ProviderFormDialog({this.existing});

  @override
  State<_ProviderFormDialog> createState() => _ProviderFormDialogState();
}

class _ProviderFormDialogState extends State<_ProviderFormDialog> {
  late final TextEditingController _label;
  late final TextEditingController _baseUrl;
  late final TextEditingController _apiKey;
  bool _obscureKey = true;

  List<String> _models = const [];
  bool _loadingModels = false;
  String? _loadModelsError;

  String? _chatModel;
  // API-DIAG-001 (owner 2026-10-26): dịch là năng lực RIÊNG — phải chọn được
  // model dịch, không bắt buộc dùng chung chat model nữa.
  String? _translationModel;
  String? _sttModel;
  String? _ttsModel;

  AiProviderHealth? _health;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _label = TextEditingController(text: e?.label ?? '');
    _baseUrl = TextEditingController(
        text: e?.baseUrl ?? _kPresets.first.baseUrl);
    _apiKey = TextEditingController(text: e?.apiKey ?? '');
    _chatModel = e?.chatModel;
    _translationModel = e?.translationModel;
    _sttModel = e?.sttModel;
    _ttsModel = e?.ttsModel;
  }

  @override
  void dispose() {
    _label.dispose();
    _baseUrl.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  OpenAiCompatClient _clientFromFields() => OpenAiCompatClient(
        baseUrl: _baseUrl.text,
        apiKey: _apiKey.text.isEmpty ? null : _apiKey.text,
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.existing == null
          ? l10n.aiProviderAdd
          : l10n.aiProviderEdit),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                value: _detectPreset(),
                decoration: InputDecoration(labelText: l10n.aiProviderPreset),
                items: [
                  ..._kPresets.map(
                    (p) => DropdownMenuItem(value: p.baseUrl, child: Text(p.name)),
                  ),
                  DropdownMenuItem(
                    value: '',
                    child: Text(l10n.aiProviderPresetCustom),
                  ),
                ],
                onChanged: (v) {
                  if (v != null && v.isNotEmpty) {
                    setState(() => _baseUrl.text = v);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _label,
                decoration: InputDecoration(labelText: l10n.aiProviderLabel),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _baseUrl,
                decoration:
                    InputDecoration(labelText: l10n.aiProviderBaseUrl),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _apiKey,
                obscureText: _obscureKey,
                decoration: InputDecoration(
                  labelText: l10n.aiProviderApiKey,
                  hintText: l10n.aiProviderApiKeyHint,
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscureKey ? Icons.visibility : Icons.visibility_off),
                    onPressed: () =>
                        setState(() => _obscureKey = !_obscureKey),
                  ),
                ),
              ),
              // Provider OpenRouter CÓ SẴN: nếu build này không có key
              // (build cục bộ / thiếu secret CI) ⇒ báo rõ để user dán key
              // một lần thay vì tưởng app hỏng.
              if (_isBuiltinOpenRouterWithoutKey) ...[
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline,
                        size: 14, color: Colors.orange),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        context.uiText(
                            'Chưa có API key cho OpenRouter. Dán key (sk-or-v1-…) vào ô trên, hoặc build lại bằng CI có secret OPENROUTER_API_KEY.'),
                        style: const TextStyle(
                            color: Colors.orange, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _testing ? null : _testConnection,
                    icon: _testing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_tethering),
                    label: Text(l10n.aiProviderTestConnection),
                  ),
                  const SizedBox(width: 8),
                  if (_health != null)
                    Expanded(
                      child: Text(
                        _healthText(l10n),
                        style: TextStyle(
                          color: _health!.ok ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                ],
              ),
              const Divider(),
              OutlinedButton.icon(
                onPressed: _loadingModels ? null : _loadModels,
                icon: _loadingModels
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_outlined),
                label: Text(l10n.aiProviderLoadModels),
              ),
              if (_loadModelsError != null) ...[
                const SizedBox(height: 4),
                Text(
                  _loadModelsError!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
              // MODEL-PICKER-001: vẫn hiện 4 ô chọn kể cả khi chưa tải được
              // danh sách — dialog cho GÕ TAY tên model (server nhà/private
              // model không nằm trong /v1/models).
              if (_models.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: Text(l10n.aiProviderNoModels,
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              const SizedBox(height: 12),
              // MODEL-PICKER-001 (owner 2026-10-26): danh sách model của
              // provider thật có thể vài trăm dòng (OpenRouter) — dropdown bắt
              // cuộn tay rất lâu. Đổi sang picker CÓ Ô TÌM KIẾM (+ gõ tay tên
              // model không có trong /v1/models).
              _ModelPickerField(
                label: l10n.aiProviderChatModel,
                models: _models,
                value: _chatModel,
                noneLabel: l10n.aiProviderNone,
                onChanged: (v) => setState(() => _chatModel = v),
              ),
              // API-TRANS-MODEL-001: ô chọn model DỊCH (trước đây không có).
              _ModelPickerField(
                label: context.uiText('Model dịch (dùng cho Dịch thuật)'),
                models: _models,
                value: _translationModel,
                noneLabel:
                    context.uiText('Dùng chung chat model (chưa chọn riêng)'),
                onChanged: (v) => setState(() => _translationModel = v),
              ),
              _ModelPickerField(
                label: l10n.aiProviderSttModel,
                models: _models,
                value: _sttModel,
                noneLabel: l10n.aiProviderNone,
                onChanged: (v) => setState(() => _sttModel = v),
              ),
              _ModelPickerField(
                label: l10n.aiProviderTtsModel,
                models: _models,
                value: _ttsModel,
                noneLabel: l10n.aiProviderNone,
                onChanged: (v) => setState(() => _ttsModel = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.aiProviderCancel),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(l10n.aiProviderSave),
        ),
      ],
    );
  }

  /// Provider OpenRouter có sẵn mà build này KHÔNG có key
  /// (build cục bộ, hoặc CI thiếu secret OPENROUTER_API_KEY).
  bool get _isBuiltinOpenRouterWithoutKey =>
      widget.existing?.id == kBuiltinOpenRouterId &&
      _apiKey.text.trim().isEmpty;

  String _detectPreset() {
    final normalized = OpenAiCompatClient.normalizeBaseUrl(_baseUrl.text);
    for (final p in _kPresets) {
      if (OpenAiCompatClient.normalizeBaseUrl(p.baseUrl) == normalized) {
        return p.baseUrl;
      }
    }
    return '';
  }

  String _healthText(AppLocalizations l10n) {
    final h = _health!;
    if (h.ok) {
      return '${l10n.aiProviderConnectionOk} · '
          '${h.latency.inMilliseconds} ms · '
          '${h.modelCount ?? 0} ${l10n.aiProviderModelsLabel}';
    }
    final err = h.error;
    return '${l10n.aiProviderConnectionFail}'
        '${err != null ? ' (${err.code.name})' : ''}';
  }

  Future<void> _testConnection() async {
    setState(() => _testing = true);
    final health = await _clientFromFields().healthCheck();
    if (!mounted) return;
    setState(() {
      _testing = false;
      _health = health;
    });
  }

  Future<void> _loadModels() async {
    setState(() {
      _loadingModels = true;
      _loadModelsError = null;
    });
    try {
      final models = await _clientFromFields().listModels();
      if (!mounted) return;
      setState(() {
        _models = models;
        _loadingModels = false;
      });
    } on AiApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingModels = false;
        _loadModelsError = '${e.code.name}: ${e.message}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingModels = false;
        _loadModelsError = '$e';
      });
    }
  }

  void _save() {
    final label = _label.text.trim();
    final baseUrl = OpenAiCompatClient.normalizeBaseUrl(_baseUrl.text);
    if (label.isEmpty || baseUrl.isEmpty) {
      // Thiếu tên / URL — không lưu (form đã có gợi ý rõ từng trường).
      return;
    }
    final existing = widget.existing;
    final config = AiProviderConfig(
      id: existing?.id ??
          'provider-${DateTime.now().microsecondsSinceEpoch}',
      label: label,
      baseUrl: baseUrl,
      apiKey: _apiKey.text.isEmpty ? null : _apiKey.text,
      chatModel: _chatModel,
      translationModel: _translationModel,
      sttModel: _sttModel,
      ttsModel: _ttsModel,
      enabled: existing?.enabled ?? true,
    );
    AiProviderStore.instance.upsert(config);
    Navigator.pop(context, true);
  }
}

/// MODEL-PICKER-001 (owner 2026-10-26): *"danh sách dài, kéo tìm lâu"* —
/// thay `DropdownButtonFormField` bằng **ô chọn có tìm kiếm**.
///
/// Một dòng hiển thị giá trị hiện tại (bấm vào → mở dialog); dialog có ô lọc
/// gõ tới đâu lọc tới đó trên `label` (+ `subtitle`), chọn "None" để bỏ chọn.
/// Giữ `isExpanded`/ellipsis như bản cũ để tên model dài không tràn ngang.
class _ModelPickerField extends StatelessWidget {
  final String label;
  final List<String> models;
  final String? value;
  final String noneLabel;
  final ValueChanged<String?> onChanged;

  const _ModelPickerField({
    required this.label,
    required this.models,
    required this.value,
    required this.noneLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _PickerField(
        label: label,
        value: value,
        placeholder: noneLabel,
        onTap: () async {
          final picked = await _SearchPickerDialog.show(
            context,
            title: label,
            hint: context.uiText('Tìm'),
            noneLabel: noneLabel,
            selectedId: value,
            options: [
              for (final m in models) _PickerOption(id: m, label: m),
            ],
            searchPlaceholder: context.uiText('Gõ để tìm nhanh…'),
            emptyLabel: context.uiText('Không tìm thấy'),
          );
          if (picked == null) return; // huỷ dialog
          onChanged(picked.id);
        },
      ),
    );
  }
}

/// Ô chọn provider ưu tiên cho 1 năng lực — cũng CÓ TÌM KIẾM (provider có
/// thể nhiều: cloud + LAN + server nhà).
class _ProviderPickerField extends StatelessWidget {
  final List<AiProviderConfig> candidates;
  final String? value;
  final String noneLabel;
  final String label;
  final ValueChanged<String?> onChanged;

  const _ProviderPickerField({
    required this.candidates,
    required this.value,
    required this.noneLabel,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final current = candidates.where((p) => p.id == value).toList();
    return _PickerField(
      label: label,
      value: current.isEmpty ? null : current.first.label,
      placeholder: noneLabel,
      onTap: () async {
        final picked = await _SearchPickerDialog.show(
          context,
          title: label,
          hint: context.uiText('Tìm'),
          noneLabel: noneLabel,
          selectedId: value,
          options: [
            for (final p in candidates)
              _PickerOption(id: p.id, label: p.label, subtitle: p.baseUrl),
          ],
          searchPlaceholder: context.uiText('Gõ để tìm nhanh…'),
          emptyLabel: context.uiText('Không tìm thấy'),
        );
        if (picked == null) return;
        onChanged(picked.id);
      },
    );
  }
}

/// Ô "bấm để chọn" (không tự gõ) — hiển thị giá trị hiện tại hoặc placeholder.
class _PickerField extends StatelessWidget {
  final String label;
  final String? value;
  final String placeholder;
  final VoidCallback onTap;

  const _PickerField({
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasValue = value != null && value!.isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.search),
          isDense: true,
        ),
        child: Text(
          hasValue ? value! : placeholder,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: hasValue
              ? theme.textTheme.bodyMedium
              : theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.hintColor),
        ),
      ),
    );
  }
}

class _PickerOption {
  final String id;
  final String label;
  final String? subtitle;
  const _PickerOption({required this.id, required this.label, this.subtitle});
}

class _PickerResult {
  /// null = "không chọn" (None); dialog bị huỷ trả về null thay vì object này.
  final String? id;
  const _PickerResult(this.id);
}

/// Dialog chọn có tìm kiếm — dùng chung cho model & provider.
class _SearchPickerDialog extends StatefulWidget {
  final String title;
  final String hint;
  final String searchPlaceholder;
  final String emptyLabel;
  final String noneLabel;
  final List<_PickerOption> options;
  final String? selectedId;

  const _SearchPickerDialog({
    required this.title,
    required this.hint,
    required this.searchPlaceholder,
    required this.emptyLabel,
    required this.noneLabel,
    required this.options,
    required this.selectedId,
  });

  /// Trả về null khi huỷ, [_PickerResult] khi chọn (id null = bỏ chọn).
  static Future<_PickerResult?> show(
    BuildContext context, {
    required String title,
    required String hint,
    required String searchPlaceholder,
    required String emptyLabel,
    required String noneLabel,
    required List<_PickerOption> options,
    String? selectedId,
  }) {
    return showDialog<_PickerResult>(
      context: context,
      builder: (_) => _SearchPickerDialog(
        title: title,
        hint: hint,
        searchPlaceholder: searchPlaceholder,
        emptyLabel: emptyLabel,
        noneLabel: noneLabel,
        options: options,
        selectedId: selectedId,
      ),
    );
  }

  @override
  State<_SearchPickerDialog> createState() => _SearchPickerDialogState();
}

class _SearchPickerDialogState extends State<_SearchPickerDialog> {
  late final TextEditingController _query;
  List<_PickerOption> _filtered = const [];

  @override
  void initState() {
    super.initState();
    _query = TextEditingController();
    _filtered = widget.options;
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _filter(String raw) {
    final q = raw.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = widget.options;
        return;
      }
      _filtered = widget.options
          .where((o) =>
              o.label.toLowerCase().contains(q) ||
              (o.subtitle?.toLowerCase().contains(q) ?? false))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 460,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _query,
              autofocus: true,
              onChanged: _filter,
              decoration: InputDecoration(
                labelText: widget.hint,
                hintText: widget.searchPlaceholder,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: _query.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _query.clear();
                          _filter('');
                        },
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_filtered.length} / ${widget.options.length}',
              style: theme.textTheme.bodySmall,
            ),
            const Divider(height: 8),
            // Cho phép GÕ TAY: `/v1/models` không phải lúc nào cũng có model
            // riêng (server nhà, model vừa deploy, proxy…) — gõ tên rồi chọn.
            if (_query.text.trim().isNotEmpty &&
                !_filtered.any((o) => o.id == _query.text.trim()))
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.keyboard_outlined),
                  title: Text(
                    '${context.uiText("Dùng tên đã gõ")}: '
                    '${_query.text.trim()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => Navigator.pop(
                      context, _PickerResult(_query.text.trim())),
                ),
              ),
            Expanded(
              child: _filtered.isEmpty
                  ? Center(
                      child: Text(widget.emptyLabel,
                          style: theme.textTheme.bodySmall),
                    )
                  : ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (context, i) {
                        final o = _filtered[i];
                        final selected = o.id == widget.selectedId;
                        return ListTile(
                          dense: true,
                          selected: selected,
                          leading: Icon(selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked),
                          title: Text(o.label,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: o.subtitle == null
                              ? null
                              : Text(o.subtitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall),
                          onTap: () =>
                              Navigator.pop(context, _PickerResult(o.id)),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, const _PickerResult(null)),
          child: Text(widget.noneLabel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context).aiProviderCancel),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Helpers nhãn dùng chung (routing + báo cáo "AI đang chạy")
// ═══════════════════════════════════════════════════════════════════════════

String _capabilityLabelOf(AppLocalizations l10n, AiRouteCapability cap) {
  switch (cap) {
    case AiRouteCapability.chat:
      return l10n.aiRoutingChat;
    case AiRouteCapability.sttFile:
      return l10n.aiRoutingStt;
    case AiRouteCapability.translation:
      return l10n.aiRoutingTranslation;
    case AiRouteCapability.tts:
      return l10n.aiRoutingTts;
  }
}

String _routeModeLabelOf(
    BuildContext context, AppLocalizations l10n, AiRouteMode m) {
  switch (m) {
    // Nhãn "Tự động" đi qua `uiText()` — không cần thêm khoá ARB cho 26
    // locale, English fallback nằm trong catalog rule #5.
    case AiRouteMode.auto:
      return context.uiText('Tự động (theo mạng)');
    case AiRouteMode.offlineFirst:
      return l10n.aiRouteOfflineFirst;
    case AiRouteMode.onlineFirst:
      return l10n.aiRouteOnlineFirst;
    case AiRouteMode.offlineOnly:
      return l10n.aiRouteOfflineOnly;
  }
}

String _localEngineLabelOf(BuildContext context, AiLocalEngineHint hint) {
  switch (hint) {
    case AiLocalEngineHint.gemmaOrFallback:
      return context.uiText('Gemma trên máy (chưa có model thì trả lời mẫu)');
    case AiLocalEngineHint.translationChain:
      return context.uiText('Chuỗi engine dịch trên máy (HY-MT / ML Kit…)');
    case AiLocalEngineHint.whisperOrSherpa:
      return context.uiText('Whisper / sherpa (Parakeet) trên máy');
    case AiLocalEngineHint.deviceTts:
      return context.uiText('TTS trên máy (Piper / Edge / Zalo / FPT…)');
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// API-SYNC-001 — đồng bộ cấu hình lên Firebase
// ═══════════════════════════════════════════════════════════════════════════

class _CloudSyncSection extends StatelessWidget {
  const _CloudSyncSection();

  /// Ghép câu trạng thái ở UI (rule vàng #5) — service chỉ trả enum + mốc.
  String _statusText(BuildContext context, AiSettingsSyncStatus st) {
    switch (st.state) {
      case AiSettingsSyncState.idle:
        return context.uiText('Chưa đồng bộ');
      case AiSettingsSyncState.syncing:
        return context.uiText('Đang đồng bộ…');
      case AiSettingsSyncState.ok:
        final at = st.lastSyncedAt;
        if (at == null) return context.uiText('Đã đồng bộ');
        final d = at.toLocal();
        final hh = d.hour.toString().padLeft(2, '0');
        final mm = d.minute.toString().padLeft(2, '0');
        return '${context.uiText("Đã đồng bộ")} ${d.day}/${d.month} $hh:$mm';
      case AiSettingsSyncState.error:
        final detail = st.message;
        return detail == null
            ? context.uiText('Đồng bộ lỗi')
            : '${context.uiText("Đồng bộ lỗi")}: $detail';
      case AiSettingsSyncState.signedOut:
        return context.uiText('Chưa đăng nhập — chỉ lưu trên máy');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sync = AiSettingsCloudSync.instance;
    return ListenableBuilder(
      listenable: sync,
      builder: (context, _) {
        final st = sync.status;
        final busy = st.state == AiSettingsSyncState.syncing;
        final color = switch (st.state) {
          AiSettingsSyncState.ok => Colors.green,
          AiSettingsSyncState.error => Colors.red,
          _ => theme.hintColor,
        };
        return Card(
          color: theme.colorScheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.cloud_sync_outlined,
                        color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.uiText('Đồng bộ cấu hình lên Firebase'),
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  context.uiText(
                      'Đăng nhập là có sẵn cấu hình (provider, key, chế độ định tuyến) ở máy khác — không phải nhập lại. Chỉ lưu trong tài khoản của bạn.'),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      busy
                          ? Icons.sync
                          : (st.state == AiSettingsSyncState.error
                              ? Icons.error_outline
                              : Icons.cloud_done_outlined),
                      size: 16,
                      color: color,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(_statusText(context, st),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: color)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: busy
                          ? null
                          : () => sync.syncNow(store: AiProviderStore.instance),
                      icon: const Icon(Icons.cloud_upload_outlined),
                      label: Text(context.uiText('Đẩy lên Firebase')),
                    ),
                    TextButton.icon(
                      onPressed: busy
                          ? null
                          : () => sync.pullNow(store: AiProviderStore.instance),
                      icon: const Icon(Icons.cloud_download_outlined),
                      label: Text(context.uiText('Tải từ Firebase')),
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
}

// ═══════════════════════════════════════════════════════════════════════════
// API-DIAG-001 — "AI đang chạy hiện tại là gì" + chạy thử THẬT
// ═══════════════════════════════════════════════════════════════════════════

class _RuntimeReportSection extends StatefulWidget {
  final AiProviderStore store;
  const _RuntimeReportSection({required this.store});

  @override
  State<_RuntimeReportSection> createState() => _RuntimeReportSectionState();
}

class _RuntimeReportSectionState extends State<_RuntimeReportSection> {
  final Map<AiRouteCapability, AiProbeResult> _results = {};
  bool _running = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final reports = buildAiRoutingReport(
      store: widget.store,
      network: AiConnectivityRouter.instance.kind,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.monitor_heart_outlined,
                    color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.uiText('AI đang chạy hiện tại'),
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              context.uiText(
                  'Báo cáo theo cấu hình thật đang chạy: năng lực nào đi API (provider + model nào), năng lực nào chạy trên máy. Bấm "Chạy thử" để gửi một request thật, rất nhỏ, tới đúng provider/model đó.'),
              style: theme.textTheme.bodySmall,
            ),
            const Divider(),
            ...reports.map((r) => _row(context, l10n, r)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _running ? null : () => _probe(reports),
                  icon: _running
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_circle_outline),
                  label: Text(context.uiText('Chạy thử tất cả')),
                ),
                TextButton.icon(
                  onPressed: () => setState(_results.clear),
                  icon: const Icon(Icons.refresh),
                  label: Text(context.uiText('Xoá kết quả thử')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
      BuildContext context, AppLocalizations l10n, AiCapabilityReport r) {
    final theme = Theme.of(context);
    final probe = _results[r.capability];
    final warnColor = Colors.orange;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(_capabilityLabelOf(l10n, r.capability),
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ),
              Text(
                _routeModeLabelOf(context, l10n, r.effectiveMode),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.hintColor),
              ),
            ],
          ),
          const SizedBox(height: 2),
          // Dòng chính: API · <provider> · <model>  |  trên máy: engine
          Text(
            r.usesApi
                ? 'API · ${r.provider!.label} · ${r.model}'
                : '${context.uiText("Trên máy")} · '
                    '${_localEngineLabelOf(context, r.localEngine)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: r.usesApi ? Colors.green.shade700 : null,
            ),
          ),
          if (r.translationFallsBackToChatModel)
            Text(
              context.uiText(
                  'Chưa chọn model dịch riêng ⇒ đang dùng chat model ở trên.'),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.hintColor),
            ),
          if (r.warning != AiRouteWarning.none)
            Text(
              r.warning == AiRouteWarning.noProviderForCapability
                  ? context.uiText(
                      'Chưa có nhà cung cấp nào phục vụ năng lực này ⇒ sẽ chạy trên máy.')
                  : context.uiText(
                      'Provider chưa chọn model cho năng lực này ⇒ sẽ chạy trên máy.'),
              style: theme.textTheme.bodySmall?.copyWith(color: warnColor),
            ),
          if (probe != null) ...[
            const SizedBox(height: 2),
            Text(
              _probeText(context, probe),
              style: theme.textTheme.bodySmall?.copyWith(
                color: switch (probe.status) {
                  AiProbeStatus.ok => Colors.green,
                  AiProbeStatus.failed => Colors.red,
                  AiProbeStatus.skipped => theme.hintColor,
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _probeText(BuildContext context, AiProbeResult r) {
    switch (r.status) {
      case AiProbeStatus.skipped:
        return r.skipReason == AiProbeSkipReason.noModel
            ? context.uiText('Chưa thử: provider chưa chọn model.')
            : context.uiText('Chưa thử: không có provider ⇒ chạy trên máy.');
      case AiProbeStatus.failed:
        final code = r.errorCode == null ? '' : ' · ${r.errorCode!.name}';
        final detail =
            r.errorDetail == null ? '' : ' · ${r.errorDetail}';
        if (r.capability == AiRouteCapability.sttFile &&
            r.modelPresentInModelList == false) {
          return context.uiText(
                  'LỖI: model chưa có trong danh sách của provider ⇒ bóc băng sẽ lỗi.')
              + code;
        }
        return '${context.uiText("LỖI")}$code$detail';
      case AiProbeStatus.ok:
        final ms = r.latency.inMilliseconds;
        switch (r.capability) {
          case AiRouteCapability.translation:
            return 'OK · $ms ms · ${context.uiText("trả về")}: ${r.sample}'
                '${r.provider?.translationModel == null ? " · ${context.uiText("đang mượn chat model")}" : ""}';
          case AiRouteCapability.chat:
            return 'OK · $ms ms · ${context.uiText("trả về")}: ${r.sample}';
          case AiRouteCapability.tts:
            return 'OK · $ms ms · ${r.audioBytes ?? 0} byte audio';
          case AiRouteCapability.sttFile:
            return 'OK · $ms ms · ${r.modelCount ?? 0} model · '
                '${context.uiText("model có trong danh sách; chưa bóc băng file thật")}';
        }
    }
  }

  Future<void> _probe(List<AiCapabilityReport> reports) async {
    setState(() => _running = true);
    await probeAiCapabilities(
      targets: [
        for (final r in reports)
          AiCapabilityProbeTarget(r.capability, r.provider),
      ],
      onResult: (result) {
        if (!mounted) return;
        setState(() => _results[result.capability] = result);
      },
    );
    if (!mounted) return;
    setState(() => _running = false);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Routing — khi nào dùng API, ưu tiên provider nào
// ═══════════════════════════════════════════════════════════════════════════

class _RoutingSection extends StatelessWidget {
  final AiProviderStore store;
  const _RoutingSection({required this.store});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.aiRoutingTitle,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...AiRouteCapability.values.map(
          (cap) => _RoutingTile(capability: cap, store: store),
        ),
      ],
    );
  }
}

class _RoutingTile extends StatelessWidget {
  final AiRouteCapability capability;
  final AiProviderStore store;

  const _RoutingTile({required this.capability, required this.store});

  String _capabilityLabel(AppLocalizations l10n) =>
      _capabilityLabelOf(l10n, capability);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mode = store.routing.modeOf(capability);
    final candidates =
        store.enabledProviders.where((p) => p.supports(capability)).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_capabilityLabel(l10n),
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              for (final m in AiRouteMode.values)
                ChoiceChip(
                  label: Text(_modeLabel(context, l10n, m)),
                  selected: mode == m,
                  onSelected: (_) => _setMode(m),
                ),
            ],
          ),
          // YT-AUDIT-06 (IN4-104): nói rõ "Tự động" đang thành cái gì trên
          // máy này — người dùng không phải đoán.
          if (mode == AiRouteMode.auto)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _autoModeHint(context),
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ),
          if (mode != AiRouteMode.offlineOnly && candidates.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  // MODEL-PICKER-001: danh sách provider cũng dài (cloud +
                  // LAN + server nhà) ⇒ picker CÓ TÌM KIẾM, không bắt cuộn.
                  Expanded(
                    child: _ProviderPickerField(
                      label: l10n.aiRoutingProvider,
                      candidates: candidates,
                      value: _preferredValue(candidates),
                      noneLabel: l10n.aiProviderNone,
                      onChanged: _setPreferred,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String? _preferredValue(List<AiProviderConfig> candidates) {
    final preferred = store.routing.preferredProviderOf(capability);
    if (preferred == null) return null;
    return candidates.any((p) => p.id == preferred) ? preferred : null;
  }

  String _modeLabel(BuildContext context, AppLocalizations l10n, AiRouteMode m) {
    switch (m) {
      // YT-AUDIT-06 (IN4-104): nhãn "Tự động" đi qua `uiText()` + English
      // fallback trong `tool/legacy_ui_english_overrides.json` (không cần
      // thêm khoá ARB mới cho 26 locale).
      case AiRouteMode.auto:
        return context.uiText('Tự động (theo mạng)');
      case AiRouteMode.offlineFirst:
        return l10n.aiRouteOfflineFirst;
      case AiRouteMode.onlineFirst:
        return l10n.aiRouteOnlineFirst;
      case AiRouteMode.offlineOnly:
        return l10n.aiRouteOfflineOnly;
    }
  }

  /// YT-AUDIT-06 (IN4-104): giải thích mode `auto` theo loại mạng hiện tại.
  String _autoModeHint(BuildContext context) {
    final kind = AiConnectivityRouter.instance.kind;
    return switch (kind) {
      AiNetworkKind.wifi => context.uiText(
          'Đang dùng Wifi ⇒ ưu tiên trả lời từ mạng, hỏng mới chạy trên máy.',
        ),
      AiNetworkKind.mobile => context.uiText(
          'Đang dùng mạng di động ⇒ ưu tiên chạy trên máy, không được mới qua mạng.',
        ),
      AiNetworkKind.none => context.uiText('Không có mạng ⇒ chỉ chạy trên máy.'),
    };
  }

  void _setMode(AiRouteMode m) {
    final modes =
        Map<AiRouteCapability, AiRouteMode>.from(store.routing.modes);
    modes[capability] = m;
    store.updateRouting(store.routing.copyWith(modes: modes));
  }

  void _setPreferred(String? id) {
    final preferred = Map<AiRouteCapability, String>.from(
        store.routing.preferredProviderIds);
    if (id == null) {
      preferred.remove(capability);
    } else {
      preferred[capability] = id;
    }
    store.updateRouting(
        store.routing.copyWith(preferredProviderIds: preferred));
  }
}
