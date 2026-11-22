# THƯ VIỆN CHUNG I4U — Ideation v1.1 (tên mã: GREAT LIBRARY)

> Trạng thái: **IDEATION v1.1** — 5/6 quyết định đã LOCKED (2026-11-15), còn D2 chờ chốt.
> Ý tưởng gốc (owner): một thư viện tổng hợp — **file âm thanh, hình ảnh, từ vựng**
> (động từ thông dụng, …) — cộng đồng dùng app có thể **xem, tải về dùng cá nhân**,
> và chính họ cũng có thể **đề xuất nội dung lên cho người khác**.
>
> Tài liệu này là bản brainstorm để owner duyệt hướng; khi chốt sẽ tách thành
> PLAN + ADR theo quy ước `docs/project/PLAN.md` và `docs/adr/`.

---

## 0. Quyết định đã chốt (owner, 2026-11-15)

| # | Quyết định | Trạng thái |
|---|---|---|
| **D1** | Tên chính thức: **Thư Viện Chung I4U** (tên mã kỹ thuật: `great_library`) | ✅ LOCKED |
| **D2** | Pack seed P0: **trộn cả 3 nguồn** (tự soạn bằng pipeline app + tài nguyên app ship sẵn + public domain/CC). Ưu tiên **EN→VI trước**; khi ổn định, kế thừa mở rộng VI→EN / Pali→VI nếu khả thi | ✅ LOCKED |
| **D3** | **Tải pack KHÔNG cần đăng nhập**; chỉ yêu cầu tài khoản khi *đóng góp / đánh giá / báo cáo* | ✅ LOCKED |
| **D4** | Storage **pluggable**: Firebase Storage làm backend đầu; trừu tượng hoá `PackStorageBackend` để thêm **Supabase Storage** (hoặc khác) khi Firebase hết dung lượng. Quota: con số đề xuất ở §6.2 (owner duyệt/đổi sau) | ✅ LOCKED hướng |
| **D5** | **AI gợi ý metadata/tags** lúc soạn pack: ĐƯỢC — opt-in, BYOK đúng triết lý app | ✅ LOCKED |
| **D6** | Kiểm duyệt: **màn admin trong app**, chỉ hiện khi đăng nhập tài khoản owner `be.you8778@gmail.com` | ✅ LOCKED |

---

## 1. Tầm nhìn một câu

> **"Một thư viện sống trong In4Up, do chính cộng đồng người học góp lên —
> ai cũng lấy về để học, ai cũng có thể gieo một hạt giống cho người khác."**

Điểm khác biệt so với các kho chia sẻ ngoài kia: nội dung **sinh ra là để học sâu
(deep study)** — mọi pack tải về **cắm thẳng vào các Studio của app** (Listen /
Read / Vocab / Memory Garden), không phải file rời phải tự import.

---

## 2. Định vị trong app

- Một tab/màn mới: **Thư Viện Chung I4U** (tên mã: `great_library`). Entry từ Home + quick action.
- Tôn chỉ xuyên suốt (khớp triết lý app):
  1. **Offline-first** — catalog duyệt online, nhưng pack đã tải dùng 100% offline.
  2. **Riêng tư** — không bắt đăng nhập để *xem/tải* pack công khai được duyệt;
     chỉ yêu cầu tài khoản khi *đóng góp / đánh giá / báo cáo*.
  3. **Chất > lượng** — duyệt tay giai đoạn đầu, seed bởi đội dự án.

## 3. Mô hình nội dung: đơn vị chia sẻ là "PACK"

Thay vì chia sẻ file lẻ, mọi thứ gói trong **Pack** — dễ version, dễ kiểm duyệt,
dễ import ngược vào app.

| Loại Pack (giai đoạn đầu) | Nội dung | Import vào đâu trong app |
|---|---|---|
| **VocabPack** | JSON từ vựng (từ, nghĩa, ví dụ, IPA, POS, CEFR) + audio phát âm (sinh bằng pipeline TTS-bulk sẵn có) + ảnh minh hoạ (spec vocab-2-images) | Vocab / Memory Garden |
| **AudioPack** | File audio + transcript/LRC (đã có parser LRC) + metadata chương | Audio Library (Listen) |
| **ImageSet** | Ảnh theo chủ đề kèm caption/song ngữ, đóng gói gọn | Flashcard / minh hoạ từ vựng |

