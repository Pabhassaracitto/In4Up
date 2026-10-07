import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/models/reader_contextual_panel_state.dart';

void main() {
  test('actions require non-empty selected text', () {
    const empty = I4uReaderContextualPanelState(
      mode: I4uReaderContextPanelMode.mobileSheet,
      selection: I4uReaderSelectionContext(text: '  ', sourceId: 'book'),
    );
    expect(empty.hasSelection, isFalse);
    expect(empty.canRunAction, isFalse);

    const selected = I4uReaderContextualPanelState(
      mode: I4uReaderContextPanelMode.desktopPanel,
      selection: I4uReaderSelectionContext(text: 'tri giác', sourceId: 'book'),
    );
    expect(selected.hasSelection, isTrue);
    expect(selected.canRunAction, isTrue);
  });

  test('loading prevents duplicate contextual actions', () {
    const state = I4uReaderContextualPanelState(
      mode: I4uReaderContextPanelMode.desktopPanel,
      selection: I4uReaderSelectionContext(text: 'tri giác', sourceId: 'book'),
      isLoading: true,
    );
    expect(state.hasSelection, isTrue);
    expect(state.canRunAction, isFalse);
  });
}
