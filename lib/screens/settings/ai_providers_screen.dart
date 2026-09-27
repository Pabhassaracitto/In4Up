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
import 'package:in4up/l10n/app_localizations.dart';
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
        Chip(label: Text('${l10n.aiProviderChatModel}: ${_config.chatModel}')),
      if (_config.sttModel != null)
        Chip(label: Text('${l10n.aiProviderSttModel}: ${_config.sttModel}')),
      if (_config.ttsModel != null)
        Chip(label: Text('${l10n.aiProviderTtsModel}: ${_config.ttsModel}')),
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
              if (_models.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(l10n.aiProviderNoModels,
                      style: Theme.of(context).textTheme.bodySmall),
                )
              else ...[
                const SizedBox(height: 12),
                _ModelDropdown(
                  label: l10n.aiProviderChatModel,
                  models: _models,
                  value: _chatModel,
                  noneLabel: l10n.aiProviderNone,
                  onChanged: (v) => setState(() => _chatModel = v),
                ),
                _ModelDropdown(
                  label: l10n.aiProviderSttModel,
                  models: _models,
                  value: _sttModel,
                  noneLabel: l10n.aiProviderNone,
                  onChanged: (v) => setState(() => _sttModel = v),
                ),
                _ModelDropdown(
                  label: l10n.aiProviderTtsModel,
                  models: _models,
                  value: _ttsModel,
                  noneLabel: l10n.aiProviderNone,
                  onChanged: (v) => setState(() => _ttsModel = v),
                ),
              ],
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
      sttModel: _sttModel,
      ttsModel: _ttsModel,
      enabled: existing?.enabled ?? true,
    );
    AiProviderStore.instance.upsert(config);
    Navigator.pop(context, true);
  }
}

class _ModelDropdown extends StatelessWidget {
  final String label;
  final List<String> models;
  final String? value;
  final String noneLabel;
  final ValueChanged<String?> onChanged;

  const _ModelDropdown({
    required this.label,
    required this.models,
    required this.value,
    required this.noneLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && models.contains(value);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String?>(
        value: hasValue ? value : null,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: [
          DropdownMenuItem<String?>(value: null, child: Text(noneLabel)),
          ...models.map((m) => DropdownMenuItem<String?>(value: m, child: Text(m))),
        ],
        onChanged: onChanged,
      ),
    );
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

  String _capabilityLabel(AppLocalizations l10n) {
    switch (capability) {
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
                  label: Text(_modeLabel(l10n, m)),
                  selected: mode == m,
                  onSelected: (_) => _setMode(m),
                ),
            ],
          ),
          if (mode != AiRouteMode.offlineOnly && candidates.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Text('${l10n.aiRoutingProvider}: ',
                      style: Theme.of(context).textTheme.bodySmall),
                  DropdownButton<String?>(
                    value: _preferredValue(candidates),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(l10n.aiProviderNone),
                      ),
                      ...candidates.map(
                        (p) => DropdownMenuItem<String?>(
                          value: p.id,
                          child: Text(p.label),
                        ),
                      ),
                    ],
                    onChanged: (v) => _setPreferred(v),
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

  String _modeLabel(AppLocalizations l10n, AiRouteMode m) {
    switch (m) {
      case AiRouteMode.offlineFirst:
        return l10n.aiRouteOfflineFirst;
      case AiRouteMode.onlineFirst:
        return l10n.aiRouteOnlineFirst;
      case AiRouteMode.offlineOnly:
        return l10n.aiRouteOfflineOnly;
    }
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
