// lib/features/screen_translate/screen_translate_card.dart
//
// Thẻ bật/tắt "Dịch màn hình toàn hệ thống" trong Quản lý Model AI
// (XLAT-SCR-002 · ADR-0011 · sửa XLAT-SCR-003 · nâng cấp XLAT-SCR-005).
//
// Nền tảng không phải Android: thẻ vẫn hiện nhưng ở trạng thái "chỉ Android"
// và mọi nút bị khoá — tiêu chí nghiệm thu #6 (desktop không hỏng, không
// bày nút bấm vào thì lỗi).
//
// XLAT-SCR-003: thẻ KHÔNG tự đoán quyền nữa — mọi quyết định đi qua
// `ScreenTranslatePermissionResolver` (thuần Dart, có test). Thiếu overlay hay
// thiếu consent thì thẻ nói RÕ thiếu gì và mở đúng màn hình cài đặt, thay vì
// để user bật bong bóng xong bấm vào không thấy gì.
//
// XLAT-SCR-005 (owner 24/10):
//  - Chọn được CẢ ngôn ngữ nguồn (mặc định Tự nhận diện) và ngôn ngữ đích,
//    có nút hoán đổi hai chiều. Trước đây chỉ đổi được đích, nguồn luôn là
//    tiếng Anh.
//  - Công tắc "mỗi lần bấm bong bóng: kéo chọn vùng" — dịch một khung thay vì
//    cả màn hình cho nhanh.
//  - Dòng mô tả nói rõ mặc định là "tiếng Anh ↔ ngôn ngữ ứng dụng" và đổi
//    được sang bất kỳ cặp nào.
//
// i18n: mọi chuỗi đi qua `context.uiText(...)` và đã đăng ký trong
// `lib/core/language/priority_ui_overrides.dart` đủ en/hi/zh/zh_TW/si
// (quy tắc vàng #5).

import 'package:in4up/core/language/localized_material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/language/app_language.dart';
import '../translation/translation_language_picker.dart';
import 'screen_translate_channel.dart';
import 'screen_translate_permission.dart';
import 'screen_translate_prefs.dart';

class ScreenTranslateCard extends StatefulWidget {
  const ScreenTranslateCard({super.key, this.channel});

  /// Bơm channel giả trong test widget (mặc định dùng channel thật).
  final ScreenTranslateChannel? channel;

  @override
  State<ScreenTranslateCard> createState() => _ScreenTranslateCardState();
}

