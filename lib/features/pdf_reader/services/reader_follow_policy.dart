/// Shared follow policy: playback never takes the viewport away immediately
/// after a user gesture. Engine callbacks only provide sentence-level timing.
class ReaderFollowPolicy {
  bool karaoke = true;
  bool autoScroll = true;
  DateTime? _manualUntil;

  void manualScroll(DateTime now) {
    _manualUntil = now.add(const Duration(seconds: 5));
  }

  bool shouldReveal({required DateTime now, required bool visible}) =>
      autoScroll && !visible &&
      (_manualUntil == null || !now.isBefore(_manualUntil!));
}
