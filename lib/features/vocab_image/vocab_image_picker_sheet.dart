// lib/features/vocab_image/vocab_image_picker_sheet.dart
//
// IMG-WEB-001 — Bảng chọn hình cho từ vựng, ƯU TIÊN ảnh trên mạng.
//
// Lý do đổi thứ tự: khi học từ, máy người dùng hầu như không có sẵn ảnh minh
// họa cho từ ("bướm", "tháp Eiffel", "cái cân") — trước đây một chạm mở thẳng
// gallery nên người dùng toàn bỏ qua bước hình. Giờ: mở là tìm ảnh trên mạng
// (luôn có), "Trong máy" là đường thứ hai, kèm chụp ảnh và tách nền ML Kit
// ngay trong preview trước khi lưu.
//
// Ảnh web được TẢI VỀ + lưu vào app storage (hash dedup), không lưu thẳng
// URL: ôn tập phải chạy offline và link ngoài mạng chết bất cứ lúc nào.

import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../../core/language/localized_material.dart';
import '../background_removal/background_removal.dart';

import 'vocab_image_api_config.dart';
import 'vocab_image_service.dart';
import 'vocab_image_web_service.dart';
import 'vocab_media_type.dart';

/// Nguồn ảnh trong sheet. Device flow hỗ trợ camera, gallery và preview
/// tách nền ML Kit trước khi lưu.
///
/// LOTTIE-001 — thêm nhánh `pasteUrl`: dán liên kết ảnh tĩnh (.png/.webp…)
/// HOẶC animation Lottie (.json/.lottie); file vẫn được tải về app storage
/// để học offline (giống 2 nguồn còn lại).
enum VocabImageSourceKind { web, device, pasteUrl }

/// Kết quả trả về cho caller ([VocabImagePicker] / word list / word actions).
class VocabImagePickResult {
  /// Relative path trong app storage (đã lưu) — null nếu không chọn ảnh mới.
  final String? imagePath;

  /// true = người dùng xin bỏ ảnh khỏi từ.
  final bool removed;

  const VocabImagePickResult({this.imagePath, this.removed = false});
}

/// Sheet chọn hình: tìm trên mạng (mặc định, tự tìm luôn khi mở) / máy.
class VocabImagePickerSheet extends StatefulWidget {
  /// Từ cần hình — dùng làm từ khóa tìm kiếm mặc định.
  final String? word;

  /// Nghĩa của từ (thêm vào query khi từ khóa gốc quá mơ hồ).
  final String? meaning;

  final bool hasExistingImage;

  const VocabImagePickerSheet({
    super.key,
    this.word,
    this.meaning,
    this.hasExistingImage = false,
  });

  /// Open the sheet. Returns null when the user just closes it.
  static Future<VocabImagePickResult?> show(
    BuildContext context, {
    String? word,
    String? meaning,
    bool hasExistingImage = false,
  }) {
    return showModalBottomSheet<VocabImagePickResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        // Bàn mềm (đang gõ từ khóa) không che mất danh sách ảnh.
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(sheetContext).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: VocabImagePickerSheet(
              word: word,
              meaning: meaning,
              hasExistingImage: hasExistingImage,
            ),
          ),
        ),
      ),
    );
  }

  @override
  State<VocabImagePickerSheet> createState() => _VocabImagePickerSheetState();
}

class _VocabImagePickerSheetState extends State<VocabImagePickerSheet> {
  final VocabImageWebService _web = VocabImageWebService();
  final TextEditingController _query = TextEditingController();
  final ScrollController _scroll = ScrollController();

  List<VocabWebImage> _results = const [];
  bool _loading = false;
  bool _busy = false;
  bool _removingBackground = false;
  Uint8List? _originalDeviceBytes;
  Uint8List? _cutoutBytes;
  bool _showCutout = false;
  String? _backgroundRemovalMessage;

  /// Provider + API key hiện hành (IMG-WEB-001: tìm ảnh PHẢI qua API key;
  /// chưa có key thì rơi về nguồn mở + nhắc user nhập key).
  VocabImageApiSettings? _cfg;

