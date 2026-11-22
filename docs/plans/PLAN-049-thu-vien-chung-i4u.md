# PLAN-049 — Thư Viện Chung I4U (Great Library): thư viện cộng đồng audio · hình ảnh · từ vựng

> **Trạng thái:** 📋 proposed (chờ owner duyệt → doing). Chưa code.
> **Ngày:** 2026-11-15. **Nguồn:** owner qua agent `arena/a04e4405-in4up`.
> **Nền tảng quyết định:** [`docs/great_library_ideation_v1.md`](../great_library_ideation_v1.md)
> — ideation v1.2, **6/6 quyết định D1–D6 đã LOCKED** (tên gọi, seed, không cần
> đăng nhập để tải, storage pluggable, AI gợi ý BYOK, admin in-app theo uid owner).
> **Liên quan:** ADR-0031 · cards `GLIB-001..008` · tận dụng WORDLIST-TTS-001,
> `vocab_image`, API-001/002 (tầng Server API/BYOK), ADR-0001 (SM-2), rule vàng #5 (i18n).

---

## 1. Mục tiêu

Đưa vào app một màn **Thư Viện Chung I4U** (tên mã `great_library`) nơi:

1. Người dùng **duyệt / xem trước / tải về** các gói học liệu cộng đồng
   (từ vựng, âm thanh, hình ảnh) **không cần đăng nhập** (D3), dùng **offline
   100%** sau khi tải — đúng xương sống offline-first của app.
2. Pack tải về **cắm thẳng vào Studio** tương ứng (Vocab → Memory Garden/SM-2,
   Audio → Audio Library, ImageSet → flashcard minh hoạ), không phải file rời.
3. Người dùng **đóng góp pack của chính mình** (export từ dữ liệu cá nhân hoặc
   soạn mới) → hàng chờ kiểm duyệt → owner duyệt trong **màn admin trong app**
   (D6) → published cho cộng đồng.

**P0 ship gì:** khung pack + catalog + UI duyệt/tải/import + **~22 pack seed do
team soạn** (D2). Chưa mở đóng góp công khai ở P0.

**Không làm (giai đoạn này):** MXH hoá (feed/chat/comment mở), đổi engine
SM-2/audio, đụng `lib/ffi/`, backend server riêng ngoài Firebase/Supabase REST,
bản quyền thương mại, tính năng trả phí.

---

## 2. Khảo sát nội bộ (đã đối chiếu trên tree 2026-11-15)

| Nhu cầu Thư Viện Chung | Hiện trạng trong repo | Kết luận |
|---|---|---|
| Catalog/metadata pack | `lib/services/firestore_rest_client.dart` (`FirestoreRestClient`) + `firebase_rest_auth.dart` | Đủ nền REST; viết `GlCatalogService` mỏng trên đó, KHÔNG thêm SDK |
| Lưu/tải file nhị phân | `lib/services/storage_service.dart` (`StorageService` — Firebase Storage REST) | Đặt sau interface `PackStorageBackend` (ADR-0031 D3) để thêm Supabase sau |
| Auth khi đóng góp / admin | `lib/services/auth_service.dart` | Gate admin = uid của `be.you8778@gmail.com` trong `gl_config/admins` |
| Import audio vào Tab Nghe | `lib/services/audio_import_service.dart`, `audio_library_service.dart` | `PackImportService` gọi lại, không viết lại |
| Transcript/LRC cho AudioPack | `lib/services/lrc_time_parser.dart` | Pack nhúng LRC; preview parse bằng parser sẵn có |
| VocabPack → SRS | `lib/services/vocab_sync_service.dart`, `vocab_batch/vocab_batch_extractor.dart`, Memory Garden (`lib/screens/memory_mode/`) + SM-2 (ADR-0001) | Import = tạo WordEntry mới qua đường vocab hiện có; KHÔNG chạm thuật toán SM-2 |
| Ảnh từ vựng | `lib/features/vocab_image/` | ImageSet cắm vào luồng ảnh minh hoạ sẵn có |
| Sinh audio cho VocabPack | WORDLIST-TTS-001 (đọc Từ+Nghĩa hàng loạt) | Wizard đóng góp chạy TTS bulk on-device trước khi upload |
| AI gợi ý metadata (D5) | `packages/in4up_ai/…/ai_engine_remote.dart` + provider store (API-001/002, BYOK) | Nút "Gợi ý bằng AI" opt-in; tắt mặc định; không auto-publish |
| i18n | 26 ARB × 555 key; rule vàng #5 (T2: hi/zh/zh_TW/si bắt buộc cùng PR) | Toàn bộ chrome màn mới qua ARB; **nội dung pack là user content → không dịch** |
| Web build | `deploy-web.yml` có GitHub Pages | Cổng web của thư viện (share link) để P3, không làm ở P0/P1 |

