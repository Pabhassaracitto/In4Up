# ADR-0005: "Nhịp điệu học tập" — sự kiện học thật theo ngày, một kho duy nhất (HOME-STREAK-001)

- **Ngày:** 2026-09-15
- **Trạng thái:** ĐÃ TRIỂN KHAI (B6 / HOME-STREAK-001, branch `arena/01a0a702-in4up`);
  CI 🟢/🔴 cập nhật trong KANBAN. Còn nghiệm thu thiết bị (mở lại app, qua ngày).
- **Phạm vi:** `lib/models/learning_activity.dart`, `lib/services/learning_activity_service.dart`
  (mới), `lib/providers/focus_provider.dart`, `lib/screens/home/widgets/focus_streak_card.dart`
  (viết lại), + 6 điểm gọi `record(...)` ở nơi phát sinh hành động thật. Không đổi
  schema WordEntry/Knowledge, không đổi route, không chạm vùng FFI/Studio.

## Bối cảnh

Thẻ "Nhịp điệu học tập" (`focus_streak_card.dart`) chỉ hiển thị `FocusProvider.streak`.
Streak đó chỉ tăng trong `FocusProvider.saveEffort(score)` — hàm gắn với **slider nỗ
lực đã bị bỏ ở HOME-001**, nên không còn caller nào: streak gần như luôn 0 và không
phản ánh việc học thật (KANBAN — HOME-STREAK-001).

Ba cách làm, đã cân nhắc:

1. **Suy diễn từ dữ liệu sẵn có** (`RecentFilesService.lastOpened`,
   `VocabularyProvider.allWords.createdAt`, LHB `reviewState`, shadowing history,
   translation cache): không cần lưu gì mới, nhưng mỗi nguồn có quy ước thời gian và
   vòng đời riêng (xoá từ thì mất dấu "hôm đó có học"; `lastOpened` bị ghi đè nên chỉ
   giữ lần đọc cuối; cache dịch có thể bị clear) ⇒ streak **sai và không tái lập được**,
   lại còn phải quét Hive/JSON mỗi lần vẽ thẻ.
2. **Mỗi module tự giữ streak riêng** (LHB đã có `_streak`; thêm cho đọc/shadowing…):
   N streak N công thức, không có "ngày học" thống nhất, thẻ Home phải hợp nhất —
   trái tinh thần "một nguồn sự thật" và sẽ lệch nhau khi một module đổi luật.
3. **Một kho sự kiện học thật dùng chung** (đã chọn): nơi phát sinh hành động gọi
   `record(kind, sourceKey)`; kho gộp theo ngày, lưu bền; streak tính từ kho đó.

## Quyết định

### 1. Một kho duy nhất, ghi tại NƠI HÀNH ĐỘNG THẬT

`LearningActivityService` (singleton, `ChangeNotifier`) là nguồn sự thật cho "ngày
học". Sự kiện được ghi tại đúng chỗ hành động xảy ra — **không** ghi trong `build()`
hay trong `initState` thuần hiển thị:

| Hoạt động | Nơi ghi | `sourceKey` |
|---|---|---|
| Mở/đọc tài liệu | `RecentFilesService.addOrUpdate` | `file.id` |
| Phút đọc thật | `ReadModeScreen` (nhịp 1 phút, huỷ khi dispose) | `fileId\|YYYY-M-DTH:MM` |
| Lưu/import từ | `VocabularyProvider.addWord/addWords`, `MemoryController.addWord` | từ đã normalize |
| Ôn LHB | `LearnByHeartProvider.submitReview/submitAssessment` | `item.id` |
| Shadowing | `ShadowingProvider._analyzeRecording` (khi thành công) | `savedEntry.id` |
| Dịch | `TranslationService.translateText` (khi thành công) | `stableSourceKey(src\|tgt\|câu)` (FNV-1a) |

`saveEffort`/`last_effort_score` bị bỏ khỏi đường tính streak (KANBAN HOME-001 đã bỏ
slider). Dữ liệu effort cũ trong prefs **không bị xoá**, chỉ không còn được dùng.

### 2. Idempotent theo (ngày, kind, `sourceKey`) — không nhân đôi khi rebuild/restart

