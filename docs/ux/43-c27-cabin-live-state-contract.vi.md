# C-27 — Cabin Live: State contract (máy móc, có thể kiểm chứng)

- **Phiên bản hợp đồng:** v1 (2026-10-09) · **Nhánh:** `arena/af0abe2f-in4up`
- **Mục tiêu:** đây là bản **chính tắc** để code (`lib/features/cabin/models/c27_cabin_live_state.dart`,
  `lib/features/cabin/controllers/c27_cabin_live_controller.dart`) và máy bắt
  (`test/c27_cabin_live_*_test.dart`) cùng dựa vào. Mọi lệch giữa code và hợp đồng này là lỗi.
- **Nguyên tắc:** "chỉ sai khi ĐỎ THẬT" — phần không kiểm được bằng logic thuần thì KHÔNG tự
  nhận pass (theo D-031/D-032).

## 1. Định nghĩa trạng thái (14 state — enum `C27CabinLiveState`)

```text
idle  permissionRequesting  ready  connecting  listening  translating  speaking
paused  reconnecting  offline  handoffActive  ending  saved  error
```

Ý nghĩa từng state xem doc 42 §3. `CabinState` cũ (6 state) là tập con ý nghĩa tương đương.

## 2. Định nghĩa sự kiện (enum `C27CabinEvent`)

```text
startRequested        bắt đầu từ Nghe (xin quyền)
permissionsGranted    đã cấp quyền micro (+ overlay nếu có)
permissionsDenied     từ chối quyền
engineConnect         bắt đầu kết nối engine
engineConnected       kết nối engine thành công
engineConnectFailed   kết nối engine thất bại (1 lượt)
partialCaption        có caption tạm (STT interim)
finalCaption          có caption nguồn đã chốt
translatedCaption     có bản dịch cho caption đã chốt
playbackStarted       bắt đầu phát lại audio gốc
playbackEnded         phát lại xong
pause                 tạm dừng
resume                tiếp tục sau tạm dừng
connectionLost        mất kết nối engine
disconnected→(same)   (gộp vào connectionLost)
reconnected           kết nối lại thành công
reconnectFailed       một lượt reconnect thất bại
networkLost           mất mạng
networkRestored       có mạng lại
serviceUnavailable    engine lỗi vĩnh viễn / hết quota
handoffOpened         mở Handoff Drawer
handoffClosed         đóng Handoff Drawer (quay lại state cũ)
endRequested          yêu cầu kết thúc phiên
saveDraft             chọn lưu nháp
discardDraft          chọn bỏ nháp
reset                 xoá phiên đã lưu, bắt đầu phiên mới
dismissError          bỏ qua lỗi (giữ session để save draft)
recoveryLoaded        khôi phục phiên bị ngắt (CabinSession.recovered)
```

## 3. Bảng chuyển trạng thái (chính tắc)

Ký hiệu: `A --e--> B` nghĩa state `A` + event `e` ⇒ state `B`. Self-loop cập nhật dữ liệu,
state không đổi.

