import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/navigation/back_dismiss_coordinator.dart';

void main() {
  const coordinator = I4uBackDismissCoordinator();

  test('dismisses the top overlay before lower layers', () {
    final decision = coordinator.decide(const I4uBackState(
      overlays: ['quick-actions', 'chat'],
      panel: 'context-panel',
    ));

    expect(decision.action, I4uBackAction.dismissOverlay);
    expect(decision.id, 'chat');
  });

  test('protects an unsaved draft before returning to source', () {
    final decision = coordinator.decide(const I4uBackState(
      hasUnsavedDraft: true,
      sourceReturnPath: '/read/source-1',
    ));

    expect(decision.action, I4uBackAction.confirmDraft);
  });

  test('autosaves a draft when the host confirms it succeeded', () {
    final decision = coordinator.decide(
      const I4uBackState(hasUnsavedDraft: true),
      draftAutosaveSucceeded: true,
    );

    expect(decision.action, I4uBackAction.saveDraft);
  });

  test('uses source return, route history, then home fallback', () {
    expect(
      coordinator.decide(const I4uBackState(sourceReturnPath: '/read')).action,
      I4uBackAction.returnToSource,
    );
    expect(
      coordinator.decide(const I4uBackState(hasRouteHistory: true)).action,
      I4uBackAction.popRoute,
    );
    expect(
      coordinator.decide(const I4uBackState()).action,
      I4uBackAction.goHome,
    );
  });

  test('root Home can delegate final exit to the platform', () {
    final decision = coordinator.decideAtRoot(
      const I4uBackState(),
      homeIsCurrent: true,
    );
    expect(decision.action, I4uBackAction.allowSystemExit);
  });
}
