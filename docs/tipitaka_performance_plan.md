# Tipiṭaka — kế hoạch & kết quả tối ưu tốc độ mở (TIPI-PERF-01)

> Kết luận ngắn: độ trễ "mở Tipiṭaka / mở bài" **không** nằm ở dung lượng DB
> hay ở Flutter, mà ở **số lượng truy vấn lặp lại trên mỗi lần mở màn hình**:
> kiểm tra DB hai lần, dò từng cột bản dịch bằng full scan, và 4 subquery
> tiêu đề sách cho *từng* sách trong *từng* lần vẽ cây mục lục. Đã sửa cả ba,
> cộng thêm prewarm + khung xương (skeleton) để người dùng không phải nhìn
> vòng xoay.

## 1. Đo trước khi sửa (bottleneck thật)

Dựng DB tổng hợp 600.000 đoạn (~323 MB, 120 sách, có `translation_en` +
`translation_vi`, 2 cột ngôn ngữ rỗng) rồi đo bằng SQLite trên desktop; trên
máy ARM/Android các số này thường ×4–8.

| Truy vấn / luồng | Thời gian | Ghi chú |
|---|---|---|
| `SELECT COUNT(*) FROM tipitaka_segments` | 1,4 ms | không phải vấn đề |
| `SELECT 1 … WHERE translation_my <> '' LIMIT 1` (cột rỗng) | **100 ms** | full scan; `info()` gọi cho **từng** cột ngôn ngữ |
| `SELECT 1 … WHERE pali_text <> '' LIMIT 1` | 0,1 ms | dừng ở dòng đầu |
| `getBooksByCollection()` — 4 subquery tiêu đề × 40 sách | **1.139 ms** | mỗi subquery `ORDER BY order_index LIMIT 1` phải **sort toàn bộ** đoạn của sách |
| `_hasOfficialCatalog` (EXISTS) | 0,2 ms | ổn |
| 1 trang đọc 60 đoạn | 7,9 ms | sẽ về ~0 với index `(book_id, order_index, id)` |

Cộng thêm chi phí *kiến trúc* nhìn thấy trong code:

1. `openReady()` **kiểm tra lại DB mỗi lần gọi**: mở read-only → 3 × `COUNT(*)`
   → `PRAGMA table_info` → probe nội dung, rồi mở lại handle thứ hai. Reader gọi
   `openReady()` cho mỗi trang, mỗi lần lưu highlight, mỗi bước TTS.
2. Màn đọc gọi `TipitakaDb.info()` → **đếm toàn bảng + dò 5 cột bản dịch** chỉ
   để lấy *danh sách ngôn ngữ*. Thư viện/tìm kiếm/workspace cũng vậy.
3. Thư viện chờ `openReady()` **xong** mới đọc snapshot cache → mất toàn bộ lợi
   ích của snapshot (mỗi lần mở vẫn phải chờ SQLite).
4. Reader hiển thị `CircularProgressIndicator` toàn màn hình → 300 ms cũng thấy
   như treo.

## 2. Đã sửa

### P1 — Đường mở DB (db_service.dart)

- **Fast path `openReady()`**: ghi nhớ fingerprint `path + size + mtime` của DB
  đã kiểm tra (`_verifiedFingerprint`). Cùng fingerprint ⇒ trả handle đang mở,
  không mở read-only, không probe. Chỉ một `stat()` (~0,1 ms).
- **Probe O(1)**: `_isUsableDatabaseFile` / `_isEmptyAppDatabase` đổi `COUNT(*)`
  → `SELECT 1 … LIMIT 1` (semantics y hệt: "có ít nhất 1 dòng").
- **`fileFingerprint()`** (mới, public): nhận dạng file DB **không mở SQLite**,
  dùng cho snapshot thư viện và các cache bên dưới.
- **`prewarm()`** (mới): mở/kiểm tra DB + cache mục lục + tập ngôn ngữ + tạo
  index trang đọc, chạy **sau frame đầu** khi người dùng vào tab Đọc
  (`read_mode_screen.dart`). Bấm "Tam Tạng" sau đó là mở tức thì.

### P2 — Tập ngôn ngữ & `info()`

- `TipitakaDatabaseInfo` giữ nguyên API; `info()` vẫn trả **số dòng chính xác**
  (COUNT là index-count, không phải table scan) nhưng **không còn dò cột bản
  dịch** — phần đó chuyển sang `availableLanguages(db)`.
- `availableLanguages(db)` (mới): memo theo `(path, importRevision)` + **lưu bền
  theo fingerprint** trong `SharedPreferences` (`tipitaka_perf_cache.dart`), nên
  cold start không tốn full scan nào. Mất cache ⇒ tự tính lại y như cũ.
- Reader / tìm kiếm / workspace / language pack / thư viện chuyển sang
  `availableLanguages()` (chỉ cần danh sách ngôn ngữ).

### P3 — Tiêu đề sách trong cây mục lục

- `getBooksByCollection()`: bỏ câu SQL "4 subquery/sách trong 1 statement".
  Giờ: 1 query lấy sách + tiêu đề **giải một lần cho mỗi sách** và memo
  (`_titlesForBook`). SQL tiêu đề **giữ nguyên từng chữ** nên kết quả không đổi.
