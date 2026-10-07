import 'package:flutter/foundation.dart';

import '../../models/reader_contextual_panel_state.dart';

enum I4uReaderContextualFlowStep { reader, panel, capability, returning }

@immutable
class I4uReaderContextualFlowState {
  const I4uReaderContextualFlowState({
    this.step = I4uReaderContextualFlowStep.reader,
    this.selection,
    this.action,
  });

  final I4uReaderContextualFlowStep step;
  final I4uReaderSelectionContext? selection;
  final I4uReaderContextAction? action;

  bool get canReturnToReader => selection != null;
}

/// State machine for the Reader vertical slice. It owns flow transitions, not
/// the presentation of a sheet/panel or the implementation of a capability.
class I4uReaderContextualFlowController extends ValueNotifier<I4uReaderContextualFlowState> {
  I4uReaderContextualFlowController() : super(const I4uReaderContextualFlowState());

  void select(I4uReaderSelectionContext selection) {
    value = I4uReaderContextualFlowState(
      step: I4uReaderContextualFlowStep.panel,
      selection: selection,
    );
  }

  void run(I4uReaderContextAction action) {
    if (value.selection == null) return;
    value = I4uReaderContextualFlowState(
      step: I4uReaderContextualFlowStep.capability,
      selection: value.selection,
      action: action,
    );
  }

  void returnToReader() {
    if (value.selection == null) return;
    value = I4uReaderContextualFlowState(
      step: I4uReaderContextualFlowStep.returning,
      selection: value.selection,
    );
  }

  void completeReturn() {
    value = I4uReaderContextualFlowState(
      step: I4uReaderContextualFlowStep.reader,
      selection: value.selection,
    );
  }
}
