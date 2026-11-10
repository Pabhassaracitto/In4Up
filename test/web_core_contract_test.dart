import 'package:flutter_test/flutter_test.dart';

import 'package:in4up/features/web_core/web_content_fetcher.dart';
import 'package:in4up/features/web_core/web_proxy_config.dart';
import 'package:in4up/features/web_core/web_proxy_translation_engine.dart';

void main() {
  group('Web Core proxy contract', () {
    test('fails closed when no proxy is configured', () async {
      expect(WebProxyConfig.isConfigured, isFalse);

      final translation = await WebProxyTranslationEngine().translate(
        text: 'hello',
        targetLang: 'vi',
      );
      expect(translation.isSuccess, isFalse);
      expect(translation.error, contains('proxy'));

      await expectLater(
        WebContentFetcher().fetch(Uri.parse('https://example.com')),
        throwsA(isA<WebContentFetchException>()),
      );
    });
  });
}
