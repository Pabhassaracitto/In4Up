import 'package:flutter/foundation.dart';

/// Ordered layers used by the shell before route history is considered.
enum I4uBackLayer { overlay, panel, sheet, draft, sourceReturn, routeHistory, homeFallback }

@immutable
class I4uBackState {
  const I4uBackState({
    this.overlays = const <String>[],
    this.panel,
    this.sheet,
    this.hasUnsavedDraft = false,
    this.sourceReturnPath,
    this.hasRouteHistory = false,
  });

  final List<String> overlays;
  final String? panel;
  final String? sheet;
  final bool hasUnsavedDraft;
  final String? sourceReturnPath;
  final bool hasRouteHistory;

  bool get canDismiss =>
      overlays.isNotEmpty ||
      panel != null ||
      sheet != null ||
      hasUnsavedDraft ||
      sourceReturnPath != null ||
      hasRouteHistory;
}

enum I4uBackAction {
  dismissOverlay,
  closePanel,
  closeSheet,
  saveDraft,
  confirmDraft,
  returnToSource,
  popRoute,
  goHome,
  allowSystemExit,
}

@immutable
class I4uBackDecision {
  const I4uBackDecision(this.action, {this.id});

  final I4uBackAction action;
  final String? id;
}

/// Pure decision layer for Escape, Android back and app-bar back buttons.
/// The host performs the returned action and then updates its state.
class I4uBackDismissCoordinator {
  const I4uBackDismissCoordinator();

  I4uBackDecision decide(I4uBackState state, {bool draftAutosaveSucceeded = false}) {
    if (state.overlays.isNotEmpty) {
      return I4uBackDecision(
        I4uBackAction.dismissOverlay,
        id: state.overlays.last,
      );
    }
    if (state.panel != null) {
      return I4uBackDecision(I4uBackAction.closePanel, id: state.panel);
    }
    if (state.sheet != null) {
      return I4uBackDecision(I4uBackAction.closeSheet, id: state.sheet);
    }
    if (state.hasUnsavedDraft) {
      return I4uBackDecision(
        draftAutosaveSucceeded
            ? I4uBackAction.saveDraft
            : I4uBackAction.confirmDraft,
      );
    }
    if (state.sourceReturnPath != null) {
      return I4uBackDecision(
        I4uBackAction.returnToSource,
        id: state.sourceReturnPath,
      );
    }
    if (state.hasRouteHistory) {
      return const I4uBackDecision(I4uBackAction.popRoute);
    }
    return const I4uBackDecision(I4uBackAction.goHome);
  }

  /// A root route may opt out of the final Home fallback and allow the
  /// platform/router to close the app instead.
  I4uBackDecision decideAtRoot(I4uBackState state, {bool homeIsCurrent = false}) {
    final decision = decide(state);
    if (decision.action == I4uBackAction.goHome && homeIsCurrent) {
      return const I4uBackDecision(I4uBackAction.allowSystemExit);
    }
    return decision;
  }
}
