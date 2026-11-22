# ADR-0031 — Thư Viện Chung I4U: gói `.i4upack`, catalog Firestore REST, storage pluggable, kiểm duyệt pending-first

- **Trạng thái:** ✅ accepted (owner chốt D1–D6 tại
  [`docs/great_library_ideation_v1.md`](../great_library_ideation_v1.md) §0,
  2026-11-15). Chưa code — triển khai theo PLAN-049.
- **Nguồn:** owner qua agent `arena/a04e4405-in4up`.

## Bối cảnh

Owner muốn một **thư viện cộng đồng trong app** (âm thanh, hình ảnh, từ vựng):
người dùng xem/tải về dùng cá nhân, và đóng góp cho người khác. Ràng buộc sẵn có
của repo: offline-first; client nói chuyện Firebase qua **REST** sẵn có
(`FirestoreRestClient`, `StorageService`, `auth_service.dart`), không kéo SDK
nặng; dung lượng Firebase có hạn → phải có đường thoát storage; nội dung cộng
đồng bắt buộc kiểm duyệt; AI cloud luôn opt-in BYOK.

## Quyết định

### D1 — Đơn vị chia sẻ là gói `.i4upack`, không chia sẻ file lẻ

- `.i4upack` = ZIP: `manifest.json` (schema versioned, có `license`, `tags`,
  `srcLang/dstLang`, `level`, `stats`) + `data/` (vocab JSON / LRC / caption) +
  `media/`. `sha256` toàn gói; `version` tăng dần mỗi lần tác giả cập nhật.
- **Loại trừ:** REST tải từng file lẻ (nhiều request, không verify toàn vẹn,
  khó version); format nhị phân tự chế (không cần — `archive` pure-Dart đủ).

### D2 — Catalog = Firestore qua REST client sẵn có; write luôn vào hàng chờ

- Collections: `gl_packs` (metadata, `status`), `gl_pack_versions`,
  `gl_contributions` (hàng chờ), `gl_reviews`/`gl_reports` (P2), `gl_config/admins`.
- Rules: đọc public chỉ với `status == 'published'`; user đăng nhập được `create`
  vào `gl_contributions` (không được tự `published`); chỉ uid admin đổi `status`.
- **Loại trừ:** server API riêng (chi phí + vận hành, chưa cần ở quy mô đầu);
  client SDK Firestore đầy đủ (trái quy ước REST nhẹ của app).

### D3 — Storage qua interface `PackStorageBackend` (pluggable)

- Backend 1: **Firebase Storage** (REST sẵn có). Backend 2 khi hết quota:
  **Supabase Storage**. Manifest ghi `storage.backend` + `storage.path` ⇒ hai
  backend song hành, pack cũ không cần migrate.
- Download qua byte-range (resume), verify `sha256` sau khi tải.
- **Loại trừ:** gọi thẳng Firebase Storage từ UI (khoá chết vào một nhà cung
  cấp — owner đã nêu lo Firebase hết dung lượng); tự host server file (vận hành).

### D4 — Kiểm duyệt pending-first; admin là màn trong app, gate bằng uid owner

- Mọi pack user gửi ở `pending`; chỉ màn admin (uid ∈ `gl_config/admins`, uid
  của `be.you8778@gmail.com`) duyệt/từ chối/ẩn. UI ẩn entry với mọi tài khoản
  khác; **Firestore rules là rào chắn thật**.
- P2 bổ sung report + auto-hide theo ngưỡng (ADR/plan sau khi có số liệu vận hành).
- **Loại trừ:** auto-publish (rủi ro bản quyền/nội dung xấu); web admin riêng
  (owner chọn in-app); Cloud Functions ở giai đoạn đầu (chi phí/độ phức tạp).

### D5 — Tải pack không cần đăng nhập

- Đọc catalog + tải pack `published`: không yêu cầu auth (giảm ma sát, đúng
  tinh thần thư viện). Auth chỉ bắt buộc: đóng góp, đánh giá, báo cáo.
- Hệ quả: chống abuse download bằng quota mềm phía Storage/CDN, không bằng auth.

### D6 — AI gợi ý metadata lúc soạn pack: opt-in, BYOK, không auto-publish

- Nút "Gợi ý bằng AI" trong wizard dùng tầng `AiEngineRemote`/provider store
  (API-001/002) — mặc định TẮT, key của chính user. Gợi ý luôn qua tay người soạn.

## Hệ quả

- ✅ Không dependency native mới (ZIP qua `archive` pure-Dart); toàn bộ client
  đi qua REST hiện có → web build không vỡ.
- ✅ Storage đổi backend không làm hỏng pack đã phát hành.
- ⚠️ Moderation thủ công phụ thuộc thời gian owner ở P0/P1 — chấp nhận vì
  cộng đồng còn nhỏ; P2 cân nhắc auto-mod khi ≥ ~200 pack published.
- ⚠️ Firestore rules là điểm nghẽn bảo mật duy nhất cho cổng admin → phải test
  rules bằng REST tay (AT3 của PLAN-049) trước khi mở P1.

## Lịch sử

- 2026-11-15 | accepted | owner chốt D1–D6 trong ideation; agent
  `arena/a04e4405-in4up` ghi ADR kèm PLAN-049.
