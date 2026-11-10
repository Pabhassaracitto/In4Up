import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/screens/memory_mode/memory_provider.dart';
import 'package:in4up/screens/tools/word_list/word_list_controller.dart';
import 'package:in4up/screens/tools/word_list/word_list_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  test('delete exactly the five selected manual entries and end selection', () {
    final controller = WordListController();
    for (var i = 0; i < 10; i++) {
      controller.addManualEntry(WordEntry.manual(id: '$i', word: 'word$i'));
    }
    controller.toggleSelecting();
    for (var i = 0; i < 5; i++) {
      controller.toggleSelect('$i');
    }
    controller.deleteSelected();
    final remaining = controller.displayEntries.map((e) => e.id).toSet();
    expect(remaining, {'5', '6', '7', '8', '9'});
    expect(controller.selectedIds, isEmpty);
    expect(controller.isSelecting, isFalse);
  });

  test('empty selection is a no-op', () {
    final controller = WordListController();
    controller.addManualEntry(WordEntry.manual(id: 'x', word: 'x'));
    expect(controller.deleteSelected, returnsNormally);
    expect(controller.displayEntries.map((e) => e.id), contains('x'));
  });

  test('memory entries remain, matching single manual delete', () async {
    final memory = MemoryProvider.controller;
    while (!memory.isLoaded) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(memory.addWord(word: 'garden-srs-bulk-test'), isTrue);
    final item = memory.allItems.singleWhere((i) => i.word == 'garden-srs-bulk-test');
    final controller = WordListController();
    controller.removeManualEntry(item.id);
    expect(memory.allItems.map((i) => i.id), contains(item.id));
    controller.toggleSelecting();
    controller.toggleSelect(item.id);
    controller.deleteSelected();
    expect(memory.allItems.map((i) => i.id), contains(item.id));
    memory.removeItem(item.id);
  });
}