`record` trả `false` nếu sự kiện đã được tính trong ngày. Nhờ vậy: widget rebuild,
`didChangeDependencies` chạy lại, mở lại app, hay kích hoạt lặp cùng một hành động đều
không làm số liệu tăng. Sự kiện không có khoá tự nhiên (gõ tay) dùng khoá tự sinh.

### 3. Persist gọn: gộp theo ngày, không lưu từng event thô

Một chuỗi JSON trong SharedPreferences (`in4up_learning_activity_v1`):

```json
{"v":1,"days":{"2026-09-15":{"read_min":12,"vocab":3}},"keys":{"2026-09-15":["vocab|apple"]}}
```

- `days`: bộ đếm đã gộp theo kind ⇒ kích thước phụ thuộc số ngày, không phụ thuộc
  số hành động (một ngày 300 lượt dịch vẫn chỉ 1 khoá `translation`).
- `keys`: chỉ giữ khoá chống trùng **3 ngày gần nhất** (`dedupeRetentionDays`), trần
  300 khoá/ngày; ngày cũ hơn `retentionDays = 400` bị dọn. Ghi 1 lần/sự kiện.
- Payload hỏng/kind lạ ⇒ bỏ qua phần không đọc được, không crash (test có phủ).

### 4. Ngày = NGÀY ĐỊA PHƯƠNG, chốt lúc ghi

"Thuộc ngày nào" được quyết định tại thời điểm ghi bằng `learningDayKey(instant)`
(`DateTime.toLocal()` → `YYYY-MM-DD`). Khoá ngày lưu nguyên văn ⇒ đọc lại ở bất kỳ
timezone nào cũng **giữ nguyên lịch sử**, không có chuyện một event bị tính lại sang
ngày khác. Dịch ngày dùng constructor `DateTime(y, m, d ± n)` (không cộng `Duration`)
để đúng qua DST và ranh giới tháng/năm.

### 5. Streak: có "ân hạn trong ngày", nghỉ trọn ngày là đứt

- Hôm nay có học ⇒ đếm ngược từ hôm nay.
- Hôm nay chưa học nhưng hôm qua có ⇒ **giữ nguyên chuỗi** (không tụt lúc 00:00), không
  cộng thêm — đúng AT "ngày không học không tăng".
- Cách một ngày trống ⇒ 0.

### 6. UI đọc qua `FocusProvider` (facade), không hardcode

`FocusStreakCard` lấy số liệu từ `FocusProvider.snapshot()` (hôm nay theo từng kind +
streak + 7 ngày). Biểu đồ 7 ngày nhãn là **số ngày trong tháng** (không cần dịch). Nhãn
chrome mới dùng `context.uiText(...)` + catalog `tool/legacy_ui_english_overrides.json`
(rule #5: locale ≠ vi → hiện English, không fallback vi).

## Hệ quả

- Thêm 1 service + 1 model; 6 file có thêm 4–10 dòng hook. Không có vòng lặp phụ thuộc
  mới (hooks chỉ gọi service, service không biết provider nào).
- `FocusProvider` mất API `saveEffort/lastEffortScore/hasAssessedToday` — đã kiểm tra
  không còn caller nào trong `lib/` và `test/`.
- Streak cũ (từ thời slider) **không được seed** sang kho mới: dữ liệu cũ không phản ánh
  hành động thật, seed vào là bịa số. Người dùng bắt đầu chuỗi mới từ hành động thật.
- Muốn đổi luật "thế nào là một ngày học" ⇒ sửa tại một chỗ (`record` + `streak`), test
  ở `test/home_streak/` là lưới an toàn.
- Ngày không học KHÔNG được ghi vào `days` ⇒ persist không phình theo thời gian thực tế.

## Việc còn mở (chủ dự án)

- Bật `docs/ci/home_streak_tests.yml` (GitHub App của agent thiếu quyền `workflows`).
  Hiện `test/knowledge/home_streak_ci_oracle_test.dart` gọi tạm bộ test qua job knowledge.
- Nghiệm thu thiết bị theo AT: đọc + lưu từ hôm nay → card > 0; mở lại app không nhân
  đôi; qua ngày không học → streak giữ; học ngày kế tiếp → +1.
- Nếu sau này cần màn "thống kê chi tiết": đọc thẳng `LearningActivityService.snapshot`
  / `recentDays` thay vì thêm nguồn dữ liệu thứ hai.
