// ADR-0018 (P1) — MÀN HÌNH TỪ ĐIỂN RIÊNG.
//
// Vì sao phải có màn này chứ không chỉ mở sheet kết quả:
//   * Bong bóng tra từ (P4), link `in4up://dict?w=…` (P2) và "Mở bằng In4Up"
//     (P3) đều chỉ là **cách đưa một chuỗi/tệp vào app**. Nếu mỗi đường tự
//     dựng UI riêng thì sẽ có 4 kiểu hiển thị, 4 chỗ xử lý "chưa có bộ từ
//     điển", 4 chỗ lưu lịch sử. Một màn + một hàm [open] biến chúng thành
//     adapter mỏng.
//   * Trước đây `DictManagerScreen` (trang cài đặt) là chỗ duy nhất mở được,
//     còn `DictionaryService.lookupPrefix()` thì **không ai gọi** — không có
//     ô tìm, không gợi ý, không lịch sử.
//
// Nguyên tắc:
//   - KHÔNG viết lại renderer nghĩa: dùng `DictDefinitionView(compact: false)`
//     (đã có nhóm loại từ, nghĩa đánh số, ví dụ, đa ngữ).
//   - Mọi chuỗi đi qua `context.uiText(...)` (quy tắc #5 — locale ≠ vi không
//     bao giờ rơi về tiếng Việt).
//   - Không tự gọi DB khi chưa có bộ từ điển: hiện onboarding rõ ràng.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:in4up/core/language/localized_material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../tts/tts_service.dart';
import '../models/dict_entry.dart';
import '../models/dict_info.dart';
import '../services/dict_history.dart';
import '../services/dict_text_cleaner.dart';
import '../services/dictionary_service.dart';
import 'dict_definition_view.dart';
import 'dict_manager_screen.dart';
import 'dict_pack_screen.dart';

class DictionaryScreen extends StatefulWidget {
  /// Từ cần tra ngay khi mở (từ link, từ bong bóng, từ "Open with In4Up").
  final String? initialQuery;

  /// Nơi mở màn này — chỉ để ghi nhật ký/lịch sử, KHÔNG đổi cách hiển thị.
  /// `home` · `pdf` · `read` · `deep_link` · `file` · `bubble` · `unknown`.
  final String? source;

  const DictionaryScreen({super.key, this.initialQuery, this.source});

