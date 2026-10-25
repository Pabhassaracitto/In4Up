import 'package:flutter/foundation.dart';

import '../../models/i4u_shell_contracts.dart';

/// Short-lived source context published by a pushed workspace before it returns
/// to MainShell. The destination can render the source without coupling to
/// the player/video route.
class I4uWorkspaceHandoffInbox extends ChangeNotifier {
  I4uWorkspaceHandoffInbox._();

  static final I4uWorkspaceHandoffInbox instance =
      I4uWorkspaceHandoffInbox._();

  I4uSourceFingerprint? _current;
  I4uSourceFingerprint? get current => _current;

  void publish(I4uSourceFingerprint source) {
    _current = source;
    notifyListeners();
  }

  void clear() {
    if (_current == null) return;
    _current = null;
    notifyListeners();
  }
}