Mở rộng Phase sau: **ReadingPack** (văn bản + dịch), **DeckPack** (SRS sẵn lịch),
**PlaylistPack** (pháp thoại/series theo thứ tự), **DictPack** (bảng tra mini).

### 3.1 Metadata chuẩn của một Pack (manifest)

```json
{
  "id": "pack_01JAB…",
  "type": "vocab | audio | image",
  "title": "500 động từ thông dụng nhất (A1–B1)",
  "description": "…",
  "srcLang": "en", "dstLang": "vi",
  "tags": ["verbs", "cefr-a2", "daily-life"],
  "level": "A1|A2|B1|B2|C1|C2|mixed",
  "author": {"uid": "…", "displayName": "…", "verified": true},
  "license": "cc-by | cc0 | cc-by-nc | self-made | permission-granted",
  "version": 3,
  "sha256": "…", "sizeBytes": 4821133,
  "stats": {"downloads": 1280, "rating": 4.6, "ratings": 210},
  "status": "published | pending | rejected | hidden",
  "createdAt": "…", "updatedAt": "…"
}
```

### 3.2 Định dạng file gói: `.i4upack`

- ZIP: `manifest.json` + `media/` + `data/`. Có `sha256` toàn cục + theo file lớn.
- App hỗ trợ **export pack từ dữ liệu cá nhân** (vocab list của mình, playlist audio
  của mình) → chính là bước đầu của "đề xuất lên cho người khác" (xem §5.3).

---

## 4. Trải nghiệm người dùng (UX)

### 4.1 Khám phá (Browse)
- Trang chủ thư viện: **Nổi bật tuần** (staff-pick), **Mới nhất**, **Tải nhiều**,
  hàng theo chủ đề (Động từ, Phrasal verbs, IELTS, Pháp thoại, Truyện song ngữ…).
- Tìm kiếm + bộ lọc: loại pack · ngôn ngữ nguồn/đích · CEFR · tag · có/không audio.

### 4.2 Xem trước (Preview) — bắt buộc trước khi tải
- VocabPack: lướt thử ~20 thẻ, nghe thử audio, xem ảnh minh hoạ.
- AudioPack: nghe thử 60s + xem đoạn transcript.
- Hiện rõ: dung lượng, giấy phép, tác giả, số lượt tải, rating.

### 4.3 Tải về & dùng cá nhân
- **Một chạm** → tải `.i4upack` (resume được, verify checksum) → **Import vào Studio
  tương ứng**. Tận dụng pipeline import sẵn có (`audio_library_service`,
  `text_library_service`, vocab store).
- Cài "Theo dõi pack" → khi tác giả ra **version mới**, app báo có update (diff nhẹ).

### 4.4 Đóng góp (Contribute)
- Nút **"Đề xuất pack"** từ 2 nguồn:
  a. **Từ dữ liệu sẵn có của mình** (chọn vocab list / playlist audio → Export-as-Pack);
  b. **Soạn mới** (wizard 3 bước: nội dung → metadata → cam kết bản quyền).
- Vocab: app chạy **TTS bulk on-device** để sinh audio phát âm trước khi up → pack
  đồng nhất chất lượng, giảm tải server.
- Sau upload: trạng thái `pending` → màn **"Đóng góp của tôi"** theo dõi
  pending/published/rejected + lý do từ chối để sửa gửi lại.

### 4.5 Tương tác xã hội (nhẹ, có kiểm soát)
- Phase 2+: rating 5★ + "Hữu ích", **báo cáo vi phạm** (report), comment ngắn.
- Không feed, không chat mở — tránh biến thành MXH, giữ đúng chất "thư viện".

---

## 5. Kiểm duyệt & chất lượng (phần sống còn)

### 5.1 Ba lớp phòng vệ
1. **Tự động (lúc upload):** chặn định dạng/kích thước sai, scan từ khoá cấm,
   kiểm tra manifest hợp lệ, giới hạn quota (gợi ý ≤ 50 MB/pack, ≤ N pack/tháng/tài khoản).
2. **Con người (giai đoạn đầu):** mọi pack qua **hàng chờ moderation** —
   owner/moderator duyệt trước khi `published`. Lý do: cộng đồng còn nhỏ, 1 người
   duyệt vẫn gánh được; tránh rủi ro bản quyền/nội dung xấu ngay từ đầu.
