import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/grammar/models/grammar_highlight_settings.dart';
import 'package:in4up/features/grammar/services/grammar_settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('compact grammar legend default', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('new settings start with a collapsed Content Words legend', () {
      final settings = GrammarHighlightSettings.defaults();

      expect(settings.activePresetId, 'content-words');
      expect(settings.legendCollapsed, isTrue);
    });

    test('migrates existing settings once and preserves later user choices',
        () async {
      final oldSettings = GrammarHighlightSettings.defaults().copyWith(
        legendCollapsed: false,
      );
      SharedPreferences.setMockInitialValues({
        GrammarSettingsService.settingsKey: jsonEncode(oldSettings.toJson()),
      });

      final migrated = await GrammarSettingsService.load();
      expect(migrated.legendCollapsed, isTrue);
      expect(migrated.activePresetId, oldSettings.activePresetId);
      expect(migrated.visibleCategories, oldSettings.visibleCategories);

      final expandedByUser = migrated.copyWith(legendCollapsed: false);
      await GrammarSettingsService.save(expandedByUser);
      final reloaded = await GrammarSettingsService.load();

      expect(reloaded.legendCollapsed, isFalse);
    });
  });
}
