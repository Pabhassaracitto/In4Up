import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:in4up/features/tipitaka/models/language_pack.dart';
import 'package:in4up/features/tipitaka/services/db_service.dart';
import 'package:in4up/features/tipitaka/services/language_pack_service.dart';

enum TipitakaTaskPhase {
  queued,
  downloading,
  extracting,
  importing,
  completed,
  failed,
}

class TipitakaTaskStatus {
  final String id;
  final String label;
  final TipitakaTaskPhase phase;
  final double? progress;
  final String? error;
  final DateTime startedAt;
  final DateTime? finishedAt;

  const TipitakaTaskStatus({
    required this.id,
    required this.label,
    required this.phase,
    required this.progress,
    required this.error,
    required this.startedAt,
    required this.finishedAt,
  });

  bool get isActive => phase.index < TipitakaTaskPhase.completed.index;
  bool get isDone =>
      phase == TipitakaTaskPhase.completed || phase == TipitakaTaskPhase.failed;

  TipitakaTaskStatus copyWith({
    TipitakaTaskPhase? phase,
    double? progress,
    bool clearProgress = false,
    String? error,
    bool clearError = false,
    DateTime? finishedAt,
  }) {
    return TipitakaTaskStatus(
      id: id,
      label: label,
      phase: phase ?? this.phase,
      progress: clearProgress ? null : progress ?? this.progress,
      error: clearError ? null : error ?? this.error,
      startedAt: startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
    );
  }
}

/// Keeps DB downloads/imports alive independently of the route that started
/// them. Popping the Tipiṭaka screen therefore does not cancel the task.
class TipitakaTaskCoordinator {
  TipitakaTaskCoordinator._();

  static final instance = TipitakaTaskCoordinator._();

  final tasks = ValueNotifier<List<TipitakaTaskStatus>>(const []);
  final _running = <String, Future<TipitakaTaskStatus>>{};

  Future<TipitakaTaskStatus> downloadAndImport(
    TipitakaLanguagePack pack,
  ) {
    final id = 'language:${pack.code}';
    final existing = _running[id];
    if (existing != null) return existing;

    final started = TipitakaTaskStatus(
      id: id,
      label: pack.name,
      phase: TipitakaTaskPhase.queued,
      progress: null,
      error: null,
      startedAt: DateTime.now(),
      finishedAt: null,
    );
    _publish(started);

    final future = _runDownload(pack, started);
    _running[id] = future;
    future.whenComplete(() => _running.remove(id));
    return future;
  }

  Future<TipitakaTaskStatus> importFile(String path, {String? label}) {
    final id = 'file:$path';
    final existing = _running[id];
    if (existing != null) return existing;

    final started = TipitakaTaskStatus(
      id: id,
      label: label ?? path.split(RegExp(r'[/\\]')).last,
      phase: TipitakaTaskPhase.queued,
      progress: null,
      error: null,
      startedAt: DateTime.now(),
      finishedAt: null,
    );
    _publish(started);

    final future = _runFileImport(path, started);
    _running[id] = future;
    future.whenComplete(() => _running.remove(id));
    return future;
  }

  static String batchId(List<String> paths) =>
      'files:${_orderedFiles(paths).join('|')}';

  static List<String> _orderedFiles(List<String> paths) {
    final ordered = [...paths]..sort((a, b) {
      final aPali = _looksLikePali(a);
      final bPali = _looksLikePali(b);
      if (aPali != bPali) return aPali ? -1 : 1;
      return a.compareTo(b);
    });
    return ordered;
  }

  Future<TipitakaTaskStatus> importFiles(List<String> paths) {
    final ordered = _orderedFiles(paths);
    final id = batchId(paths);
    final existing = _running[id];
    if (existing != null) return existing;

    final started = TipitakaTaskStatus(
      id: id,
      label: '${ordered.length} file(s)',
      phase: TipitakaTaskPhase.queued,
      progress: null,
      error: null,
      startedAt: DateTime.now(),
      finishedAt: null,
    );
    _publish(started);
    final future = _runFileImports(ordered, started);
    _running[id] = future;
    future.whenComplete(() => _running.remove(id));
    return future;
  }

