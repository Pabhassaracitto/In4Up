import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:in4up/core/language/localized_material.dart';

import 'package:in4up/features/tipitaka/screens/language_pack_screen.dart';
import 'package:in4up/features/tipitaka/screens/library_screen.dart';
import 'package:in4up/features/tipitaka/screens/tipitaka_task_overlay.dart';
import 'package:in4up/features/tipitaka/services/db_service.dart';
import 'package:in4up/features/tipitaka/services/tipitaka_language_resolver.dart';
import 'package:in4up/features/tipitaka/services/tipitaka_markup.dart';
import 'package:in4up/features/tipitaka/services/tipitaka_task_service.dart';

class TipitakaDownloadScreen extends StatefulWidget {
  const TipitakaDownloadScreen({super.key});

  @override
  State<TipitakaDownloadScreen> createState() => _TipitakaDownloadScreenState();
}

class _TipitakaDownloadScreenState extends State<TipitakaDownloadScreen> {
  TipitakaDatabaseInfo? _info;
  List<TipitakaImportRecord> _imports = const [];
  bool _demoPresent = false;
  bool _demoDisabled = false;
  bool _loading = true;
  bool _importing = false;
  bool _scanning = false;
  bool _busy = false;
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
      final imports = await TipitakaDb.importHistory(db);
      final demoPresent = await TipitakaDb.hasDemoData(db);
      if (mounted) {
        setState(() {
          _info = info;
          _imports = imports;
          _demoPresent = demoPresent;
          _demoDisabled = false;
        });
      }
    } catch (error) {
      var demoDisabled = false;
      try {
        demoDisabled = await TipitakaDb.isBundledDemoDisabled();
      } catch (_) {
        // Platform without a documents directory: keep the generic message.
      }
      if (mounted) {
        setState(() {
          _info = null;
          _imports = const [];
          _demoPresent = false;
          _demoDisabled = demoDisabled;
          _error = error.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _confirm(String title, String message) async {
    final cancelLabel = context.uiText('Hủy');
    final deleteLabel = context.uiText('Xoá');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(deleteLabel),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  List<String> get _installedLanguages {
    final languages = <String>{
      for (final record in _imports)
        if (record.languageCode.isNotEmpty)
          TipitakaLanguageResolver.normalize(record.languageCode),
      for (final code in _info?.availableLanguages ?? const <String>{})
        TipitakaLanguageResolver.normalize(code),
    }..remove('');
    final ordered = languages.toList()..sort();
    return ordered;
  }

  Future<void> _deleteLanguage(String language) async {
    if (_busy) return;
    final successText = context.uiText('Đã xóa gói ngôn ngữ.');
    final failureText = context.uiText('Không thể xóa gói ngôn ngữ.');
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await _confirm(
      context.uiText('Xác nhận xóa gói'),
      context.uiText('Toàn bộ nội dung của gói này sẽ bị xóa khỏi thư viện.'),
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await TipitakaDb.deleteLanguagePack(language);
      await _refresh();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(successText)));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(failureText)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteDatabase() async {
    if (_busy) return;
    final successText = context.uiText('Đã xóa cơ sở dữ liệu Tipiṭaka.');
    final failureText = context.uiText('Không thể xóa cơ sở dữ liệu.');
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await _confirm(
      context.uiText('Xóa cơ sở dữ liệu Tipiṭaka?'),
      context.uiText(
        'Thao tác này xóa DB đã cài, bản sao lưu và các gói đã tải. Bạn có thể import lại bất kỳ lúc nào.',
      ),
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await TipitakaDb.deleteDatabase();
      await _refresh();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(successText)));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(failureText)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _purgeDemo() async {
    if (_busy) return;
    final successText = context.uiText('Đã dọn bản Demo.');
    final failureText = context.uiText('Không thể dọn bản Demo.');
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await TipitakaDb.purgeDemoData();
      await _refresh();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(successText)));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(failureText)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreDemo() async {
    if (_busy) return;
    final successText = context.uiText('Đã khôi phục bản mẫu.');
    final failureText = context.uiText('Không thể khôi phục bản mẫu.');
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await TipitakaDb.restoreBundledDemo();
      await _refresh();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(successText)));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(failureText)));
    } finally {
      if (mounted) setState(() => _busy = false);
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
          if (info?.isReady == true) ...[
            const SizedBox(height: 12),
            _DatabaseManagementCard(
              info: info!,
              imports: _imports,
              languages: _installedLanguages,
              demoPresent: _demoPresent,
              busy: _busy,
              onDeleteLanguage: _deleteLanguage,
              onDeleteDatabase: _deleteDatabase,
              onPurgeDemo: _purgeDemo,
            ),
          ] else if (!_loading && _demoDisabled) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : _restoreDemo,
              icon: const Icon(Icons.restore_outlined),
              label: Text(context.uiText('Khôi phục bản mẫu')),
            ),
          ],
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
                          context.uiText('${task.label} · ${_taskPhaseLabel(context, task.phase)}'),
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
          Card(
            child: ListTile(
              leading: const Icon(Icons.copyright_outlined),
              title: Text(context.uiText('Nguồn dữ liệu Pāli')),
              subtitle: Text(
                context.uiText(
                  'Chaṭṭha Saṅgāyana (CSCD), Vipassana Research Institute — CC BY-NC. Giữ ghi công và chỉ sử dụng phi thương mại.',
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
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

/// PSRC-160 — explicit, auditable management of the installed database:
/// imported packs, demo cleanup and full deletion with confirmation.
class _DatabaseManagementCard extends StatelessWidget {
  final TipitakaDatabaseInfo info;
  final List<TipitakaImportRecord> imports;
  final List<String> languages;
  final bool demoPresent;
  final bool busy;
  final ValueChanged<String> onDeleteLanguage;
  final VoidCallback onDeleteDatabase;
  final VoidCallback onPurgeDemo;

  const _DatabaseManagementCard({
    required this.info,
    required this.imports,
    required this.languages,
    required this.demoPresent,
    required this.busy,
    required this.onDeleteLanguage,
    required this.onDeleteDatabase,
    required this.onPurgeDemo,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.tune_outlined),
              title: Text(context.uiText('Quản lý dữ liệu')),
              subtitle: Text(
                '${(info.bytes / (1024 * 1024)).toStringAsFixed(1)} MB · '
                '${info.path}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (languages.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 2),
                child: Text(
                  context.uiText('Gói dữ liệu đã import'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              for (final language in languages)
                Builder(builder: (context) {
                  final sources = imports
                      .where((record) => record.languageCode == language)
                      .map((record) => record.sourceName)
                      .where((name) => name.isNotEmpty)
                      .join(', ');
                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: const Icon(Icons.language_outlined, size: 20),
                    title: Text(tipitakaLanguageLabel(language)),
                    subtitle: Text(
                      sources.isEmpty
                          ? context.uiText('Dữ liệu đi kèm ứng dụng')
                          : sources,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      tooltip: context.uiText('Xóa gói ngôn ngữ'),
                      onPressed: busy ? null : () => onDeleteLanguage(language),
                      icon: Icon(
                        Icons.delete_outline,
                        color: scheme.error,
                        size: 20,
                      ),
                    ),
                  );
                }),
            ],
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (demoPresent)
                  OutlinedButton.icon(
                    onPressed: busy ? null : onPurgeDemo,
                    icon: const Icon(Icons.cleaning_services_outlined),
                    label: Text(context.uiText('Dọn bản Demo')),
                  ),
                OutlinedButton.icon(
                  onPressed: busy ? null : onDeleteDatabase,
                  icon: Icon(Icons.delete_forever_outlined, color: scheme.error),
                  label: Text(context.uiText('Xóa toàn bộ cơ sở dữ liệu')),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              context.uiText(
                'Thao tác này xóa DB đã cài, bản sao lưu và các gói đã tải. Bạn có thể import lại bất kỳ lúc nào.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
