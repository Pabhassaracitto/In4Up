# ADR-0006: Đồng bộ lưu trữ Learn by Heart đa thiết bị (LHB-006)

- **Ngày:** 2026-09-23
- **Trạng thái:** ĐÃ TRIỂN KHAI + **CI XANH** trên `arena/01a0d016-in4up`
  (analyze + rule #5 + 47 test LHB, trong đó 19 test sync) — còn nghiệm thu
  2 thiết bị theo bảng AT bên dưới.
- **Phạm vi:** `lib/features/learn_by_heart/**` (model item + stats, storage,
  `learn_by_heart_merge.dart` mới, `learn_by_heart_sync_service.dart` mới,
  provider, hub screen, i18n), `lib/main.dart`, `test/learn_by_heart_sync_test.dart`.
  **Không** thêm dependency, **không** đổi schema collection `vocabulary`/
  text library, **không** đụng `lib/ffi/`, **không** đổi hành vi WordList.

## Bối cảnh

- Module Thuộc Lòng (LHB) chỉ lưu cục bộ trong SharedPreferences
  (`learn_by_heart_items_v1`, `learn_by_heart_streak_v1`, …). Đổi máy / cài lại
  app là mất tiến độ SRS đã học — trong khi WordList (`VocabSyncService`) đã có
  đồng bộ đa thiết bị từ lâu.
- Yêu cầu owner (2026-09-23): rà doc/plan xem đã có kế hoạch đồng bộ cho LHB
  chưa; chưa có thì lập kế hoạch **và** triển khai.
- Kết quả rà soát: **chưa có card/kế hoạch nào cho LHB sync.**
  - `INTEGRATE-1` (proposed) chỉ nói về knowledge module (evidence/ReviewEvent).
  - `AUDIT-2026-08-21` §4 xác nhận phạm vi sync hiện tại = `vocabulary_v2` + meta.
  - Hạ tầng dùng lại được đã có: `AuthService` (facade plugin/REST — ADR-0005
    Linux), `FirestoreRestClient` (`getDocument`/`listCollection`/`runQuery`/
    `commitWrites`), `connectivity_plus`, `shared_preferences`.

## Quyết định

1. **Giữ nguyên nguồn sự thật cục bộ (SharedPreferences), không migrate Hive.**
   Thêm 2 khoá trạng thái sync:
   - `learn_by_heart_pending_v1` — hàng đợi id có thay đổi chưa đẩy;
   - `learn_by_heart_tombstones_v1` — bia mộ `id → ISO8601` cho bài đã xoá.
   Lý do: dữ liệu LHB đã nằm trong tay người dùng; migrate kho lưu là rủi ro
   mất dữ liệu không cần thiết. Sync chỉ là lớp phủ thêm.

2. **Schema Firestore (chỉ thêm nhánh mới dưới `users/{uid}`):**
   - `users/{uid}/learn_by_heart/{itemId}` = JSON bài (đúng format local)
     + `updatedAt` (ISO string), `deleted` (bool), `deletedAt` (ISO),
     `_syncedAt` (server timestamp — chỉ để kéo incremental).
   - `users/{uid}/lhb_meta/checkpoint` = `{ lastSyncedAt }`
   - `users/{uid}/lhb_meta/stats` = `{ streak, lastActiveDate, updatedAt }`

3. **Hòa giải LWW "cloud thắng"** — trừ khi bản cục bộ có thay đổi **chưa đẩy**
   (pending) với mốc `syncStamp` (= `updatedAt` → `lastReviewedAt` → `createdAt`)
   **mới hơn** mốc cloud. Lúc đó giữ cục bộ và đẩy lên.
   Lý do quan trọng: bài seed mới sinh trên máy mới có `createdAt = "bây giờ"`;
   nếu so mốc thuần thì seed sẽ đè dữ liệu thật của người dùng. "Pending" là
   dấu hiệu duy nhất phân biệt *thay đổi thật của người dùng* với *rác sinh tự
   động*, nên mọi mutation đều `markPending` (kể cả khi chưa đăng nhập).
   - **Bổ sung 2026-09-23 (test bắt lỗi, đã sửa):** phép "đã đồng bộ rồi, bỏ qua"
     phải dựa trên **nội dung y hệt** (`hasSameContent` — JSON chuẩn hoá thứ tự
     key, vì Firestore REST có thể trả key khác thứ tự `toJson()`), **không**
     dựa trên so sánh mốc thời gian: so mốc làm máy đang giữ bản CŨ HƠN cloud
     không bao giờ nhận bản cloud (trái luật LWW ở trên). Bài mới từ cloud giữ
     đúng **thứ tự doc cloud trả về** khi đưa lên đầu danh sách.

4. **Xoá = bia mộ (soft delete), không xoá cứng doc.** Doc
   `{deleted: true, deletedAt}` lan sang mọi thiết bị và chặn hồi sinh; bài
   sống lại (sửa sau khi bị xoá) sẽ xoá bia mộ. Bia mộ cục bộ quá 365 ngày
   được dọn (doc cloud giữ nguyên — vô hại).

5. **Pull trước — Push sau** (giống `VocabSyncService`): `initialize(uid)` →
   load checkpoint → pull (merge) → flushPending. `flushPending` debounce 5s,
   có listener connectivity (best-effort), kéo incremental theo
   `_syncedAt > checkpoint`, nhánh REST cho Linux dùng đúng REST client ADR-0005.

6. **Lần đầu bật sync cho tài khoản**: nếu cloud TRỐNG và máy đang có bài
   (chưa có checkpoint) → đẩy toàn bộ lên, tránh mất dữ liệu học offline trước
   ngày đăng nhập.

7. **Streak/nhịp học đồng bộ kèm** ở doc `stats` với luật "ngày `lastActiveDate`
   mới hơn thắng; cùng ngày lấy streak lớn hơn" (`LearnByHeartStats.reconcile`).
   Không chạy lại công thức streak trên cloud — tránh 2 nguồn logic.

8. **UI**: icon trạng thái (cloud_queue/cloud_sync/cloud_done/cloud_off) trên
   app bar hub LHB + sheet "Đồng bộ đa thiết bị": Đồng bộ ngay / Kéo toàn bộ từ
   cloud / Đẩy tất cả lên cloud / gợi ý đăng nhập khi chưa có tài khoản.
   Chuỗi mới qua `LearnByHeartL10n` đủ **6 ngữ** (vi/en/hi/zh/zh_TW/si) —
   rule #5: locale ≠ vi không hiện tiếng Việt.

9. **Tách phần thuần logic ra `LearnByHeartMerge`** (không I/O, không Firebase)
   để test offline được: `shouldApplyRemote`, `merge`, `pruneTombstones`,
   `LearnByHeartRemoteRecord.fromFirestoreDoc`.

## Hệ quả

- **Tích cực:** tiến độ thuộc lòng + streak đi theo tài khoản qua thiết bị;
  offline-first giữ nguyên (ghi local tức thời, mạng chỉ là lớp phủ);
  xoá lan đúng nghĩa nhờ bia mộ; Linux vẫn sync được qua REST (ADR-0005);
  0 dependency mới; logic hòa giải test được mà không cần Firebase.
- **Âm / đã chấp nhận:**
  - LWW dựa trên đồng hồ máy (clock skew vẫn là rủi ro đã ghi trong
    `AUDIT-2026-08-21` §4.2 cho vocab — xử lý tương tự khi có quyết định dùng
    server timestamp cho nhánh so sánh).
  - Reset mẫu gốc là hành động CỤC BỘ: hàng đợi pending bị xoá, tombstone giữ
    nguyên ⇒ dữ liệu cloud sẽ quay lại ở lần pull kế tiếp; muốn xoá thật thì
    xoá từng bài (đi qua bia mộ).
  - Linux không có realtime push (REST): pull chạy lúc mở app/bật sync/khi có
    mạng lại; push qua hàng đợi debounce.
  - `_syncedAt` là field kỹ thuật trong doc — đã strip khi decode (không lọt
    vào model).
- **Không đổi:** `vocabulary`/`vocab_meta`, text library, knowledge module
  (vẫn thuộc INTEGRATE-1).

## AT nghiệm thu (2 thiết bị, ~15 phút)

1. Máy A thêm/sửa bài (mạng bật) → máy B mở hub LHB → thấy thay đổi.
2. Máy B đánh giá FSRS 1 bài → máy A mở lại → tiến độ SRS (nextReviewDate,
   streak) khớp.
3. Máy A xoá bài → máy B mở → bài biến mất và **không hồi sinh** sau khi mở
   lại app (bia mộ).
4. Cả 2 offline: cùng sửa 1 bài → vào mạng lần lượt → bản mới hơn thắng
   (ghi nhận kết quả như AUDIT §4).
5. Máy mới (chưa từng sync) đăng nhập → kéo đủ bài + streak; trường hợp cloud
   trống + máy có bài → đẩy toàn bộ lên.
6. Linux: đăng nhập → nút đồng bộ chạy qua REST (log `LHB sync (REST)`), không
   có plugin vẫn hoạt động.

## Bằng chứng máy (CI) — 2026-09-23

- `App Analyze + Locale Test (wide oracle)` run **35922641394** 🟢 — analyze
  toàn app (chỉ ERROR fatal) + rule #5 (chrome không tiếng Việt), commit `8e89954`.
- Cùng workflow run **35923191460** 🟢 — thêm bước mới **"LHB tests"** chạy 4 file
  `test/learn_by_heart*_test.dart`: **47 test xanh**, trong đó **19 test LHB-006**
  (mốc LWW, bia mộ, pending, streak, kho cục bộ). Artifact `app-lhb-test-log`.
- Chuỗi commit: `6c96d0e` (triển khai) → `8e89954` (sửa 6 lỗi analyze) →
  `51b2eff` (đưa test vào oracle + 2 sửa lỗi hòa giải) → `fc1e0d3` (YAML step name).

## Việc còn mở

- **Nghiệm thu thiết bị** theo bảng AT ở trên (2 thiết bị thật + Linux REST) —
  bước duy nhất còn lại; agent trong sandbox không có thiết bị/Firebase thật.
- Cân nhắc đưa quyết định LWW sang `serverTimestamp` khi có ADR chung cho
  vocab (hiện chỉ checkpoint/stats dùng server timestamp).
