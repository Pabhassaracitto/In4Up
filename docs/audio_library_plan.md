# 📚 KẾ HOẠCH TRIỂN KHAI — PHỤ LỤC A: THƯ VIỆN ÂM THANH (Audio Library)

> **Bối cảnh:** Phụ lục A của `docs/handoff_soundlist_v1.md` — vấn đề "mở file âm thanh khó" (phải điều hướng sâu qua FilePicker từng lần, không quét, không chỉ mục, không cấu hình thư mục).
> **Mục tiêu:** Âm thanh "có mặt" trong app một cách có tổ chức — quét được, tìm được, có địa chỉ ổn định — làm nền cho Soundlist (điểm/chương/đoạn đều key bằng `audioPath`).
> **Ràng buộc:** ZERO dependency mới (file_picker 11.0.2 đã có; MediaStore/SAF qua MethodChannel tự viết trong `MainActivity.kt` đã có sẵn). Không đổi tên box Hive. Offline-first.
> **Trạng thái:** Kế hoạch — CHƯA code. Chờ nghiệm thu tay Soundlist + chốt của Hội đồng.

---

## 1. Chẩn đoán hiện trạng (đã đọc code — xác minh)

| Thành phần | Hiện trạng |
|---|---|
| `ListenLibraryScreen` | Chỉ hiển thị **RecentAudio** (30 file gần đây, SharedPreferences) — không quét thư viện |
| Mở file mới | `FilePicker.pickFiles` → điều hướng sâu thủ công từng lần |
| `QuickAudioSheet` | Chỉ 5 file recent |
| `RecentAudioService` | 30 item, SharedPreferences, có `addOrUpdate`/`updatePosition` |
| `PlayerProvider` | Lưu `lastAudioPath` (1 file) |
| Android manifest | **Đã có sẵn** `READ_MEDIA_AUDIO`, `READ_EXTERNAL_STORAGE`, `READ_MEDIA_IMAGES/VIDEO` |
| Android native | `android/app/src/main/kotlin/com/in2up/MainActivity.kt` — sẵn để thêm MethodChannel |
| `file_picker` | **^11.0.2** — hỗ trợ `pickFiles` + `getDirectoryPath` (SAF tree URI) |

**Hệ quả trực tiếp cho Soundlist:** mọi entity key bằng chuỗi `audioPath`; file đổi chỗ/đổi tên → dữ liệu Âm mục "mất". Thiếu fingerprint + re-link.

---

## 2. Thiết kế — 4 lớp

### Lớp 1 — Bảng chỉ mục thư viện (Hive box mới `audio_library`)
```dart
class AudioLibraryEntry {
  String libraryId;      // 'media_<id>' | 'folder_<treeUri>_<docId>' | 'picked_<path>'
  String uri;            // content:// hoặc file path chuẩn hóa (\\ → /)
  String title;          // hiển thị (basename nếu không có metadata)
  String? artist;
  int durationMs;
  int sizeBytes;
  String source;         // 'media' | 'folder' | 'picked' | 'recent'
  DateTime addedAt;
  DateTime? lastPlayed;
  String? fingerprint;   // SHA-256 8 bytes của 64KB đầu file (hex 16)
}
```
- **Quét MediaStore (Android):** MethodChannel `in4up.audiolib` → query `MediaStore.Audio.Media.EXTERNAL_CONTENT_URI` (projection: ID, DISPLAY_NAME, TITLE, ARTIST, DURATION, SIZE, DATE_ADDED, DATA/RELATIVE_PATH). API 33+ cần runtime `READ_MEDIA_AUDIO`; API ≤32 dùng `READ_EXTERNAL_STORAGE` (manifest đã khai báo).
- **Thư mục người dùng chọn (SAF):** `FilePicker.getDirectoryPath` (Android trả tree URI; cần `takePersistableUriPermission`) → lưu `library_root_uri` vào settings → quét con bằng MethodChannel `DocumentFile` (AndroidX) — zero package mới.
- **Hợp nhất:** entry từ media + folder + picked + recent → de-dupe theo `uri` và `fingerprint`; `lastPlayed` ghi đè khi phát.
- **Quét tăng dần:** lúc khởi động (nền) + khi mở màn hình Thư viện (debounce 500ms) + pull-to-refresh. Không block UI (Isolate cho phần hash).

