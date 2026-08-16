import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/grammar/models/grammar_category.dart';
import 'package:in4up/features/grammar/models/grammar_highlight_preset.dart';
import 'package:in4up/features/grammar/models/grammar_highlight_settings.dart';
import 'package:in4up/features/grammar/services/grammar_preset_library_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('GrammarHighlightPreset generated-description provenance', () {
    test('round-trips generated provenance through JSON', () {
      const preset = GrammarHighlightPreset(
        id: 'custom-1',
        name: 'My preset',
        description:
            'Preset cá nhân gồm 3 nhóm từ loại được chọn thủ công.',
        visibleCategories: {GrammarCategory.noun, GrammarCategory.verb},
        descriptionIsGenerated: true,
      );

      final restored = GrammarHighlightPreset.fromJson(preset.toJson());

      expect(restored.description, preset.description);
      expect(restored.descriptionIsGenerated, isTrue);
    });

    test('recognizes only known legacy generated descriptions', () {
      GrammarHighlightPreset restore(String description) {
        return GrammarHighlightPreset.fromJson({
          'id': 'legacy',
          'name': 'Legacy preset',
          'description': description,
          'visibleCategories': ['noun'],
        });
      }

      expect(
        restore('Preset cá nhân gồm 7 nhóm từ loại được chọn thủ công.')
            .descriptionIsGenerated,
        isTrue,
      );
      expect(
        restore('Preset cá nhân tối giản cho vùng đọc tập trung.')
            .descriptionIsGenerated,
        isTrue,
      );
      expect(
        restore('Mô tả cá nhân do người dùng nhập.').descriptionIsGenerated,
        isFalse,
      );
    });

    test('respects explicit persisted provenance over legacy detection', () {
      final restored = GrammarHighlightPreset.fromJson({
        'id': 'custom-2',
        'name': 'Custom',
        'description':
            'Preset cá nhân gồm 3 nhóm từ loại được chọn thủ công.',
        'visibleCategories': ['noun'],
        'descriptionIsGenerated': false,
      });

      expect(restored.descriptionIsGenerated, isFalse);
    });

    test('marks the synthesized custom preset description as generated', () {
      expect(
        GrammarHighlightPresets.byId('custom').descriptionIsGenerated,
        isTrue,
      );
      expect(
        GrammarHighlightPresets.byId('basic-pos').descriptionIsGenerated,
        isFalse,
      );
    });

    test(
      'service distinguishes synthesized descriptions from supplied content',
      () async {
        SharedPreferences.setMockInitialValues({});
        final settings = GrammarHighlightSettings.defaults().copyWith(
          visibleCategories: {
            GrammarCategory.noun,
            GrammarCategory.verb,
            GrammarCategory.adjective,
          },
        );

        final synthesized = await GrammarPresetLibraryService.savePreset(
          name: 'Generated description',
          description: '   ',
          settings: settings,
          existingId: 'generated-description',
        );
        final supplied = await GrammarPresetLibraryService.savePreset(
          name: 'Supplied description',
          description: '  My own study notes.  ',
          settings: settings,
          existingId: 'supplied-description',
        );

        expect(synthesized.description, isNotEmpty);
        expect(synthesized.descriptionIsGenerated, isTrue);
        expect(supplied.description, 'My own study notes.');
        expect(supplied.descriptionIsGenerated, isFalse);

        final restored = await GrammarPresetLibraryService.loadCustomPresets();
        expect(
          restored
              .singleWhere((preset) => preset.id == synthesized.id)
              .descriptionIsGenerated,
          isTrue,
        );
        expect(
          restored
              .singleWhere((preset) => preset.id == supplied.id)
              .descriptionIsGenerated,
          isFalse,
        );
      },
    );
  });
}
