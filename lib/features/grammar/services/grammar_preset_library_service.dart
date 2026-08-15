import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/grammar_category.dart';
import '../models/grammar_highlight_preset.dart';
import '../models/grammar_highlight_settings.dart';

class GrammarPresetLibraryService {
  GrammarPresetLibraryService._();

  static const String presetsKey = 'grammar_highlight_custom_presets_v1';

  static List<GrammarHighlightPreset> builtInPresets() =>
      GrammarHighlightPresets.defaults();

  static Future<List<GrammarHighlightPreset>> loadCustomPresets() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(presetsKey);
    if (raw == null || raw.trim().isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      final list = decoded is List ? decoded : const <dynamic>[];
      return list
          .whereType<Map>()
          .map((item) => GrammarHighlightPreset.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .where((preset) => !preset.isBuiltIn)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<List<GrammarHighlightPreset>> loadAllPresets() async {
    final customs = await loadCustomPresets();
    return [...builtInPresets(), ...customs];
  }

  static Future<GrammarHighlightPreset> savePreset({
    required String name,
    String description = '',
    required GrammarHighlightSettings settings,
    String? existingId,
  }) async {
    final current = await loadCustomPresets();
    final preset = GrammarHighlightPreset(
      id: existingId ?? 'user-${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      description: description.trim().isEmpty
          ? _buildDefaultDescription(settings.visibleCategories)
          : description.trim(),
      visibleCategories: Set<GrammarCategory>.from(settings.visibleCategories),
      showLegend: settings.showLegend,
      emphasizeContentWords: settings.emphasizeContentWords,
      audienceLabel: 'Content',
      focusSummary: _buildFocusSummary(settings.visibleCategories),
      isBuiltIn: false,
    );

    final next = List<GrammarHighlightPreset>.from(current);
    final index = next.indexWhere((item) => item.id == preset.id);
    if (index >= 0) {
      next[index] = preset;
    } else {
      next.add(preset);
    }
    await _persist(next);
    return preset;
  }

  static Future<void> deletePreset(String id) async {
    final current = await loadCustomPresets();
    current.removeWhere((preset) => preset.id == id);
    await _persist(current);
  }

  static Future<void> _persist(List<GrammarHighlightPreset> presets) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      presetsKey,
      jsonEncode(presets.map((preset) => preset.toJson()).toList()),
    );
  }

  static String _buildFocusSummary(Set<GrammarCategory> categories) {
    if (categories.isEmpty) return 'Content';
    final sorted = categories.toList()
      ..sort((a, b) => a.referenceStyleIndex.compareTo(b.referenceStyleIndex));
    final labels = sorted.take(4).map((category) => category.shortCode).toList();
    final suffix = sorted.length > 4 ? ' +${sorted.length - 4}' : '';
    return labels.join(' · ') + suffix;
  }

  static String _buildDefaultDescription(Set<GrammarCategory> categories) {
    if (categories.isEmpty) {
      return 'Content';
    }
    if (categories.length <= 2) {
      return 'Content';
    }
    return 'Content';
  }
}