3. **Cộng đồng (Phase 2+):** report ≥ ngưỡng → pack tự `hidden` chờ xem lại;
   moderator có dashboard đơn giản (web nhỏ hoặc màn admin trong app).

### 5.2 Bản quyền (copyright) — quyết định sớm
- Mỗi pack bắt buộc chọn **license** + checkbox "Tôi có quyền chia sẻ nội dung này".
- Gợi ý ưu tiên: nội dung **tự soạn**, CC0/CC-BY/CC-BY-NC, pháp thoại có phép chia sẻ.
- Cơ chế **takedown** đơn giản: email/form báo cáo bản quyền → ẩn trong 48h.
- Audio nhạc/phim có bản quyền thương mại: **chặn ở lớp tự động** (nhận diện cơ bản
  + quy định rõ trong hướng dẫn đóng góp).

### 5.3 Uy tín người đóng góp
- Badge **"Tác giả đã kiểm chứng"** (verified creator) cho người có ≥ 3 pack chất lượng.
- Trang hồ sơ tác giả tối giản: tên, các pack, tổng lượt tải.

---

## 6. Kiến trúc kỹ thuật (tận dụng tối đa những gì đã có)

| Khối | Dùng lại | Viết mới |
|---|---|---|
| Catalog & metadata | `FirestoreRestClient` (đã có) | Collections `gl_packs`, `gl_pack_versions`, `gl_reviews`, `gl_reports`, `gl_contributions` + Firestore rules (read public cho `published`, write → pending) |
| Lưu file nhị phân | `StorageService` (Firebase Storage REST) | **Interface `PackStorageBackend` pluggable** (D4) — xem §6.1; path `packs/{id}/{version}.i4upack`, lifecycle rule dọn version cũ |
| Auth (khi contribute) | `AuthService` / `FirebaseRestAuth` | — |
| Sinh audio VocabPack | pipeline **wordlist TTS bulk** | Bọc thành bước "Prepare pack" on-device |
| Import vào Studio | `audio_library_service`, `text_library_service`, vocab store/SM-2 | `PackImportService` mỏng: giải nén → validate → route theo `type` |
| Cache/offline | storage local hiện có | Catalog cache + download queue (resume, retry, checksum) |
| i18n | 26 ARB catalogues | Key mới cho toàn bộ màn Great Library (theo rule #5) |

**Nguyên tắc:** client chỉ đọc/qua REST (đúng chất app, không SDK nặng); logic kiểm
duyệt đặt ở **màn admin trong app** (D6) thay vì Cloud Functions ở giai đoạn đầu
→ chi phí ≈ 0, vận hành đơn giản. Khi cộng đồng lớn, cân nhắc Cloud
Functions/Genkit cho auto-mod + thông báo.

### 6.1 Storage pluggable (D4)

- App **không gọi Firebase Storage trực tiếp từ UI** — mọi thao tác pack đi qua
  interface `PackStorageBackend` (upload/download theo byte-range, resume, lấy URL).
- Backend đầu tiên: **Firebase Storage** (đã có REST client sẵn). Khi gần hết
  dung lượng: thêm **Supabase Storage** làm backend thứ hai — pack mới ghi sang
  Supabase, pack cũ vẫn đọc từ Firebase, song hành không gián đoạn.
- Manifest + catalog (Firestore) lưu rõ `storage.backend` + `storage.path`
  → đổi/thêm backend không ảnh hưởng pack đã phát hành.

### 6.2 Quota đề xuất (D4 — chờ owner duyệt con số)

| Mục | Đề xuất | Ghi chú |
|---|---|---|
| Dung lượng / pack | ≤ **50 MB** | AudioPack dài (pháp thoại) cho nâng tới **200 MB** qua cờ moderator |
| Số pack đóng góp | ≤ **10 pack/tháng/tài khoản** | Verified creator có thể nâng |
| Tổng upload | ≤ **200 MB/tháng/tài khoản** | Chống spam tốn quota |
| Cảnh báo vận hành | App báo owner khi Storage đạt **80%** | Kích hoạt backend dự phòng (Supabase) |

### 6.3 Cổng admin (D6)

- Owner đăng nhập Firebase Auth bằng `be.you8778@gmail.com` → app resolve **uid**
  → kiểm tra uid trong doc `gl_config/admins` (owner tạo 1 lần) → hiện entry
  **"Duyệt pack"** trong Thư Viện Chung. Tài khoản khác không bao giờ thấy màn này.
- **Firestore rules mới là rào chắn thật** (UI ẩn chỉ là tiện ích): chỉ uid trong
  admin list được (a) ghi `status: published/hidden`, (b) đọc `gl_contributions`,
  (c) xoá pack/review vi phạm.
- Màn admin trong app: hàng chờ `pending` → xem trước pack → Duyệt / Từ chối
  (kèm lý do gửi contributor) / Ẩn; tab báo cáo (Phase 2).

### 6.4 AI gợi ý metadata (D5)

- Trong wizard soạn pack: nút **"Gợi ý bằng AI"** (opt-in, **BYOK** — dùng tầng
  `AiEngineRemote` đã có: Gemini/Groq/OpenAI…). AI đề xuất: title, mô tả, tags,
  CEFR ước lượng, ngôn ngữ nguồn/đích. Người soạn **xem & sửa trước khi gửi** —
  AI không tự publish. Mặc định TẮT, tôn trọng triết lý offline-first.

**Chi phí Firebase:** pack public đọc nhiều → cân nhắc cache catalog on-device
(TTL vài giờ) và CDN cho file pack; ước lượng quota theo số user trước khi mở upload.

---

## 7. Gamification nhẹ (đúng chất app)

- Điểm **"gieo hạt"🌱**: +điểm khi pack được duyệt, khi có lượt tải/rating tốt.
- Bảng **"Nhà góp vườn"** theo tháng; badge trên hồ sơ.
- Không streak ép, không bảng xếp hạng tiêu cực — khuyến khích cho đi (dana) hơn ganh đua.

---

## 8. Lộ trình đề xuất (Roadmap)

| Phase | Nội dung | Điều kiện mở cửa |
|---|---|---|
| **P0 — Seed (curated-only)** | UI Browse/Preview/Download/Import; ~20–50 pack **do team tự soạn** (500 động từ, 1000 từ A1–B2, bộ pháp thoại có phép, ảnh chủ đề). Chưa mở upload. | Release khi import 3 loại pack vào Studio hoạt động offline 100% |
| **P1 — Mở đóng góp** | Wizard Export-as-Pack + upload → moderation queue; màn "Đóng góp của tôi"; màn admin duyệt. | Mở cho nhóm nhỏ (beta 20–50 người) trước, rồi public |
| **P2 — Tương tác & tự động** | Rating, report + auto-hide, verified creator, thông báo version mới | Khi ≥ ~200 pack published |
| **P3 — Mở rộng** | ReadingPack/DeckPack/PlaylistPack, chia sẻ link web, gợi ý bằng AI (opt-in BYOK), API mở | Sau audit cộng đồng |

---

## 9. Rủi ro & câu hỏi mở

**Rủi ro:** bản quyền audio/ảnh; chi phí moderation; vượt quota Firebase (đã có
lối thoát D4 — Supabase); spam/nội dung xấu; trẻ em dùng chung (cần điều khoản
đơn giản + nút report dễ thấy).

### 9.1 Câu hỏi đã chốt

D1, D3, D4, D5, D6 — xem bảng §0.

### 9.2 D2 — "Pack seed" là gì & chọn nguồn nào? *(giải thích chi tiết)*

**"Pack seed" = lô pack đầu tiên do chính mình soạn sẵn**, để ngày mở cửa thư
viện không bị trống trơn (người dùng đầu tiên vào mà thấy rỗng sẽ bỏ đi ngay,
và cũng chưa ai đóng góp cho một thư viện chưa có gì). Cần khoảng **20–50 pack**
trước khi release P0. Ba nguồn lấy nội dung seed (có thể **trộn lẫn**):

| Nguồn | Làm thế nào | Ví dụ pack | Điểm mạnh / yếu |
|---|---|---|---|
| **a) Tự soạn từ dữ liệu mở + pipeline sẵn có trong app** | Lấy bảng từ vựng mở (NGSL/NAWL — free cho giáo dục), ghép nghĩa Việt từ từ điển app đang bundle, sinh audio bằng **TTS bulk**, gắn ảnh | "500 động từ thông dụng A1–B1", "800 từ IELTS theo chủ đề" | ✅ Chủ động 100%, đồng nhất chất lượng · ⏱️ tốn công biên soạn |
| **b) Tài nguyên app đã ship sẵn** | Đóng gói audio/pháp thoại/Tipiṭaka mà app đang phát hành (đã có quyền dùng) | "Pháp thoại — series ngắn có transcript" | ✅ Nhanh nhất, sẵn quyền · Chỉ bao nhiêu đó nội dung |
| **c) Nguồn public domain / CC mở** | LibriVox (audio truyện public domain), Tatoeba (câu ví dụ CC-BY) — ghi credit, không cần xin phép riêng | "Truyện cổ Grimm — audio + text song ngữ" | ✅ Kho lớn, hợp pháp · Cần chọn lọc + convert định dạng |

