// lib/utils/safe_set_state.dart
//
// LISTEN-LRC-001: provider listeners (Player/Understand/Soundlist) fire on
// async player ticks that can land while the framework is mid-build. Calling
// setState (or showing a snackbar) on a State whose element is currently
// building throws "setState() called during build" and cascades into
// framework assertions (`_elements.contains(element)`, stale InheritedWidget
// dependOn — the red "tab Hiểu" screen). This mixin defers those mutations
// to the next post-frame when needed instead of throwing.

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// True when calling [State.setState] right now would throw because the
/// framework is inside the build/layout phase.
bool listenShouldDeferSetState() {
  final phase = SchedulerBinding.instance.schedulerPhase;
  return phase != SchedulerPhase.idle &&
      phase != SchedulerPhase.postFrameCallbacks;
}

/// Drop-in guard for States driven by high-frequency provider listeners.
mixin SafeSetStateMixin<T extends StatefulWidget> on State<T> {
  /// Like [State.setState], but waits for the next post-frame when the
  /// framework is mid-build instead of throwing.
  void safeSetState(VoidCallback fn) {
    if (!mounted) return;
    if (!listenShouldDeferSetState()) {
      setState(fn);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(fn);
    });
  }

  /// Runs [fn] after the current frame, skipping it if the State was
  /// disposed meanwhile. Use for snackbars/toasts triggered from listeners,
  /// which also must not run while the messenger is building.
  void runPostFrame(VoidCallback fn) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      fn();
    });
  }
}
