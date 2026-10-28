import 'package:flutter/foundation.dart';

import '../navigation/workspace_handoff_inbox.dart';
import 'remember_flow.dart';

/// Connects the shared Watch/Listen/Cabin handoff payload to the Remember
/// review flow. The workspace may render its own source card, while the flow
/// controller keeps the same source alive when a review session starts,
/// pauses, rates and completes.
class I4uRememberHandoffCoordinator extends ChangeNotifier {
  I4uRememberHandoffCoordinator._() {
    _inbox.addListener(_onInboxChanged);
    _onInboxChanged();
  }

  static final I4uRememberHandoffCoordinator instance =
      I4uRememberHandoffCoordinator._();

  final I4uWorkspaceHandoffInbox _inbox =
      I4uWorkspaceHandoffInbox.instance;
  final I4uRememberFlowController flow = I4uRememberFlowController();

  void _onInboxChanged() {
    final source = _inbox.current;
    if (source == null) return;
    flow.loadFromHandoff(source);
    notifyListeners();
  }

  void clear() {
    _inbox.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _inbox.removeListener(_onInboxChanged);
    flow.dispose();
    super.dispose();
  }
}
