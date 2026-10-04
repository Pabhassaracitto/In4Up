import 'dart:async';

import 'package:in4up/core/language/localized_material.dart';

import 'package:in4up/features/tipitaka/services/tipitaka_task_service.dart';

/// A small root overlay that remains visible when the user pops the data
/// screen and continues using another part of the app.
class TipitakaTaskOverlay {
  static final _activeEntries = <String, OverlayEntry>{};

  static void show(BuildContext context, String taskId) {
    if (_activeEntries.containsKey(taskId)) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _TaskToast(
        taskId: taskId,
        onRemove: () {
          if (entry.mounted) entry.remove();
          _activeEntries.remove(taskId);
        },
      ),
    );
    _activeEntries[taskId] = entry;
    overlay.insert(entry);
  }
}

class _TaskToast extends StatefulWidget {
  final String taskId;
  final VoidCallback onRemove;

  const _TaskToast({required this.taskId, required this.onRemove});

  @override
  State<_TaskToast> createState() => _TaskToastState();
}

class _TaskToastState extends State<_TaskToast> {
  Timer? _dismissTimer;
  TipitakaTaskStatus? _lastStatus;

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  void _scheduleDismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = Timer(const Duration(seconds: 8), widget.onRemove);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<TipitakaTaskStatus>>(
      valueListenable: TipitakaTaskCoordinator.instance.tasks,
      builder: (context, tasks, child) {
        TipitakaTaskStatus? status;
        for (final item in tasks) {
          if (item.id == widget.taskId) status = item;
        }
        status ??= _lastStatus;
        if (status == null) return const SizedBox.shrink();
        _lastStatus = status;
        if (status.isDone) _scheduleDismiss();

        final isError = status.phase == TipitakaTaskPhase.failed;
        final isDone = status.phase == TipitakaTaskPhase.completed;
        final progress = status.progress;
        final phase = switch (status.phase) {
          TipitakaTaskPhase.queued => context.uiText('Đang xếp hàng'),
          TipitakaTaskPhase.downloading => context.uiText('Đang tải'),
          TipitakaTaskPhase.extracting => context.uiText('Đang giải nén'),
          TipitakaTaskPhase.importing => context.uiText('Đang import'),
          TipitakaTaskPhase.completed => context.uiText('Đã hoàn tất'),
          TipitakaTaskPhase.failed => context.uiText('Thất bại'),
        };

        return Positioned(
          left: 16,
          right: 16,
          bottom: MediaQuery.paddingOf(context).bottom + 16,
          child: SafeArea(
            top: false,
            child: Material(
              elevation: 8,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 11, 10, 11),
                child: Row(
                  children: [
                    Icon(
                      isError
                          ? Icons.error_outline
                          : isDone
                              ? Icons.check_circle_outline
                              : Icons.sync,
                      color: isError
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${status.label} · $phase',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if (status.error != null)
                            Text(
                              status.error!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontSize: 12,
                              ),
                            )
                          else if (progress != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: LinearProgressIndicator(value: progress),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: context.uiText('Ẩn thông báo'),
                      onPressed: widget.onRemove,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
