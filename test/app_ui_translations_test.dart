import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/language/app_ui_translations.dart';
import 'package:in4up/core/language/localized_material.dart'
    show LocalizedUiBuildContext, Text;

void main() {
  group('AppUITranslations', () {
    test('uses English as the fallback for untranslated locales', () {
      expect(AppUITranslations.translate('Lưu', 'en-US'), 'Save');
      expect(AppUITranslations.translate('Lưu', 'bn-BD'), 'Save');
      expect(AppUITranslations.translate('Lưu', 'bo-CN'), 'Save');
    });

    test('Home hub copy is English / native, not leftover Vietnamese', () {
      const home =
          'Home là trung tâm điều phối: tiếp tục học, theo dõi tiến độ và truy cập nhanh hệ thống.';
      expect(AppUITranslations.translate(home, 'en'), isNot(contains('là trung tâm')));
      expect(AppUITranslations.translate('Nghe · Nói', 'en'), 'Listen · Speak');
      expect(AppUITranslations.translate('Nghe · Nói', 'zh'), '听 · 说');
      expect(AppUITranslations.translate('Nghe · Nói', 'si'), isNot('Nghe · Nói'));
      expect(AppUITranslations.translate('Quản lý Model AI', 'hi'), isNot('Quản lý Model AI'));
      expect(AppUITranslations.translate('Tải về', 'en'), 'Download');
      expect(AppUITranslations.translate('Ôn tập · SRS', 'zh'), '复习 · SRS');
    });

    test('uses real locale translations when the catalog has one', () {
      expect(AppUITranslations.translate('Lưu', 'de-DE'), 'Speichern');
      expect(AppUITranslations.translate('Lưu', 'fr-FR'), 'Enregistrer');
      expect(AppUITranslations.translate('Lưu', 'ja-JP'), '保存');
    });

    test('preserves Traditional Chinese locale subtags', () {
      expect(
        AppUITranslations.translate('Hệ điều hành Tri thức', 'zh-Hans-CN'),
        '知识操作系统',
      );
      expect(
        AppUITranslations.translate('Hệ điều hành Tri thức', 'zh-Hant-TW'),
        '知識作業系統',
      );
      expect(
        AppUITranslations.translate('Hệ điều hành Tri thức', 'zh_TW'),
        '知識作業系統',
      );
    });

    test('interpolates reviewed ARB templates without losing values', () {
      expect(
        AppUITranslations.translate('Lỗi: network timeout', 'fr'),
        'Erreur network timeout',
      );
      expect(
        AppUITranslations.translate('Dòng 2/14', 'en'),
        'Line 2/14',
      );
    });

    test('uses reviewed fallbacks for generated model UI templates', () {
      expect(AppUITranslations.translate('trang 42', 'en'), 'page 42');
      expect(AppUITranslations.translate('dòng 3', 'de'), 'line 3');
      expect(AppUITranslations.translate('cuộn 50%', 'fr'), 'scroll 50%');
      expect(
        AppUITranslations.translate(
          'Preset cá nhân gồm 7 nhóm từ loại được chọn thủ công.',
          'en',
        ),
        'Personal preset with 7 manually selected part-of-speech groups.',
      );
    });

    test('supports templates assembled from adjacent Dart strings', () {
      expect(
        AppUITranslations.translate(
          '🇬🇧 en ×2  •  Câu 3/10  •  Vòng 1/4',
          'en',
        ),
        '🇬🇧 en ×2  •  Sentence 3/10  •  Round 1/4',
      );
    });

    test('localizes reviewed generated values at explicit UI boundaries', () {
      expect(
        AppUITranslations.translate('Dòng 5 / 20', 'en'),
        'Line 5 / 20',
      );
      expect(
        AppUITranslations.translate('Đang chờ... 1.5s', 'en'),
        'Waiting... 1.5s',
      );

      final relativeTime = AppUITranslations.translate('5p trước', 'en');
      expect(relativeTime, '5m ago');
      expect(
        AppUITranslations.translate('Đã lưu $relativeTime', 'en'),
        'Saved 5m ago',
      );

      final anchorAge = AppUITranslations.translate('3 phút trước', 'en');
      expect(
        AppUITranslations.translate('Câu 7  •  $anchorAge', 'en'),
        'Sentence 7  •  3 minutes ago',
      );
      expect(
        AppUITranslations.translate('65% độ dài câu gốc', 'en'),
        '65% of the original length',
      );
      expect(AppUITranslations.translate('Đặt 20 phút', 'en'), 'Set 20 minutes');
    });

    test('localizes generated custom-widget labels without losing content', () {
      expect(
        AppUITranslations.translate('12 lần gặp', 'en'),
        'Encountered 12 times',
      );
      expect(
        AppUITranslations.translate('4 nhóm đang bật', 'en'),
        '4 groups enabled',
      );
      expect(
        AppUITranslations.translate('Tối thiểu 6 ký tự', 'en'),
        'At least 6 characters',
      );
      expect(
        AppUITranslations.translate('PDF đoạn chọn · lesson-one', 'en'),
        'PDF selection · lesson-one',
      );
      expect(
        AppUITranslations.translate('Nhảy tới 02:15 trong audio', 'en'),
        'Jump to 02:15 in audio',
      );
    });

    test('exact lookup does not translate template-shaped content', () {
      expect(AppUITranslations.translateExact('10 phút', 'en'), '10 phút');
      expect(AppUITranslations.translate('10 phút', 'en'), '10 minutes');
    });

    testWidgets('Text requires an explicit UI boundary for templates',
        (tester) async {
      await tester.pumpWidget(
        material.MaterialApp(
          locale: const material.Locale('en'),
          home: material.Builder(
            builder: (context) => material.Column(
              children: [
                const Text('10 phút'),
                material.Text(context.uiText('10 phút')),
              ],
            ),
          ),
        ),
      );

      expect(find.text('10 phút'), findsOneWidget);
      expect(find.text('10 minutes'), findsOneWidget);
    });

    test('keeps Vietnamese unchanged when Vietnamese is selected', () {
      expect(AppUITranslations.translate('Lưu', 'vi-VN'), 'Lưu');
      expect(AppUITranslations.translate('Dòng 2/14', 'vi'), 'Dòng 2/14');
    });

    test('never guesses at unknown document or vocabulary content', () {
      const userText = 'Đây là nội dung tiếng Việt do người dùng nhập.';
      expect(AppUITranslations.translate(userText, 'en'), userText);
      expect(AppUITranslations.containsSource(userText), isFalse);
    });

    test('falls back to English for listen/pdf/web/memory QA labels', () {
      const cases = {
        'Chậm và nhiều vòng để bắt chước kỹ từng âm.':
            'Slow, many loops to copy each sound carefully.',
        'Tập trung vào độ rõ âm và độ chính xác phát âm.':
            'Focus on sound clarity and pronunciation accuracy.',
        'Cân bằng giữa phát âm, trí nhớ và nhịp phản xạ.':
            'Balance pronunciation, memory, and reaction rhythm.',
        'Ưu tiên nhịp nói tự nhiên và giữ mạch câu.':
            'Prioritize natural speaking rhythm and keep the sentence flow.',
        'Không màu': 'No color',
        'Loại từ': 'Part of speech',
        'Độ khó': 'Difficulty',
        'Pháp thoại & Dharma': 'Dharma talks',
        'Nguồn đọc cố định cho Phật học, thiền và pháp thoại tiếng Anh.':
            'Fixed reading sources for Buddhism, meditation, and English dharma talks.',
        'Nguồn đọc chậm, rõ, phù hợp để luyện từ vựng và đọc hiểu.':
            'Slow, clear reading sources for vocabulary and comprehension practice.',
        'Tin tức & Kiến thức': 'News and Knowledge',
        'Tin tức &amp; Kiến thức': 'News and Knowledge',
        'Giữ lại các nguồn preset cũ và mở rộng thêm nơi đọc chung.':
            'Keep the previous preset sources and add more general reading sites.',
        'NGHE': 'LISTEN',
        'Hiểu + Nghe': 'Understand + Listen',
        'Hiểu + Đọc': 'Understand + Read',
        'Nghe + Đọc': 'Listen + Read',
        '🟢 NGHE': '🟢 LISTEN',
      };
      cases.forEach((source, english) {
        expect(AppUITranslations.translate(source, 'en'), english);
        expect(AppUITranslations.translate(source, 'ja'), isNot(source));
      });
    });

    test('falls back to English for I2U chat harvest labels', () {
      const cases = {
        'Hỏi đáp về từ vựng và ngữ pháp': 'Ask about vocabulary and grammar',
        'Trợ lý học tập I2U': 'I2U learning assistant',
        'Xóa cuộc trò chuyện': 'Clear conversation',
        'AI local chưa sẵn sàng. Bạn có thể import model .gguf trong phần cài đặt AI.':
            'Local AI is not ready. You can import a .gguf model in AI settings.',
      };
      cases.forEach((source, english) {
        expect(AppUITranslations.translate(source, 'en'), english);
        expect(AppUITranslations.translate(source, 'ja'), isNot(source));
      });
    });

    test('falls back to English for writing-studio harvest labels', () {
      const cases = {
        'Nguồn cho Viết': 'Writing source',
        'Dùng đoạn này cho bài Viết lại ý':
            'Use this passage for a rewrite exercise',
        'Đã nhận đoạn chọn để luyện Viết':
            'Received a selected passage for writing practice',
        'Tín hiệu quan sát · không phải điểm semantic':
            'Observational signals · not a semantic score',
        '65% độ dài nguồn': '65% of source length',
        'Đoạn trích · Example article': 'Excerpt · Example article',
      };
      cases.forEach((source, english) {
        expect(AppUITranslations.translate(source, 'en'), english);
        expect(AppUITranslations.translate(source, 'ja'), isNot(source));
      });
    });

    test('does not use the old generic Content substitution', () {
      const knownSources = [
        'Đang khởi động...',
        'Chưa có văn bản',
        'Tìm bộ sưu tập, link, bookmark, lịch sử, tên miền...',
      ];
      for (final source in knownSources) {
        final translated = AppUITranslations.translate(source, 'en');
        expect(translated, isNot(source));
        expect(translated, isNot('Content'));
      }
    });
  });
}
