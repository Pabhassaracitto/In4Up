import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/vocabulary_provider.dart';
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
  List<DictInfo> _dicts = [];

  @override
  void initState() {
    super.initState();
    _loadDicts();
  }

  Future<void> _loadDicts() async {
    await DictionaryService.instance.ensureInitialized();
    setState(() {
      _dicts = DictionaryService.instance.dictionaries;
      _isLoading = false;
    });
  }

  Future<void> _importDict() async {
    setState(() => _isLoading = true);

    final info = await DictImportService.pickAndImportMdx(
      onProgress: (progress, message) {
        // TODO: Show progress dialog
      },
    );

    setState(() {
      _dicts = DictionaryService.instance.dictionaries;
      _isLoading = false;
    });

    if (info != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã import: ${info.name} (${info.entryCount} entries)'),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
    }
  }

  Future<void> _deleteDict(DictInfo dict) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2235),
        title: const Text('Xóa từ điển?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Xóa "${dict.name}" (${dict.entryCount} entries)?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF5350)),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DictionaryService.instance.deleteDict(dict.id);
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
        title: const Text('Quản lý từ điển',
            style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2196F3)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _dicts.isEmpty
              ? _buildEmptyState()
              : _buildDictList(),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2196F3),
        onPressed: _importDict,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.menu_book, size: 64, color: Colors.grey[800]),
          const SizedBox(height: 16),
          Text(
            'Chưa có từ điển nào',
            style: TextStyle(
                color: Colors.grey[500],
                fontSize: 16,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Nhấn + để import file .mdx',
            style: TextStyle(color: Colors.grey[700], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildDictList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _dicts.length,
      itemBuilder: (context, index) {
        final dict = _dicts[index];
        return _DictCard(
          dict: dict,
          onToggle: (enabled) async {
            await DictionaryService.instance.toggleDict(dict.id, enabled);
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
                  '${dict.entryCount} entries · ${dict.langPairLabel}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
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
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