**Và "ngôn ngữ ưu tiên" nghĩa là:** pack đầu tiên phục vụ cặp ngôn ngữ nào —
**EN→VI** (người Việt học Anh — đông nhất?), **VI→EN** (người nước ngoài học Việt),
hay **Pali→VI** (đặc sản Phật pháp của app)? Làm trước 1 hướng cho gọn, hay đi
song song?

> **→ Quyết định D2 (LOCKED 2026-11-15):**
> - Nguồn: **trộn cả 3** (a + b + c) — tự soạn bằng pipeline app, đóng gói tài
>   nguyên app ship sẵn, và bổ sung public domain/CC (LibriVox, Tatoeba).
> - Ngôn ngữ: **EN→VI trước**; khi ổn định, kế thừa hạ tầng để mở rộng VI→EN /
>   Pali→VI nếu khả thi.

### 9.3 Danh sách pack seed P0 đề xuất (~22 pack, EN→VI)

**VocabPack (~10 pack)** — soạn bằng pipeline: bảng từ mở + nghĩa Việt từ từ
điển bundle + TTS bulk + ảnh minh hoạ:

| # | Pack | Trình độ | Nguồn |
|---|---|---|---|
| 1 | 500 động từ thông dụng nhất | A1–B1 | NGSL + TTS bulk |
| 2 | 120 động từ bất quy tắc (V1/V2/V3) | A2–B1 | Tự soạn |
| 3 | 300 phrasal verbs thông dụng | B1–B2 | Tự soạn |
| 4–7 | 1000 từ NGSL theo chủ đề (4 pack: gia đình & ăn uống · học tập & công việc · du lịch & giao thông · cảm xúc & xã hội) | A1–A2 | NGSL |
| 8 | Tính từ & trạng từ miêu tả | A2–B1 | NGSL |
| 9 | Collocations thông dụng | B1–B2 | Tự soạn |
| 10 | IELTS Academic Wordlist theo chủ đề | B2–C1 | NAWL |