**Khe hở phải xây mới:** định dạng `.i4upack` + builder/parser/checksum; download
manager có resume; catalog cache offline; màn hình Thư Viện Chung; wizard đóng
góp; màn admin; tooling soạn pack seed (`tool/`).

---

## 3. Phạm vi

### 3.1 Trong phạm vi

- **P0 (seed-only):** GLIB-001 (pack core), GLIB-002 (storage/download),
  GLIB-003 (catalog), GLIB-004 (UI duyệt/xem trước/tải), GLIB-005 (import vào
  Studio), GLIB-008 (seed ~22 pack EN→VI, D2). Admin ở P0 chỉ là **script/đường
  publish nội bộ** trong GLIB-008 (team tự publish), chưa cần màn admin.
- **P1 (mở đóng góp):** GLIB-006 (wizard contribute + AI gợi ý BYOK),
  GLIB-007 (màn admin moderation + Firestore rules siết).
- **P2 (ghi nhận, chưa xếp lịch):** rating 5★/"hữu ích", report + auto-hide
  theo ngưỡng, verified creator, thông báo version mới.

### 3.2 Ngoài phạm vi

- Comment/feed/chat; follow tác giả; chia sẻ link web (P3); ReadingPack/
  DeckPack/PlaylistPack (P3); Cloud Functions auto-mod; đa ngôn ngữ nội dung
  ngoài EN→VI ở seed (D2: ổn định rồi mở rộng VI→EN/Pali→VI).
- Không thêm dependency nặng: ZIP dùng `archive` (kiểm tra pubspec hiện có,
  nếu chưa có thì thêm pure-Dart `archive` — không native), không Firebase SDK.

---

## 4. Kiến trúc tổng thể (chi tiết & phương án đã loại: ADR-0031)

1. **Đơn vị chia sẻ = `.i4upack`** — ZIP gồm `manifest.json` + `data/` + `media/`;
   `sha256` toàn gói + version tăng dần. Không chia sẻ file lẻ.
2. **Catalog = Firestore qua REST sẵn có** — collections `gl_packs`,
   `gl_pack_versions`, `gl_contributions`, `gl_reviews`(P2), `gl_reports`(P2),
   `gl_config/admins`. Read `published` = public; mọi write từ user → `pending`.
3. **Storage pluggable** — `PackStorageBackend` interface; backend 1 = Firebase
   Storage; backend 2 (khi hết quota) = Supabase Storage; manifest ghi
   `storage.backend` nên 2 backend song hành, pack cũ không ảnh hưởng.
4. **Moderation pending-first + admin in-app** — màn duyệt chỉ hiện khi uid ∈
   `gl_config/admins`; Firestore rules là rào chắn thật, UI chỉ là tiện ích.
5. **Tải không cần đăng nhập** — Storage rules cho read public `packs/**`;
   auth chỉ bắt buộc ở contribute/rate/report.

## 5. Work packages

### GLIB-001 — Pack core: model + `.i4upack` builder/parser/validator (P0)
- `lib/features/great_library/models/pack_manifest.dart`: `PackManifest` (field
  như ideation §3.1), `PackType {vocab, audio, image}` (append-only enum),
  parse/serialize, validate (schema version, size limits, license bắt buộc).
- `lib/features/great_library/services/pack_file.dart`: build/đọc `.i4upack`
  (ZIP), tính + verify `sha256`, trích manifest không giải nén media.
- Test thuần: round-trip build→parse; từ chối manifest sai/trùng file; checksum
  lệch → fail; kích thước vượt quota → fail sớm.

### GLIB-002 — `PackStorageBackend` + DownloadManager (P0)
- `lib/features/great_library/services/pack_storage_backend.dart` (interface:
  `put/get/downloadUrl/byteRange`), `firebase_pack_storage.dart` (wrap
  `StorageService`), chừa `supabase_pack_storage.dart` (stub + TODO).
- `pack_download_manager.dart`: hàng đợi tải, resume theo byte-range, retry
  backoff, verify checksum sau tải, cache vị trí file đã tải (metadata local).