### Lớp 2 — Địa chỉ ổn định + Re-link (mấu chốt cho Soundlist)
- **Bước 1 (additive, không phá dữ liệu cũ):** thêm trường `audioId` (nullable) vào `SoundMark`, `SoundChapter`, `SoundTranscript`; `Segment` (model có sẵn) giữ nguyên `audioPath` + thêm `audioId` tương tự nếu cần. Khi lưu mới → gán `audioId = libraryId` nếu khớp fingerprint.
- **Bước 2 (migration):** `relinkMissingFiles()` — với mỗi entity có `audioPath` trỏ tới file không tồn tại: tìm entry thư viện có cùng `fingerprint` (hoặc cùng title+duration) → cập nhật `audioPath` mới → lưu lại. Chạy khi khởi động / từ Settings.
- **Bước 3 (tương lai, tùy chọn):** đổi key chính sang `audioId`; giữ `audioPath` làm trường hiển thị/phát.

### Lớp 3 — UI (nâng cấp `ListenLibraryScreen`, giữ Recent làm lớp nhanh)
- **Tab 1 — Gần đây:** như hiện tại (30 recent) — giữ nguyên.
- **Tab 2 — Thư viện:** danh sách toàn bộ audio đã chỉ mục: tìm kiếm (tên/artist), sắp xếp (tên/ngày/dài), nhóm theo thư mục, badge: "có mục lục/điểm/đoạn" (số liệu từ SoundlistProvider), badge 🔥 nếu có vùng lặp nhiều.
- **Tab 3 — Âm mục:** file nào có dữ liệu Soundlist (mở rộng từng file như màn hình Tools).
- **Hành động:** "➕ Chọn thư mục âm thanh" (SAF), "📁 Import file" (giữ FilePicker), "🔄 Quét lại", trạng thái quét + quyền (nếu bị từ chối → hướng dẫn bật).
- **Empty state:** hướng dẫn rõ ràng (chọn thư mục / import) thay vì màn hình trống.

### Lớp 4 — Nền tảng còn lại
- **iOS:** giữ `UIDocumentPicker` (file_picker) + danh sách "đã import" (lưu bookmark để giữ quyền). Không làm MediaStore MPMediaQuery trong MVO.
- **Windows:** `getDirectoryPath` + quét thư mục bằng `Directory` (dart:io — không cần native).
- **Android 13+ quyền:** flow runtime permission mượt (Rationale → Settings nếu từ chối vĩnh viễn).

---

## 3. Lộ trình theo phase (MVO trước, mở rộng sau)

| Phase | Nội dung | DoD (có thể verify) |
|---|---|---|
| **P1 — MVO (Android)** | Box `audio_library` + MethodChannel MediaStore + runtime permission + UI tab Thư viện (tìm/sắp xếp/phát) + hợp nhất recent | Quét được toàn bộ nhạc/pháp thoại trên máy; mở file 1 chạm từ danh sách |
| **P2 — Thư mục + SAF** | `getDirectoryPath` + persist URI + quét con DocumentFile + nhóm theo thư mục + "Chọn thư mục âm thanh" | Chọn 1 thư mục Pháp thoại → app liệt kê & phát được; quyền giữ sau khởi động lại |
| **P3 — Re-link + audioId** | `audioId` additive + fingerprint + `relinkMissingFiles()` + migration | Đổi tên/di chuyển file → dữ liệu Âm mục vẫn tìm lại được (re-link); test đơn vị cho hash + re-link |
| **P4 — Mở rộng** | iOS (import list) + Windows (folder scan) + quét nền tăng dần + badge thống kê | Ít nhất 2 nền tảng hoạt động; quét không giật UI |

