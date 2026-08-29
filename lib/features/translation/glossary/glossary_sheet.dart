// lib/features/translation/glossary/glossary_sheet.dart
//
// Màn "Thuật ngữ dịch" — quản lý glossary (list / thêm / sửa / khóa / xóa).
// UI tối giản, theo đúng luật i18n: mọi chuỗi chrome qua uiText + override
// English (locale ≠ vi không bao giờ hiện tiếng Việt).
//
// Nguồn dữ liệu: GlossaryStore (Hive box `translation_glossary`).

import 'dart:async';

import '../../../core/language/localized_material.dart';
import 'glossary_store.dart';
import 'translation_glossary.dart';

/// Mở bottom sheet quản lý glossary.
Future<void> showGlossarySheet(
  BuildContext context, {
  Color accentColor = const Color(0xFF6C63FF),
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF1A1A2E),
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => GlossarySheet(accentColor: accentColor),
  );
}

class GlossarySheet extends StatefulWidget {
  final Color accentColor;

  const GlossarySheet({super.key, required this.accentColor});

  @override
  State<GlossarySheet> createState() => _GlossarySheetState();
}

class _GlossarySheetState extends State<GlossarySheet> {
  final GlossaryStore _store = GlossaryStore();
  final TextEditingController _search = TextEditingController();
  StreamSubscription<void>? _sub;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _sub = _store.changes.listen((_) {
      if (mounted) setState(() {});
    });
    _store.ensureInit().then((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = _store.entries
        .where((e) {
          final q = _search.text.trim().toLowerCase();
          if (q.isEmpty) return true;
          return e.sourceNorm.toLowerCase().contains(q) ||
              e.targetText.toLowerCase().contains(q);
        })
        .toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.uiText('Thuật ngữ dịch'),
                    style: const TextStyle(
                      fontSize: 17,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.grey),
                  tooltip: context.uiText('Hủy'),
                ),
              ],
            ),
            Text(
              context.uiText(
                'Thuật ngữ khóa giữ nguyên khi dịch — engine không được đè.',
              ),
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: context.uiText('Tìm thuật ngữ...'),
                hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
                prefixIcon:
                    const Icon(Icons.search, size: 16, color: Colors.grey),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (!_ready)
              const Padding(
                padding: EdgeInsets.all(24),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Text(
                      context.uiText('Chưa có thuật ngữ nào.'),
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.uiText('Bấm + để thêm.'),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                height: 420,
                child: ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (ctx, i) => _entryTile(ctx, entries[i]),
                ),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => _showEditor(context, entry: null),
                style: FilledButton.styleFrom(
                  backgroundColor: widget.accentColor,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add, size: 16),
                label: Text(context.uiText('Thêm')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _entryTile(BuildContext context, GlossaryEntry entry) {
    return InkWell(
      onTap: () => _showEditor(context, entry: entry),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              entry.locked ? Icons.lock : Icons.lock_open,
              size: 12,
              color: entry.locked ? Colors.amber : Colors.grey,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.sourceNorm,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${entry.sourceLang.toUpperCase()} → '
                    '${entry.targetLang.toUpperCase()} · '
                    '${_domainLabel(context, entry.domain)}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 10),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                entry.targetText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _domainLabel(BuildContext context, String domain) {
    switch (domain) {
      case GlossaryDomain.buddhist:
        return context.uiText('Phật học');
      case GlossaryDomain.user:
        return context.uiText('Người dùng');
      default:
        return context.uiText('Chung');
    }
  }

  Future<void> _showEditor(BuildContext context,
      {GlossaryEntry? entry}) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _GlossaryEditorSheet(
        store: _store,
        entry: entry,
        accentColor: widget.accentColor,
        onSaved: () {
          if (mounted) setState(() {});
        },
      ),
    );
  }
}

class _GlossaryEditorSheet extends StatefulWidget {
  final GlossaryStore store;
  final GlossaryEntry? entry;
  final Color accentColor;
  final VoidCallback onSaved;

  const _GlossaryEditorSheet({
    required this.store,
    required this.entry,
    required this.accentColor,
    required this.onSaved,
  });

  @override
  State<_GlossaryEditorSheet> createState() => _GlossaryEditorSheetState();
}

class _GlossaryEditorSheetState extends State<_GlossaryEditorSheet> {
  late final TextEditingController _source;
  late final TextEditingController _target;
  late String _sourceLang;
  late String _targetLang;
  late String _domain;
  late bool _locked;

  static const _sourceLangs = <String>['pi', 'en', 'hi', 'vi'];
  static const _targetLangs = <String>['vi', 'en', 'hi'];
  static const _domains = <String>[
    GlossaryDomain.buddhist,
    GlossaryDomain.user,
    GlossaryDomain.general,
  ];

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _source = TextEditingController(text: entry?.sourceNorm ?? '');
    _target = TextEditingController(text: entry?.targetText ?? '');
    _sourceLang = entry?.sourceLang ?? 'pi';
    _targetLang = entry?.targetLang ?? 'vi';
    _domain = entry?.domain ?? GlossaryDomain.user;
    _locked = entry?.locked ?? true;
  }

  @override
  void dispose() {
    _source.dispose();
    _target.dispose();
    super.dispose();
  }

  String _langLabel(String code) {
    switch (code) {
      case 'pi':
        return 'Pali';
      case 'en':
        return 'English';
      case 'hi':
        return 'Hindi';
      case 'vi':
        return 'Vietnamese';
      default:
        return code;
    }
  }

  Future<void> _save() async {
    final source = _source.text.trim();
    final target = _target.text.trim();
    if (source.isEmpty || target.isEmpty) return;
    final entry = GlossaryEntry(
      id: GlossaryEntry.makeId(source, _sourceLang, _targetLang),
      sourceNorm: source,
      sourceLang: _sourceLang,
      targetLang: _targetLang,
      targetText: target,
      locked: _locked,
      domain: _domain,
      priority: _domain == GlossaryDomain.user
          ? GlossaryPriority.user
          : GlossaryPriority.seed,
    );
    final ok = await widget.store.upsert(entry);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    widget.onSaved();
    if (ok) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Đã lưu thuật ngữ'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _delete() async {
    final entry = widget.entry;
    if (entry == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(
          context.uiText('Xóa thuật ngữ này?'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          entry.sourceNorm,
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              context.uiText('Hủy'),
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Xóa',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.store.remove(entry.id);
    Navigator.pop(context);
    if (mounted) widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.entry != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.uiText(isEditing ? 'Sửa thuật ngữ' : 'Thêm thuật ngữ'),
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _source,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                labelText: context.uiText('Từ nguồn'),
                labelStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _sourceLang,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF252540),
                    borderRadius: BorderRadius.circular(10),
                    items: [
                      for (final code in _sourceLangs)
                        DropdownMenuItem(
                          value: code,
                          child: Text(
                            '${_langLabel(code)} ($code)',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                    ],
                    onChanged: (v) =>
                        setState(() => _sourceLang = v ?? 'pi'),
                    decoration: InputDecoration(
                      labelText: context.uiText('Ngôn ngữ nguồn'),
                      labelStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _targetLang,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF252540),
                    borderRadius: BorderRadius.circular(10),
                    items: [
                      for (final code in _targetLangs)
                        DropdownMenuItem(
                          value: code,
                          child: Text(
                            '${_langLabel(code)} ($code)',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                    ],
                    onChanged: (v) =>
                        setState(() => _targetLang = v ?? 'vi'),
                    decoration: InputDecoration(
                      labelText: context.uiText('Ngôn ngữ đích'),
                      labelStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _target,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                labelText: context.uiText('Bản dịch khóa'),
                labelStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _locked,
              onChanged: (v) => setState(() => _locked = v),
              activeColor: widget.accentColor,
              title: Text(
                context.uiText('Khóa — engine không được đè'),
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            DropdownButtonFormField<String>(
              value: _domain,
              isExpanded: true,
              dropdownColor: const Color(0xFF252540),
              borderRadius: BorderRadius.circular(10),
              items: [
                for (final code in _domains)
                  DropdownMenuItem(
                    value: code,
                    child: Text(
                      switch (code) {
                        GlossaryDomain.buddhist => context.uiText('Phật học'),
                        GlossaryDomain.user => context.uiText('Người dùng'),
                        _ => context.uiText('Chung'),
                      },
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
              ],
              onChanged: (v) =>
                  setState(() => _domain = v ?? GlossaryDomain.user),
              decoration: InputDecoration(
                labelText: context.uiText('Ngữ cảnh'),
                labelStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (isEditing)
                  TextButton.icon(
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Xóa'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                    ),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    context.uiText('Hủy'),
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: widget.accentColor,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(context.uiText('Lưu')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