- Test thuần: fake backend (byte array), resume ghép đúng byte, checksum fail →
  xoá file rác + báo lỗi.

### GLIB-003 — Catalog service + Firestore schema/rules + cache offline (P0)
- `lib/features/great_library/services/gl_catalog_service.dart`: list/search/
  filter (client-side trên cache), `getPack`, `getVersions`; TTL cache local
  (vài giờ) để giảm read Firestore.
- `firestore.rules` (bổ sung block `gl_*`): read public khi `status==published`;
  create `gl_contributions` cần auth; update status chỉ admin uid (P1 siết).
- `docs/great_library_firestore_schema.md`: schema từng collection + rule mẫu.
- Test thuần: parse document → model; filter/search thuần trên list cache.

### GLIB-004 — UI Thư Viện Chung: browse · preview · tải (P0)
- `lib/features/great_library/ui/`: `great_library_screen.dart` (Nổi bật / Mới /
  Tải nhiều + hàng chủ đề), `pack_search_filter.dart`, `pack_detail_screen.dart`
  (metadata + license + rating placeholder + nút Tải), preview theo loại:
  VocabPack lướt ~20 thẻ + nghe thử TTS/audio kèm; AudioPack nghe thử 60s + xem
  LRC; ImageSet lướt ảnh + caption.
