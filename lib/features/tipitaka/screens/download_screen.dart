import 'package:file_picker/file_picker.dart';
import 'package:in4up/core/language/localized_material.dart';

import 'package:in4up/features/tipitaka/screens/language_pack_screen.dart';
import 'package:in4up/features/tipitaka/screens/library_screen.dart';
import 'package:in4up/features/tipitaka/services/db_service.dart';

class TipitakaDownloadScreen extends StatefulWidget {
  const TipitakaDownloadScreen({super.key});

  @override
  State<TipitakaDownloadScreen> createState() => _TipitakaDownloadScreenState();
}

class _TipitakaDownloadScreenState extends State<TipitakaDownloadScreen> {
  TipitakaDatabaseInfo? _info;
  bool _loading = true;
  bool _importing = false;
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
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['sqlite', 'db'],
      );
      if (!mounted || result == null) return;
      final path = result.files.single.path;
      if (path == null) {
        throw const TipitakaDatabaseException(
          'Không lấy được đường dẫn file trên thiết bị này.',
        );
      }
      await TipitakaDb.installDatabaseFile(path);
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.uiText('Đã import cơ sở dữ liệu Tipiṭaka.'))),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.uiText('Import thất bại: $error'))),
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _openLibrary() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TipitakaLibraryScreen()),
    );
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
                    ? 'Hãy import một DB chuẩn hóa hoặc tải gói ngôn ngữ.'
                    : 'Không thể kiểm tra cơ sở dữ liệu Tipiṭaka.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
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
            label: const Text('Import DB chuẩn hóa từ thiết bị'),
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
              'Quy trình dành cho developer:\n'
              '1. Đặt DB nguồn .db đã giải nén vào reference/.\n'
              '2. Chạy python scripts/import_tipitaka.py.\n'
              '3. Đưa file assets/db/tipitaka.sqlite vào build để app tự copy '
              'ở lần chạy đầu, hoặc import file chuẩn hóa từ màn hình này.\n\n'
              'File tải từ Pa-Auk là DB nguồn, không phải DB app chuẩn hóa; '
              'ứng dụng sẽ không mở nhầm file đó như một DB rỗng.',
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
