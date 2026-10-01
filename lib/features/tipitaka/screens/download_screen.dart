import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:in4up/core/language/localized_material.dart';

import 'package:in4up/features/tipitaka/screens/language_pack_screen.dart';
import 'package:in4up/features/tipitaka/screens/library_screen.dart';
import 'package:in4up/features/tipitaka/screens/tipitaka_task_overlay.dart';
import 'package:in4up/features/tipitaka/services/db_service.dart';
import 'package:in4up/features/tipitaka/services/tipitaka_task_service.dart';

class TipitakaDownloadScreen extends StatefulWidget {
  const TipitakaDownloadScreen({super.key});

  @override
  State<TipitakaDownloadScreen> createState() => _TipitakaDownloadScreenState();
}

class _TipitakaDownloadScreenState extends State<TipitakaDownloadScreen> {
  TipitakaDatabaseInfo? _info;
  bool _loading = true;
  bool _importing = false;
  bool _scanning = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final db = await TipitakaDb.openReady();
      final info = await TipitakaDb.info(db);
      if (mounted) setState(() => _info = info);
    } catch (error) {
      if (mounted) {
        setState(() {
          _info = null;
          _error = error.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _importDatabase() async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['sqlite', 'sqlite3', 'db', 'zip'],
      );
      if (!mounted || result == null) {
        if (mounted) setState(() => _importing = false);
        return;
      }
      final path = result.files.single.path;
      if (path == null) {
        throw const TipitakaDatabaseException(
          'Không lấy được đường dẫn file trên thiết bị này.',
        );
      }

      final taskId = 'file:$path';
      TipitakaTaskOverlay.show(context, taskId);
      final task = TipitakaTaskCoordinator.instance.importFile(path);
      unawaited(task.then((status) {
        if (!mounted) return;
        setState(() => _importing = false);
        if (status.phase == TipitakaTaskPhase.completed) {
          _refresh();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status.phase == TipitakaTaskPhase.completed
                  ? context.uiText('Đã import cơ sở dữ liệu Tipiṭaka.')
                  : context.uiText('Import thất bại: ${status.error}'),
            ),
          ),
        );
      }));
    } catch (error) {
      if (!mounted) return;
      setState(() => _importing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.uiText('Import thất bại: $error'))),
      );
    }
  }

  Future<void> _scanImportFolder() async {
    if (_scanning || _importing) return;
    setState(() => _scanning = true);
    try {
      final files = await TipitakaDb.discoverImportFiles();
      if (!mounted) return;
      if (files.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.uiText(
                'Chưa thấy file. Hãy đặt .db/.sqlite/.zip vào thư mục '
                'Documents/in4up/tipitaka/imports rồi quét lại.',
              ),
            ),
          ),
        );
        return;
      }
      final taskId = TipitakaTaskCoordinator.batchId(files);
      TipitakaTaskOverlay.show(context, taskId);
      final task = TipitakaTaskCoordinator.instance.importFiles(files);
      unawaited(task.then((status) {
        if (!mounted) return;
        if (status.phase == TipitakaTaskPhase.completed) _refresh();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status.phase == TipitakaTaskPhase.completed
                  ? context.uiText('Đã import các file tìm thấy trong thư mục.')
                  : context.uiText('Import thất bại: ${status.error}'),
            ),
          ),
        );
      }));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.uiText('Quét thất bại: $error'))),
        );
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  void _openLibrary() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TipitakaLibraryScreen()),
    );
  }

  String _taskPhaseLabel(BuildContext context, TipitakaTaskPhase phase) {
    return switch (phase) {
      TipitakaTaskPhase.queued => context.uiText('Đang xếp hàng'),
      TipitakaTaskPhase.downloading => context.uiText('Đang tải'),
      TipitakaTaskPhase.extracting => context.uiText('Đang giải nén'),
      TipitakaTaskPhase.importing => context.uiText('Đang import'),
      TipitakaTaskPhase.completed => context.uiText('Đã hoàn tất'),
      TipitakaTaskPhase.failed => context.uiText('Thất bại'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    return Scaffold(
      appBar: AppBar(title: const Text('Tipiṭaka — Dữ liệu')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Icon(
            info?.isReady == true ? Icons.cloud_done : Icons.cloud_off,
            size: 52,
            color: info?.isReady == true
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 12),
          Text(
            info?.isReady == true
                ? 'Cơ sở dữ liệu đã sẵn sàng'
                : 'Chưa có cơ sở dữ liệu hợp lệ',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (info?.isReady == true)
            Card(
              child: ListTile(
                leading: const Icon(Icons.storage),
                title: Text(
                  '${info!.segmentCount} ${context.uiText('đoạn kinh')}',
                ),
                subtitle: Text(
                  '${info.collectionCount} ${context.uiText('tạng')} · '
                  '${info.bookCount} ${context.uiText('sách')} · '
                  '${info.availableLanguages.join(', ')}\n${info.path}',
                ),
              ),
            )
          else
            Text(
              context.uiText(
                _error == null
                    ? 'Hãy import DB Pa-Auk hoặc tải gói ngôn ngữ.'
                    : 'Không thể kiểm tra cơ sở dữ liệu Tipiṭaka.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ValueListenableBuilder<List<TipitakaTaskStatus>>(
            valueListenable: TipitakaTaskCoordinator.instance.tasks,
            builder: (context, tasks, child) {
              if (tasks.isEmpty) return const SizedBox.shrink();
              final recent = tasks.reversed.take(5).toList();
              return Card(
                margin: const EdgeInsets.only(top: 16),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.sync_alt),
                      title: Text(context.uiText('Tác vụ Tipiṭaka gần đây')),
                    ),
                    for (final task in recent)
                      ListTile(
                        dense: true,
                        leading: Icon(
                          task.phase == TipitakaTaskPhase.failed
                              ? Icons.error_outline
                              : task.isDone
                                  ? Icons.check_circle_outline
                                  : Icons.sync,
                        ),
                        title: Text(
                          '${task.label} · ${_taskPhaseLabel(context, task.phase)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: task.error == null
                            ? task.progress == null
                                ? null
                                : LinearProgressIndicator(value: task.progress)
                            : Text(
                                task.error!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _importing ? null : _importDatabase,
            icon: _importing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_open),
            label: const Text('Import DB hoặc gói ngôn ngữ từ thiết bị'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _scanning ? null : _scanImportFolder,
            icon: _scanning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.folder_open),
            label: const Text('Quét thư mục import của developer'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TipsLanguagePackScreen(),
                ),
              );
              _refresh();
            },
            icon: const Icon(Icons.language),
            label: const Text('Tải gói ngôn ngữ Pa-Auk'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Kiểm tra lại DB'),
          ),
          const SizedBox(height: 20),
          Text(
            context.uiText(
              'Bạn có thể chọn trực tiếp DB Pa-Auk .db/.sqlite/.zip hoặc file '
              'tipitaka.sqlite đã chuẩn hóa. Với build developer, đặt file vào '
              'Documents/in4up/tipitaka/imports/ rồi bấm Quét thư mục import. '
              'Ứng dụng sẽ tự nhận diện, chuyển DB nguồn sang schema In4Up và '
              'giữ lại Python importer cho các DB rất lớn.',
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: info?.isReady == true ? _openLibrary : null,
            icon: const Icon(Icons.menu_book_rounded),
            label: const Text('Mở thư viện'),
          ),
        ],
      ),
    );
  }
}
