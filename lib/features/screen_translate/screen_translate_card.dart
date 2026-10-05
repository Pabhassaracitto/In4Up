// lib/features/screen_translate/screen_translate_card.dart
//
// Thẻ bật/tắt "Dịch màn hình toàn hệ thống" trong Quản lý Model AI
// (XLAT-SCR-002 · ADR-0011).
//
// Nền tảng không phải Android: thẻ vẫn hiện nhưng ở trạng thái "chỉ Android"
// và mọi nút bị khoá — tiêu chí nghiệm thu #6 (desktop không hỏng, không
// bày nút bấm vào thì lỗi).
//
// i18n: mọi chuỗi đi qua `context.uiText(...)` và đã đăng ký trong
// `lib/core/language/priority_ui_overrides.dart` đủ en/hi/zh/zh_TW/si
// (quy tắc vàng #5).

import 'package:in4up/core/language/localized_material.dart';

import '../../core/language/app_language.dart';
import '../translation/translation_language_picker.dart';
import 'screen_translate_channel.dart';
import 'screen_translate_prefs.dart';

class ScreenTranslateCard extends StatefulWidget {
  const ScreenTranslateCard({super.key, this.channel});

  /// Bơm channel giả trong test widget (mặc định dùng channel thật).
  final ScreenTranslateChannel? channel;

  @override
  State<ScreenTranslateCard> createState() => _ScreenTranslateCardState();
}

class _ScreenTranslateCardState extends State<ScreenTranslateCard> {
  late final ScreenTranslateChannel _channel =
      widget.channel ?? ScreenTranslateChannel();

  bool _supported = false;
  bool _hasOverlay = false;
  bool _running = false;
  bool _busy = false;
  String _target = kScreenTranslateDefaultTarget;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final supported = await _channel.isSupported();
    final overlay = supported ? await _channel.hasOverlayPermission() : false;
    final running = supported ? await _channel.isRunning() : false;
    final target = await loadScreenTranslateTarget();
    if (!mounted) return;
    setState(() {
      _supported = supported;
      _hasOverlay = overlay;
      _running = running;
      _target = target;
    });
  }

  Future<void> _toggle() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (_running) {
        await _channel.stop();
        if (!mounted) return;
        setState(() => _running = false);
        return;
      }
      if (!_hasOverlay) {
        await _channel.requestOverlayPermission();
        // Quyền được cấp ở màn hình Settings của hệ thống → quay lại mới
        // biết kết quả; user bấm lại nút là đủ (không poll nền tốn pin).
        return;
      }
      final started = await _channel.start(targetLanguage: _target);
      if (!mounted) return;
      setState(() => _running = started);
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

  Future<void> _onLanguageSelected(AppLanguage language) async {
    final code = await saveScreenTranslateTarget(language.translationCode);
    if (!mounted) return;
    setState(() => _target = code);
    if (_running) await _channel.setTargetLanguage(code);
  }

  @override
  Widget build(BuildContext context) {
    final target = AppLanguageCatalog.fromCode(
      _target,
      fallback: AppLanguageCatalog.vietnamese,
    );
    final androidOnly = !ScreenTranslateChannel.platformSupported;

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
            if (_supported && !_hasOverlay)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  context.uiText(
                    'Cần quyền "Hiển thị trên ứng dụng khác" để vẽ bong bóng và bản dịch.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.orangeAccent,
                      ),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(
                  _running
                      ? Icons.stop_circle_outlined
                      : Icons.bubble_chart_outlined,
                ),
                label: Text(
                  !_supported
                      ? context.uiText('Chỉ có trên Android')
                      : !_hasOverlay
                          ? context.uiText('Cấp quyền hiển thị trên ứng dụng khác')
                          : _running
                              ? context.uiText('Tắt bong bóng dịch')
                              : context.uiText('Bật bong bóng dịch'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _running ? Colors.red.shade700 : Colors.lightBlue.shade700,
                  foregroundColor: Colors.white,
                ),
                onPressed: (!_supported || _busy) ? null : _toggle,
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
