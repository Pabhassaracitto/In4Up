// lib/features/screen_translate/screen_translate_card.dart
//
// Thẻ bật/tắt "Dịch màn hình toàn hệ thống" trong Quản lý Model AI
// (XLAT-SCR-002 · ADR-0011 · sửa XLAT-SCR-003).
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
  ScreenTranslateNativeStatus _status = ScreenTranslateNativeStatus.fallback;

  /// Máy trạng thái quyền — nguồn duy nhất quyết định UI.
  ScreenTranslatePermissionSnapshot get _state => _resolver.resolve(_status);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
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
    final target = await loadScreenTranslateTarget();
    if (!mounted) return;
    setState(() {
      _status = status;
      _target = target;
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
      final started = await _channel.start(targetLanguage: _target);
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
    if (_state.status.running) await _channel.setTargetLanguage(code);
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
            Text(
              context.uiText(
                'Bong bóng nổi trên mọi ứng dụng: bấm để chụp màn hình, nhận dạng chữ rồi hiện bản dịch đè đúng vị trí. Dùng đúng engine dịch bạn đang chọn.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  context.uiText('Ngôn ngữ đích'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(width: 10),
                TranslationLanguagePickerButton(
                  sourceLanguage: AppLanguageCatalog.english,
                  targetLanguage: target,
                  accentColor: Colors.lightBlue,
                  onSelected: _onLanguageSelected,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  context.uiText(message),
                  style: orange,
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
            Text(
              context.uiText(
                'Android hỏi bạn cho phép chụp màn hình mỗi lần bật — đó là quy định của hệ thống, không phải lỗi.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