- `_hasStructuralTitles()` (mới): nếu DB **không có** dòng tiêu đề cấu trúc
  (`block_type` = book/chapter/heading hoặc marker `rend="…"` thô) thì mọi
  subquery tiêu đề chắc chắn trả `NULL` ⇒ **bỏ hẳn**, không scan sách nào.
  Đây là hình dạng của DB demo và DB đã chuẩn hoá — chính là ca "load chậm".
  Cờ này lưu bền theo fingerprint.
- `getBookById()` dùng chung cache trên (deep-link từ tìm kiếm/"Đọc tiếp").

### P4 — Index cho trang đọc

- Index `idx_segments_book_order (book_id, order_index, id)`:
  - tạo **offline trong lúc import** (`_openImportTarget` + `scripts/import_tipitaka.py`),
  - tạo lazy cho DB cũ **chỉ khi ≤ 250.000 đoạn** (`ensurePerformanceIndexes`)
    — DB lớn hơn thì không bao giờ build index trên đường đọc (sẽ chặn
    connection duy nhất); re-import một pack là có index.
- `PRAGMA optimize` sau khi tạo.

### P5 — Trải nghiệm khi vẫn phải chờ

- **Thư viện**: vẽ cây từ snapshot **trước** khi mở SQLite (fingerprint = 1
  `stat()`), sau đó refresh nền với thanh tiến trình 2 px ở đầu body; cây vẫn
  bấm được. `getCollections` + `getCatalogIndexBooks` + ngôn ngữ chạy song song.
  Snapshot lưu không còn chặn paint. Sách đã tải của node đang mở **không bị
  reset** khi refresh nền (trước đây node đang mở có thể trắng sách).
- **Reader**: thay vòng xoay toàn màn hình bằng **skeleton** đúng bố cục trang
  (tiêu đề sách thật + thanh tiến trình + các dòng chữ mờ), chữ thật hiện ngay
  khi trang đầu về.

## 3. Không đánh đổi những thứ sau

- Không đổi schema DB, không migration phá huỷ, không bảng mới ⇒ DB của người
  dùng cũ vẫn mở đúng.
- Mọi cache đều **keyed by fingerprint** (path+size+mtime). Import luôn cài bằng
  rename nguyên tử ⇒ fingerprint đổi ⇒ cache cũ không thể phục vụ nội dung mới.
- Cache chỉ là **tăng tốc**: lỗi đọc/ghi `SharedPreferences` được nuốt và fallback
  về SQLite (đúng như trước).
- Không cache theo handle "lạ" (test/tool tự mở DB): chỉ cache khi handle thuộc
  `TipitakaDb` — tránh lẫn dữ liệu giữa 2 DB cùng `book_id`.

## 4. Đo lại (kỳ vọng)

| Luồng | Trước | Sau |
|---|---|---|
| Mở thư viện (đã có snapshot) | chờ verify + snapshot + query | **1 `stat()` → paint ngay**, refresh nền |
| Mở thư viện (cold, DB lớn) | verify 2 lần + probe cột | 1 lần verify O(1) + cache ngôn ngữ |
| Mở 1 bộ sách 120 sách | ~1,1 s (desktop) | query sách + memo tiêu đề (bỏ hẳn nếu DB không có tiêu đề cấu trúc) |
| Mở 1 bài đọc | `info()` full scan ×N + 2 handle | cache ngôn ngữ + 1 handle + index trang |
| Trang đọc kế tiếp | sort toàn bộ đoạn của sách | range read trên index |
| Bấm "Tam Tạng" sau khi vào tab Đọc | chờ toàn bộ | prewarm đã xong ⇒ tức thì |

## 5. Kiểm chứng

- `test/tipitaka_open_performance_test.dart` (mới):
  - tiêu đề sách (pali/en/vi/ngôn ngữ động qua `tipitaka_translations`) **khớp**
    kết quả trước khi tối ưu;
  - DB "phẳng" (không tiêu đề cấu trúc) không trả tiêu đề nội dung, vẫn fallback
    `name_vi`/`name_en` đúng thứ tự;
  - `availableLanguages()` memo + `info()` đồng ý + số dòng chính xác;
  - `ensurePerformanceIndexes` tạo đúng index và phân trang vẫn đúng thứ tự;
  - pin tĩnh: probe `EXISTS`, `_verifiedFingerprint`, `fileFingerprint`,
    `prewarm`, `idx_segments_book_order`, và không quay lại câu SQL 1 statement.
- Bộ test Tipiṭaka sẵn có (`catalog_filter`, `demo_purge`, `display_language`,
  `independent_language_import`, `workspace_retention`, …) phải xanh — chúng
  dùng handle tự mở nên không đi qua cache nào ở trên.
- Nghiệm thu thiết bị: DB demo + DB đã import ≥ 1 gói ngôn ngữ; đo
  `mở thư viện`, `mở sách`, `cuộn 5 trang` trên máy thật.

## 6. Việc còn lại (đề xuất)

- Ghi `languages`/`segment_count` **ngay trong DB** (`tipitaka_meta`) lúc import
  để lần cài đầu tiên không phải probe cột rỗng (hiện chỉ tốn 1 lần/pack).
- Cache trang đọc đầu tiên theo sách trong RAM (mở lại 1 sách đã đọc ⇒ 0 truy vấn).
- Nếu canon thật > 250k đoạn: cân nhắc "Tối ưu dữ liệu" trong Quản lý dữ liệu để
  người dùng chủ động build index (kèm cảnh báo thời gian).
