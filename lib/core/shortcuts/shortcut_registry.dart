import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Scope in which an accelerator may be handled.
enum I4uShortcutScope { global, workspace, modal, player }

enum I4uShortcutPlatform { macos, windows, linux, web, other }

/// A user-facing fallback must exist even when the accelerator is disabled.
@immutable
class I4uShortcutDefinition {
  const I4uShortcutDefinition({
    required this.id,
    required this.key,
    required this.scope,
    required this.fallbackAction,
    this.platforms = const {
      I4uShortcutPlatform.macos,
      I4uShortcutPlatform.windows,
      I4uShortcutPlatform.linux,
      I4uShortcutPlatform.web,
    },
    this.enabled = false,
  });

  final String id;
  final LogicalKeyboardKey key;
  final I4uShortcutScope scope;
  final String fallbackAction;
  final Set<I4uShortcutPlatform> platforms;
  final bool enabled;

  bool supports(I4uShortcutPlatform platform) => platforms.contains(platform);
}

/// The state needed to decide whether an accelerator may run.
@immutable
class I4uShortcutInvocation {
  const I4uShortcutInvocation({
    required this.key,
    required this.platform,
    this.scope = I4uShortcutScope.global,
    this.isMetaPressed = false,
    this.isControlPressed = false,
    this.isAltPressed = false,
    this.isShiftPressed = false,
    this.isTextInputFocused = false,
    this.isContentEditableFocused = false,
  });

  final LogicalKeyboardKey key;
  final I4uShortcutPlatform platform;
  final I4uShortcutScope scope;
  final bool isMetaPressed;
  final bool isControlPressed;
  final bool isAltPressed;
  final bool isShiftPressed;
  final bool isTextInputFocused;
  final bool isContentEditableFocused;

  bool get hasModifier =>
      isMetaPressed || isControlPressed || isAltPressed || isShiftPressed;
}

/// Registry and policy layer. It deliberately does not install a global
/// keyboard listener; the active shell/widget owns event subscription.
class I4uShortcutRegistry {
  I4uShortcutRegistry(Iterable<I4uShortcutDefinition> definitions)
      : _definitions = {
          for (final definition in definitions) definition.id: definition,
        };

  final Map<String, I4uShortcutDefinition> _definitions;
  final Map<String, bool> _overrides = <String, bool>{};

  Iterable<I4uShortcutDefinition> get definitions => _definitions.values;

  void setEnabled(String id, bool enabled) {
    if (_definitions.containsKey(id)) _overrides[id] = enabled;
  }

  bool isEnabled(String id) => _overrides[id] ?? _definitions[id]?.enabled ?? false;

  /// Returns a definition only when policy permits handling the event.
  I4uShortcutDefinition? resolve(I4uShortcutInvocation invocation) {
    if (invocation.isTextInputFocused || invocation.isContentEditableFocused) {
      return null;
    }

    // OS/browser-reserved chords remain outside this registry.
    if (_isReservedBrowserChord(invocation)) return null;

    for (final definition in _definitions.values) {
      if (definition.key != invocation.key ||
          definition.scope != invocation.scope ||
          !definition.supports(invocation.platform) ||
          !isEnabled(definition.id)) {
        continue;
      }
      return definition;
    }
    return null;
  }

  bool _isReservedBrowserChord(I4uShortcutInvocation input) {
    final primary = input.isMetaPressed || input.isControlPressed;
    if (!primary) return false;

    // Tab switching, browser back, open and close stay native.
    return input.key == LogicalKeyboardKey.bracketLeft ||
        input.key == LogicalKeyboardKey.keyO ||
        input.key == LogicalKeyboardKey.keyW ||
        (input.key.keyLabel.length == 1 &&
            '12345'.contains(input.key.keyLabel));
  }
}

I4uShortcutPlatform currentI4uShortcutPlatform(TargetPlatform platform) {
  switch (platform) {
    case TargetPlatform.macOS:
      return I4uShortcutPlatform.macos;
    case TargetPlatform.windows:
      return I4uShortcutPlatform.windows;
    case TargetPlatform.linux:
      return I4uShortcutPlatform.linux;
    case TargetPlatform.fuchsia:
      return I4uShortcutPlatform.other;
    case TargetPlatform.iOS:
    case TargetPlatform.android:
      return I4uShortcutPlatform.other;
  }
}
