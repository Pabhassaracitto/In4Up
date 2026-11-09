/// Process-local single-flight gate for the Android battery exemption prompt.
///
/// Startup and the settings shortcut share the same permission request. This
/// tiny gate makes sure they cannot open two system prompts concurrently.
class BatteryPromptGate {
  bool _inFlight = false;

  bool tryEnter() {
    if (_inFlight) return false;
    _inFlight = true;
    return true;
  }

  void leave() {
    _inFlight = false;
  }
}
