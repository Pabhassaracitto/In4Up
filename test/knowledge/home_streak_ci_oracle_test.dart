// test/knowledge/home_streak_ci_oracle_test.dart
//
// CẦU NỐI ORACLE (tạm) — không phải test của module Knowledge.
//
// Vì sao tồn tại: HOME-STREAK-001 (B6) cần test cho kho hoạt động học + thẻ
// "Nhịp điệu học tập", nhưng GitHub App của agent **không có quyền `workflows`**
// nên không push được `.github/workflows/home_streak_tests.yml`. Bản mẫu workflow
// đã để ở `docs/ci/home_streak_tests.yml` cho owner bật.
//
// Trong lúc chờ owner bật job riêng, job `knowledge_tests.yml` (chạy
// `flutter test test/knowledge`) là CI duy nhất chạy được bộ test mới — file này
// gọi ĐÚNG bộ test đó (không copy, không fork nội dung).
//
// Khi job riêng đã bật: xoá file cầu nối này — bộ test vẫn chạy ở
// `test/home_streak/**` theo workflow mới.
//
// Bộ test thật: test/home_streak/home_streak_suites.dart

import '../home_streak/home_streak_suites.dart';

void main() {
  defineLearningActivityServiceTests();
  defineFocusStreakCardTests();
}
