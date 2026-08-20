# Bật CI cho module Knowledge (MVA Task 1)

Token GitHub App của agent KHÔNG có quyền `workflows` (không được tạo/sửa
file trong `.github/workflows/`). Workflow đã viết sẵn tại
`tool/ci/knowledge_tests.yml`.

## Cách bật (chọn 1)

1. **Bằng tay (1 lệnh):**
   ```
   git checkout arena/01a019bb-in4up
   cp tool/ci/knowledge_tests.yml .github/workflows/knowledge_tests.yml
   git add .github/workflows/knowledge_tests.yml
   git commit -m "ci: enable knowledge module tests"
   git push
   ```
   Sau đó mọi push vào `lib/knowledge/**` hoặc `test/knowledge/**`
   (kể cả của agent) sẽ tự chạy analyze + test.

2. **Cấp lại quyền cho GitHub App** (reconnect GitHub trong Arena với
   permission `workflows`) — agent sẽ tự đặt file và quản lý CI.

Workflow chạy: flutter 3.44.1 (khớp `build.yml`) → `flutter pub get`
→ `flutter analyze lib/knowledge test/knowledge`
→ `flutter test test/knowledge` (DoD Task 1).
