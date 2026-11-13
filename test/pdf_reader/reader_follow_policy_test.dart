import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/pdf_reader/services/reader_follow_policy.dart';
void main() {
  test('follow only outside viewport, respects five second manual override', () {
    final policy = ReaderFollowPolicy();
    final now = DateTime(2026);
    expect(policy.karaoke, isTrue);
    expect(policy.shouldReveal(now: now, visible: true), isFalse);
    expect(policy.shouldReveal(now: now, visible: false), isTrue);
    policy.manualScroll(now);
    expect(policy.shouldReveal(now: now.add(const Duration(seconds: 4)), visible: false), isFalse);
    expect(policy.shouldReveal(now: now.add(const Duration(seconds: 5)), visible: false), isTrue);
    policy.autoScroll = false;
    expect(policy.shouldReveal(now: now.add(const Duration(seconds: 6)), visible: false), isFalse);
  });
}
