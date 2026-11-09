# PLAN-042 — Pháp thoại từ Drive: nguồn nội dung + tiến độ nghe

> **Trạng thái:** doing — **sóng P1 (DHRM-001) đã có code + test + i18n VÀ ĐÃ
> XANH TRÊN CI** (`2d2cdaa`→`7e3be6b`: analyze 0 error, bước `DHRM-001 tests`,
> toàn bộ suite queue cũ). Còn lại: nghiệm thu thiết bị (AT-4/AT-7 thật) và
> P2–P5 vẫn proposed. Sandbox không có Flutter SDK ⇒ mọi kết luận "chạy được"
> dưới đây đều kèm số run CI (xem §15.5).
> **Nguồn:** người sở hữu (2026-11-03, qua agent `arena/c61e07dd-in4up`) — thư mục
> Drive công khai
> [12. PHÁP THOẠI CÁC NGÀI THIỀN SƯ HỆ THỐNG PA AUK — TIẾNG VIỆT](https://drive.google.com/drive/folders/1naMj6Gr4nWUDqkWpuHV-iq-0d-KZb7k5)
> + bản nháp đặc tả `DharmaTalk` (chuyển lại từ AI Studio).
> **Nền khảo sát:** `arena/c61e07dd-in4up` tại `eabef5a` (2026-11-03). Không có
> Flutter SDK trong sandbox ⇒ mọi số liệu code dưới đây là **đọc mã**, chưa chạy.
> **Card:** `DHRM-001` … `DHRM-004` (KANBAN). **ADR:** 0022.

---

## 0. TL;DR

Bản nháp đặc tả `DharmaTalk` đúng về **ý định sản phẩm** nhưng sai ở **3 điểm kỹ
thuật** sẽ làm hỏng dữ liệu người dùng nếu làm y nguyên:

| Điểm trong bản nháp | Vấn đề thực tế trong repo | Kết luận |
|---|---|---|
| `driveFileId` là khóa chính | Đang phát qua **file cache tạm** (`getTemporaryDirectory()/drive_cache`), vị trí nghe/LRC/lời vàng đều key bằng **path** (đã là vấn đề có thật: PLAN-039 §1.3, ADR-0019 §3). Cache bị Android dọn bất kỳ lúc nào ⇒ `lastPosition` mất. | Khóa = danh tính nội dung (`driveFileId` + `md5(size)` + `modifiedTime`), KHÔNG phải path cache |
| `isCompleted` + `lastPosition` nằm trong `DharmaTalk` | `PlayerProvider.saveCurrentPosition()` chỉ ghi khi > 5 s và ghi theo path (`StorageService.savePosition`) | Tách **tiến độ nghe** thành store riêng, có bản ghi "đã nghe xong" chủ đích |
| "Không tự động gọi STT" | Đúng, nhưng lý do kỹ thuật mạnh hơn: 1 bài 60–90 phút × whisper tiny = rất tốn pin/nhiệt (đã có cảnh báo `qa_heavy_task_thermal_audit.md`) | STT là hành động có chủ đích cho **đoạn đang nghe**, không phải cho cả file |

Ngoài ra bản nháp bỏ sót **dữ liệu thật của Drive**: 7 collection (A–G) gồm cả
**kinh tụng**, **sách nói**, **Ebook/PDF**, **biểu đồ tu tập** — không chỉ pháp
thoại. Mục 3 dưới đây là taxonomy lấy từ chính thư mục đó (đọc công khai ngày
2026-11-03).

**Đề xuất triển khai theo 5 sóng** (mục 11): P1 danh mục + resume trên **audio
đã tải về máy** → P2 Drive import (tải bền vững) → P3 Drive stream → P4 lời vàng
→ P5 STT/trích lục. Không có sóng nào chạm `lib/ffi/` hay `UltraTimeStretch`.

---

## 1. Bối cảnh & đính chính

1. Nội dung Drive là **pháp thoại Phật giáo hệ phái Pa Auk bằng tiếng Việt**
   (đối tượng: thiền sinh, người lớn tuổi, nghe dài, nghe lại nhiều lần) —
   **không** phải tài liệu luyện phát âm/CEFR. Mọi trường `cefrLevel`/`zipf`
   kiểu cũ không áp dụng.
2. Phần kỹ thuật của bản nháp (tái dùng `GoogleDriveBrowser`, quản lý file
   Drive) **vẫn hợp lệ** và nên tái dùng — không xây lại tầng Drive.
3. Yêu cầu người dùng cuối, xếp theo tần suất sử dụng thực tế:
   **nghe tiếp đúng chỗ** > **biết bài nào đã nghe** > **tìm theo vị Thầy/khoá
   thiền** > tra cứu/thích thú phụ (lời vàng, STT).

---

## 2. Hiện trạng code (đọc mã — có dẫn chứng)

### 2.1 Tầng Drive đã có

| Thành phần | Năng lực hiện có | Thiếu cho pháp thoại |
|---|---|---|
| `lib/services/google_drive_service.dart` (438 dòng) | `signIn` (scope `drive.readonly`), `listItems(audioOnly)`, `searchAudio`, `getStreamInfo`, `downloadToCache`, `getCacheSizeMB`/`clearCache` (**chưa UI nào gọi**), breadcrumb | Không lưu chỉ mục; không đọc `modifiedTime`/`md5Checksum`/`audioMediaMetadata`; cache dựa `getTemporaryDirectory()`; mỗi lần mở là gọi API lại |
| `lib/screens/listen_mode/widgets/google_drive_browser.dart` (808 dòng) | Duyệt thư mục, tìm, phát/stream, tải | `_streamFile` nhét token vào **query string** (`&access_token=`); `player.loadSong()` ⇒ mỗi bài 1 queue mới (mất thứ tự series); 13 chuỗi chrome tiếng Việt **hard-code** (rule #5) |
| `AudioLibraryDrawer` | Tab Thiết bị / Drive / YouTube | Không có lối vào "pháp thoại" |

### 2.2 Tầng phát & tiến độ (điểm quyết định)

```
PlayerProvider.loadSong(path, title, artist)        lib/providers/player_provider.dart:461
  └─ startQueue([AudioQueueItem(source: path)])      :495  ← Drive phá queue mỗi bài
PlayerProvider._loadQueueTrack(...)                  :551
  ├─ pause() → saveCurrentPosition() TRƯỚC khi đổi nguồn   :561  (đúng, giữ nguyên)
  ├─ content:// → AudioLibraryChannel.resolveContentToCache :595
  ├─ savedMs = _storage.getSavedPosition(normalizedPath)    :650
  └─ _onQueueLoaded() → RecentAudio.fromLocalFile(source)   :737
PlayerStatsMixin.saveCurrentPosition()               lib/providers/player/player_stats_mixin.dart:61
  └─ chỉ ghi khi position > 5 s, key = currentSongPath
```

Hệ quả trực tiếp: nếu phát Drive bằng file trong `drive_cache/`, thì
`lastPosition`, `SoundMark.audioPath`, `.in4up_lrc/*.lrc`, "Gần đây" đều trỏ vào
một đường dẫn **sẽ biến mất**. Đây không phải giả thuyết: `RecentAudio` đã có
cơ chế `localIdentity` + migrate id (`recent_audio.dart:120`) vì đúng loại lỗi
này, và ADR-0019 §3 đã phải xử lý cho `content://`.

### 2.3 Âm mục / thư viện / i18n (tái dùng được)

- `SoundMark.audioPath + position + kind{quote,custom…}` + `SoundlistProvider` —
  **đã đủ** để làm "lời vàng" mà không cần model mới.
- `AudioLibraryEntry` + `AudioLibraryProvider` + `AudioPlaylist` — đã có
  `language`-ish metadata (`album`/`artist`/`folder`/`favorite`), filter thuần
  (test: `test/audio_library_filters_test.dart`).
- `MemoryItem` (`lib/screens/memory_mode/models/memory_item.dart`) đã có
  `audioPath/audioStart/audioEnd/sourceFile/tags` ⇒ có thể nhận "hạt giống" lời
  vàng **additive**, không phá dữ liệu cũ.
- `lib/knowledge/` (KnowledgeUnit/Evidence) **chưa nối vào app** (chỉ 1 import
  nội bộ ở `grammar`) ⇒ **không** đặt phụ thuộc vào MVA cho sóng P1–P3.

### 2.4 Ghi chú nền tảng

- `google_sign_in` 6.3.0 + `googleapis` 16.0.0 đã trong `pubspec.yaml`. Lock chỉ
  có `_android`, `_ios`, `_web`, `_platform_interface` ⇒ **không có bản Windows/
  Linux** ⇒ tab Drive hiện sẽ lỗi runtime trên desktop; phải chặn bằng
  `Platform.isAndroid || Platform.isIOS` và hiện thông điệp rõ ràng.
- Bản web dùng entrypoint riêng `lib/main_web.dart` ⇒ Drive **không** nằm trong
  phạm vi web.

---

## 3. Dữ liệu thật của thư mục Drive (2026-11-03)

### 3.1 Taxonomy cấp 1 — 7 collection (không phải "danh sách bài giảng")

| # | Collection | Loại nội dung thật | Cần xử lý |
|---|---|---|---|
| A | Kinh tụng truyền thống Pa Auk | **Audio tụng** (Pāḷi) | "Nghe để tụng theo" — tốc độ 1.0x mặc định, không STT tự động |
| B | Sách nói các Ngài Thiền Sư | **Audiobook** (11 bộ) | Cần chương/đoạn liên tục + resume |
| C | Bài giảng – Pháp thoại (đã giảng xong) | **39 series** pháp thoại | Trọng tâm của PLAN-042 |
| D | Pháp thoại đang giảng | 1 series **đang cập nhật** | Cần "có bài mới" (so `modifiedTime`) |
| E | Sách – Ebook | PDF/EPUB | **Ngoài phạm vi** (đã có tab Đọc) — chỉ hiện lối tắt |
| F | Biểu Đồ Tu Tập | Ảnh/PDF | Ngoài phạm vi |
| G | Tài liệu quán bất tịnh | Ảnh/PDF | Ngoài phạm vi |
| — | `Phu luc 14-Dec-2024.csv` | Bảng Album/Title/Artist (286 KB, ~1000 dòng) | **Không dùng** cho P1 (không có `driveFileId`) — nhưng là nguồn đối chiếu tên về sau |

### 3.2 Taxonomy cấp 2 — series

Cấu trúc điển hình (đã kiểm 3 series thật):

```
C. Bài giảng - Pháp thoại ... - Đã giảng xong/
  34. Sayadaw U Kovida Khoá thiền PS 2024 - Tiếng Việt/
      B1 180324 Hướng dẫn Thiền Niệm Hơi Thở .mp3
      B2 Bojjhaṅga Sutta - Kinh Thất Giác Chi P1 - 190324.mp3
      B10 Hỷ giác chi Ân Đức Tăng Bảo - Bojjhaṅga Sutta - Kinh Thất Giác Chi P9 270324.mp3
      …
  21. Sayadaw U Kovida - Giác Chi-Bhojjanga-... 2019/
      01.Satisambhojjhanga Niệm Giác Chi 150919.mp3
      05.Hỷ Giác Chi 1 Ân Đức Phật 121019.mp3
      …
  15. Sayadaw U Janakābhivaṃsa - Chuỗi pháp thoại không hỏi đáp/
      01. A-01. Hướng dẫn Niệm hơi thở căn bản.mp3
      05-06. 5 Quyền - Phần 3-4 (52).mp3      ← một file chứa 2 buổi
      10. 5 quyền - phần cuối(60).mp3          ← "phần cuối", không số
```

⇒ **Thầy giảng nằm ở tên THƯ MỤC**, chủ đề nằm ở **tên FILE**; năm/khoá thiền
nằm ở **tên series**. Một bộ phân tích chỉ đọc tên file sẽ mất 60% metadata.

### 3.3 Phát hiện từ probe trên tên thật

Đã viết `tool/dharma_name_probe.py` + fixture
`test/fixtures/dharma_drive_names.csv` (44 tên thật, có cả tên "bẩn") và chạy:

| # | Phát hiện | Ảnh hưởng thiết kế |
|---|---|---|
| F1 | `B1…B13` **không** khớp `^\d+[.)]`; Drive đang sắp `B10, B11, B12, B13, B2…` (lexicographic) | Bắt buộc **natural sort** + nhận tiền tố `B<n>`; thứ tự hiển thị ≠ thứ tự API trả về |
| F2 | Ngày dạng `ddMMyy` không dấu phân cách: `150919`, `270324`, `201119`, `011119` | Cần validate (1≤d≤31, 1≤m≤12) + cờ `dateConfidence`; **không** hiển thị ngày nếu không chắc |
| F3 | Một tên có thể chứa **range buổi**: `05-06. … Phần 3-4` | Mô hình phải có `episodeStart/episodeEnd`, không phải `episode` đơn |
| F4 | Thời lượng trong tên: `(54 phút)`, `(52)`, `(60)` | Chỉ là **gợi ý**; thời lượng thật lấy từ player/Drive; cấm hiển thị như số liệu tin cậy |
| F5 | Cùng một vị Thầy, nhiều cách viết: `Sayadaw U Revata`/`Reveta`, `Kumārābhivaṃsa`/`Kumurabhivamsa`, `SU Kovida`/`Ngài U Kovida`, `Pa Auk Sayadawgyi`/`Pa Auk Tawya Sayadaw` | Cần **canonical speaker key** (bỏ dấu, lowercase) + bảng alias; nếu không, bộ lọc theo Thầy sẽ vỡ thành 5 mục rác |
| F6 | File rác: `desktop.ini`, `.csv`, `.pdf` trong thư mục audio | Lọc bằng allowlist extension đã có (`_audioExtensions`) |
| F7 | Hậu tố nhà sản xuất: `- end sound` | Cờ `housekeeping`, chuẩn hoá khi hiển thị, **không** ghi đè tên gốc |
| F8 | Chuỗi `En-Vi` bị nhận là `vi` thay vì song ngữ (lỗi thứ tự luật) | Luật ngôn ngữ phải xét **bilingual trước** `vi`; đây chính là lý do phải viết test cho parser |
| F9 | Thứ tự luật cũng quan trọng: xét `ordinal` trước `range` ⇒ `05-06. …` chỉ lấy `05` và để lại `06.` trong tiêu đề (probe bản 1 **đã mắc** lỗi này, đã sửa) | `range` phải xét **trước** `ordinal`; ghi thành test AT-1 |
| F10 | Tách ngày xong vẫn phải **xoá token ngày khỏi tiêu đề** theo đúng định dạng đã bắt (probe bản 1 để `2024-03-18` lọt vào `title`) | Test phải so cả `title`, không chỉ so các trường metadata — "trường đúng nhưng tiêu đề bẩn" vẫn là lỗi người dùng thấy |

> Kết luận: parser là **hàm thuần, có test từ 44 tên thật** — không phải regex
> viết trong widget.

---

## 4. Mô hình dữ liệu đề xuất (đính chính bản nháp `DharmaTalk`)

### 4.1 Nguyên tắc

1. **Nội dung ≠ tiến độ.** `DharmaTalk` là metadata (từ Drive/tên file); tiến
   độ nghe là bản ghi riêng, khóa theo *danh tính nội dung*, để đổi nguồn phát
   (stream ⇄ file đã tải) không làm mất vị trí.
2. **Additive.** Không đổi box Hive cũ (`saved_positions`, `sound_marks`,
   `audio_library`, `audio_playlists`). Chỉ thêm box mới.
3. **Không có "nguồn sự thật thứ hai".** `AudioLibraryEntry` vẫn là nơi player
   lấy `libraryId`; `DharmaTalk` **trỏ** tới `libraryId`/`driveFileId`, không
   chép lại toàn bộ entry.

### 4.2 Model

```dart
// lib/features/dharma/models/dharma_talk.dart
enum DharmaCollection { chanting, audiobook, talkArchive, talkOngoing, other }
enum DharmaLanguage { vi, pali, bilingual, my, en, unknown }

/// Một "buổi" (một file audio) — đơn vị nhỏ nhất có thể phát.
class DharmaEpisode {
  final String episodeKey;   // ổn định: 'drive:<fileId>' | 'local:<audioIdentity>'
  final String? driveFileId; // null nếu đã import về máy và Drive bị ngắt kết nối
  final String title;        // tên hiển thị đã làm sạch (KHÔNG mất tên gốc)
  final String rawName;      // tên gốc — để hiển thị "xem tên gốc"/debug
  final int? episodeStart;   // 'B12' → 12 ; '05-06' → 5
  final int? episodeEnd;     // '05-06' → 6 ; null nếu 1 buổi
  final DateTime? talkDate;  // ddMMyy/yyyyMMdd nếu đọc được
  final DateTime? dateConfidence; // null = đoán được nhưng không chắc
  final int? durationHintMin;     // '(54 phút)' — CHỈ để gợi ý
  final String? libraryId;        // nếu đã import vào thư viện máy
  final int sizeBytes;
  final DateTime? driveModifiedTime;
  final String? contentMd5;       // md5Checksum của Drive (nếu có)
}

/// Một series (thư mục cấp 2) — cấp mà người dùng thực sự "học".
class DharmaSeries {
  final String seriesKey;        // 'drive:<folderId>'
  final String? driveFolderId;
  final String title;            // đã bỏ số thứ tự đầu
  final int? orderIndex;         // '34.' → 34
  final String? speakerKey;      // canonical: 'sayadaw_u_kovida'
  final String? speakerDisplay;  // 'Sayadaw U Kovida'
  final DharmaCollection collection;
  final DharmaLanguage language;
  final int? year;               // 2014, 2024…
  final String? venue;           // 'Đà Lạt', 'Ba Vì', 'PS', 'Nepal'
  final String? topic;           // 'Bojjhaṅga Sutta', 'Parami', 'Thanh tịnh đạo'
  final List<DharmaEpisode> episodes; // sắp theo natural order
  final DateTime? lastSyncedAt;
}

/// Tiến độ — KHÔNG nằm trong model nội dung.
class DharmaProgress {
  final String episodeKey;
  final Duration lastPosition;
  final Duration duration;       // 0 nếu chưa biết
  final bool completedManually;  // người dùng bấm "Đã nghe xong"
  final DateTime lastPlayedAt;
  final int listenSecondsTotal;  // cộng dồn, phục vụ thống kê (không bắt buộc P1)
  bool get isCompleted =>
      completedManually ||
      (duration > Duration.zero && lastPosition >= duration - const Duration(seconds: 30));
}
```

**Vì sao bỏ `final bool isCompleted` khỏi model nội dung** (khác bản nháp): nếu
`isCompleted` nằm trong object metadata thì mỗi lần đồng bộ Drive (ghi đè
metadata) sẽ **xoá** trạng thái người dùng, trừ khi mọi lần sync đều merge cẩn
thận. Tách store ⇒ sync không bao giờ chạm tiến độ.

### 4.3 Lưu trữ

| Box (mới) | Nội dung | Khóa | Ghi chú |
|---|---|---|---|
| `dharma_catalog` | `DharmaSeries` (JSON, gồm episodes) | `seriesKey` | Ghi đè được khi sync — **không** chứa tiến độ |
| `dharma_progress` | `DharmaProgress` | `episodeKey` | Chỉ app ghi; không bao giờ bị sync ghi đè |
| `dharma_settings` | chế độ nghe mặc định (tốc độ, sleep timer, "chỉ audio đã tải") | key | |

`StorageService.initialize()` mở thêm 2–3 box (`Future.wait` hiện có ~16 box —
chi phí mở thêm box rỗng là không đáng kể; cần đo thời gian khởi động trên máy
thật, xem AT-4).

### 4.4 Di trú

1. Lần chạy đầu: không có gì để migrate (box mới).
2. Nếu người dùng **đã** phát file Drive bằng luồng cũ: `RecentAudio` đã có bản
   ghi với `id = local_<md5(path cache)>` và `localPath = /…/drive_cache/<fileId>.mp3`.
   ⇒ Có thể **adopt** vị trí cũ bằng `driveFileId` trích từ tên file cache (tên
   cache = `${item.id}$safeExt`, `google_drive_service.dart:332`). Việc adopt là
   **tuỳ chọn, có xác nhận**, không tự gán (theo ADR-0019 §3: không tự nhận dữ
   liệu cũ chỉ vì trùng tên).

---

## 5. Bộ phân tích metadata (phần khó nhất — phải làm sớm)

`lib/features/dharma/services/dharma_name_parser.dart` — **hàm thuần**, 0 I/O,
test bằng `test/fixtures/dharma_drive_names.csv`.

### 5.1 Luật (thứ tự bắt buộc — F8 cho thấy thứ tự sai là sai kết quả)

```
parseSeries(folderName, collection):
  1. tách số thứ tự đầu:  '^(\d{1,3})[.)]\s*'          → orderIndex
  2. tách hậu tố năm:     '(19|20)\d{2}\s*$'           → year
  3. tách ngôn ngữ (bilingual TRƯỚC vi): 'Song ngữ|En-Vi|En - Vi' → bilingual
                                          'Tiếng Việt|\bVi\b'     → vi
                                          'English'               → en
  4. tách speaker: 'Sayadaw U X' | 'Pa[- ]Auk Sayadawgyi' | 'Sayalay X'
                   | 'SU X' | 'Ngài U X' | 'Pa Auk Tawya Sayadaw'   → speakerDisplay
     ⇒ canonical: bỏ dấu (NFD), lowercase, gộp khoảng trắng, map alias (F5)
  5. tách sutta/topic: token Pāḷi in nghiêng không dấu ('Bojjhaṅga Sutta',
     'Metta Sutta', 'Parami', 'Mangala Sutta') HOẶC cụm sau ' - ' cuối
  6. venue: từ điển nhỏ {'Đà Lạt','Da Lat','Ba Vì','Long Hai','Phước Sơn','PS',
     'Nepal','Hàn Quốc','Tukpok','US'} (cho phép người dùng sửa + lưu)
  7. title = tên đã bỏ (1)(2)(3)(4)(6) — KHÔNG bỏ (5)

parseEpisode(fileName):
  1. bỏ extension (allowlist audio)
  2. range buổi: '^(\d{1,3})\s*-\s*(\d{1,3})\s*[.)]'  → episodeStart/End  (F3)
  3. tiền tố: '^[Bb](\d{1,2})\b' | '^(\d{1,3})\s*[.)\-]'              (F1)
  4. ngày: 8 số (yyyyMMdd) hoặc 6 số (ddMMyy, validate)               (F2)
  5. part: '(Phần|Phan|P)\s*(\d{1,2})' — lấy mốc CUỐI (B12/B13 có 'P1/P2' nội dung)
  6. durationHint: '\((\d{1,3})\s*(?:phút|phut)?\)' ở CUỐI chuỗi, 1..300   (F4)
  7. housekeeping: 'end sound|final|intro|outro' → cờ, giữ tên gốc      (F7)
  8. title = phần còn lại, gộp khoảng trắng, trim
```

### 5.2 Nguyên tắc "đoán an toàn"

- **Không bao giờ** xoá `rawName`; UI có "xem tên gốc".
- Trường đoán được đều có mức tin cậy: `year` (chuỗi ≥ 4 số ở cuối) = chắc;
  `date` ddMMyy = chắc nếu validate qua, ngược lại **bỏ** (không hiển thị).
- `speakerDisplay` sai ⇒ người dùng sửa 1 lần, ghi vào `dharma_speaker_alias`
  (override tay thắng alias máy) — bài học F5.
- **Cấm** suy ra chủ đề từ AI/LLM trong P1 (xem §12).

### 5.3 Sắp xếp

`naturalCompare` tách chuỗi thành (text, number) — tái dùng cho cả
`episodeStart`, `orderIndex`, `B<n>`. Đây là thứ tự **hiển thị**; không phụ
thuộc `orderBy: 'folder, name'` của Drive API.

---

## 6. Luồng phát — thứ tự ưu tiên và lý do

| Sóng | Nguồn phát | Vì sao làm trước/sau | Rủi ro chính |
|---|---|---|---|
| **P1** | Audio **đã có trên máy** (import qua `AudioImportService` → `audio_imports/`) | Tái dùng toàn bộ đường đã được kiểm: path bền vững, `saved_positions` hoạt động, LRC/Âm mục hoạt động, không cần mạng | Chỉ giải quyết được người đã tải sẵn |
| **P2** | **Tải về bền vững** từ Drive (`audio_imports/dharma/<fileId>`) | Đúng mô hình "sách nói": tải 1 lần, nghe offline nhiều lần; `fileId` trong tên ⇒ danh tính ổn định | Dung lượng (1 series có thể > 1 GB); cần chọn series/đơn vị tải |
| **P3** | **Stream** Drive (URL có header `Authorization`) | Cần mạng liên tục; chỉ để "nghe thử trước khi tải" | `just_audio` + redirect 302 của Drive; token hết hạn giữa bài |
| P4 | Lời vàng | Sau khi có phát ổn định | — |
| P5 | STT/trích lục | Tốn pin/nhiệt; chỉ theo yêu cầu | — |

**Quyết định P3 (stream) chi tiết:** phải đổi từ `&access_token=` trong query
sang **HTTP header** — với `just_audio`, dùng `AudioSource.uri(uri, headers: …)`
hoặc `LockCachingAudioSource`; **không** ghi Bearer token vào query
(log/lịch sử trình duyệt/redirect). Nếu `just_audio` không nhận header cho
source hiện tại thì P3 chuyển sang "tải rồi phát" (chấp nhận chờ) — **không**
hạ cấp bảo mật.

**Không đổi**: `_loadQueueTrack` vẫn là nơi duy nhất nạp nguồn; pháp thoại chỉ
tạo `AudioQueueItem` với `source = path bền vững` (P1/P2) hoặc `https://…`
(P3, cần nhánh xử lý riêng vì `saveCurrentPosition` key bằng path ⇒ **phải**
dùng `episodeKey` cho tiến độ, xem §4.3).

---

## 7. UX đề xuất

### 7.1 Điểm vào

- Tab **Nghe** → drawer → tab **Drive** hiện có, thêm chế độ **"Pháp thoại"**
  (mặc định khi mở thư mục được đánh dấu là pháp thoại).
- Thêm **thẻ ở Home** ("Pháp thoại — nghe tiếp") chỉ khi đã có tiến độ > 0
  (không thêm màn trống).

### 7.2 Màn danh mục (mới) — `DharmaLibraryScreen`

```
┌ Pháp thoại ─────────────────────── [⟳] ┐
│ [Nghe tiếp]  [Theo Thầy] [Theo khoá]   │   ← 3 nhóm, mặc định "Nghe tiếp"
│                                         │
│ ▸ Nghe tiếp                             │
│   Sayadaw U Kovida · Giác Chi 2019      │
│   05. Hỷ Giác Chi 1 · 03:12/58:20  ▓▓▒  │   ← resume + progress
│                                         │
│ ▸ Theo Thầy  (chip: tất cả / từng vị)   │
│   Sayadaw U Kovida · 7 series · 1 sẵn   │
│   Pa Auk Sayadawgyi · 5 series          │
└─────────────────────────────────────────┘
```

- **Series → danh sách buổi**: hiện `episodeStart` đã sắp natural, dấu ✓ khi
  `isCompleted`, "đang nghe" khi `isInProgress`; nhãn "Đã tải" / "Trên Drive".
- **Thanh phát**: dùng `AudioQueueItem` + queue của PLAN-039 ⇒ có sẵn
  bài trước/bài sau, "Danh sách đang phát". **Không** tạo trình phát thứ hai.
- Nút **"Đã nghe xong"** (thủ công) + tự đánh dấu khi tới ~95%/30 s cuối.
- Giữ **sleep timer** (đã có) và **tốc độ**; thêm preset pháp thoại
  (`0.8x / 0.9x / 1.0x`) và **nhớ theo series** (người lớn tuổi nghe chậm).
- Chế độ **"Tụng"** cho collection A: không resume tự động, không auto-next,
  hiện lời kinh nếu có file `.lrc`/text đi kèm.

### 7.3 Không làm (để tránh phình)

- Không lịch/streak riêng cho pháp thoại (dùng `learning_activity` chung sau).
- Không tạo màn "tìm kiếm toàn văn" (P5 mới bàn).
- Không tự tải cả collection (chỉ tải theo series/buổi, có thanh tiến trình + huỷ).

---

## 8. Vườn Trí Nhớ — "lời vàng" (P4)

Bản nháp đề xuất "lưu Lời vàng vào Vườn". Khả thi **không cần chờ MVA**:

1. `SoundMark(kind: quote)` + `position` + `note` **đã có** (tên "Câu hay",
   `sound_mark.dart:14`). Trong pháp thoại, nút "Lưu lời vàng" = tạo SoundMark
   quote tại `position` + text người dùng gõ/đọc.
2. "Hạt giống" trong Vườn: `MemoryItem` **đã có** `audioPath/audioStart/audioEnd`
   + `tags` ⇒ thêm 1 factory `MemoryItem.fromDharmaQuote(...)` (additive, không
   đổi schema box), thẻ ôn tập mở lại đúng `episodeKey` + timestamp.
3. Kiến trúc đích (khi `lib/knowledge/` vào app qua INTEGRATE-1) là
   `KnowledgeUnit(kind: note|sentence)` + `EvidenceLocator(timestampStart)` —
   **đã có sẵn trường**, nghĩa là P4 hôm nay không tạo nợ kỹ thuật: cùng dữ
   liệu, chỉ đổi nơi lưu.
4. **Không** đẩy transcript pháp thoại vào Vườn (hàng nghìn dòng ⇒ phá SRS).

---

## 9. i18n (rule #5 — AGENTS.md)

- Toàn bộ chrome mới (≥ 25 chuỗi: "Pháp thoại", "Nghe tiếp", "Theo Thầy",
  "Đã nghe xong", "Lưu lời vàng", "Đã tải", "Trên Drive", "Mất kết nối Drive"…)
  phải qua ARB **hoặc** `uiText()` + English trong
  `tool/legacy_ui_english_overrides.json`, và **dịch đủ** `hi/zh/zh_TW/si`
  (T2 — bắt buộc trong cùng PR).
- **Không** dịch: tên bài giảng, tên Thầy, tên chủ đề Pāḷi, tên file gốc — đây
  là nội dung người dùng.
- Cơ hội dọn nợ: 13 chuỗi tiếng Việt hard-code trong `google_drive_browser.dart`
  (dòng 167, 168, 175, 176, 190, 209, 229, 242, 316, 351, 475, 476, 742) đang vi
  phạm rule #5 — sửa luôn trong card `DHRM-002`.
- Nhãn `AudioSourceX.label` (`audio_library_entry.dart:15`) cũng hard-code vi —
  **không** sửa trong đợt này nếu chưa lượng được phạm vi test (ghi nhận riêng).

---

## 10. Rủi ro & đối sách

| # | Rủi ro | Mức | Đối sách |
|---|---|---|---|
| R1 | **Token/`_account` hết hạn giữa bài**, `DriveApi` ném 401 | Cao | `getStreamInfo`/`downloadToCache` phải refresh + retry **1 lần**, trả lỗi có kiểu (`DriveErrorKind.auth/network/notFound/quota`); UI có nút "Kết nối lại" |
| R2 | Cache `getTemporaryDirectory()` bị Android dọn ⇒ mất vị trí | Cao (đã xảy ra với `file_picker`) | P2 dùng `getApplicationDocumentsDirectory()/audio_imports/dharma` (bền, giống `AudioImportService`), **không** dùng `drive_cache` cho nội dung người dùng nghe dài |
| R3 | **Dung lượng**: series 20 buổi × 60 phút ≈ 500 MB–1,5 GB | Cao | Tải theo **buổi** + "tải cả series" có xác nhận; hiện dung lượng ước tính trước khi tải (`size` từ Drive API); màn "Bộ nhớ pháp thoại" xoá từng series |
| R4 | Drive API quota (1000 req/100 s/user) khi sync 39 series | Trung bình | 1 request `files.list`/folder + `pageSize: 1000`, lưu `pageToken`; cache chỉ mục 7 ngày; sync thủ công có nút ⟳ + "có bài mới" cho collection D |
| R5 | File Drive bị đổi nội dung nhưng giữ `fileId` | Trung bình | Lưu `md5Checksum` + `modifiedTime`; nếu lệch ⇒ hiện "nguồn đã thay đổi" (theo tinh thần `Evidence.verifyAgainst`, AT3) và **không** tự xoá tiến độ |
| R6 | `google_sign_in` không có Windows/Linux | Trung bình | Chặn sớm bằng `Platform.isAndroid || Platform.isIOS`; desktop hiện hướng dẫn "tải file về máy rồi import" (P1 vẫn dùng được) |
| R7 | Tên file có ký tự Pāḷi/tiếng Việt + emoji ⇒ `_getSafeFilePath` copy sang `systemTemp` (`audio_player_service.dart:148`) | Trung bình | Đây là vùng **cấm sửa** (audio realtime/FFI liên quan). Chỉ **đặt tên file tải về bằng ASCII + `fileId`** (`<fileId>.mp3`) để không kích hoạt nhánh sanitize; tên hiển thị lấy từ metadata |
| R8 | Người dùng nghe dở rồi xoá audio đã tải | Trung bình | `episodeKey` độc lập path ⇒ tiến độ còn; UI hiện "Cần tải lại" thay vì "mất dữ liệu" |
| R9 | Parser sai ⇒ lọc theo Thầy rác | Trung bình | Fixture 44 tên thật + test; cho phép sửa tay + "xem tên gốc" (§5.2) |
| R10 | Vi phạm rule #5 | Trung bình | Mục 9 + test locale của CI |

---

## 11. Kế hoạch thi công (sóng)

| Sóng | Card | Nội dung | Phụ thuộc | Ước lượng |
|---|---|---|---|---|
| **P1a** | `DHRM-001` | Model `DharmaSeries/DharmaEpisode/DharmaProgress` + `DharmaNameParser` + `naturalCompare` + box Hive + **test từ fixture thật** | — | 1,5 ngày |
| **P1b** | `DHRM-001` | `DharmaLibraryScreen` (danh mục/buổi) trên **audio đã import**; resume qua `DharmaProgress`; nút "Đã nghe xong"; i18n | P1a | 2 ngày |
| **P2** | `DHRM-002` | Drive: `listItems` trả thêm `md5Checksum/modifiedTime/audioMediaMetadata.durationMillis`; **import bền vững** (`audio_imports/dharma/`); sync chỉ mục vào `dharma_catalog`; sửa 13 chuỗi hard-code; chặn desktop | P1a | 2,5 ngày |
| **P3** | `DHRM-002` | Stream bằng **header** (không token trong URL) + fallback "tải rồi phát"; xử lý R1/R5 | P2 | 1,5 ngày |
| **P4** | `DHRM-003` | "Lời vàng" = `SoundMark(quote)` + `MemoryItem.fromDharmaQuote`; lối vào Vườn + mở lại đúng timestamp | P1b | 1,5 ngày |
| **P5** | `DHRM-004` | STT **theo đoạn đang nghe** (dùng `SttServiceFacade` + VAD có sẵn), lưu LRC cạnh `episodeKey`; cảnh báo pin/nhiệt | P2 | 2 ngày |

### DoD / Acceptance test

| AT | Nội dung | Sóng |
|---|---|---|
| AT-1 | 44 tên thật trong fixture ⇒ parser ra đúng `speakerKey/orderIndex/episodeStart/date` (gồm `B10 < B11 < B2` sai nếu sort lexicographic, `05-06`, `Phần cuối`) | P1a |
| AT-2 | Nghe 01:12:30 của bài 58 phút → kill app → mở lại **đúng** vị trí, kể cả khi audio nằm ở thư mục tải khác | P1b |
| AT-3 | Đổi nguồn stream ⇄ file đã tải **không** mất tiến độ (chứng minh `episodeKey` độc lập path) | P2/P3 |
| AT-4 | Khởi động nguội với 39 series (~400 buổi) trong chỉ mục: thời gian mở màn < 1 s; không block UI | P2 |
| AT-5 | Ngắt mạng giữa bài stream → báo lỗi rõ, giữ vị trí, không crash, không mất queue | P3 |
| AT-6 | Xoá audio đã tải → tiến độ còn, hiện "Cần tải lại" | P2 |
| AT-7 | 360×640: màn danh mục + danh sách buổi không overflow, chữ 1.3× | P1b |
| AT-8 | EN/JA: chrome **không** tiếng Việt; tên bài/Thầy giữ nguyên nguồn | P1b/P2 |
| AT-9 | Không hồi quy queue PLAN-039 & karaoke PLAN-040 (`listen_queue_tests.yml` xanh) | mọi sóng |

### CI

- Thêm bước vào `.github/workflows/app_analyze.yml`:
  `flutter test test/dharma/` (parser + natural sort + progress merge).
- Thêm `lib/features/dharma/**`, `lib/services/google_drive_service.dart`,
  `lib/features/dharma/**` vào **paths** của `listen_queue_tests.yml` để đụng
  vào tầng nghe là chạy lại regression queue.
- Sandbox này **không có Flutter SDK** ⇒ analyze/test phải chạy trên CI (theo
  `docs/skills/ci-red-debugging/SKILL.md`).

---

## 12. Ngoài phạm vi (ghi rõ để không "trôi")

- Ebook/PDF (collection E/F/G) — thuộc tab Đọc.
- OCR/ dịch pháp thoại, tóm tắt bằng LLM, tìm kiếm ngữ nghĩa.
- Sửa `UltraTimeStretch`/`lib/ffi/` (Quy tắc vàng #1).
- Gộp điểm số 3 skill SM-2 (Quy tắc vàng #2).
- Đổi khóa dữ liệu cũ (`saved_positions`, `sound_marks`) sang `episodeKey`
  — chỉ **ghi mới** song song; migration là quyết định riêng có ADR.
- Dùng `Phu luc 14-Dec-2024.csv` làm nguồn (thiếu `driveFileId`).
- Windows/Linux Drive (không có plugin).

---

## 13. Cần người sở hữu chốt (mặc định đã đề xuất)

| # | Câu hỏi | Đề xuất mặc định |
|---|---|---|
| Q1 | Ưu tiên P1 (audio đã có trên máy) hay P2/P3 (Drive trực tiếp)? | **P1 → P2 → P3**. Lý do: đường dữ liệu bền vững đã kiểm, ra giá trị ngay, không phụ thuộc token |
| Q2 | Tải bền vững đặt ở `audio_imports/dharma/` hay thư mục người dùng chọn (SAF)? | `audio_imports/dharma/` (đơn giản, có sẵn, không cần quyền mới); SAF để sau |
| Q3 | Có gộp mục "Pháp thoại" thành **tab thứ 4** của `AudioLibraryDrawer` (hiện 3 tab) hay ở tab Drive? | Tab Drive + chuyển chế độ "Pháp thoại" (giữ 3 tab, không phá test 3 tab hiện có) |
| Q4 | "Đã nghe xong" tự động ở ngưỡng nào? | ≥ 95% **hoặc** còn ≤ 30 s (thống nhất với `RecentAudio.isCompleted` đang dùng −10 s… đề xuất nâng lên 30 s cho bài dài, **không** đổi hành vi file ngắn cũ) |
| Q5 | Có nhớ tốc độ riêng theo series? | Có (0.8–1.0 cho người lớn tuổi), lưu trong `dharma_settings` |
| Q6 | P4 "lời vàng" lưu bằng `MemoryItem` (Vườn hiện tại) hay chờ `KnowledgeUnit`? | **`MemoryItem` additive ngay**; khi INTEGRATE-1 xong thì ánh xạ — trường đã tương thích |

---

## 14. Phụ lục — bằng chứng trong repo

- Fixture: `test/fixtures/dharma_drive_names.csv` (44 tên thật, gồm tên bẩn).
- Probe: `tool/dharma_name_probe.py` — chạy `python3 tool/dharma_name_probe.py
  test/fixtures/dharma_drive_names.csv` để xem metadata đoán được của từng tên.
  - Đã chạy 2026-11-03 với Python 3 (không cần thư viện ngoài): 44/44 tên cho ra
    `title` không rỗng; `05-06` → `range` (không lẫn `06.` vào tiêu đề);
    `B1/B2/B13` → đọc được số buổi; `150919` → `2019-09-15`.
  - Probe **không** phải test CI — nó tồn tại để chốt luật trước khi viết Dart;
    bản Dart (`test/dharma/`) mới là máy bắt (AT-1).
  - Lịch sử sửa probe: v1 mắc F9 (range sau ordinal) và F10 (ngày lọt tiêu đề)
    ⇒ đúng là hai lỗi dễ mắc khi port sang Dart, nên đã ghi thành AT-1.
- Code liên quan: `google_drive_service.dart`, `google_drive_browser.dart`,
  `player_provider.dart` (:461/:495/:551/:650/:737),
  `player_stats_mixin.dart:61`, `audio_library_entry.dart`, `sound_mark.dart`,
  `memory_item.dart`, `recent_audio.dart`.
- ADR liên quan: 0019 (queue + URI/cache), 0013 (hai ảnh — kiểu additive),
  0021 (chrome tab Đọc — mẫu chia nhóm UI), 0022 (ADR của kế hoạch này).

---

## 15. Nhật ký thi công P1 (DHRM-001) — 2026-11-03

### 15.1 File đã tạo

| File | Vai trò |
|---|---|
| `lib/features/dharma/models/dharma_talk.dart` | `DharmaSeries` · `DharmaEpisode` · `DharmaProgress` · enum collection/language/source — JSON round-trip |
| `lib/features/dharma/services/dharma_text.dart` | `foldDiacritics` · `searchKey` · `naturalCompare` (thuần) |
| `lib/features/dharma/services/dharma_name_parser.dart` | Parser tên file/thư mục theo §5; bảng alias vị Thầy; `buildSeries` |
| `lib/features/dharma/services/dharma_scanner.dart` | `scanDharmaFolder` (SAF/máy tính) + `buildDharmaCatalog` (PURE) + `DharmaCatalog` |
| `lib/features/dharma/services/dharma_store.dart` | 3 box Hive: `dharma_catalog` / `dharma_progress` / `dharma_overrides` |
| `lib/features/dharma/services/dharma_provider.dart` | Quét, tiến độ, phát qua `startQueue`, nhóm theo Thầy, override tay |
| `lib/features/dharma/screens/dharma_library_screen.dart` | 3 nhóm + danh sách series/buổi; "Đã nghe xong"; "xem tên gốc" |
| `test/dharma/dharma_name_parser_test.dart` | AT-1: 20+ test trên tên THẬT |
| `test/dharma/dharma_catalog_test.dart` | Lập danh mục + tiến độ (AT-2/AT-3 nền) |

Sửa (nhỏ, có chủ đích): `lib/services/text_device_channel.dart` (nhận
`extensions`, **không đổi** hành vi mặc định của Thư viện đọc),
`lib/services/storage_service.dart` (mở 3 box mới), `lib/main.dart` (đăng ký
provider), `lib/screens/listen_mode/widgets/audio_library_drawer.dart` (tab thứ
4 "Pháp thoại" — 3 tab cũ giữ nguyên index),
`android/.../MainActivity.kt` (**thêm 1 trường** `relativeDir` vào kết quả
`scanTree` để dựng lại series khi quét từ thư mục gốc),
`lib/core/language/priority_ui_overrides.dart` (32 chuỗi chrome × 5 locale),
2 workflow CI.

### 15.2 Lỗi thật phát hiện trong lúc làm (đã sửa — ghi lại vì dễ tái phát)

1. **`(54 phút)` nằm trước `- end sound`.** Xoá hậu tố rác để lại dấu `-` ở
   cuối chuỗi ⇒ regex thời lượng neo `$` **không khớp**. Sửa: xoá hậu tố ⇒ cắt
   `[\s\-–—_]+$` ⇒ mới khớp thời lượng. Test AT-1 khoá lại trường hợp này.
2. **Chủ đề Pāḷi không bao giờ khớp** nếu so trên `searchKey` (dạng `_`) bằng
   chuỗi có dấu cách. Sửa: dựng "haystack" thay `_` → dấu cách rồi so.
3. **`RegExp` phân biệt hoa/thường + `searchKey` đã lowercase** ⇒ nhánh
   `'Tiếng Việt'` chết. Sửa: mọi so khớp trên token lowercase.
4. **Ordinal hai lớp** (`01. A-01. …`) để lại `A-01` trong tiêu đề ⇒ thêm bước
   bỏ mã thứ hai, không đổi số buổi.
5. **`AudioSource`/`TextDeviceChannel.scanTree` là `static`** ⇒ thêm tham số
   `extensions` qua constructor nhỏ thay vì đổi chữ ký static (không phá
   Thư viện đọc/Video).

### 15.3 Cách kiểm chứng khi không có Flutter SDK (bổ sung bằng CI thật, xem 15.5)

- Logic parser được **viết lại bằng Python** (`/tmp`, không commit) và chạy trên
  9 tên file thật khó nhất ⇒ tất cả khớp sau khi sửa (15.2 #1). Bản Dart giữ
  đúng thứ tự luật; test `test/dharma/` là máy bắt chính thức.
- Đã kiểm: mọi `import` tương đối của module mới trỏ tới file **có thật**;
  không import thừa; YAML của 2 workflow đúng thụt lề theo mẫu bước liền kề.
- **ĐÃ kiểm trên CI** (không phải suy đoán): `flutter analyze` 0 error,
  `flutter test test/dharma/` xanh, i18n/locale test xanh, toàn bộ 12 nhóm test
  queue cũ xanh — xem §15.5.
- **CHƯA kiểm (cần máy thật):** build Android với `relativeDir`, hành vi SAF
  thật, 360×640/AT-7, mở màn < 1 s với 39 series (AT-4).

### 15.4 Rủi ro còn mở của P1

| # | Rủi ro | Đối sách |
|---|---|---|
| P1-R1 | `dharma_catalog` ghi lại toàn bộ mỗi lần quét (400 buổi ≈ vài trăm KB JSON) | Chấp nhận ở P1; nếu chậm khởi động (AT-4) thì chuyển sang ghi theo series + `putAll` một lần |
| P1-R2 | Provider đọc vị trí mỗi 10 s khi đang phát | Chỉ ghi khi `_playingEpisodeKey != null` và `duration > 0`; tần suất bằng `saved_positions` hiện có |
| P1-R3 | Người dùng chọn NHẦM thư mục cha (quét cả ổ đĩa) | Giới hạn `maxFiles` 5000 (native cũng có), hiện `error=empty` rõ ràng, cho "quên nguồn" |
| P1-R4 | Buổi đã import thủ công (không qua quét) không có trong catalog | P1 chấp nhận: chỉ hiện gì quét được; nhập tay từng file vẫn dùng tab Thiết bị |

### 15.5 Kết quả CI (bằng chứng, không phải tự khai)

| Run | Commit | Kết quả |
|---|---|---|
| `41645680480` | `1a089e4` (lần đầu) | ❌ **4 lỗi biên dịch thật** — xem 15.6 #1–#4 |
| `41646948044` | `7365f35` | ✅ analyze · ✅ bước `DHRM-001 tests` · ✅ PLAN-039 (`test/listen_queue_widget_test.dart` xanh lại) · ✅ 12 nhóm queue |
| `41667985507` | `7e3be6b` | ✅ analyze · ✅ `DHRM-001 tests` (3 file: parser · catalog · provider) · ✅ PLAN-039 |
| `41667985422` | `7e3be6b` | ✅ android-resolver-compile + toàn bộ `listen_queue_*` |

Bước CI mới (`app_analyze.yml`, id `dharma-tests`) chạy `flutter test test/dharma/`
và **tự bỏ qua** nếu nhánh không có file test (để nhánh cũ không đỏ oan).

### 15.6 Lỗi thật do CI bắt (đã sửa — giữ lại vì dễ tái phát)

1. `DateTime` không có constructor `const` ⇒ **không thể** dùng `kNeverPlayed`
   (`static final`) làm giá trị mặc định của tham số tuỳ chọn. Chọn
   `lastPlayedAt` kiểu `DateTime?` (`null` = chưa từng phát) để giữ `const
   DharmaProgress` cho test.
2. `const Set<String> _venues = {'da lat': 'Đà Lạt', …}` — viết `Set` nhưng nội
   dung là `Map` ⇒ 2 lỗi (gán sai kiểu + `.entries` không tồn tại). Đúng phải là
   `const Map<String, String>`; **và** không được trùng khoá (`'đà lạt'`/`'da
   lat'` phải chọn một — `searchKey` đã bỏ dấu nên chỉ cần bản không dấu).
3. Đổi `TextDeviceChannel.scanTree` từ `static` → instance là **thay đổi phá vỡ
   hợp đồng**: `lib/providers/text_device_provider.dart` còn gọi kiểu static ⇒
   `static_access_to_instance_member`. Đã sửa call site; bài học: khi đổi
   static→instance phải `grep` hết call site TRƯỚC khi push.
4. Hai test AT-1 do **tôi viết sai kỳ vọng**, không phải code sai:
   (a) đòi `searchKey('Reveta') == searchKey('Revata')` — bỏ dấu không đổi được
   phụ âm, việc đó là của bảng alias; (b) coi `58/60 phút` là "đã xong" trong
   khi ngưỡng là ≥95% **hoặc** còn ≤30 s ⇒ phải dùng `59:45/60:00`.
   ⇒ Test cũng là code: kỳ vọng sai làm đỏ CI y như bug thật.

### 15.7 Vì sao "check xanh" mà GitHub vẫn báo xung đột khi *Rebase and merge*

Ba nguyên nhân khác nhau, đã gặp lần lượt — đừng nhầm cái này với cái kia:

1. **Sai base.** Nhánh này xếp trên `arena/01a0251e-in4up`, **không** phải
   `main`. Mở PR với base `main` ⇒ diff 1192 file + `CONFLICTING` ngay, dù code
   không sai. Đúng: `--base arena/01a0251e-in4up` (như PR #128, #96).
2. **Commit merge trong PR.** *Rebase and merge* từ chối (`rebaseable = false`)
   nếu head chứa merge commit. Lần đầu tôi `git merge` base vào nhánh ⇒ phải
   thay bằng `git rebase`; hiện `git log --merges base..HEAD` = **0**.
3. **Base trôi sau khi đã rebase.** Đây là cái khó thấy nhất: base nhận thêm
   commit (`6907250` → `5a1613f2`, 7 commit) nên 3 file base cũng sửa bị lệch
   lại ⇒ GitHub tính conflict **tại thời điểm bạn bấm nút**, không phải lúc bạn
   rebase. Checks vẫn xanh vì chúng chạy trên **merge ref cũ**, hoàn toàn không
   chứng minh rebase được.

   ⇒ Trước khi bấm: `git fetch && git merge-tree --write-tree --name-only HEAD origin/<base>`
   — liệt kê đúng file sẽ xung đột, khỏi đoán.

**Xung đột thật ở vòng này (đã giải, giữ cả hai phía):**

| File | Base làm gì | Tôi làm gì | Cách giải |
|---|---|---|---|
| `lib/services/text_device_channel.dart` | Thêm `extensions` vào **static** `scanTree` | Đổi `scanTree` thành **instance** + field `extensions` | **Bỏ cách của tôi**, dùng static của base — ít xâm lấn hơn, không phá call site nào |
| `lib/core/language/priority_ui_overrides.dart` | Thêm khoá M4U-IMPORT-002 (model import) | Thêm 30 khoá pháp thoại | Ghép cả hai; kiểm 1050 khoá, 0 trùng, ngoặc cân |

Bài học: khi mình sửa một hàm **dùng chung** (`TextDeviceChannel` phục vụ cả Thư
viện đọc và Video) mà base cũng vừa sửa, ưu tiên **cách ít xâm lấn hơn** — kể cả
khi cách của mình "sạch" hơn về mặt thiết kế. Ở đây cách của base thắng vì nó
không đổi chữ ký static nào, nên `text_device_provider.dart` không phải sửa.
