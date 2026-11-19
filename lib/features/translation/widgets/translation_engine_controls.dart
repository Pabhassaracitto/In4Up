import '../../../core/language/localized_material.dart';
import '../../../core/language/translation_ui_labels.dart';
import '../text_provider_translation.dart';
import '../translation_service.dart';

bool _online(String id) => id != 'hymt' && id != 'mlkit' && id != 'offline';

/// The Read toolbar and engine sheet share the same selection and notifier.
/// Choosing Google here explicitly leaves Offline-only; reordering never does.
class TranslationEnginePicker extends StatelessWidget {
  final TranslationService service;
  final bool enabled;

  const TranslationEnginePicker({
    super.key,
    required this.service,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: service,
        builder: (context, _) {
          final choices = service.engineChoices;
          final selected = choices.any((e) => e.id == service.selectedEngineId)
              ? service.selectedEngineId
              : null;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              InputDecorator(
                decoration: InputDecoration(
                  labelText: context.uiText(TranslationUiLabels.preferred),
                  isDense: true,
                  contentPadding: const EdgeInsets.fromLTRB(10, 4, 8, 4),
                  border: const OutlineInputBorder(),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    key: const Key('translation-engine-picker'),
                    isExpanded: true,
                    isDense: true,
                    value: selected,
                    hint: Text(service.selectedEngineName),
                    items: [
                      for (final engine in choices)
                        DropdownMenuItem(
                          value: engine.id,
                          child: Row(
                            children: [
                              Icon(
                                  _online(engine.id)
                                      ? Icons.cloud_outlined
                                      : Icons.offline_bolt,
                                  size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                  child: Text(
                                '${engine.name} · ${context.uiText(_online(engine.id) ? TranslationUiLabels.online : TranslationUiLabels.offline)}',
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              )),
                            ],
                          ),
                        ),
                    ],
                    onChanged: !enabled
                        ? null
                        : (id) {
                            if (id != null) service.preferEngine(id);
                          },
                  ),
                ),
              ),
              if (service.offlineOnly)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    context.uiText(TranslationUiLabels.onlineHint),
                    style: const TextStyle(
                        fontSize: 11, color: Colors.orangeAccent),
                  ),
                ),
            ],
          );
        },
      );
}

/// Same numbered list + drag handles as voice settings, with keyboard/touch
/// alternatives. Kept inside a collapsed PSRC-191 section, not another long
/// always-expanded column of settings.
class TranslationEngineOrderList extends StatelessWidget {
  final TranslationService service;
  final Color accentColor;

  const TranslationEngineOrderList({
    super.key,
    required this.service,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: service,
        builder: (context, _) {
          final engines = service.engineChoices;
          void move(int from, int to) {
            final ids = engines.map((e) => e.id).toList();
            ids.insert(to, ids.removeAt(from));
            service.setEnginePriority(ids);
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(context.uiText(TranslationUiLabels.orderHint),
                  style: const TextStyle(fontSize: 11, color: Colors.white70)),
              const SizedBox(height: 8),
              ReorderableListView.builder(
                key: const Key('translation-engine-order'),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: engines.length,
                onReorder: (from, to) => move(from, to > from ? to - 1 : to),
                itemBuilder: (context, index) {
                  final engine = engines[index];
                  return Material(
                    key: ValueKey(engine.id),
                    color: Colors.transparent,
                    child: Row(
                      children: [
                        ReorderableDragStartListener(
                          key: ValueKey('translation-drag-${engine.id}'),
                          index: index,
                          child: const SizedBox(
                            width: 40,
                            height: 48,
                            child: Icon(Icons.drag_handle, size: 20),
                          ),
                        ),
                        Text('${index + 1}',
                            style: TextStyle(color: accentColor)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(engine.name,
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis)),
                        IconButton(
                          key: ValueKey('translation-up-${engine.id}'),
                          tooltip: context.uiText(TranslationUiLabels.up),
                          icon: const Icon(Icons.arrow_upward, size: 18),
                          onPressed:
                              index == 0 ? null : () => move(index, index - 1),
                          visualDensity: VisualDensity.compact,
                        ),
                        IconButton(
                          key: ValueKey('translation-down-${engine.id}'),
                          tooltip: context.uiText(TranslationUiLabels.down),
                          icon: const Icon(Icons.arrow_downward, size: 18),
                          onPressed: index == engines.length - 1
                              ? null
                              : () => move(index, index + 1),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  );
                },
              ),
              Text(context.uiText(TranslationUiLabels.policyHint),
                  style: const TextStyle(fontSize: 11, color: Colors.white70)),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: service.savedEnginePriority == null
                      ? null
                      : service.resetEnginePriority,
                  child: Text(context.uiText(TranslationUiLabels.automatic)),
                ),
              ),
            ],
          );
        },
      );
}

/// Finite run state plus REQUEST-scoped provenance (not lastUsedEngine from a
/// different screen). Engine output and error details are allowed to wrap.
class TranslationRunStatusPanel extends StatelessWidget {
  final TranslationMixin document;
  final VoidCallback? onRetry;

  const TranslationRunStatusPanel({
    super.key,
    required this.document,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation:
            Listenable.merge([document, document.translationEngineNotifier]),
        builder: (context, _) {
          final status = document.translationStatus;
          if (status == TranslationRunStatus.idle ||
              document.translationBlockedBySamePair) {
            return const SizedBox.shrink();
          }
          final label = switch (status) {
            TranslationRunStatus.translating => TranslationUiLabels.translating,
            TranslationRunStatus.succeeded => TranslationUiLabels.succeeded,
            TranslationRunStatus.partial => TranslationUiLabels.partial,
            TranslationRunStatus.failed => TranslationUiLabels.failed,
            TranslationRunStatus.cancelled => TranslationUiLabels.cancelled,
            TranslationRunStatus.idle => '',
          };
          final failed = status == TranslationRunStatus.failed ||
              status == TranslationRunStatus.partial;
          final color = failed ? Colors.orangeAccent : Colors.tealAccent;
          final result = document.lastTranslationResult;
          final route = result?.route;
          final actual = route?.actualEngineName ?? result?.engineName ?? '';
          final active = document.isTranslating
              ? document.translationEngineNotifier.value
              : null;
          return Semantics(
            liveRegion: true,
            child: Padding(
              key: const Key('translation-run-status'),
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${context.uiText(label)} · '
                    '${context.uiText(TranslationUiLabels.counts)}: '
                    '${document.successfulTranslations} / ${document.failedTranslations}',
                    key: const Key('translation-run-outcome'),
                    style: TextStyle(fontSize: 11, color: color),
                  ),
                  if (active != null)
                    Text('${context.uiText('Đang dịch bằng')}: $active',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.white70)),
                  if (result?.isSuccess == true)
                    Text(
                      result!.engineName == 'cache'
                          ? context.uiText(TranslationUiLabels.cache)
                          : route?.usedFallback == true
                              ? '${context.uiText(TranslationUiLabels.fallback)}: '
                                  '${route!.selectedEngineName} → $actual'
                              : '${context.uiText(TranslationUiLabels.actual)}: $actual',
                      key: const Key('translation-result-engine'),
                      style:
                          const TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  if (document.translationError != null)
                    Text(context.uiText(document.translationError!),
                        key: const Key('translation-error-detail'),
                        style: const TextStyle(
                            fontSize: 11, color: Colors.orangeAccent)),
                  if (failed && onRetry != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: Text(context.uiText(TranslationUiLabels.retry)),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
}