  /// Provider bị bỏ qua vì thiếu key ở lần tìm gần nhất.
  VocabImageProvider? _missingKey;

  /// Lưới ảnh rỗng vì LỖI (mạng/rate limit/tải fail) — khác với "tìm mà
  /// không ra kết quả": UI đổi câu gợi ý.
  bool _failed = false;
  VocabImageSourceKind _source = VocabImageSourceKind.web;
  int _busyIndex = -1;

  /// LOTTIE-001 — ô dán URL (ảnh hoặc Lottie .json).
  final TextEditingController _urlCtrl = TextEditingController();
  String? _urlError;

  @override
  void initState() {
    super.initState();
    _query.text =
        VocabImageWebService.buildQuery(word: widget.word, meaning: widget.meaning);
    VocabImageApiConfig.instance.load().then((cfg) {
      if (mounted) setState(() => _cfg = cfg);
    });
    // Ưu tiên mạng → mở là tìm, người dùng chỉ việc chạm ảnh.
    if (_query.text.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _search());
    }
  }

  @override
  void dispose() {
    _query.dispose();
    _scroll.dispose();
    _urlCtrl.dispose();
    _web.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.isEmpty) {
      setState(() {
        _results = const [];
        _failed = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
    });
    final results = await _web.search(q, settings: _cfg);
    if (!mounted) return;
    setState(() {
      _results = results;
      _loading = false;
      _missingKey = _web.missingKeyProvider;
      // Có lỗi mạng (mạng tắt, 429, JSON lạ) → nói rõ để người dùng thử lại.
      _failed = results.isEmpty && _web.lastError != null;
    });
  }

  Future<void> _useWebImage(VocabWebImage image) async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    final path = await VocabImageService.instance
        .saveFromUrl(image.imageUrl, client: _web);
    if (!mounted) return;
    setState(() => _busy = false);
    if (path == null) {
      setState(() => _failed = true);
      return;
    }
    Navigator.of(context).pop(VocabImagePickResult(imagePath: path));
  }

  Future<void> _pickDeviceImage({required bool camera}) async {
    setState(() {
      _busy = true;
      _backgroundRemovalMessage = null;
    });
    final bytes = camera
        ? await VocabImageService.instance.pickCameraBytes()
        : await VocabImageService.instance.pickGalleryBytes();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _originalDeviceBytes = bytes;
      _cutoutBytes = null;
      _showCutout = false;
      _backgroundRemovalMessage = null;
    });
  }

  Future<void> _removeBackground() async {
    final original = _originalDeviceBytes;
    if (original == null || _removingBackground) return;
    setState(() {
      _removingBackground = true;
      _backgroundRemovalMessage = null;
    });
    final cutout = await BackgroundRemovalService.instance.removeBackground(original);
    if (!mounted) return;
    setState(() {
      _removingBackground = false;
      _cutoutBytes = cutout;
      _showCutout = cutout != null;
      _backgroundRemovalMessage = cutout == null
          ? context.uiText(
              'Chưa thể tách nền trên thiết bị này. Ảnh gốc vẫn được giữ nguyên.')
          : context.uiText('Đã tách nền bằng Google ML Kit.');
    });
  }

  Future<void> _saveDeviceImage() async {
    final bytes = _showCutout && _cutoutBytes != null
        ? _cutoutBytes!
        : _originalDeviceBytes;
    if (bytes == null || _busy) return;
    setState(() => _busy = true);
    final path = await VocabImageService.instance.saveFromBytes(bytes);
    if (!mounted) return;
    setState(() => _busy = false);
    if (path == null) {
      setState(() => _backgroundRemovalMessage =
          context.uiText('Không thể lưu ảnh. Vui lòng thử lại.'));
      return;
    }
    Navigator.of(context).pop(VocabImagePickResult(imagePath: path));
  }

  void _resetDeviceImage() {
    setState(() {
      _originalDeviceBytes = null;
      _cutoutBytes = null;
      _showCutout = false;
      _backgroundRemovalMessage = null;
    });
  }

  /// LOTTIE-001 — tải media từ URL dán (ảnh tĩnh hoặc Lottie .json) về
  /// app storage rồi trả kết quả như mọi nguồn khác → offline được ngay.
  Future<void> _downloadPastedUrl() async {
    final url = _urlCtrl.text.trim();
    if (!isNetworkMediaUrl(url)) {
      setState(() => _urlError = context.uiText(
          'Liên kết chưa hợp lệ — cần bắt đầu bằng http:// hoặc https://'));
      return;
    }
    setState(() {
      _busy = true;
      _urlError = null;
    });
    final path = await VocabImageService.instance.saveFromUrl(url);
    if (!mounted) return;
    setState(() => _busy = false);
    if (path == null || path.isEmpty) {
      setState(() => _urlError = context.uiText(
          'Không tải được file (lỗi mạng, sai định dạng, hoặc animation quá 2MB).'));
      return;
    }
    Navigator.of(context).pop(VocabImagePickResult(imagePath: path));
  }

  void _remove() =>
      Navigator.of(context).pop(const VocabImagePickResult(removed: true));

  bool get _cfgReady => _cfg?.selectedProviderUsable ?? false;

  /// 'Nguồn: Pexels · API key ok' / '…chưa có API key → nguồn mở'.
  String _statusLabel(BuildContext context) {
    final cfg = _cfg;
    if (cfg == null) return context.uiText('Đang đọc cấu hình ảnh…');
    final keyState = cfg.selectedProviderUsable
        ? context.uiText('API key: đã nhập')
        : context.uiText('API key: chưa nhập — tìm bằng nguồn mở');
    return '${context.uiText('Nguồn: ${cfg.provider.label}')} · $keyState';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    var columns = (width / 150).floor();
    if (columns < 2) columns = 2;
    if (columns > 5) columns = 5;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.86,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(
              children: [
                Icon(Icons.image_search, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.uiText('Hình ảnh ghi nhớ'),
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, size: 18, color: scheme.onSurfaceVariant),
                  tooltip: context.uiText('Đóng'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                context.uiText('Ưu tiên ảnh trên mạng — máy ít khi có sẵn ảnh cho từ.'),
                style: TextStyle(
                    color: scheme.onSurfaceVariant, fontSize: 11.5, height: 1.4),
              ),
            ),
          ),
          // ── Trạng thái nguồn + API key ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _statusLabel(context),
                    style: TextStyle(
                        color: _cfgReady
                            ? scheme.onSurfaceVariant
                            : Colors.orange.shade300,
                        fontSize: 11),
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final saved = await showVocabImageKeyDialog(context);
                    if (saved != true || !mounted) return;
                    final cfg = await VocabImageApiConfig.instance.load();
                    if (!mounted) return;
                    setState(() => _cfg = cfg);
                    _search();
                  },
                  icon: const Icon(Icons.key_outlined, size: 15),
                  label: Text(context.uiText('API key')),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ── Chuyển nguồn ảnh ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<VocabImageSourceKind>(
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: [
                ButtonSegment(
                  value: VocabImageSourceKind.web,
                  icon: const Icon(Icons.public, size: 15),
                  label: Text(context.uiText('Trên mạng')),
                ),
                ButtonSegment(
                  value: VocabImageSourceKind.device,
                  icon: const Icon(Icons.smartphone, size: 15),
                  label: Text(context.uiText('Trong máy')),
                ),
                // LOTTIE-001 — dán liên kết Lottie/ảnh (WordUp-style:
                // user tự mang animation từ LottieFiles về).
                ButtonSegment(
                  value: VocabImageSourceKind.pasteUrl,
                  icon: const Icon(Icons.link, size: 15),
                  label: Text(context.uiText('Dán URL')),
                ),
              ],
              selected: {_source},
              onSelectionChanged: (s) => setState(() => _source = s.first),
            ),
          ),
          const SizedBox(height: 8),

          Flexible(
            child: switch (_source) {
              VocabImageSourceKind.web => _buildWeb(columns),
              VocabImageSourceKind.device => _buildDevice(),
              VocabImageSourceKind.pasteUrl => _buildUrlPaste(),
            },
          ),

          // ── Footer: bỏ ảnh đang có ──────────────────────────────────────
          if (widget.hasExistingImage)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _remove,
                      icon: const Icon(Icons.link_off, size: 16),
                      label: Text(context.uiText('Bỏ ảnh hiện tại')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_busy)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(context.uiText('Đang lưu ảnh…'),
                      style: TextStyle(
                          color: scheme.onSurfaceVariant, fontSize: 12)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────── WEB (ưu tiên) ─────
  Widget _buildWeb(int columns) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _query,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  style: TextStyle(color: scheme.onSurface, fontSize: 14),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: context.uiText('Nhập từ khóa tìm ảnh…'),
                    hintStyle: TextStyle(
                        color: scheme.onSurfaceVariant, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _loading ? null : _search,
                child: Text(context.uiText('Tìm')),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (_loading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Column(
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.2, color: scheme.primary),
                ),
                const SizedBox(height: 8),
                Text(context.uiText('Đang tìm ảnh trên mạng…'),
                    style: TextStyle(
                        color: scheme.onSurfaceVariant, fontSize: 12)),
              ],
            ),
          )
        else if (_results.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Column(
              children: [
                Icon(_failed ? Icons.wifi_off_rounded : Icons.photo_library_outlined,
                    size: 26, color: scheme.onSurfaceVariant),
                const SizedBox(height: 6),
                Text(
                  _failed
                      ? context.uiText(
                          'Không lấy được ảnh — kiểm tra mạng rồi bấm Tìm lại.')
                      : context.uiText(
                          'Chưa có ảnh — bấm Tìm hoặc thử từ khóa khác.'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: scheme.onSurfaceVariant, fontSize: 12),
                ),
                if (_failed) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _loading ? null : _search,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: Text(context.uiText('Thử lại')),
                  ),
                ],
                if (_missingKey != null && _results.isEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    context.uiText(
                        'Nguồn ưu tiên cần API key. Dán key vào phần API key để tìm đúng nhà cung cấp ảnh.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.orange.shade200, fontSize: 11),
                  ),
                ],
              ],
            ),
          )
        else
          Flexible(
            child: Scrollbar(
              controller: _scroll,
              child: ListView(
                controller: _scroll,
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                children: [
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 0.78,
                    ),
                    itemCount: _results.length,
                    itemBuilder: (context, index) =>
                        _buildResultTile(_results[index], index),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildResultTile(VocabWebImage image, int index) {
    final scheme = Theme.of(context).colorScheme;
    final busy = _busyIndex == index;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: _busy
          ? null
          : () {
              setState(() => _busyIndex = index);
              _useWebImage(image).whenComplete(() {
                if (mounted) setState(() => _busyIndex = -1);
              });
            },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.outlineVariant),
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    image.thumbUrl,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    loadingBuilder: (context, child, progress) =>
                        progress == null
                            ? child
                            : Center(
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.8,
                                    color: scheme.primary,
                                  ),
                                ),
                              ),
                    errorBuilder: (context, error, stack) => Center(
                      child: Icon(Icons.broken_image_outlined,
                          size: 22, color: scheme.onSurfaceVariant),
                    ),
                  ),
                  if (busy)
                    ColoredBox(
                      color: Colors.black45,
                      child: Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: 34,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 2, 6, 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      image.title.isEmpty ? image.source : image.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: scheme.onSurface, fontSize: 10.5),
                    ),
                    Text(
                      image.credit,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: scheme.onSurfaceVariant, fontSize: 9),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────── DÁN URL ────────
  /// LOTTIE-001 — nhánh "Dán URL": nhận link ảnh tĩnh hoặc animation
  /// Lottie, tải về máy (offline-first) rồi trả kết quả như nguồn web/device.
  Widget _buildUrlPaste() {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.animation_outlined, size: 30, color: scheme.primary),
            const SizedBox(height: 8),
            Text(
              context.uiText(
                  'Dán liên kết ảnh (.png/.jpg/.webp) hoặc animation Lottie (.json). File sẽ được tải về máy để học offline.'),
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: scheme.onSurfaceVariant, fontSize: 11.5, height: 1.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlCtrl,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.url,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'https://lottie.host/…/minh-hoa.json',
                prefixIcon: const Icon(Icons.link, size: 16),
                suffixIcon: IconButton(
                  tooltip: context.uiText('Dán từ clipboard'),
                  icon: const Icon(Icons.content_paste, size: 16),
                  onPressed: () async {
                    final data =
                        await Clipboard.getData(Clipboard.kTextPlain);
                    final text = data?.text?.trim() ?? '';
                    if (text.isNotEmpty) {
                      _urlCtrl.text = text;
                      setState(() => _urlError = null);
                    }
                  },
                ),
              ),
              onSubmitted: _busy ? null : (_) => _downloadPastedUrl(),
            ),
            if (_urlError != null) ...[
              const SizedBox(height: 8),
              Text(
                _urlError!,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.error, fontSize: 11),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : _downloadPastedUrl,
              icon: const Icon(Icons.download_outlined, size: 18),
              label: Text(context.uiText('Tải về & lưu')),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────── MÁY ──────
  Widget _buildDevice() {
    final scheme = Theme.of(context).colorScheme;
    final original = _originalDeviceBytes;
    final cutout = _cutoutBytes;

    if (original == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.photo_camera_back_outlined,
                  size: 30, color: scheme.onSurfaceVariant),
              const SizedBox(height: 8),
              Text(
                context.uiText('Chụp ảnh hoặc chọn ảnh trong máy.'),
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: scheme.onSurfaceVariant, fontSize: 11.5),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _busy
                        ? null
                        : () => _pickDeviceImage(camera: true),
                    icon: const Icon(Icons.photo_camera_outlined, size: 18),
                    label: Text(context.uiText('Chụp ảnh')),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _pickDeviceImage(camera: false),
                    icon: const Icon(Icons.folder_open, size: 18),
                    label: Text(context.uiText('Thư viện')),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final preview = _showCutout && cutout != null ? cutout : original;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            width: double.infinity,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.memory(preview, fit: BoxFit.contain),
          ),
          const SizedBox(height: 10),
          if (cutout != null)
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.image_outlined, size: 16),
                  label: Text(context.uiText('Ảnh gốc')),
                ),
                ButtonSegment(
                  value: true,
                  icon: const Icon(Icons.auto_fix_high, size: 16),
                  label: Text(context.uiText('Đã tách nền')),
                ),
              ],
              selected: {_showCutout},
              onSelectionChanged: (selected) =>
                  setState(() => _showCutout = selected.first),
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                context.uiText('Bạn có thể tách nền tự động trước khi lưu.'),
                style: TextStyle(
                    color: scheme.onSurfaceVariant, fontSize: 12),
              ),
            ),
          if (_backgroundRemovalMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _backgroundRemovalMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cutout == null ? Colors.orange.shade300 : Colors.green.shade300,
                fontSize: 11.5,
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (_removingBackground)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => _removeBackground(),
                  icon: const Icon(Icons.auto_fix_high, size: 18),
                  label: Text(context.uiText('Tách nền tự động')),
                ),
                OutlinedButton.icon(
                  onPressed: _saveDeviceImage,
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(context.uiText('Dùng ảnh này')),
                ),
                TextButton.icon(
                  onPressed: _resetDeviceImage,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text(context.uiText('Chọn lại')),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Dialog nhập API key tìm ảnh (IMG-WEB-001).
///
/// Key lưu VÀO MÁY người dùng (SharedPreferences) — không bao giờ commit vào
/// repo. Bản build nội bộ có thể đưa key lúc build:
/// `--dart-define=VOCAB_IMAGE_PROVIDER=pexels --dart-define=VOCAB_IMAGE_API_KEY=…`
Future<bool?> showVocabImageKeyDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => const _VocabImageKeyDialog(),
  );
}

