// lib/features/great_library/ui/contribute_wizard_screen.dart
//
// GLIB-006 — wizard đóng góp pack (PLAN-049 §GLIB-006, ADR-0031 D6).
// 3 bước: (1) chọn nguồn — export-as-pack từ Vườn nhớ của mình hoặc soạn mới;
// (2) metadata (nút "Gợi ý bằng AI" opt-in BYOK, mặc định TẮT; user sửa lại);
// (3) cam kết bản quyền + license → build .i4upack → upload → gl_contributions
// pending. Quota client: 10 pack/tháng.
//
// Chrome qua AppLocalizations (rule vàng #5). TTS bulk on-device (Piper) chạy
// ở bước build khi user bật (pack vocab) — best effort, lỗi không chặn gửi.

import 'package:flutter/material.dart';
import 'package:in4up/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../../providers/vocabulary_provider.dart';
import '../models/pack_manifest.dart';
import '../services/contribution_ai_suggest.dart';
import '../services/pack_contribution_service.dart';
import '../services/pack_file.dart';

class ContributeWizardScreen extends StatefulWidget {
  const ContributeWizardScreen({
    super.key,
    required this.service,
    this.aiSuggest,
    this.onSubmitted,
  });

  final PackContributionService service;

  /// Null → nút AI ẩn hoàn toàn (không BYOK cấu hình).
  final ContributionAiSuggest? aiSuggest;

  /// Callback sau khi gửi thành công (test bắt được).
  final VoidCallback? onSubmitted;

  @override
  State<ContributeWizardScreen> createState() => _ContributeWizardScreenState();
}

class _ContributeWizardScreenState extends State<ContributeWizardScreen> {
  int _step = 0;

  // Bước 1 — nguồn.
  bool _fromMyVocab = true;
  final List<ContributionVocabInput> _manualItems = <ContributionVocabInput>[];
  final _manualWord = TextEditingController();
  final _manualMeaning = TextEditingController();

  // Bước 2 — metadata.
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _tags = TextEditingController();
  String _level = 'mixed';
  bool _aiBusy = false;
  String? _aiNote;

  // Bước 3 — cam kết + license + gửi.
  bool _rightsConfirmed = false;
  PackLicense _license = PackLicense.selfMade;
  bool _submitting = false;
  String? _submitError;

  static const _levels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2', 'mixed'];

  @override
  void dispose() {
    _manualWord.dispose();
    _manualMeaning.dispose();
    _title.dispose();
    _description.dispose();
    _tags.dispose();
    super.dispose();
  }

  List<ContributionVocabInput> _collectItems(BuildContext context) {
    if (_fromMyVocab) {
      final vocab = context.read<VocabularyProvider>();
      return vocab.allWords
          .where((w) =>
              w.word.trim().isNotEmpty && w.meaning.trim().isNotEmpty)
          .map((w) => ContributionVocabInput(
                word: w.word,
                meaning: w.meaning,
                phonetic: w.phonetic,
                example: w.example,
              ))
          .toList(growable: false);
    }
    return List.unmodifiable(_manualItems);
  }

