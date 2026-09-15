// test/home_streak/smoke_test.dart

import 'package:flutter_test/flutter_test.dart';

/// Smoke test để xác nhận workflow `home_streak_tests.yml` chạy được trước khi
/// thêm test thật của HOME-STREAK-001 (sandbox không có Flutter SDK local —
/// CI là oracle, xem docs/skills/ci-red-debugging/SKILL.md).
void main() {
  test('home_streak CI oracle is wired', () {
    expect(1 + 1, 2);
  });
}
