import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/translation/cache/translation_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TranslationCache().clear();
  });

  test('Hy-MT and ML Kit caches do not overwrite each other', () async {
    final cache = TranslationCache();
    await cache.put(
      text: 'hello',
      sourceLang: 'EN',
      targetLang: 'VI',
      translation: 'xin chào hymt',
      engine: 'hymt|off',
    );
    await cache.put(
      text: 'hello',
      sourceLang: 'EN',
      targetLang: 'VI',
      translation: 'xin chào mlkit',
      engine: 'mlkit|on',
    );

    expect(
      await cache.get(
        text: 'hello',
        sourceLang: 'EN',
        targetLang: 'VI',
        engine: 'hymt|off',
      ),
      'xin chào hymt',
    );
    expect(
      await cache.get(
        text: 'hello',
        sourceLang: 'EN',
        targetLang: 'VI',
        engine: 'mlkit|on',
      ),
      'xin chào mlkit',
    );
  });

  test('switching engine does not return the previous pipeline cache', () async {
    final cache = TranslationCache();
    await cache.put(
      text: 'hello',
      sourceLang: 'EN',
      targetLang: 'VI',
      translation: 'bản Hy-MT cũ',
      engine: 'hymt|off',
    );

    expect(
      await cache.get(
        text: 'hello',
        sourceLang: 'EN',
        targetLang: 'VI',
        engine: 'auto|on',
      ),
      isNull,
    );
  });
}