  static bool _looksLikePali(String path) {
    final name = path.toLowerCase();
    return name.contains('pali') || name.contains('roman');
  }

  TipitakaTaskStatus? statusFor(String id) {
    for (final task in tasks.value) {
      if (task.id == id) return task;
    }
    return null;
  }

  Future<TipitakaTaskStatus> _runDownload(
    TipitakaLanguagePack pack,
    TipitakaTaskStatus started,
  ) async {
    var current = started.copyWith(phase: TipitakaTaskPhase.downloading);
    _publish(current);
    try {
      final service = const TipitakaLanguagePackService();
      final result = await service.download(
        pack,
        onProgress: (received, total) {
          final progress = total == null || total <= 0
              ? null
              : (received / total).clamp(0.0, 1.0).toDouble();
          current = current.copyWith(progress: progress);
          _publish(current);
        },
      );
      current = current.copyWith(
        phase: TipitakaTaskPhase.extracting,
        clearProgress: true,
      );
      _publish(current);
      final databasePath = result.databasePath;
      if (databasePath == null) {
        throw const TipitakaDatabaseException(
          'Không tìm thấy file SQLite bên trong gói tải xuống.',
        );
      }
      current = current.copyWith(phase: TipitakaTaskPhase.importing);
      _publish(current);
      await TipitakaDb.importSourceDatabase(
        databasePath,
        languageCode: pack.languageCode,
      );
      current = current.copyWith(
        phase: TipitakaTaskPhase.completed,
        clearProgress: true,
        finishedAt: DateTime.now(),
      );
      _publish(current);
      return current;
    } catch (error) {
      current = current.copyWith(
        phase: TipitakaTaskPhase.failed,
        clearProgress: true,
        error: '$error',
        finishedAt: DateTime.now(),
      );
      _publish(current);
      return current;
    }
  }

  Future<TipitakaTaskStatus> _runFileImports(
    List<String> paths,
    TipitakaTaskStatus started,
  ) async {
    var current = started.copyWith(phase: TipitakaTaskPhase.importing, progress: 0);
    _publish(current);
    try {
      for (var index = 0; index < paths.length; index++) {
        await TipitakaDb.installDatabaseFile(paths[index]);
        current = current.copyWith(
          progress: (index + 1) / paths.length,
        );
        _publish(current);
      }
      current = current.copyWith(
        phase: TipitakaTaskPhase.completed,
        clearProgress: true,
        finishedAt: DateTime.now(),
      );
      _publish(current);
      return current;
    } catch (error) {
      current = current.copyWith(
        phase: TipitakaTaskPhase.failed,
        clearProgress: true,
        error: '$error',
        finishedAt: DateTime.now(),
      );
      _publish(current);
      return current;
    }
  }

  Future<TipitakaTaskStatus> _runFileImport(
    String path,
    TipitakaTaskStatus started,
  ) async {
    var current = started.copyWith(phase: TipitakaTaskPhase.importing);
    _publish(current);
    try {
      await TipitakaDb.installDatabaseFile(path);
      current = current.copyWith(
        phase: TipitakaTaskPhase.completed,
        finishedAt: DateTime.now(),
      );
      _publish(current);
      return current;
    } catch (error) {
      current = current.copyWith(
        phase: TipitakaTaskPhase.failed,
        error: '$error',
        finishedAt: DateTime.now(),
      );
      _publish(current);
      return current;
    }
  }

  void _publish(TipitakaTaskStatus task) {
    final next = [...tasks.value];
    final index = next.indexWhere((item) => item.id == task.id);
    if (index == -1) {
      next.add(task);
    } else {
      next[index] = task;
    }
    while (next.length > 5) {
      next.removeAt(0);
    }
    tasks.value = next;
  }
}