  Future<void> _runAiSuggest() async {
    final ai = widget.aiSuggest;
    if (ai == null || _aiBusy) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _aiBusy = true;
      _aiNote = null;
    });
    final items = _collectItems(context);
    final suggestion = await ai.suggest(
      type: PackType.vocab,
      sampleWords: items.map((e) => e.word).toList(),
    );
    if (!mounted) return;
    setState(() {
      _aiBusy = false;
      if (suggestion == null) {
        _aiNote = l10n.glAiSuggestUnavailable;
      } else {
        if (suggestion.title != null && _title.text.trim().isEmpty) {
          _title.text = suggestion.title!;
        }
        if (suggestion.description != null &&
            _description.text.trim().isEmpty) {
          _description.text = suggestion.description!;
        }
        if (suggestion.tags != null && _tags.text.trim().isEmpty) {
          _tags.text = suggestion.tags!.join(', ');
        }
        if (suggestion.level != null) _level = suggestion.level!;
        _aiNote = l10n.glAiSuggestApplied;
      }
    });
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    final meta = ContributionMetadata(
      title: _title.text.trim(),
      description: _description.text.trim(),
      tags: _tags.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList(growable: false),
      level: _level,
      license: _license,
    );
    // Build pack ĐỒNG BỘ trước để lỗi format/quota hiện ngay trên UI.
    final String packId;
    final PackBuildResult pack;
    try {
      packId = PackContributionService.newPackId(
          meta.title, DateTime.now());
      pack = widget.service.buildVocabPack(
        packId: packId,
        meta: meta,
        items: _collectItems(context),
      );
    } on ContributionException catch (e) {
      setState(() {
        _submitting = false;
        _submitError = switch (e.code) {
          'quota-exceeded' => l10n.glQuotaExceeded,
          'no-valid-items' => l10n.glNoValidItems,
          'payload-over-quota' => l10n.glPackTooLarge,
          _ => '${l10n.glContributeFailed} (${e.code} ${e.detail})',
        };
      });
      return;
    }
    final result = await widget.service
        .submit(pack: pack, title: meta.title);
    if (!mounted) return;
    if (result.status == ContributionStatus.failed &&
        (result.errorCode ?? '').contains('upload-unsupported')) {
      // Backend HTTPS tĩnh (không Blaze): pack đã build xong — hướng dẫn
      // chia sẻ file thủ công cho owner (không mất công soạn).
      setState(() {
        _submitting = false;
        _submitError = l10n.glUploadUnsupported;
      });
      return;
    }
    if (result.status == ContributionStatus.submitted) {
      widget.onSubmitted?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.glContributeSuccess)),
      );
      Navigator.of(context).pop();
    } else {
      setState(() {
        _submitting = false;
        _submitError = result.errorCode ?? l10n.glContributeFailed;
      });
    }
  }

  bool get _canNextStep1 => _collectItems(context).isNotEmpty;
  bool get _canNextStep2 => _title.text.trim().isNotEmpty;
  bool get _canSubmit => _rightsConfirmed && !_submitting;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.glContribute)),
      body: Stepper(
        currentStep: _step,
        onStepContinue: () {
          if (_step == 0 && _canNextStep1) {
            setState(() => _step = 1);
          } else if (_step == 1 && _canNextStep2) {
            setState(() => _step = 2);
          } else if (_step == 2 && _canSubmit) {
            _submit();
          }
        },
        onStepCancel: () {
          if (_step > 0) setState(() => _step -= 1);
        },
        controlsBuilder: (context, details) => Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            children: [
              FilledButton(
                // Key theo BƯỚC của controls (không phải currentStep) —
                // Stepper dựng đủ 3 cụm nên key phải khác nhau mỗi cụm.
                key: ValueKey('gl_wizard_continue_${details.stepIndex}'),
                onPressed: details.onStepContinue,
                child: Text(_step == 2
                    ? l10n.glContributeSubmit
                    : l10n.glNext),
              ),
              if (_step > 0) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: details.onStepCancel,
                  child: Text(l10n.glBack),
                ),
              ],
            ],
          ),
        ),
        steps: [
          // ── Bước 1: nguồn nội dung ──
          Step(
            title: Text(l10n.glStepSource),
            isActive: _step >= 0,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RadioListTile<bool>(
                  value: true,
                  groupValue: _fromMyVocab,
                  onChanged: (v) => setState(() => _fromMyVocab = v ?? true),
                  title: Text(l10n.glSourceMyVocab),
                ),
                RadioListTile<bool>(
                  value: false,
                  groupValue: _fromMyVocab,
                  onChanged: (v) => setState(() => _fromMyVocab = v ?? true),
                  title: Text(l10n.glSourceManual),
                ),
                if (!_fromMyVocab) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _manualWord,
                          decoration:
                              InputDecoration(labelText: l10n.glWordLabel),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _manualMeaning,
                          decoration:
                              InputDecoration(labelText: l10n.glMeaningLabel),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () {
                          final item = ContributionVocabInput(
                            word: _manualWord.text,
                            meaning: _manualMeaning.text,
                          );
                          if (!item.isValid) return;
                          setState(() {
                            _manualItems.add(item);
                            _manualWord.clear();
                            _manualMeaning.clear();
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.glItemCount(_manualItems.length)),
                ] else
                  Text(l10n.glItemCount(_collectItems(context).length)),
              ],
            ),
          ),
          // ── Bước 2: metadata (+ AI gợi ý opt-in) ──
          Step(
            title: Text(l10n.glStepMetadata),
            isActive: _step >= 1,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _title,
                  decoration: InputDecoration(labelText: l10n.glTitleLabel),
                  onChanged: (_) => setState(() {}),
                ),
                TextField(
                  controller: _description,
                  decoration:
                      InputDecoration(labelText: l10n.glDescriptionLabel),
                  maxLines: 3,
                ),
                TextField(
                  controller: _tags,
                  decoration: InputDecoration(labelText: l10n.glTagsLabel),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(l10n.glLevelLabel),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: _level,
                      items: _levels
                          .map((l) =>
                              DropdownMenuItem(value: l, child: Text(l)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _level = v ?? 'mixed'),
                    ),
                  ],
                ),
                if (widget.aiSuggest != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _aiBusy ? null : _runAiSuggest,
                    icon: _aiBusy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.auto_awesome),
                    label: Text(l10n.glAiSuggest),
                  ),
                  if (_aiNote != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(_aiNote!,
                          style: Theme.of(context).textTheme.bodySmall),
                    ),
                ],
              ],
            ),
          ),
          // ── Bước 3: bản quyền + license + gửi ──
          Step(
            title: Text(l10n.glStepLicense),
            isActive: _step >= 2,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.glLicenseLabel,
                    style: Theme.of(context).textTheme.titleSmall),
                for (final lic in PackLicense.values)
                  RadioListTile<PackLicense>(
                    dense: true,
                    value: lic,
                    groupValue: _license,
                    onChanged: (v) =>
                        setState(() => _license = v ?? PackLicense.selfMade),
                    title: Text(lic.wire),
                  ),
                CheckboxListTile(
                  value: _rightsConfirmed,
                  onChanged: (v) =>
                      setState(() => _rightsConfirmed = v ?? false),
                  title: Text(l10n.glRightsCommitment),
                ),
                if (_submitError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_submitError!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ),
                if (_submitting)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