| # | Từ | Event | Đến | Guard / side effect |
|---|---|---|---|---|
| 1 | idle | startRequested | permissionRequesting | tạo `sessionId` mới |
| 2 | permissionRequesting | permissionsGranted | ready | |
| 3 | permissionRequesting | permissionsDenied | error | có retry (dismissError) |
| 4 | ready | engineConnect | connecting | `reconnectAttempts = 0` |
| ready | endRequested | ending | khôi phục phiên cũ rồi kết thúc ngay (save draft / discard) |
| 5 | connecting | engineConnected | listening | `reconnectAttempts = 0` |
| 6 | connecting | engineConnectFailed | reconnecting | `reconnectAttempts++` |
| 7 | connecting | serviceUnavailable | error | giữ session |
| 8 | listening | partialCaption | listening (self) | upsert caption stage=partial |
| listening | serviceUnavailable | error | giữ session (service unavailable giữa phiên) |
| 9 | listening | finalCaption | translating | upsert caption stage=final |
| 10 | translating | translatedCaption | listening | caption stage=translated |
| translating | serviceUnavailable | error | giữ session |
| 11 | listening | playbackStarted | speaking | |
| 12 | speaking | playbackEnded | listening |
| speaking | serviceUnavailable | error | giữ session | |
| 13 | listening | pause | paused | giữ sessionId + timer offset |
| 14 | paused | resume | listening |
| paused | serviceUnavailable | error | giữ session | |
| 15 | connecting | connectionLost | reconnecting | `reconnectAttempts++` |
| 16 | listening | connectionLost | reconnecting | `reconnectAttempts++` |
| 17 | translating | connectionLost | reconnecting | `reconnectAttempts++` |
| 18 | speaking | connectionLost | reconnecting | `reconnectAttempts++` |
| 19 | reconnecting | reconnected | listening | `reconnectAttempts = 0` |
| 20 | reconnecting | reconnectFailed | reconnecting | nếu `reconnectAttempts < 3` (self, đếm tiếp) |
| 21 | reconnecting | reconnectFailed | offline | nếu `reconnectAttempts >= 3` |
| 22 | reconnecting | serviceUnavailable | error | giữ session |
| 23 | listening | networkLost | offline | |
| 24 | translating | networkLost | offline | |
| 25 | speaking | networkLost | offline | |
| 26 | paused | networkLost | offline | |
| 27 | offline | networkRestored | connecting | |
| 28 | offline | serviceUnavailable | error | giữ session |
| 29 | listening | handoffOpened | handoffActive | nhớ `handoffOrigin = listening` |
| 30 | paused | handoffOpened | handoffActive | nhớ `handoffOrigin = paused` |
| 31 | handoffActive | handoffClosed | (handoffOrigin) | về đúng listening/paused |
| 32 | listening | endRequested | ending | |
| 33 | translating | endRequested | ending | |
| 34 | speaking | endRequested | ending | |
| 35 | paused | endRequested | ending | |
| 36 | reconnecting | endRequested | ending | |
| 37 | offline | endRequested | ending | |
| 38 | handoffActive | endRequested | ending | |
| 39 | ending | saveDraft | saved | ghi cache (chỉ final/translated) |
| 40 | ending | discardDraft | idle | xoá nháp, `sessionId` bỏ |
| 41 | saved | reset | idle | `sessionId` mới ở lần start tiếp |
| 42 | error | dismissError | idle | giữ sessionId để recovery |
| 43 | idle | recoveryLoaded | ready | `CabinSession.recovered = true` |

**Bất kỳ cặp (state, event) không có trong bảng ⇒ REJECT** — `transition()` trả `null`,
state không đổi, không side effect.

## 4. Bất biến (invariants)

1. Luôn ở đúng một state; state đầu tiên là `idle`.
2. `sessionId` không đổi trong suốt một phiên (mọi state từ `ready` đến `saved`); chỉ đổi khi
   tạo phiên mới (sau `reset`/`discardDraft` rồi `startRequested`).
3. Caption `id` tăng đơn điệu; mỗi `id` có đúng một chuỗi stage `partial → final → translated`,
   không lùi.
4. `reconnectAttempts` chỉ tăng ở `engineConnectFailed`/`connectionLost`/`reconnectFailed` (tối đa
   3), và reset về 0 khi `engineConnected`/`reconnected`.
5. `handoffActive` luôn có `handoffOrigin ∈ {listening, paused}` và `activeHandoff != null`;
   `handoffClosed` về đúng `handoffOrigin`.
6. `returnPath` không đổi khi state ∈ {handoffActive} và giữa các handoff liên tiếp trong chuỗi
   Nghe → Cabin → Hiểu → Nhớ; chỉ đổi khi mở phiên Cabin mới.
7. Ở `saved`/`error` không có transition nào quay lại `listening` cùng `sessionId`.
8. Partial captions không bao giờ vào `C27SessionSnapshot` (chỉ final/translated).

## 5. Caption contract (3 stage)

```text
enum C27CaptionStage { partial, final, translated }
```

- `partial`: `isFinal = false`, `translatedText` rỗng, text thay đổi liên tục (cùng id).
- `final`: `isFinal = true`, `translatedText` rỗng.
- `translated`: `isFinal = true`, `translatedText` khác rỗng.
- Map với `CabinCaption` hiện có: stage suy ra từ `isFinal` + `translatedText` rỗng hay không
  (`stageOf(CabinCaption)`).

## 6. Handoff schema (10 trường bắt buộc)

```json
{
  "sourceType": "cabin",          // home|read|listen|understand|remember|cabin
  "sessionId": "c27-2026-10-09T…",// string, duy nhất mỗi phiên
  "timestamp": 1760000000000,     // int, epoch milliseconds
  "originalCaption": "…",          // string (nguồn)
  "translatedCaption": "…",        // string (đích)
  "sourceLanguage": "vi",          // mã ngôn ngữ nguồn
  "targetLanguage": "en",          // mã ngôn ngữ đích
  "speakerTag": "S1",              // string, có thể rỗng
  "sessionTitle": "…",             // tiêu đề phiên Cabin
  "returnPath": "cabin"            // đường quay lại Cabin Live
}
```

