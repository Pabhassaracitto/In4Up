import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/shortcuts/shortcut_registry.dart';

void main() {
  I4uShortcutRegistry registry() => I4uShortcutRegistry([
        const I4uShortcutDefinition(
          id: 'open-command-palette',
          key: LogicalKeyboardKey.keyK,
          scope: I4uShortcutScope.global,
          fallbackAction: 'open-search-button',
        ),
      ]);

  test('accelerator is opt-in and resolves in its scope', () {
    final shortcuts = registry();
    final input = const I4uShortcutInvocation(
      key: LogicalKeyboardKey.keyK,
      platform: I4uShortcutPlatform.macos,
      isMetaPressed: true,
    );

    expect(shortcuts.resolve(input), isNull);
    shortcuts.setEnabled('open-command-palette', true);
    expect(shortcuts.resolve(input)?.id, 'open-command-palette');
  });

  test('text inputs and contenteditable never receive accelerators', () {
    final shortcuts = registry()..setEnabled('open-command-palette', true);
    expect(
      shortcuts.resolve(const I4uShortcutInvocation(
        key: LogicalKeyboardKey.keyK,
        platform: I4uShortcutPlatform.web,
        isMetaPressed: true,
        isTextInputFocused: true,
      )),
      isNull,
    );
    expect(
      shortcuts.resolve(const I4uShortcutInvocation(
        key: LogicalKeyboardKey.keyK,
        platform: I4uShortcutPlatform.web,
        isMetaPressed: true,
        isContentEditableFocused: true,
      )),
      isNull,
    );
  });

  test('reserved browser chords stay native', () {
    final shortcuts = I4uShortcutRegistry([
      const I4uShortcutDefinition(
        id: 'bad-tab-switch',
        key: LogicalKeyboardKey.digit1,
        scope: I4uShortcutScope.global,
        fallbackAction: 'button',
        enabled: true,
      ),
    ]);

    expect(
      shortcuts.resolve(const I4uShortcutInvocation(
        key: LogicalKeyboardKey.digit1,
        platform: I4uShortcutPlatform.macos,
        isMetaPressed: true,
      )),
      isNull,
    );
  });
}