class _VocabImageKeyDialog extends StatefulWidget {
  const _VocabImageKeyDialog();

  @override
  State<_VocabImageKeyDialog> createState() => _VocabImageKeyDialogState();
}

class _VocabImageKeyDialogState extends State<_VocabImageKeyDialog> {
  VocabImageProvider _provider = VocabImageProvider.pexels;
  final TextEditingController _key = TextEditingController();
  bool _loading = true;

  /// IMG-WEB-001 — "tự gán ảnh đầu tiên" (mặc định tắt: tự tìm + chạm chọn).
  bool _auto = false;

  /// LOTTIE-001 — "chỉ tải ảnh/animation khi xem" (mặc định tắt: tải về
  /// máy ngay sau import để học offline).
  bool _lazy = false;

  @override
  void initState() {
    super.initState();
    VocabImageApiConfig.instance.load().then((cfg) {
      if (!mounted) return;
      setState(() {
        _provider = cfg.provider;
        _key.text = cfg.keyFor(cfg.provider) ?? '';
        _auto = cfg.autoAssignFirst;
        _lazy = cfg.lazyDownload;
        _loading = false;
      });
    });
  }

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // Key cho nguồn "không cần key" (vd token Openverse) vẫn được lưu —
    // có token thì hết bị rate limit.
    final value = _key.text.trim();
    final config = VocabImageApiConfig.instance;
    await config.saveProvider(_provider);
    await config.saveKey(_provider, value);
    await config.saveAutoAssign(_auto);
    await config.saveLazyDownload(_lazy);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_loading) {
      return AlertDialog(
        content: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: CircularProgressIndicator(strokeWidth: 2, color: scheme.primary),
          ),
        ),
      );
    }
    return AlertDialog(
      title: Text(context.uiText('Nhà cung cấp ảnh + API key')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.uiText('Chọn nhà cung cấp'),
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
            const SizedBox(height: 6),
            DropdownButtonFormField<VocabImageProvider>(
              isExpanded: true,
              value: _provider,
              decoration: const InputDecoration(isDense: true),
              items: [
                for (final p in VocabImageProvider.values)
                  DropdownMenuItem(
                    value: p,
                    child: Text(
                      p.needsKey ? p.label : '${p.label} · không cần key',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
              ],
              onChanged: (p) {
                if (p == null) return;
                setState(() => _provider = p);
                // Nạp key đã lưu của provider khác (nếu có).
                VocabImageApiConfig.instance.load().then((cfg) {
                  if (!mounted) return;
                  setState(() => _key.text = cfg.keyFor(p) ?? '');
                });
              },
            ),
            const SizedBox(height: 12),
            Text(context.uiText('API key'),
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
            const SizedBox(height: 6),
            TextField(
              controller: _key,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                hintText: _provider.needsKey
                    ? context.uiText('Dán API key…')
                    : context.uiText('Bỏ trống nếu không dùng key'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.uiText('Cách lấy key: ${_provider.howTo}'),
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
            ),
            const SizedBox(height: 4),
            Text(
              context.uiText(
                  'Key chỉ lưu trên máy này (không đi vào Git, không gửi về server In4Up).'),
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
            ),
            const SizedBox(height: 12),
            // IMG-WEB-001: owner chốt "mặc định là tự tìm, chạm chọn nhưng có
            // thể chọn thêm toggle tự gán ảnh trong cài đặt riêng" — toggle nằm
            // ở CHÍNH dialog cài đặt ảnh này, mặc định tắt.
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _auto,
              onChanged: (v) => setState(() => _auto = v),
              title: Text(context.uiText('Tự gán ảnh đầu tiên'),
                  style: const TextStyle(fontSize: 13)),
              subtitle: Text(
                context.uiText(
                    'Mặc định: tự tìm rồi bạn chạm chọn. Bật để thêm từ là gán luôn ảnh đầu tiên tìm được, không mở sheet.'),
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
              ),
            ),
            // LOTTIE-001 — chiến lược tải media khi import CSV.
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _lazy,
              onChanged: (v) => setState(() => _lazy = v),
              title: Text(
                  context.uiText('Chỉ tải ảnh/animation khi xem'),
                  style: const TextStyle(fontSize: 13)),
              subtitle: Text(
                context.uiText(
                    'Tắt (mặc định): import CSV có link ảnh/Lottie thì tải về máy ngay — học offline trọn vẹn. Bật: giữ link, tự tải và lưu ở lần xem đầu tiên (tiết kiệm dữ liệu, nhưng từ chưa xem sẽ không có minh họa khi offline).'),
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.uiText('Hủy')),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(context.uiText('Lưu')),
        ),
      ],
    );
  }
}