Quy tắc validate (máy bắt dùng)

- Đủ **đúng 10** trường, không thêm field lạ trong v1 (schema kín).
- Mọi trường bắt buộc phải có mặt; `originalCaption`, `translatedCaption`,
  `sourceLanguage`, `targetLanguage`, `sessionId`, `returnPath`, `sessionTitle`,
  `sourceType`, `timestamp` phải **không rỗng** (`speakerTag` được rỗng).
- `sourceType` phải thuộc enum; `timestamp` > 0.
- `returnPath` không chứa ký tự điều khiển; chỉ chữ thường + `/` + `-`.
- Round-trip `toJson`/`fromJson` phải **bảo toàn 10/10 trường** (so sánh từng field).

## 7. Session cache contract

- `C27SessionSnapshot` (dữ liệu sẽ ghi, nhà cung cấp cache tự lo IO — ở đây là
  `CabinSessionStore`):
  - `sessionId`, `title`, `sourceLang`, `targetLang`, `engine`,
  - `entries`: chỉ các caption ở stage `final`/`translated` (mảng `CabinTranscriptEntry`,
    offset ms tính từ đầu phiên, không tính thời gian pause),
  - `status`: `saved` (khi từ `saveDraft`) — `unsaved` do UI Cabin cũ quản lý.
- `saveDraft`: snapshot status = `saved`, đủ entry; `discardDraft`: không ghi gì, `sessionId`
  coi như bỏ.
- Khôi phục (`recoveryLoaded`): phiên có `status = recording` trên đĩa ⇒ `recovered = true`;
  vào `ready` (tiếp tục) hoặc qua `ending` (save/discard).

## 8. Error / recovery contract

| Tình huống | Event vào | State | Khôi phục |
|---|---|---|---|
| Xin quyền thất bại | permissionsDenied | error | dismissError → idle → start lại |
| Kết nối engine fail 1–3 lượt | engineConnectFailed / reconnectFailed | reconnecting | tự retry, backoff; quá 3 → offline |
| Mất mạng | networkLost | offline | có mạng → connecting → listening |
| Engine lỗi vĩnh viễn | serviceUnavailable | error | dismissError → idle → recoveryLoaded → ending → save draft (giữ transcript) |
| Engine lỗi vĩnh viễn giữa phiên (listening/translating/speaking/paused) | serviceUnavailable | error | giữ nguyên session + caption; dismissError → idle → recoveryLoaded → ending → save draft |
| App bị tắt lúc đang ghi | (không event) | — (đĩa: recording) | mở lại: recoverInterrupted → recoveryLoaded → ready |

Session (sessionId + caption final/translated) **không bao giờ mất** ở các tình huống trên —
chỉ mất khi user chọn `discardDraft`.

## 9. Test mapping (máy bắt không pass rỗng)

| Hợp đồng | Test file | Số kịch bản tối thiểu |
|---|---|---|
| §3 bảng chuyển + §4 bất biến | `test/c27_cabin_live_state_transition_test.dart` | 14 state reachable; happy path Nghe→Cabin→Hiểu→Nhớ→về; 6 chuyển bị reject; guard reconnect 3 lượt; recovery |
| §5 caption stage | (cùng file trên) | partial→final→translated cùng id; không lùi stage; partial không vào snapshot |
| §6 handoff schema | `test/c27_cabin_live_handoff_preservation_test.dart` | đủ 10 trường; round-trip 10/10; reject thiếu từng trường; chuỗi handoff 3 hop bảo toàn dữ liệu; returnPath không đổi |
| §7 cache + §8 error/recovery | `test/c27_cabin_live_offline_reconnect_session_test.dart` | reconnect/offline/service-unavailable; save draft (chỉ final/translated); discard; sessionId ổn định; pause/resume |

**Cổng chặn trung thực:** nếu một file test không tồn tại ở CI, bước test phải ĐỎ (file list
trong `app_analyze.yml` có guard `[ -f ]` để không skip âm thầm — file bị thiếu thì bị loại
khỏi list và drift guard của C-27 phải báo thiếu; xem phần CI trong KANBAN card C-27).

## 10. Phiên bản

- **v1 (2026-10-09):** 14 state, 27 events, 48 chuyển, 10-field handoff schema, 8 bất biến.
  Mọi thay đổi hợp đồng phải bump version và cập nhật cả 3 test file.
