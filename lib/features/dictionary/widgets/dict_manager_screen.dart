// lib/features/dictionary/widgets/dict_manager_screen.dart
// Màn hình quản lý từ điển đã import.
//
// Fix chính ở đây (bug "thêm từ điển xong vẫn hiện 'Chưa có từ điển nào'"):
// import thất bại trước đây trả `null` im lặng ⇒ người dùng không hề biết vì
// sao (file sai định dạng, MDX mã hóa, engine 3.0…). Giờ mọi đường lỗi đều
// hiện thông báo cụ thể, và đang import có dialog tiến trình.

import 'package:flutter/material.dart';
import 'package:in4up/core/language/localized_material.dart';

import '../models/dict_info.dart';
import '../services/dict_import_service.dart';
import '../services/dictionary_service.dart';

/// Màn hình quản lý từ điển đã import
class DictManagerScreen extends StatefulWidget {
  const DictManagerScreen({super.key});

  @override
  State<DictManagerScreen> createState() => _DictManagerScreenState();
}

class _DictManagerScreenState extends State<DictManagerScreen> {
  bool _isLoading = true;
  bool _isImporting = false;
  List<DictInfo> _dicts = [];

  final ValueNotifier<double> _progress = ValueNotifier<double>(0);
  final ValueNotifier<String> _progressMessage = ValueNotifier<String>('');

  @override
  void initState() {
    super.initState();
    _loadDicts();
  }

  @override
  void dispose() {
    _progress.dispose();
    _progressMessage.dispose();
    super.dispose();
  }

  Future<void> _loadDicts() async {
    await DictionaryService.instance.ensureInitialized();
    if (!mounted) return;
    setState(() {
      _dicts = DictionaryService.instance.dictionaries;
      _isLoading = false;
    });
  }

  Future<void> _importDict() async {
    if (_isImporting) return;
    setState(() => _isImporting = true);

    _progress.value = 0;
    _progressMessage.value = context.uiText('Đang chuẩn bị…');
    _showProgressDialog();

    final result = await DictImportService.pickAndImportMdx(
      dialogTitle: context.uiText('Chọn file từ điển .mdx'),
      onProgress: (progress, message) {
        if (!mounted) return;
        _progress.value = progress.clamp(0.0, 1.0);
        _progressMessage.value = message;
      },
    );

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // đóng dialog tiến trình
    setState(() {
      _isImporting = false;
      _dicts = DictionaryService.instance.dictionaries;
    });

    if (result.isCancelled) return;

    if (result.isSuccess) {
      final info = result.info!;
      _showSnack(
        message:
            '${context.uiText('Đã import')}: ${info.name} (${info.entryCount} '
            '${context.uiText('mục từ')})',
        background: const Color(0xFF4CAF50),
      );
    } else {
      _showSnack(
        message: '${context.uiText('Import thất bại')} — ${result.error}',
        background: const Color(0xFFEF5350),
        duration: const Duration(seconds: 8),
      );
    }
  }

  void _showProgressDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1A2235),
          title: Text(context.uiText('Đang import từ điển…'),
              style: const TextStyle(color: Colors.white, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ValueListenableBuilder<double>(
                valueListenable: _progress,
                builder: (_, value, __) => LinearProgressIndicator(
                  value: value <= 0 ? null : value,
                  backgroundColor: Colors.white12,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
                ),
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<String>(
                valueListenable: _progressMessage,
                builder: (_, message, __) => Text(
                  message,
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnack({
    required String message,
    required Color background,
    Duration duration = const Duration(seconds: 4),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: background,
        behavior: SnackBarBehavior.floating,
        duration: duration,
      ),
    );
  }

  Future<void> _deleteDict(DictInfo dict) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2235),
        title: Text(context.uiText('Xóa từ điển?'),
            style: const TextStyle(color: Colors.white)),
        content: Text(
          '${dict.name} (${dict.entryCount} ${context.uiText('mục từ')})',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.uiText('Hủy')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF5350)),
            child: Text(context.uiText('Xóa'),
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DictionaryService.instance.deleteDict(dict.id);
      if (!mounted) return;
      setState(() {
        _dicts = DictionaryService.instance.dictionaries;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(context.uiText('Quản lý từ điển'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2196F3)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF2196F3)),
            tooltip: context.uiText('Tải lại'),
            onPressed: _isImporting ? null : _loadDicts,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _dicts.isEmpty
              ? _buildEmptyState()
              : _buildDictList(),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2196F3),
        onPressed: _isImporting ? null : _importDict,
        icon: _isImporting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.add, color: Colors.white),
        label: Text(
          context.uiText(_isImporting ? 'Đang import…' : 'Thêm từ điển'),
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book, size: 64, color: Colors.grey[800]),
            const SizedBox(height: 16),
            Text(
              context.uiText('Chưa có từ điển nào'),
              style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              context.uiText(
                'Chọn file .mdx (MDict) trong máy để tra từ offline. '
                'Hỗ trợ engine 1.x–2.x, nén zlib/LZO/không nén; chưa hỗ trợ '
                'file mã hóa và engine 3.0.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700], fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _isImporting ? null : _importDict,
              icon: const Icon(Icons.file_open, size: 18, color: Colors.white),
              label: Text(
                context.uiText('Chọn file từ điển .mdx'),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDictList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      itemCount: _dicts.length,
      itemBuilder: (context, index) {
        final dict = _dicts[index];
        return _DictCard(
          dict: dict,
          onToggle: (enabled) async {
            await DictionaryService.instance.toggleDict(dict.id, enabled);
            if (!mounted) return;
            setState(() {
              _dicts = DictionaryService.instance.dictionaries;
            });
          },
          onDelete: () => _deleteDict(dict),
        );
      },
    );
  }
}

class _DictCard extends StatelessWidget {
  final DictInfo dict;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  const _DictCard({
    required this.dict,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      '${dict.entryCount} ${context.uiText('mục từ')}',
      dict.langPairLabel,
      if (dict.engineVersion.isNotEmpty) 'MDX ${dict.engineVersion}',
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF2196F3).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.menu_book,
                color: Color(0xFF2196F3), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dict.name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  meta.join(' · '),
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Switch(
            value: dict.enabled,
            onChanged: onToggle,
            activeThumbColor: const Color(0xFF2196F3),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                color: Color(0xFFEF5350), size: 20),
            tooltip: context.uiText('Xóa'),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