- Entry từ Home (card "Thư Viện Chung") + badge "pack mới".
- i18n: mọi chrome qua ARB × 26 locale (T2 đủ hi/zh/zh_TW/si — rule #5);
  **nội dung pack giữ nguyên nguồn, không dịch**.
- Test: widget test nhẹ (fake catalog) cho list/detail/empty/error state.

### GLIB-005 — `PackImportService`: pack → Studio (P0)
- Route theo `PackType`: Vocab → tạo WordEntry qua đường vocab hiện có (kèm
  audio/ảnh vào `vocab_image`); Audio → `AudioImportService` + lưu LRC;
  ImageSet → kho ảnh flashcard. Import xong hỏi mở Studio tương ứng.
- Lưu `installedPack {packId, version}` local → khi catalog thấy version mới:
  chip "Có bản mới" → update giữ tiến độ SRS (additive, không ghi đè SM-2).
- Test thuần: mapping manifest→tham số import; update additive (mock store).

### GLIB-006 — Wizard đóng góp + AI gợi ý (P1)
- 3 bước: (1) chọn nguồn — từ vocab list/playlist audio của mình (export-as-pack)
  hoặc soạn mới; (2) metadata (nút **"Gợi ý bằng AI"** opt-in BYOK qua
  `AiEngineRemote` → title/mô tả/tags/CEFR đề xuất, user sửa lại); (3) cam kết
  bản quyền + chọn license → build `.i4upack` (VocabPack chạy TTS bulk on-device
  trước) → upload → `gl_contributions` `pending`.
- Màn "Đóng góp của tôi": trạng thái pending/published/rejected + lý do từ chối.
- Quota client-side (50 MB/pack, 10 pack/tháng — §6.2 ideation; số cuối owner duyệt).
- Test thuần: build pack từ vocab store giả; quota counter; AI-off → không gọi
  network (pin bằng fake engine).

### GLIB-007 — Màn admin moderation (P1)
- Gate: đăng nhập → uid ∈ `gl_config/admins` (owner tạo doc 1 lần, uid của
  `be.you8778@gmail.com`) → hiện entry "Duyệt pack". Rules siết: chỉ admin ghi
  `status published/hidden`, đọc contributions, xoá review/pack vi phạm.
- Màn admin: hàng chờ pending → xem trước (tái dùng preview GLIB-004) →
  Duyệt / Từ chối (lý do) / Ẩn; bảng cảnh báo Storage 80% (D4).
- Test thuần: gate logic theo uid; state machine pending→published/rejected.

### GLIB-008 — Seed pipeline P0 (~22 pack, EN→VI) (P0)
- `tool/great_library_seed/`: script đọc bảng từ mở (NGSL/NAWL — ghi attribution),
  ghép nghĩa VI từ từ điển bundle, build VocabPack; script đóng gói AudioPack từ
  LibriVox (public domain, ghi credit) + pháp thoại app sẵn có; ImageSet từ ảnh
  CC0. Audio TTS sinh bằng pipeline app (chạy 1 lần lúc soạn, đóng gói vào pack).
- Script publish nội bộ (admin token owner) thay cho màn admin ở P0.
- Danh sách 22 pack: ideation §9.3 (500 động từ, 120 bất quy tắc, 300 phrasal
  verbs, 4×NGSL chủ đề, tính/trạng từ, collocations, IELTS NAWL; Grimm/Andersen/
  Aesop + graded stories + câu ví dụ Tatoeba + 3 series pháp thoại; 4 ImageSet).
- Kiểm chứng: mọi pack seed parse pass validator GLIB-001 + license đầy đủ.

## 6. UX flows chính

| Flow | Các bước tối đa |
|---|---|
| Tải pack dùng cá nhân | Home → Thư Viện Chung → chọn pack → Xem trước → **Tải về** → **Mở trong Studio** (≤4 chạm sau khi chọn pack) |
| Đóng góp | Thư Viện Chung → Đề xuất pack → 3 bước wizard → Gửi → theo dõi ở "Đóng góp của tôi" |
| Kiểm duyệt (owner) | Đăng nhập owner → entry Duyệt pack hiện → xem trước → Duyệt/Từ chối kèm lý do |

## 7. i18n & rule vàng #5

- Chrome màn mới: key ARB mới × 26 locale; T2 (hi/zh/zh_TW/si) dịch đủ trong
  cùng PR; T3 giữ sàn ratchet (`tool/lang_rollout_report.py`).
- Tên/mô tả **pack** là nội dung cộng đồng → hiển thị nguyên gốc (ngoại lệ
  rule #5 theo đúng mục "không áp dụng: nội dung user").
- Tên tính năng "Thư Viện Chung I4U" là chuỗi chrome → có key riêng, locale ≠ vi
  dùng "I4U Community Library".

## 8. Test & CI

- Test thuần Dart cho GLIB-001/002/003/005/006/007 (parser, checksum, resume,
  quota, state machine, gate) — đúng cổng CI chỉ nhận test thuần.
- Widget test nhẹ GLIB-004. CI: `app_analyze.yml` (analyze + rule #5 + suite
  targeted mới `test/great_library/`).
- Nghiệm thu thiết bị (owner): tải AudioPack ~40 MB có resume khi tắt mạng giữa
  chừng; import VocabPack 500 từ vào Vườn; contribute end-to-end (P1).

## 9. Acceptance Tests (AT)

- **AT1:** Chưa đăng nhập, mở Thư Viện Chung → thấy ≥ 20 pack seed, xem trước
  được, tải VocabPack → từ xuất hiện trong Vườn nhớ, tắt mạng vẫn học được.
- **AT2:** Tải AudioPack đang giữa chừng tắt mạng → bật lại → resume đúng,
  checksum pass, mở trong Tab Nghe kèm transcript.
- **AT3:** Tài khoản thường KHÔNG thấy entry admin; ghi thẳng `status:published`
  qua REST bị rules chặn.
- **AT4 (P1):** Contribute wizard: AI tắt mặc định; bật BYOK → gợi ý metadata
  điền sẵn, user sửa, gửi → pack ở `pending`; owner duyệt → người khác thấy.
- **AT5:** Pack vi phạm bị từ chối → contributor thấy lý do; gửi lại được.
- **AT6:** Locale `en`: toàn bộ chrome Thư Viện Chung tiếng Anh; tên pack seed
  giữ nguyên gốc.

## 10. Rủi ro & giảm thiểu

| Rủi ro | Giảm thiểu |
|---|---|
| Bản quyền audio/ảnh | License bắt buộc + checkbox cam kết; seed chỉ từ public domain/CC/app assets; takedown ≤48h |
| Vượt quota Firebase | Storage pluggable (D4) + cache catalog + cảnh báo 80% + quota upload §6.2 ideation |
| Spam/nội dung xấu | Pending-first, duyệt tay P0/P1; report + auto-hide ở P2 |
| Firestore rules sai → lộ/ghi nhầm | Block rules riêng `gl_*`, test bằng REST tay trước khi mở P1 |
| Độ phức tạp UI mới | Tái dùng preview/reader sẵn có; widget test từ P0 |

## 11. Lịch sử

- 2026-11-15 | created (proposed) | agent `arena/a04e4405-in4up` | PLAN-049 +
  ADR-0031 + 8 card GLIB; toàn bộ quyết định lấy từ ideation v1.2 (D1–D6
  LOCKED). Chờ owner duyệt → doing.
