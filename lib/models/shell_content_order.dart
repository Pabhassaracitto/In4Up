/// The user-facing order of the two content workspaces in the shell.
///
/// This is deliberately shared by bottom navigation and library drawers so a
/// reorder can never leave the Listen tab paired with the Read library (or the
/// other way around).
enum ShellContentOrder {
  listenRead,
  readListen,
}

extension ShellContentOrderX on ShellContentOrder {
  bool get isListenFirst => this == ShellContentOrder.listenRead;
  bool get isReadFirst => this == ShellContentOrder.readListen;

  /// Whether the Listen workspace occupies the left-hand position.
  bool get listenOnLeft => isListenFirst;

  /// Whether the Read workspace occupies the left-hand position.
  bool get readOnLeft => isReadFirst;

  ShellContentOrder get toggled => isListenFirst
      ? ShellContentOrder.readListen
      : ShellContentOrder.listenRead;

  String get storageValue => name;
}

ShellContentOrder shellContentOrderFromStorage(Object? value) {
  return value == ShellContentOrder.readListen.name
      ? ShellContentOrder.readListen
      : ShellContentOrder.listenRead;
}