class _ScreenTranslateCardState extends State<ScreenTranslateCard>
    with WidgetsBindingObserver {
  late final ScreenTranslateChannel _channel =
      widget.channel ?? ScreenTranslateChannel();

  static const ScreenTranslatePermissionResolver _resolver =
      ScreenTranslatePermissionResolver();

  bool _busy = false;
  String _target = kScreenTranslateDefaultTarget;
  String _source = kScreenTranslateDefaultSource;
  bool _selectRegion = false;
  ScreenTranslateNativeStatus _status = ScreenTranslateNativeStatus.fallback;

  /// Máy trạng thái quyền — nguồn duy nhất quyết định UI.
  ScreenTranslatePermissionSnapshot get _state => _resolver.resolve(_status);

  /// Ngôn ngữ ứng dụng hiện hành (dùng làm đích GỢI Ý lần đầu).
  ///
  /// Khởi tạo bằng locale HỆ THỐNG (không chạm `context` trong `initState`),
  /// rồi [didChangeDependencies] cập nhật theo locale app đang dùng thật.
  String _appLocaleCode =
      WidgetsBinding.instance.platformDispatcher.locale.toLanguageTag();

  bool _localeHintApplied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  /// Locale app có thể khác locale hệ thống (người dùng chọn trong Cài đặt).
  /// Chỉ đồng bộ MỘT lần: người dùng đã tự chọn ngôn ngữ đích thì giá trị đã
  /// lưu luôn thắng (xem [loadScreenTranslateTarget]).
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.maybeLocaleOf(context);
    if (locale == null) return;
    final tag = locale.toLanguageTag();
    if (tag == _appLocaleCode) return;
    _appLocaleCode = tag;
    if (_localeHintApplied) return;
    _localeHintApplied = true;
    // Đọc lại SAU frame: setState trong didChangeDependencies lúc đang build
    // sẽ ném "setState() called during build".
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Quay lại từ màn hình Cài đặt hệ thống (cấp quyền overlay / consent) ⇒
  /// đọc lại trạng thái. Không có bước này thì user phải tắt/mở lại màn hình
  /// mới thấy quyền vừa cấp — đúng kiểu "im lặng" mà card này phải chữa.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final status = await _channel.status();
    final target = await loadScreenTranslateTarget(
      fallback: defaultScreenTranslateTargetForLocale(_appLocaleCode),
    );
    final source = await loadScreenTranslateSource();
    final selectRegion = await loadScreenTranslateSelectRegion();
    if (!mounted) return;
    setState(() {
      _status = status;
      _target = target;
      _source = source;
      _selectRegion = selectRegion;
    });
  }

  Future<void> _toggle() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final state = _state;
      if (state.status.running) {
        await _channel.stop();
        return;
      }
      if (state.state ==
          ScreenTranslatePermissionState.needsOverlayPermission) {
        // Quyền được cấp ở màn hình Settings của hệ thống → quay lại mới biết
        // kết quả; user bấm lại nút là đủ (không poll nền tốn pin).
        await _channel.requestOverlayPermission();
        return;
      }
      if (state.notificationsBlocked) {
        // Android 13+ chưa cấp POST_NOTIFICATIONS ⇒ notification của service
        // bị ẨN, user sẽ không bao giờ thấy trạng thái (một dạng im lặng).
        await Permission.notification.request();
      }
      final started = await _channel.start(
        targetLanguage: _target,
        sourceLanguage: _source,
        selectRegion: _selectRegion,
        locale: _appLocaleCode,
      );
      if (!mounted) return;
      if (!started) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.uiText(
                'Không bật được bong bóng. Kiểm tra quyền hiển thị trên ứng dụng khác.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        await _refresh();
      }
    }
  }

  /// Nút phụ: cấp lại consent MediaProjection khi đang ở foreground.
  Future<void> _reconsent() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _channel.requestConsent();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        await _refresh();
      }
    }
  }

  Future<void> _onLanguageSelected(AppLanguage language) async {
    final code = await saveScreenTranslateTarget(language.translationCode);
    if (!mounted) return;
    setState(() => _target = code);
    if (_state.status.running) {
      await _channel.setLanguages(
        sourceLanguage: _source,
        targetLanguage: code,
      );
    }
  }

  /// Chọn ngôn ngữ NGUỒN: 'Tự nhận diện' + toàn bộ catalog.
  Future<void> _pickSource() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Row(
                  children: [
                    const Icon(Icons.input, color: Colors.lightBlueAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.uiText('Chọn ngôn ngữ nguồn'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.auto_awesome,
                        color: Colors.lightBlueAccent,
                      ),
                      title: Text(context.uiText('Tự nhận diện')),
                      subtitle: Text(
                        context.uiText(
                          'Engine tự đoán ngôn ngữ đang hiện trên màn hình.',
                        ),
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: _source == kScreenTranslateDefaultSource
                          ? const Icon(Icons.check, color: Colors.greenAccent)
                          : null,
                      onTap: () => Navigator.pop(
                        ctx,
                        kScreenTranslateDefaultSource,
                      ),
                    ),
                    const Divider(height: 1),
                    for (final language in AppLanguageCatalog.languages)
                      ListTile(
                        leading: Text(
                          language.flag,
                          style: const TextStyle(fontSize: 20),
                        ),
                        title: Text(language.nativeName),
                        subtitle: Text(
                          language.englishName,
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: _source == language.translationCode
                            ? const Icon(
                                Icons.check,
                                color: Colors.greenAccent,
                              )
                            : null,
                        onTap: () => Navigator.pop(
                          ctx,
                          language.translationCode,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
    if (selected == null || !mounted) return;
    final code = await saveScreenTranslateSource(selected);
    if (!mounted) return;
    setState(() => _source = code);
    if (_state.status.running) {
      await _channel.setLanguages(
        sourceLanguage: code,
        targetLanguage: _target,
      );
    }
  }

  /// Hoán đổi hai đầu ngôn ngữ (EN→VI thành VI→EN, JA→VI thành VI→JA…).
  ///
  /// Nguồn đang là AUTO thì lấy đích làm nguồn, và đích mới rơi về tiếng Anh
  /// (không có "đích tự nhận diện" — đích phải là một ngôn ngữ cụ thể).
  Future<void> _swapLanguages() async {
    if (_busy) return;
    // Nguồn là AUTO ⇒ lấy đích cũ làm nguồn mới. Nếu đích cũ đã là tiếng Anh
    // thì đích mới rơi về ngôn ngữ ứng dụng (hoặc VI) — không bao giờ tạo ra
    // cặp EN → EN vô nghĩa.
    final newSource = _target;
    final newTarget = _source != kScreenTranslateDefaultSource
        ? _source
        : (newSource == AppLanguageCatalog.english.translationCode
            ? defaultScreenTranslateTargetForLocale(_appLocaleCode)
            : AppLanguageCatalog.english.translationCode);
    // Chặn cặp trùng nhau (người dùng đã chọn nguồn = đích): hoán đổi mà ra
    // VI → VI thì engine coi là "cùng ngôn ngữ" và trả nguyên văn.
    final safeTarget = newTarget == newSource
        ? (newSource == AppLanguageCatalog.english.translationCode
            ? kScreenTranslateDefaultTarget
            : AppLanguageCatalog.english.translationCode)
        : newTarget;
    setState(() => _busy = true);
    try {
      final target = await saveScreenTranslateTarget(safeTarget);
      final source = await saveScreenTranslateSource(newSource);
      if (!mounted) return;
      setState(() {
        _target = target;
        _source = source;
      });
      if (_state.status.running) {
        await _channel.setLanguages(
          sourceLanguage: source,
          targetLanguage: target,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.uiText('Đã hoán đổi ngôn ngữ nguồn và đích'),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onSelectRegionChanged(bool value) async {
    await saveScreenTranslateSelectRegion(value);
    if (!mounted) return;
    setState(() => _selectRegion = value);
    if (_state.status.running) {
      await _channel.setCaptureMode(selectRegion: value);
    }
  }

  /// Chuỗi nguồn tiếng Việt (đi qua `uiText` ⇒ có đủ en/hi/zh/zh_TW/si).
  /// Rỗng = không có gì cần báo.
  String _statusMessage() {
    final state = _state;
    if (state.state == ScreenTranslatePermissionState.unsupported) return '';
    if (state.state == ScreenTranslatePermissionState.needsOverlayPermission) {
      return 'Cần quyền "Hiển thị trên ứng dụng khác" để vẽ bong bóng và bản dịch.';
    }
    if (state.state == ScreenTranslatePermissionState.consentDenied) {
      return 'Bạn đã từ chối quyền chụp màn hình, nên bấm bong bóng chưa chụp được. Có thể cấp lại quyền bất cứ lúc nào.';
    }
    if (state.state == ScreenTranslatePermissionState.needsCaptureConsent) {
      // blockedBySystem = Android đã nuốt lệnh mở màn hình xin quyền từ nền;
      // khi ấy chỉ còn cách mở app rồi cấp quyền từ bên trong.
      return state.blockedBySystem
          ? 'Android vừa chặn việc mở màn hình xin quyền từ chạy nền. Hãy mở ứng dụng In4Up lên rồi bấm "Cấp lại quyền chụp màn hình".'
          : 'Chưa có quyền chụp màn hình cho phiên này. Bấm bong bóng rồi chọn "Bắt đầu ngay", hoặc cấp lại quyền ngay bên dưới.';
    }
    if (state.notificationsBlocked) {
      return 'Thông báo đang bị tắt nên bạn sẽ không thấy trạng thái dịch. Hãy bật thông báo để theo dõi.';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final target = AppLanguageCatalog.fromCode(
      _target,
      fallback: AppLanguageCatalog.vietnamese,
    );
    final source = _source == kScreenTranslateDefaultSource
        ? null
        : AppLanguageCatalog.fromCode(
            _source,
            fallback: AppLanguageCatalog.english,
          );
    final androidOnly = !ScreenTranslateChannel.platformSupported;
    final message = _statusMessage();
    final orange = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: Colors.orangeAccent);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.translate, color: Colors.lightBlueAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.uiText('Dịch màn hình toàn hệ thống'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (androidOnly)
                  Chip(
                    label: Text(context.uiText('Chỉ có trên Android')),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // SETTINGS-UI-COMPACT-001: đoạn mô tả dài → 1 dòng có icon để
            // mắt bắt nhanh "cái này làm gì", phần chi tiết vẫn đọc được.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.touch_app_outlined,
                    size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    context.uiText(
                      'Bong bóng nổi trên mọi ứng dụng: bấm để chụp màn hình, '
                      'nhận dạng chữ rồi hiện bản dịch đè đúng vị trí. Dùng '
                      'đúng engine dịch bạn đang chọn.',
                    ),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              context.uiText(
                'Mặc định tiếng Anh ↔ ngôn ngữ ứng dụng. Bạn đổi được cả hai đầu, kể cả hai ngôn ngữ không phải tiếng Anh.',
              ),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.white54),
            ),
            const SizedBox(height: 12),
            // ── Cặp ngôn ngữ: NGUỒN ⇄ ĐÍCH ────────────────────────────
            // SETTINGS-UI-COMPACT-001 (251e) làm nhãn gọn bằng icon + bodySmall;
            // XLAT-SCR-005 cần ĐỦ HAI ĐẦU nên vẫn giữ 2 cột + nút hoán đổi ở
            // giữa. Nhãn dùng icon (thay vì chữ đậm) để không đội chiều cao thẻ.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LanguageLabel(
                        icon: Icons.input,
                        text: context.uiText('Ngôn ngữ nguồn'),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _pickSource,
                          icon: Text(
                            source?.flag ?? '✨',
                            style: const TextStyle(fontSize: 15),
                          ),
                          label: Text(
                            source?.nativeName ??
                                context.uiText('Tự nhận diện'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: IconButton(
                    tooltip: context.uiText(
                      'Hoán đổi ngôn ngữ nguồn và đích',
                    ),
                    onPressed: _busy ? null : _swapLanguages,
                    icon: const Icon(Icons.swap_horiz),
                    color: Colors.lightBlueAccent,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LanguageLabel(
                        icon: Icons.subtitles_outlined,
                        text: context.uiText('Ngôn ngữ đích'),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TranslationLanguagePickerButton(
                          sourceLanguage:
                              source ?? AppLanguageCatalog.english,
                          targetLanguage: target,
                          accentColor: Colors.lightBlue,
                          onSelected: _onLanguageSelected,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // ── Dịch một vùng thay vì cả màn hình ─────────────────────
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                context.uiText('Mỗi lần bấm bong bóng: kéo chọn vùng'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              subtitle: Text(
                context.uiText(
                  'Bật: bấm bong bóng rồi kéo một khung trên màn hình để chỉ dịch phần đó (nhanh hơn nhiều). Giữ lâu bong bóng luôn bật chế độ này.',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              value: _selectRegion,
              onChanged: _busy || androidOnly ? null : _onSelectRegionChanged,
            ),
            const SizedBox(height: 4),
            if (message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline,
                        size: 14, color: Colors.orangeAccent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        context.uiText(message),
                        style: orange,
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(
                  state.status.running
                      ? Icons.stop_circle_outlined
                      : Icons.bubble_chart_outlined,
                ),
                label: Text(
                  !state.status.supported
                      ? context.uiText('Chỉ có trên Android')
                      : state.state ==
                              ScreenTranslatePermissionState
                                  .needsOverlayPermission
                          ? context
                              .uiText('Cấp quyền hiển thị trên ứng dụng khác')
                          : state.status.running
                              ? context.uiText('Tắt bong bóng dịch')
                              : context.uiText('Bật bong bóng dịch'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: state.status.running
                      ? Colors.red.shade700
                      : Colors.lightBlue.shade700,
                  foregroundColor: Colors.white,
                ),
                onPressed: (state.state ==
                            ScreenTranslatePermissionState.unsupported ||
                        _busy)
                    ? null
                    : _toggle,
              ),
            ),
            // Chỉ hiện khi service ĐANG chạy mà thiếu consent (máy trạng thái
            // trả requestCaptureConsent đúng trong trường hợp đó).
            if (state.action ==
                ScreenTranslateRecoveryAction.requestCaptureConsent)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.screen_share_outlined),
                    label: Text(
                      context.uiText('Cấp lại quyền chụp màn hình'),
                    ),
                    onPressed: _busy ? null : _reconsent,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.security_outlined,
                    size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    context.uiText(
                      'Android hỏi bạn cho phép chụp màn hình mỗi lần bật — '
                      'đó là quy định của hệ thống, không phải lỗi.',
                    ),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontSize: 11),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Nhãn nhỏ có icon cho cặp ngôn ngữ (SETTINGS-UI-COMPACT-001 + XLAT-SCR-005).
///
/// Tách ra để hai cột nguồn/đích không lặp 3 dòng trang trí — và để nhãn luôn
/// cùng cỡ chữ, cùng khoảng cách icon khi thẻ được chỉnh tiếp.
class _LanguageLabel extends StatelessWidget {
  const _LanguageLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