**AudioPack (~8 pack):**

| # | Pack | Nguồn |
|---|---|---|
| 11–13 | Truyện cổ Grimm / Andersen / Aesop — audio + text | LibriVox (public domain) |
| 14 | Truyện ngắn trình độ A2–B1 (graded) | LibriVox + tự tuyển |
| 15 | Câu ví dụ song ngữ theo chủ đề (audio TTS) | Tatoeba (CC-BY) + TTS bulk |
| 16–18 | Pháp thoại ngắn có transcript (3 series) | Tài nguyên app ship sẵn (b) |

**ImageSet (~4 pack):**

| # | Pack | Nguồn |
|---|---|---|
| 19 | Đồ vật trong nhà (100 ảnh, caption song ngữ) | Ảnh mở (CC0) + tự caption |
| 20 | Động vật & thiên nhiên | CC0 |
| 21 | Hoạt động hằng ngày (minh hoạ động từ) | CC0 |
| 22 | Ảnh minh hoạ bổ trợ VocabPack 1–8 | CC0, gắn theo từ |

---

## 10. Vì sao ý tưởng này hợp In4Up

- App đã có **đủ phần "dùng cá nhân"** (import, vocab, audio library, TTS bulk,
  LRC parser) → đầu "tải về dùng" gần như chỉ cần nối ống, không xây lại.
- **Offline-first** làm thư viện khác biệt hẳn kho online: tải về là của bạn, học
  không cần mạng — đúng người dùng mục tiêu (học sâu, tu tập, nơi mạng yếu).
- Vòng xoắn: người học giỏi → đóng góp pack → người mới có tài nguyên tốt →
  học giỏi → góp tiếp. Thư viện là **động cơ tăng trưởng cộng đồng** của app.
