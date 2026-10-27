// lib/features/dictionary/widgets/dict_pack_screen.dart
//
// DICT-PACK-001 (owner 2026-10-25) — "Cho phép người dùng tải bộ từ điển ở
// setting home."
//
// Màn hình này là nơi người dùng KHÔNG chuyên cũng dùng được:
//   1. Danh sách bộ từ điển có sẵn trong danh mục (`packs.json`) — bấm "Tải"
//      là app tải ZIP, giải nén, lập chỉ mục và đăng ký vào Từ điển MDX.
//   2. Dán LINK TRỰC TIẾP (ZIP/MDX) khi danh mục chưa có bộ mình cần.
//   3. Đổi "Nguồn danh mục" (URL JSON) — owner có thể host trên HuggingFace/
//      GitHub Pages rồi dán vào đây, hoặc cập nhật `packs.json` trong repo.
//
// Bộ đã cài được nhận biết qua `DictionaryService.dictionaries` (so khớp tên
// bộ/tên file gốc) để nút chuyển thành "Cài lại / Cập nhật".

import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter/services.dart';

import '../models/dict_info.dart';
import '../models/dict_pack.dart';
import '../services/dict_pack_service.dart';
import '../services/dictionary_service.dart';

class DictPackScreen extends StatefulWidget {
  const DictPackScreen({super.key});

  @override
  State<DictPackScreen> createState() => _DictPackScreenState();
}

class _DictPackScreenState extends State<DictPackScreen> {
  final _service = DictPackService();
  final _directUrlController = TextEditingController();
  final _catalogUrlController = TextEditingController();

  DictPackCatalog _catalog = DictPackCatalog.empty;
  List<DictInfo> _installed = const <DictInfo>[];
  bool _loading = true;
  bool _refreshingCatalog = false;
  String? _error;

  /// id bộ đang tải → (0..1, thông điệp).
  final Map<String, (double, String)> _progress = <String, (double, String)>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _directUrlController.dispose();
    _catalogUrlController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await DictionaryService.instance.ensureInitialized();
      final url = await _service.catalogUrl();
      final catalog = await _service.loadCatalog(url: url);
      final installed =
          List<DictInfo>.from(DictionaryService.instance.dictionaries);
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _installed = installed;
        _catalogUrlController.text = url;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _reloadCatalogFrom(String url) async {
    setState(() => _refreshingCatalog = true);
    await _service.saveCatalogUrl(url);
    final catalog = await _service.loadCatalog(url: url);
    if (!mounted) return;
    setState(() {
      _catalog = catalog;
      _refreshingCatalog = false;
    });
    if (catalog.isEmpty) {
      _snack(context.uiText(
        'Không đọc được danh mục từ nguồn này. Kiểm tra URL và định dạng JSON.',
      ));
    }
  }

  bool _isInstalled(DictPack pack) {
    final needle = pack.name.toLowerCase();
    final idNeedle = pack.id.toLowerCase();
    for (final dict in _installed) {
      final name = dict.name.toLowerCase();
      if (name == needle) return true;
      if (name.contains(idNeedle)) return true;
    }
    return false;
  }

  Future<void> _install(DictPack pack) async {
    if (_progress.containsKey(pack.id)) return;
    setState(() => _progress[pack.id] = (0.0, context.uiText('Bắt đầu…')));
    final result = await _service.install(
      pack,
      onProgress: (progress, message) {
        if (!mounted) return;
        setState(() => _progress[pack.id] = (progress, message));
      },
    );
    if (!mounted) return;
    setState(() => _progress.remove(pack.id));
    await _load();
    if (!mounted) return;

    if (result.isSuccess) {
      final names = result.imported.map((d) => d.name).join(', ');
      _snack(
        '${context.uiText('Đã cài:')} $names',
        color: const Color(0xFF4CAF50),
      );
    } else {
      _snack(
        '${context.uiText('Cài thất bại')}: '
        '${context.uiText(result.error ?? '')}',
        color: const Color(0xFFEF5350),
      );
    }
  }

  Future<void> _installDirect() async {
    final url = _directUrlController.text.trim();
    if (url.isEmpty) return;
    const key = '__direct__';
    if (_progress.containsKey(key)) return;
    setState(() => _progress[key] = (0.0, context.uiText('Bắt đầu…')));
    final result = await _service.installFromUrl(
      url,
      onProgress: (progress, message) {
        if (!mounted) return;
        setState(() => _progress[key] = (progress, message));
      },
    );
    if (!mounted) return;
    setState(() => _progress.remove(key));
    await _load();
    if (!mounted) return;
    if (result.isSuccess) {
      _directUrlController.clear();
      _snack(
        '${context.uiText('Đã cài:')} '
        '${result.imported.map((d) => d.name).join(', ')}',
        color: const Color(0xFF4CAF50),
      );
    } else {
      _snack(
        '${context.uiText('Cài thất bại')}: '
        '${context.uiText(result.error ?? '')}',
        color: const Color(0xFFEF5350),
      );
    }
  }