---

## 4. File sẽ tạo / sửa (ước lượng)

**Mới:**
- `lib/models/audio_library_entry.dart` — model + toJson/fromJson
- `lib/services/audio_library_service.dart` — quét/hợp nhất/fingerprint (Isolate)
- `lib/services/audio_library_channel.dart` — MethodChannel wrapper (MediaStore/SAF/DocumentFile)
- `lib/providers/audio_library_provider.dart` — ChangeNotifier (entries, scanState, permission)
- `lib/widgets/audio_library_views.dart` — tab Thư viện + tab Âm mục + sheet chọn thư mục
- `test/audio_library_test.dart` — fingerprint, de-dupe, re-link (logic thuần)
- `android/app/src/main/kotlin/com/in2up/AudioLibraryChannel.kt` — MethodChannel handler

**Sửa:**
- `lib/screens/listen_mode/widgets/listen_library_screen.dart` — thêm tabs + tích hợp provider
- `lib/services/storage_service.dart` — +box `audio_library`, +settings `library_root_uri`, `relinkMissingFiles` helpers (gọi qua SoundlistProvider)
- `lib/models/sound_mark.dart`, `sound_chapter.dart`, `sound_transcript.dart` — +`audioId` (additive, default null)
- `lib/main.dart` — đăng ký provider
- `android/app/src/main/AndroidManifest.xml` — (đã có quyền; chỉ cần `maxSdkVersion` cho READ_EXTERNAL_STORAGE nếu thiếu)

---

## 5. Rủi ro & giảm thiểu

| Rủi ro | Mức | Giảm thiểu |
|---|---|---|
| MediaStore chỉ thấy file được MediaStore index (file ẩn/không chuẩn bị bỏ sót) | Med | Bổ sung SAF folder picker (P2) — người dùng chọn thư mục bất kỳ |
| Quyền Android 13+ bị từ chối | Med | Flow runtime permission + hướng dẫn Settings; SAF không cần quyền |
| Quét nhiều file tốn pin/CPU | Med | Quét tăng dần nền, giới hạn 1 lần/phiên + thủ công |
| Re-link sai (2 file trùng fingerprint hiếm) | Thấp | Chỉ tự re-link khi fingerprint khớp 100% + title/duration gần khớp; ghi log để kiểm |
| MethodChannel phức tạp | Med | Giữ handler tối giản (1 lệnh query, 1 lệnh list-folder), trả JSON thuần |

---

## 6. Test & nghiệm thu

- **Unit:** `audio_library_test.dart` — fingerprint ổn định, de-dupe theo uri + fingerprint, `relinkMissingFiles` đúng (fixture JSON theo format Hive thật).
- **CI:** thêm path mới vào `soundlist_tests.yml` (hoặc workflow riêng `audio_library_tests.yml`) — analyze + test.
- **Tay (Android ≥ 8 và ≥ 13):** quét toàn bộ → danh sách đủ; chọn thư mục SAF → giữ sau restart; đổi tên 1 file có mục lục → chạy re-link → mục lục còn; phát từ tab Thư viện → Recent cập nhật.

---

## 7. Ước lượng & phụ thuộc

- P1 ~ 3–5 phiên làm việc (bao gồm CI xanh + test).
- P2 ~ 2–3 phiên. P3 ~ 2–3 phiên (cẩn thận migration additive). P4 ~ 2–4 phiên.
- **Không thêm package** — file_picker 11.0.2 (đã có) + MethodChannel tự viết.
- Chỉ bắt đầu sau khi: (a) nghiệm thu tay Soundlist xong, (b) Hội đồng chốt (đây là workstream độc lập, không đổi spec Soundlist).

---

*Kế hoạch v0.1 — sẵn sàng phản biện. Không code cho tới khi chốt.*
