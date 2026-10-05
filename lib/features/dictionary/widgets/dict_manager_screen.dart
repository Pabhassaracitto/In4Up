import 'dart:io';

import 'package:in4up/core/language/localized_material.dart';

import '../models/dict_info.dart';
import '../services/dict_import_service.dart';
import '../services/dictionary_service.dart';

/// Màn hình quản lý từ điển đã import (I4U18-DICT-001):
/// - Import THƯ MỤC hoặc NHIỀU FILE (set .mdx + .mdd + .css/asset).
/// - Hai chế độ rõ: **Liên kết** (index, không copy dữ liệu lớn) và
///   **Sao chép vào app** (ổn định lâu dài).
/// - Card hiện chế độ + badge thiếu file phụ (vẫn tra được ở chế độ giảm cấp).
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
    // Cập nhật trạng thái nguồn của từ điển LINK (user có thể đã xoá/di
    // chuyển thư mục gốc) — vẫn giữ entry vì index SQLite còn tra được.
    final refreshed = await DictionaryService.instance.refreshLinkedSources();
    if (!mounted) return;
    setState(() {
      _dicts = refreshed;
      _isLoading = false;
    });
  }

  /// Hỏi chế độ dùng từ điển — BẮT BUỘC user chọn rõ trước mỗi lần import.
  /// Trả null khi user bỏ qua.
  Future<DictStorageMode?> _askStorageMode() {
    return showDialog<DictStorageMode>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A2235),
          title: Text(
            ctx.uiText('Chọn cách dùng từ điển'),
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!Platform.isAndroid)
                _ModeOption(
                  icon: Icons.link,
                  title: ctx.uiText('Liên kết thư mục (khuyến nghị)'),
                  subtitle: ctx.uiText(
                    'Dùng ngay — chỉ tạo index tra từ, không copy file lớn '
                    '(mdx/mdd ở nguyên chỗ cũ). Xoá thư mục gốc sẽ mất hình/âm thanh '
                    'kèm theo nhưng vẫn tra được từ.',
                  ),
                  onTap: () => Navigator.pop(ctx, DictStorageMode.linked),
                ),
              if (!Platform.isAndroid) const SizedBox(height: 8),
              _ModeOption(
                icon: Icons.save_alt,
                title: ctx.uiText('Sao chép vào app'),
                subtitle: ctx.uiText(
                  'Copy mdx + mdd + css vào bộ nhớ app — ổn định lâu dài, '
                  'không sợ đổi/xoá thư mục gốc (tốn dung lượng tương đương).',
                ),
                onTap: () => Navigator.pop(ctx, DictStorageMode.imported),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ctx.uiText('Huỷ')),
            ),
          ],
        );
      },
    );
  }

  String _modeLabel(BuildContext context, DictStorageMode mode) =>
      mode == DictStorageMode.linked
          ? context.uiText('Liên kết')
          : context.uiText('Trong app');

  Future<void> _import({required bool folder}) async {
    final mode = await _askStorageMode();
    if (mode == null || !mounted) return;

    final progress = ValueNotifier<(double, String)>((0.0, ''));
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2235),
        content: ValueListenableBuilder<(double, String)>(
          valueListenable: progress,
          builder: (ctx2, value, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: value.$1 <= 0 ? null : value.$1),
              const SizedBox(height: 12),
              Text(
                // Thông điệp service (quét/import/lỗi) cũng là chrome —
                // dịch qua uiText, chuỗi lạ sẽ đi qua nguyên vẹn.
                value.$2.isEmpty
                    ? ctx2.uiText('Đang import từ điển…')
                    : ctx2.uiText(value.$2),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );

    final outcome = folder
        ? await DictImportService.pickFolderAndImport(
            mode,
            onProgress: (p, m) => progress.value = (p, m),
          )
        : await DictImportService.pickFilesAndImport(
            mode,
            onProgress: (p, m) => progress.value = (p, m),
          );

    if (mounted) Navigator.of(context).pop(); // đóng progress dialog
    progress.dispose();
    await _loadDicts();
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final modeText = _modeLabel(context, mode);
    if (outcome.isSuccess) {
      final names = outcome.imported.map((d) => d.name).join(', ');
      final missing = outcome.missingParts.isEmpty
          ? ''
          : '\n${context.uiText('Thiếu file phụ:')} '
              '${outcome.missingParts.toSet().join(' · ')}';
      final stray = outcome.strayCompanions.isEmpty
          ? ''
          : '\n${context.uiText('File lẻ không thuộc bộ nào:')} '
              '${outcome.strayCompanions.join(', ')}';
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${context.uiText('Đã import:')} $names [$modeText]$missing$stray',
          ),
          backgroundColor: outcome.missingParts.isEmpty
              ? const Color(0xFF4CAF50)
              : const Color(0xFFF9A825),
          duration: const Duration(seconds: 5),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${context.uiText('Import thất bại')}: '
            '${context.uiText(outcome.error ?? '')}',
          ),
          backgroundColor: const Color(0xFFEF5350),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _deleteDict(DictInfo dict) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2235),
        title: Text(ctx.uiText('Xóa từ điển?'),
            style: const TextStyle(color: Colors.white)),
        content: Text(
          '${dict.name} (${dict.entryCount} entries)'
          '${dict.isLinked ? '\n${ctx.uiText('Thư mục nguồn của bạn sẽ KHÔNG bị xoá.')}' : ''}',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.uiText('Huỷ')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF5350)),
            child: Text(ctx.uiText('Xoá')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DictionaryService.instance.deleteDict(dict.id);
      await _loadDicts();
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _dicts.isEmpty
              ? _buildEmptyState()
              : _buildDictList(),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                  ),
                  onPressed: () => _import(folder: true),
                  icon: const Icon(Icons.folder_open, color: Colors.white),
                  label: Text(context.uiText('Import thư mục')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF2196F3)),
                  ),
                  onPressed: () => _import(folder: false),
                  icon: const Icon(Icons.insert_drive_file,
                      color: Color(0xFF2196F3)),
                  label: Text(
                    context.uiText('Import file'),
                    style: const TextStyle(color: Color(0xFF2196F3)),
                  ),
                ),
              ),
            ],
          ),
        ),
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
            context.uiText('Chưa có từ điển nào'),
            style: TextStyle(
                color: Colors.grey[500],
                fontSize: 16,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              context.uiText(
                'Bấm Import thư mục để thêm bộ từ điển '
                '(.mdx + .mdd + .css) — dùng ngay không cần copy.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700], fontSize: 13),
            ),
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
          modeLabel: _modeLabel(context, dict.storageMode),
          onToggle: (enabled) async {
            await DictionaryService.instance.toggleDict(dict.id, enabled);
            await _loadDicts();
          },
          onDelete: () => _deleteDict(dict),
        );
      },
    );
  }
}

class _ModeOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ModeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF2196F3), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DictCard extends StatelessWidget {
  final DictInfo dict;
  final String modeLabel;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  const _DictCard({
    required this.dict,
    required this.modeLabel,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  dict.isLinked ? Icons.link : Icons.menu_book,
                  color: const Color(0xFF2196F3),
                  size: 24,
                ),
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
                      '${dict.entryCount} entries · ${dict.langPairLabel} · $modeLabel',
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
          // Badge thiếu file phụ — từ điển vẫn dùng được giảm cấp.
          if (dict.hasMissingResources) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.amber, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${context.uiText('Thiếu file phụ:')} '
                      '${dict.missingResources.join(' · ')}\n'
                      '${context.uiText('Vẫn tra được từ ở chế độ giảm cấp.')}',
                      style: const TextStyle(
                          color: Colors.amber, fontSize: 11, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