  /// ĐIỂM VÀO DUY NHẤT của màn Từ điển (ADR-0018).
  ///
  /// Mọi đường vào (Home, PDF/Read, deep link, mở file, bong bóng) gọi hàm này
  /// để chỉ có một kiểu hiển thị và một chỗ lưu lịch sử.
  static Future<void> open(
    BuildContext context, {
    String? query,
    String? source,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DictionaryScreen(initialQuery: query, source: source),
      ),
    );
  }

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  static const Color _bg = Color(0xFF080B1A);
  static const Color _surface = Color(0xFF111827);
  static const Color _accent = Color(0xFF2196F3);
  static const Color _accentLight = Color(0xFF64B5F6);

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();

  Timer? _debounce;

  List<DictInfo> _dicts = const <DictInfo>[];
  List<String> _history = const <String>[];
  List<String> _suggestions = const <String>[];

  /// Bộ đang lọc (`null` = tra trong TẤT CẢ bộ đang bật).
  String? _selectedDictId;

  /// Từ đang hiển thị kết quả (khác từ đang gõ trong ô tìm).
  String _query = '';

  List<DictEntry> _entries = const <DictEntry>[];
  DictMergedEntry? _merged;

  bool _loadingDicts = true;
  bool _searching = false;
  bool _submitted = false;

  /// Đang gõ (chưa bấm tra) ⇒ hiện gợi ý thay vì kết quả.
  bool _typing = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Khởi động ───────────────────────────────────────────────────────────

  Future<void> _bootstrap() async {
    await _loadDicts();
    await _loadHistory();
    final initial = (widget.initialQuery ?? '').trim();
    if (initial.isNotEmpty) {
      _searchController.text = initial;
      await _submit(initial);
    } else if (mounted) {
      // Chưa tra gì: đặt con trỏ vào ô tìm để gõ được ngay.
      _searchFocus.requestFocus();
    }
  }

  Future<void> _loadDicts() async {
    try {
      await DictionaryService.instance.ensureInitialized();
      final dicts = DictionaryService.instance.enabledDictionaries;
      if (!mounted) return;
      setState(() {
        _dicts = dicts;
        _loadingDicts = false;
        // Bộ đang lọc vừa bị tắt/xoá ⇒ về "tất cả".
        if (_selectedDictId != null &&
            !dicts.any((d) => d.id == _selectedDictId)) {
          _selectedDictId = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _dicts = const <DictInfo>[];
        _loadingDicts = false;
      });
    }
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(DictHistory.prefsKey) ?? const [];
      if (!mounted) return;
      setState(() => _history = saved);
    } catch (_) {
      // Không đọc được lịch sử không phải lỗi chặn tra từ.
    }
  }

  Future<void> _remember(String word) async {
    final next = DictHistory.add(_history, word);
    setState(() => _history = next);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(DictHistory.prefsKey, next);
    } catch (_) {
      // Chỉ là tiện ích.
    }
  }

  Future<void> _clearHistory() async {
    setState(() => _history = const <String>[]);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(DictHistory.prefsKey);
    } catch (_) {}
  }

  Future<void> _forget(String word) async {
    final next = DictHistory.remove(_history, word);
    setState(() => _history = next);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(DictHistory.prefsKey, next);
    } catch (_) {}
  }

  // ── Tìm & tra ───────────────────────────────────────────────────────────

  void _onTextChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _typing = false;
        _suggestions = const <String>[];
      });
      return;
    }
    setState(() => _typing = true);
    // Gợi ý sau khi người dùng NGỪNG gõ 220 ms — gõ nhanh không bắn hàng chục
    // truy vấn SQLite.
    _debounce = Timer(const Duration(milliseconds: 220), () {
      _loadSuggestions(query);
    });
  }

  Future<void> _loadSuggestions(String query) async {
    try {
      final items = await DictionaryService.instance.suggest(
        query,
        limit: 12,
        dictId: _selectedDictId,
      );
      if (!mounted) return;
      // Người dùng đã gõ tiếp trong lúc chờ ⇒ bỏ kết quả cũ.
      if (_searchController.text.trim() != query) return;
      setState(() => _suggestions = items);
    } catch (_) {
      if (!mounted) return;
      setState(() => _suggestions = const <String>[]);
    }
  }

  Future<void> _submit(String raw) async {
    final word = DictHistory.normalize(raw);
    if (word.isEmpty) return;
    _debounce?.cancel();
    _searchFocus.unfocus();
    setState(() {
      _query = word;
      _submitted = true;
      _typing = false;
      _suggestions = const <String>[];
      _searching = true;
    });
    if (_searchController.text != word) _searchController.text = word;

    List<DictEntry> entries = const <DictEntry>[];
    try {
      entries = await DictionaryService.instance.lookup(
        word,
        dictId: _selectedDictId,
      );
    } catch (_) {
      entries = const <DictEntry>[];
    }
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _merged = entries.isEmpty ? null : _merge(entries);
      _searching = false;
    });
    // Chỉ nhớ từ ĐÃ TRA ĐƯỢC — lịch sử toàn từ không tìm thấy thì vô dụng.
    if (entries.isNotEmpty) {
      await _remember(word);
    }
  }

  /// Gộp nhiều bộ từ điển cho cùng một từ — dùng lại đúng pipeline của
  /// `DictResultSheet` (DICT-CLEAN-001) để hai nơi không lệch nhau.
  DictMergedEntry _merge(List<DictEntry> entries) {
    final names = <String, String>{
      for (final info in DictionaryService.instance.dictionaries)
        info.id: info.name,
    };
    return DictTextCleaner.merge(<DictSourceText>[
      for (final entry in entries)
        DictSourceText(
          headword: entry.headword,
          definition: entry.definition,
          phonetic: entry.phonetic,
          sourceLabel: names[entry.dictId] ?? entry.dictId,
        ),
    ]);
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {
      _typing = false;
      _submitted = false;
      _query = '';
      _entries = const <DictEntry>[];
      _merged = null;
      _suggestions = const <String>[];
    });
    _searchFocus.requestFocus();
  }

  Future<void> _speak(String word) async {
    try {
      await TtsService().speak(word);
    } catch (_) {
      if (!mounted) return;
      _snack(context.uiText('Không phát âm được từ này.'));
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
      );
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    _snack(context.uiText('Đã sao chép'));
  }

  Future<void> _openManager() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const DictManagerScreen()),
    );
    // Người dùng có thể vừa import/xoá bộ ⇒ nạp lại danh sách + tra lại từ
    // đang xem (bộ vừa thêm có thể có nghĩa tốt hơn).
    await _loadDicts();
    if (_submitted && _query.isNotEmpty) await _submit(_query);
  }

  Future<void> _openPacks() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const DictPackScreen()),
    );
    await _loadDicts();
    if (_submitted && _query.isNotEmpty) await _submit(_query);
  }

  void _pickDict(String? dictId) {
    if (_selectedDictId == dictId) return;
    setState(() => _selectedDictId = dictId);
    final typed = _searchController.text.trim();
    if (_submitted && _query.isNotEmpty) {
      _submit(_query);
    } else if (typed.isNotEmpty) {
      _loadSuggestions(typed);
    }
  }

  // ── Giao diện ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1120),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _accent),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.uiText('Từ điển'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: context.uiText('Tải bộ từ điển'),
            icon: const Icon(Icons.cloud_download_outlined, color: _accent),
            onPressed: _openPacks,
          ),
          IconButton(
            tooltip: context.uiText('Quản lý từ điển'),
            icon: const Icon(Icons.tune, color: _accent),
            onPressed: _openManager,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          if (_dicts.length > 1) _buildDictFilter(),
          if (_searching)
            const LinearProgressIndicator(minHeight: 2, color: _accent),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocus,
          autofocus: false,
          textInputAction: TextInputAction.search,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          onChanged: _onTextChanged,
          onSubmitted: _submit,
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            hintText: context.uiText('Tra một từ…'),
            hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
            prefixIcon: const Icon(Icons.search, color: _accentLight, size: 20),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: context.uiText('Xoá'),
                    icon: Icon(Icons.close, color: Colors.grey[500], size: 18),
                    onPressed: _clearSearch,
                  ),
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }

  Widget _buildDictFilter() {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _filterChip(
            label: '${context.uiText('Tất cả')} (${_dicts.length})',
            selected: _selectedDictId == null,
            onTap: () => _pickDict(null),
          ),
          for (final dict in _dicts)
            _filterChip(
              label: dict.name,
              selected: _selectedDictId == dict.id,
              onTap: () => _pickDict(dict.id),
            ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? _accent.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? _accent.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? _accentLight : Colors.grey[400],
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loadingDicts) {
      return const Center(child: CircularProgressIndicator(color: _accent));
    }
    if (_dicts.isEmpty) return _buildNoDictionary();

    // Đang gõ + có gợi ý ⇒ danh sách gợi ý.
    if (_typing && !_submitted) {
      if (_suggestions.isNotEmpty) return _buildSuggestions();
      final typed = _searchController.text.trim();
      if (typed.isEmpty) return _buildHistory();
      return _buildHistory(matchingQuery: typed);
    }

    if (!_submitted) return _buildHistory();
    if (_searching && _merged == null) {
      return const Center(child: CircularProgressIndicator(color: _accent));
    }
    if (_merged == null || _merged!.isEmpty) return _buildNotFound();
    return _buildResult();
  }

  // ── Trạng thái: chưa có bộ từ điển ──────────────────────────────────────

  Widget _buildNoDictionary() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined, size: 64, color: Colors.grey[800]),
            const SizedBox(height: 16),
            Text(
              context.uiText('Chưa có từ điển nào'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.uiText(
                'Tải một bộ có sẵn (Anh–Việt, Anh–Anh…) hoặc import file .mdx '
                'của bạn. Sau khi cài, tra từ ở đây là dùng được offline.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _accent),
              onPressed: _openPacks,
              icon: const Icon(Icons.cloud_download_outlined, size: 18),
              label: Text(context.uiText('Tải bộ từ điển')),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _openManager,
              child: Text(context.uiText('Import file .mdx của tôi')),
            ),
          ],
        ),
      ),
    );
  }

  // ── Trạng thái: lịch sử ─────────────────────────────────────────────────

  Widget _buildHistory({String? matchingQuery}) {
    final items = DictHistory.matching(
      _history,
      matchingQuery ?? '',
      limit: 20,
    );
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            matchingQuery == null
                ? context.uiText(
                    'Gõ một từ để tra. Lịch sử tra từ sẽ hiện ở đây.',
                  )
                : context.uiText('Không có từ nào trong lịch sử khớp với từ đang gõ.'),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 12.5),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          children: [
            Icon(Icons.history, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 6),
            Text(
              context.uiText('Tra gần đây'),
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: _clearHistory,
              child: Text(
                context.uiText('Xoá lịch sử'),
                style: const TextStyle(fontSize: 11.5),
              ),
            ),
          ],
        ),
        for (final item in items) _historyTile(item),
      ],
    );
  }

  Widget _historyTile(String word) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: _surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(Icons.history_toggle_off,
            size: 18, color: Colors.grey[600]),
        title: Text(
          word,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        trailing: IconButton(
          tooltip: context.uiText('Xoá khỏi lịch sử'),
          icon: Icon(Icons.close, size: 16, color: Colors.grey[600]),
          onPressed: () => _forget(word),
        ),
        onTap: () => _submit(word),
      ),
    );
  }

  // ── Trạng thái: gợi ý khi đang gõ ───────────────────────────────────────

  Widget _buildSuggestions() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
      itemCount: _suggestions.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: Colors.white.withValues(alpha: 0.04),
      ),
      itemBuilder: (context, index) {
        final word = _suggestions[index];
        return ListTile(
          dense: true,
          leading: const Icon(Icons.north_west, size: 16, color: _accentLight),
          title: Text(
            word,
            style: const TextStyle(color: Colors.white, fontSize: 14.5),
          ),
          onTap: () => _submit(word),
        );
      },
    );
  }

  // ── Trạng thái: không tìm thấy ──────────────────────────────────────────

  Widget _buildNotFound() {
    return FutureBuilder<List<String>>(
      // Gợi ý "có phải bạn muốn…" lấy theo 3 ký tự đầu — đủ để bắt lỗi gõ
      // thừa/thiếu một ký tự mà không cần thuật toán so khớp mờ.
      future: DictionaryService.instance.suggest(
        _query.length <= 3 ? _query : _query.substring(0, 3),
        limit: 6,
        dictId: _selectedDictId,
      ),
      builder: (context, snapshot) {
        final hints = (snapshot.data ?? const <String>[])
            .where((w) => w.toLowerCase() != _query.toLowerCase())
            .toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey[800]),
            const SizedBox(height: 12),
            Text(
              context.uiText('Không tìm thấy "$_query"'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _dicts.length == 1
                  ? context.uiText(
                      'Từ này không có trong bộ đang bật. Bạn có thể tải thêm '
                      'bộ khác.',
                    )
                  : context.uiText(
                      'Từ này không có trong các bộ đang bật. Bạn có thể tải '
                      'thêm bộ khác.',
                    ),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
                height: 1.45,
              ),
            ),
            if (hints.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                context.uiText('Có phải bạn muốn:'),
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final hint in hints)
                    ActionChip(
                      label: Text(hint),
                      labelStyle: const TextStyle(
                        color: _accentLight,
                        fontSize: 12.5,
                      ),
                      backgroundColor: _accent.withValues(alpha: 0.12),
                      side: BorderSide(
                        color: _accent.withValues(alpha: 0.35),
                      ),
                      onPressed: () => _submit(hint),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            Center(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: _accent.withValues(alpha: 0.6)),
                ),
                onPressed: _openPacks,
                icon: const Icon(Icons.cloud_download_outlined,
                    size: 17, color: _accentLight),
                label: Text(
                  context.uiText('Tải thêm bộ từ điển'),
                  style: const TextStyle(color: _accentLight, fontSize: 12.5),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Trạng thái: có kết quả ──────────────────────────────────────────────

  Widget _buildResult() {
    final merged = _merged!;
    final headword =
        merged.headword.trim().isEmpty ? _query : merged.headword.trim();
    final ipa = (merged.ipa ?? '').trim();
    final sources = merged.sourceLabel.trim();

    // Loại từ đã có nhóm trong phần nghĩa thì KHÔNG lặp lại thành chip ở đầu
    // (DICT-VIEW-002 — cùng quy tắc với `DictResultSheet`).
    final groupPoses = <String>{
      for (final group in merged.groups)
        if ((group.pos ?? '').trim().isNotEmpty) group.pos!.trim(),
    };
    final chipPoses = <String>{
      for (final entry in _entries)
        if ((entry.partOfSpeech ?? '').trim().isNotEmpty)
          entry.partOfSpeech!.trim(),
    }.where((pos) => !groupPoses.contains(pos)).toList();

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                headword,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  height: 1.12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (ipa.isNotEmpty)
              Expanded(
                child: Text(
                  ipa,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                    letterSpacing: 0.2,
                  ),
                ),
              )
            else
              const Spacer(),
            IconButton(
              tooltip: context.uiText('Phát âm'),
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.volume_up_rounded,
                  color: _accent, size: 22),
              onPressed: () => _speak(headword),
            ),
            IconButton(
              tooltip: context.uiText('Sao chép'),
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.copy, color: Colors.white54, size: 18),
              onPressed: () => _copy(headword),
            ),
          ],
        ),
        if (chipPoses.isNotEmpty) ...[
          const SizedBox(height: 2),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final pos in chipPoses)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9C27B0).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    context.uiText(
                      DictTextCleaner.posDisplaySource(pos) ?? pos,
                    ),
                    style: const TextStyle(
                      color: Color(0xFFCE93D8),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
        const SizedBox(height: 12),
        DictDefinitionView(
          groups: merged.groups,
          compact: false,
          accentColor: _accentLight,
        ),
        if (sources.isNotEmpty) ...[
          const SizedBox(height: 22),
          Text(
            context.uiText('Nguồn: $sources'),
            style: TextStyle(color: Colors.grey[600], fontSize: 11),
          ),
        ],
      ],
    );
  }
}
