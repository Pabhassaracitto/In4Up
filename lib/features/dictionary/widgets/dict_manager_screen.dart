import 'package:flutter/material.dart';

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
  final _service = DictionaryService.instance;
  bool _importing = false;
  double _importProgress = 0;
  String _importMessage = '';

  @override
  void initState() {
    super.initState();
    _service.ensureInitialized().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _importMdx() async {
    setState(() {
      _importing = true;
      _importProgress = 0;
      _importMessage = 'Đang chọn file...';
    });

    final info = await DictImportService.pickAndImport(
      onProgress: (p, msg) {
        if (mounted) {
          setState(() {
            _importProgress = p;
            _importMessage = msg;
          });
        }
      },
    );

    if (mounted) {
      setState(() => _importing = false);
      if (info != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Đã import "${info.name}" (${info.entryCount} entries)'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF1B5E20),
          ),
        );
      }
    }
  }

  Future<void> _deleteDict(DictInfo dict) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text('Xóa "${dict.name}"?'),
        content: Text(
          '${dict.entryCount} entries sẽ bị xóa. Không thể hoàn tác.',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _service.deleteDict(dict.id);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final dicts = _service.dictionaries;

    return Scaffold(
      backgroundColor: const Color(0xFF080B1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text(
          'Quản lý từ điển',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2196F3)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Import progress
          if (_importing)
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF111827),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: _importProgress > 0 ? _importProgress : null,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF2196F3)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _importMessage,
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ],
              ),
            ),

          // Dict list
          Expanded(
            child: dicts.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: dicts.length,
                    itemBuilder: (_, i) => _DictCard(
                      dict: dicts[i],
                      onToggle: (enabled) async {
                        await _service.toggleDict(dicts[i].id, enabled);
                        if (mounted) setState(() {});
                      },
                      onDelete: () => _deleteDict(dicts[i]),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _importing ? null : _importMdx,
        backgroundColor: const Color(0xFF2196F3),
        icon: const Icon(Icons.add),
        label: const Text('Import MDX'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined,
                size: 64, color: Colors.grey[700]),
            const SizedBox(height: 16),
            Text(
              'Chưa có từ điển nào',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Nhấn "Import MDX" để thêm file từ điển\n(.mdx từ GoldenDict, MDX Dictionary, ...)',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
        ),
      ),
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: dict.enabled
                  ? const Color(0xFF2196F3).withValues(alpha: 0.15)
                  : Colors.grey.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.menu_book,
              color: dict.enabled ? const Color(0xFF2196F3) : Colors.grey,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dict.name,
                  style: TextStyle(
                    color: dict.enabled ? Colors.white : Colors.grey[500],
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      dict.langPairLabel,
                      style: TextStyle(color: Colors.grey[600], fontSize: 11),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${dict.entryCount} entries',
                      style: TextStyle(color: Colors.grey[600], fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Toggle
          Switch(
            value: dict.enabled,
            onChanged: onToggle,
            activeColor: const Color(0xFF2196F3),
          ),

          // Delete
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.grey[600], size: 20),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