  void _snack(String message, {Color? color}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 4),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(
          context.uiText('Tải bộ từ điển'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2196F3)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: context.uiText('Tải lại danh mục'),
            icon: const Icon(Icons.refresh, color: Color(0xFF2196F3)),
            onPressed: _refreshingCatalog
                ? null
                : () => _reloadCatalogFrom(_catalogUrlController.text.trim()),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                _buildIntroCard(),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: Color(0xFFEF5350),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                _buildCatalogList(),
                const SizedBox(height: 20),
                _buildDirectUrlCard(),
                const SizedBox(height: 20),
                _buildCatalogSourceCard(),
              ],
            ),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2196F3).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF2196F3).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cloud_download_outlined,
              color: Color(0xFF64B5F6), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.uiText('Tải từ điển có sẵn — một chạm'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.uiText(
                    'Chọn một bộ bên dưới: app tải về, giải nén và lập chỉ mục '
                    'ngay. Bộ đã cài hiện trong "Quản lý từ điển" và dùng được '
                    'offline. Chỉ tải khi bạn bấm — không tự tải lúc mở app.',
                  ),
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogList() {
    if (_catalog.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.uiText('Danh mục đang trống'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.uiText(
                'Chưa tải được danh mục (mạng?) hoặc danh mục chưa có bộ nào. '
                'Bạn vẫn dán được link ZIP/MDX trực tiếp ở ô bên dưới.',
              ),
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              context.uiText('Bộ từ điển có sẵn'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              context.uiText('(${_catalog.packs.length})'),
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final pack in _catalog.packs) ...[
          _buildPackCard(pack),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildPackCard(DictPack pack) {
    final installed = _isInstalled(pack);
    final progress = _progress[pack.id];
    final busy = progress != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.auto_stories,
                    color: Color(0xFF64B5F6), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pack.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (pack.langPairLabel.isNotEmpty)
                          _MetaChip(
                            label: pack.langPairLabel,
                            color: const Color(0xFFCE93D8),
                          ),
                        if (pack.sizeLabel.isNotEmpty)
                          _MetaChip(
                            label: pack.sizeLabel,
                            color: const Color(0xFF80CBC4),
                          ),
                        if (pack.version != null)
                          _MetaChip(
                            label: 'v${pack.version}',
                            color: const Color(0xFF90CAF9),
                          ),
                        if (installed)
                          _MetaChip(
                            label: context.uiText('Đã cài'),
                            color: const Color(0xFF81C784),
                          ),
                      ],
                    ),
                    if (pack.description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        pack.description,
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 11.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (busy)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: progress.$1 <= 0 ? null : progress.$1,
                  minHeight: 5,
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                ),
                const SizedBox(height: 6),
                Text(
                  context.uiText(progress.$2),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                    ),
                    onPressed: () => _install(pack),
                    icon: Icon(
                      installed ? Icons.refresh : Icons.download,
                      size: 17,
                      color: Colors.white,
                    ),
                    label: Text(
                      installed
                          ? context.uiText('Cài lại / cập nhật')
                          : context.uiText('Tải & cài'),
                      style: const TextStyle(color: Colors.white, fontSize: 12.5),
                    ),
                  ),
                ),
                if (pack.homepage != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: context.uiText('Trang nguồn'),
                    icon: const Icon(Icons.open_in_new,
                        size: 18, color: Colors.white54),
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: pack.homepage!),
                      );
                      _snack(context.uiText(
                        'Đã sao chép link nguồn — mở bằng trình duyệt để xem '
                        'giấy phép.',
                      ));
                    },
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDirectUrlCard() {
    const key = '__direct__';
    final progress = _progress[key];
    final busy = progress != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.uiText('Tải từ link trực tiếp'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.uiText(
              'Dán link ZIP (chứa .mdx + .mdd + .css) hoặc link .mdx trực tiếp.',
            ),
            style: TextStyle(color: Colors.grey[500], fontSize: 11),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _directUrlController,
            enabled: !busy,
            keyboardType: TextInputType.url,
            style: const TextStyle(color: Colors.white, fontSize: 12.5),
            decoration: InputDecoration(
              hintText: 'https://…/dictionary.zip',
              hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
              isDense: true,
              filled: true,
              fillColor: const Color(0xFF0E1526),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (busy)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: progress.$1 <= 0 ? null : progress.$1,
                  minHeight: 5,
                ),
                const SizedBox(height: 6),
                Text(
                  context.uiText(progress.$2),
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
              ],
            )
          else
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                ),
                onPressed: _installDirect,
                icon: const Icon(Icons.download, size: 17, color: Colors.white),
                label: Text(
                  context.uiText('Tải & cài'),
                  style: const TextStyle(color: Colors.white, fontSize: 12.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCatalogSourceCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.dns_outlined, size: 16, color: Colors.white54),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  context.uiText('Nguồn danh mục (catalog JSON)'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            context.uiText(
              'Owner/người dùng có thể host file packs.json (GitHub raw, '
              'HuggingFace…) rồi dán URL vào đây. Định dạng: '
              '{"packs":[{"id","name","downloadUrl"}, …]}.',
            ),
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 11,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _catalogUrlController,
            keyboardType: TextInputType.url,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: const Color(0xFF0E1526),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () async {
                  final url = DictPackService.defaultCatalogUrl;
                  _catalogUrlController.text = url;
                  await _reloadCatalogFrom(url);
                },
                child: Text(
                  context.uiText('Dùng mặc định'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 6),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                ),
                onPressed: _refreshingCatalog
                    ? null
                    : () => _reloadCatalogFrom(
                          _catalogUrlController.text.trim(),
                        ),
                child: _refreshingCatalog
                    ? const SizedBox(
                        height: 14,
                        width: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        context.uiText('Tải danh mục'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final Color color;

  const _MetaChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
