# C-27 — Cabin Live (Cross-workspace Live Utility): State detail

- **Capability:** C-27 — Cabin Live / Real-time Interpretation
- **Loại:** Cross-workspace live utility — **KHÔNG** phải workspace thứ sáu.
- **5 workspace cố định:** Home, Đọc, Nghe, Hiểu, Nhớ (không đổi — xem D-003).
- **Ngày:** 2026-10-09 · **Nhánh:** `arena/af0abe2f-in4up` · **Người soạn:** agent Arena
- **Nguồn tham chiếu:** code Cabin Live hiện hữu (`lib/features/cabin/`), `LiveCaptionBubble`,
  STT (`stts_cabin_service.dart`), caption/translation flow, audio/session behavior theo nhánh
  `251e` (nguồn tham chiếu capability — branch UX quyết định presentation/orchestration, không
  copy layout cũ).
- **Quyết định liên quan:** D-036 (log này), D-035 (shell tiêu thụ policy responsive),
  WP1 / PLAN-008 (Live Caption Bubble), PLAN-030 / CABIN-SAVE-001 (lưu phiên).

## 1. Vị trí kiến trúc (architecture placement)

C-27 là **tiện ích sống liên workspace**, đặt trên Global Shell chứ không trong một workspace:

```text
Global Shell (main_shell.dart)
├── 5 workspace: Home | Đọc | Nghe | Hiểu | Nhớ
├── Mini Player + WordlistBubble + LiveCaptionBubble (overlay stack)
├── Bottom Navigation (mobile) / Desktop Sidebar (≥1024px)
└── Full Cabin Viewport (mở từ Nghe hoặc từ bubble — full-screen route)
        └── Handoff Drawer (chuyển ngữ cảnh sang Hiểu / Nhớ)
```

- **Nguồn vào:** từ workspace **Nghe** (nút Cabin trên thanh công cụ Nghe) hoặc từ
  `LiveCaptionBubble` (mở Full Cabin Viewport).
- **Nguồn ra (handoff):** sang **Hiểu** (context chat) hoặc **Nhớ** (thẻ ôn tập) qua
  **Handoff Drawer** — kèm `sourceType` + `returnPath`.
- **Quay lại:** theo `returnPath` — từ Hiểu/Nhớ quay lại đúng Cabin Live đang mở.
- Code liên quan: `lib/features/cabin/models/cabin_caption.dart`
  (`CabinState` 6 trạng thái hiện tại, `CabinDisplayMode`, `CabinCaption`),
  `cabin_session.dart` (`CabinSession`, `CabinSessionStatus`, `CabinTranscriptEntry`),
  `services/cabin_session_store.dart` (cache trên đĩa), `widgets/live_caption_bubble.dart`,
  `screens/live_cabin_screen.dart` (Full Cabin Viewport).

## 2. Phạm vi / không phạm vi

**Trong phạm vi**

- 14-state matrix cho phiên Cabin Live (mở rộng `CabinState` 6 trạng thái hiện có).
- State machine transitions + bất biến.
- Caption model 3 giai đoạn: partial / final / translated.
- Local session cache (kế thừa `CabinSessionStore`): recording / unsaved / saved / recovered.
- Permission flow (microphone; overlay bubble trên Android).
- Reconnect / offline / service unavailable.
- Session ended: save draft / discard.
- 3 display form: Full Cabin Viewport, LiveCaptionBubble, Handoff Drawer.
- Handoff schema + `returnPath`.
- Safe-area, Bottom Navigation stacking, shortcut focus scope, responsive.

**Ngoài phạm vi**

- Thêm workspace thứ 6 hoặc đổi tên 5 workspace.
- Copy layout cũ từ 251e (251e chỉ là reference về audio/session behavior).
- Thay engine STT/dịch (giữ engine hiện có; C-27 chỉ đặc tả luồng trạng thái).
- Sync cloud phiên Cabin (để capability riêng; C-26 đã có offline/sync/conflict cho Nhớ).

## 3. 14 state matrix

| # | State (enum) | Ý nghĩa | Dữ liệu giữ khi vào state |
|---|---|---|---|
| 1 | `idle` | Chưa có phiên; bubble ẩn; màn Cabin ở trạng thái chờ | không có session |
| 2 | `permissionRequesting` | Đang xin quyền micro (và overlay nếu bật bubble trên Android) | chưa có session |
| 3 | `ready` | Đủ quyền, sẵn sàng; chưa kết nối engine | `sessionId` mới tạo |
| 4 | `connecting` | Đang kết nối engine STT/dịch | `sessionId`, `reconnectAttempts=0` |
| 5 | `listening` | Đang thu âm; nhận partial captions liên tục | `sessionId`, danh sách caption, timer |
| 6 | `translating` | Có final caption đang dịch (chưa có bản dịch) | như `listening` + caption đang dịch |
| 7 | `speaking` | Đang phát lại âm thanh gốc đã thu trong phiên | như `listening` + vị trí playback |
| 8 | `paused` | Tạm dừng: mic tắt, timer dừng, session giữ nguyên | `sessionId`, caption, timer offset |
| 9 | `reconnecting` | Mất kết nối engine; đang thử lại có backoff | `sessionId`, `reconnectAttempts` |
| 10 | `offline` | Mất mạng; engine online không khả dụng | `sessionId`, caption (có thể tiếp tục với engine local) |
| 11 | `handoffActive` | Handoff Drawer đang mở; chuẩn bị chuyển ngữ cảnh | + `activeHandoff` (schema §7) |
| 12 | `ending` | Đang kết thúc phiên; hỏi lưu nháp / bỏ | `sessionId`, toàn bộ caption |
| 13 | `saved` | Đã lưu vào local session cache | `sessionId`, đường dẫn session |
| 14 | `error` | Lỗi không tự phục hồi (service unavailable, quyền bị từ chối vĩnh viễn…) | giữ `sessionId` để còn save draft |

Quan hệ với `CabinState` hiện có (6 trạng thái: idle/listening/translating/speaking/
paused/error): C-27 **mở rộng** — `idle, listening, translating, speaking, paused, error`
trùng tên và giữ nguyên ý nghĩa; 8 trạng thái mới là phần cross-workspace + cache + permission
+ reconnect (`permissionRequesting, ready, connecting, reconnecting, offline, handoffActive,
ending, saved`). Code C-27 (`c27_cabin_live_state.dart`) là nguồn chính tắc; `CabinState`
hiện có vẫn dùng trong UI cũ cho tới khi các màn Cabin được nối vào controller C-27.

## 4. State machine transitions

Bảng chuyển đầy đủ ở **doc 43 (state contract)** — bản tóm tắt:

```text
idle ──startRequested──▶ permissionRequesting ──permissionsGranted──▶ ready
permissionRequesting ──permissionsDenied──▶ error ──dismissError──▶ idle
ready ──engineConnect──▶ connecting ──engineConnected──▶ listening
connecting ──engineConnectFailed──▶ reconnecting (đếm lần, tối đa 3)
listening ──partialCaption──▶ listening (self: cập nhật caption mờ)
listening ──finalCaption──▶ translating ──translatedCaption──▶ listening
listening ──playbackStarted──▶ speaking ──playbackEnded──▶ listening
listening ──pause──▶ paused ──resume──▶ listening
{connecting,listening,translating,speaking} ──connectionLost──▶ reconnecting
reconnecting ──reconnected──▶ listening
reconnecting ──reconnectFailed──▶ reconnecting (nếu còn lượt) / offline (hết lượt)
{listening,translating,speaking,paused} ──networkLost──▶ offline
offline ──networkRestored──▶ connecting
{connecting,reconnecting,offline} ──serviceUnavailable──▶ error
{listening,paused} ──handoffOpened──▶ handoffActive ──handoffClosed──▶ (trạng thái cũ)
{listening,translating,speaking,paused,reconnecting,offline,handoffActive} ──endRequested──▶ ending
ending ──saveDraft──▶ saved ──reset──▶ idle (phiên mới)
ending ──discardDraft──▶ idle (xoá nháp)
idle ──recoveryLoaded──▶ ready (khôi phục phiên bị ngắt: CabinSession.recovered = true)
```

**Guard đặc biệt**

- `handoffClosed` trả về đúng trạng thái cũ (`listening` hoặc `paused`) — machine nhớ
  `handoffOrigin`.
- `reconnectFailed` chỉ xuống `offline` sau khi hết 3 lượt; trước đó ở lại `reconnecting`.
- `saved` và `error` không quay lại `listening` cùng `sessionId` — muốn tiếp tục phải tạo phiên
  mới (`reset` về `idle` rồi bắt đầu lại).
- Mọi transition không có trong bảng → **reject** (machine trả `null`, không đổi state).

## 5. Caption model: partial / final / translated

Ba giai đoạn của một caption, cùng một `id` (mở rộng `CabinCaption`):

| Stage | Ý nghĩa | `isFinal` | `translatedText` | Vào cache? | Hiển thị bubble |
|---|---|---|---|---|---|
| `partial` | Kết quả tạm của STT, liên tục thay đổi | `false` | rỗng | **không** | chữ mờ/nghiêng |
| `final` | Câu nguồn đã chốt | `true` | rỗng | chỉ khi lưu phiên | chữ thường |
| `translated` | Đã có bản dịch đích | `true` | có nội dung | có | 2 dòng (nguồn + dịch) |

Quy tắc

- Tiến trình một chiều: `partial → final → translated` (cùng `id`); không lùi stage.
- `partial` không bao giờ ghi vào session cache (chỉ `final`/`translated`).
- `translated` có thể đến sau `final` nhiều giây (dịch bất đồng bộ) — bubble cập nhật tại chỗ.
- Nhiều `partial` liên tiếp cùng `id` chỉ cập nhật text, không tạo entry mới.

## 6. Local session cache

Kế thừa `CabinSessionStore` (file-based, đã có):

- Mỗi phiên = một thư mục: `session.json` (metadata `CabinSession`) + transcript
  (`CabinTranscriptEntry` với offset ms khớp vị trí file ghi âm) + audio WAV (nếu có).
- `CabinSessionStatus`: `recording` (app bị tắt lúc đang ghi ⇒ khi mở lại là `recovered`),
  `unsaved` (dừng nhưng chưa quyết định), `saved`.
- Map với state machine: `listening..offline` ⇒ `recording`; `ending` ⇒ `unsaved`;
  `saved` ⇒ `saved`. `discardDraft` ⇒ xoá thư mục nháp.
- Khôi phục: `recoverInterrupted()` liệt kê phiên `recording` ⇒ `recoveryLoaded` → `ready`
  (user tiếp tục) hoặc vào `ending` để save/discard.

## 7. Permission flow

1. `startRequested` từ Nghe ⇒ `permissionRequesting`.
2. Xin quyền **microphone** (system dialog). Thành công ⇒ `ready`.
3. Nếu bật bubble overlay (Android): xin thêm quyền **"hiển thị trên ứng dụng khác"**
   (overlay). Không cấp ⇒ bubble không nổi nhưng Full Cabin Viewport vẫn dùng được
   (ghi rõ trong UI, không chặn flow).
4. Từ chối ⇒ `error` với hướng dẫn vào Cài đặt → Ứng dụng → In4Up → Quyền; `dismissError`
   về `idle`; xin lại được nhiều lần.
5. Từ chối vĩnh viễn (system "không hỏi lại") ⇒ `error` + nút mở Cài đặt hệ thống.

## 8. Reconnect / offline / service unavailable

- **Mất kết nối engine** (`connectionLost`): vào `reconnecting`, backoff 1s/2s/4s,
  tối đa 3 lượt (`reconnectAttempts`). Thành công (`reconnected`) về `listening`;
  hết lượt (`reconnectFailed` lần 3) xuống `offline`. `sessionId` và caption giữ nguyên.
- **Mất mạng** (`networkLost`): từ `listening/translating/speaking/paused` vào `offline`.
  Ở `offline`: caption cũ vẫn xem được; nếu engine local/offline có sẵn thì tiếp tục
  được (ghi rõ đang chạy offline); engine online tạm ngừng. Có mạng lại
  (`networkRestored`) ⇒ `connecting` ⇒ `listening`.
- **Service unavailable** (engine trả lỗi vĩnh viễn / hết quota): `serviceUnavailable`
  từ `connecting/reconnecting/offline` ⇒ `error`. Phiên **không mất**: user `dismissError`
  về `idle` rồi `recoveryLoaded` để vào `ending` — chọn **save draft** (giữ transcript đã có)
  hoặc **discard**.

## 9. Session ended: save draft / discard

- `endRequested` (từ bất kỳ state active nào) ⇒ `ending`; hiện hộp thoại:
  **Lưu nháp** / **Bỏ** / (Huỷ → quay lại state trước).
- **Lưu nháp** (`saveDraft`): ghi `CabinSession(status: saved)` + entries (chỉ
  `final`/`translated`) + audio nếu có ⇒ `saved` ⇒ hiện `CabinSessionsScreen`.
- **Bỏ** (`discardDraft`): xoá thư mục nháp ⇒ `idle`. Transcript chưa lưu mất —
  hộp thoại nói rõ.
- `saved` + `reset` ⇒ `idle` (bắt đầu phiên mới; `sessionId` mới).

## 10. Ba display form

### 10.1 Full Cabin Viewport (`live_cabin_screen.dart`)

- Route full-screen mở từ Nghe hoặc từ bubble; hiển thị transcript song ngữ theo thời gian,
  `CabinDisplayMode` (oneWord / oneLine / fullTranscript), thanh điều khiển (pause/resume,
  end, display mode, handoff).
- Tôn trọng safe-area trên/dưới; không đè lên bottom nav khi ở mobile (route full-screen
  che shell; shell hiện lại khi quay về).

### 10.2 LiveCaptionBubble (`live_caption_bubble.dart`)

- Overlay nổi trên **mọi** màn hình của app (kể cả khi đang ở Home/Đọc/Nghe/Hiểu/Nhớ) —
  đây là lý do C-27 là cross-workspace.
- Kéo thả tự do; tự thu gọn sau 5s không hoạt động (auto-hide); chạm để mở rộng;
  chạm vào thân bubble ⇒ mở Full Cabin Viewport; nút trên bubble ⇒ Handoff Drawer.
- Chỉ hiện khi state ∈ {listening, translating, speaking, paused, reconnecting, offline}
  (đang có phiên); `idle`/`saved`/`error`/`ending` ⇒ ẩn.
- **Bottom Navigation stacking:** bubble nằm trên bottom nav (z-order trong `Stack` của
  shell: `WordlistBubble`, `LiveCaptionBubble` ở trên cùng) nhưng **không che** tab đang
  active: vị trí mặc định lệch sang phải (20, 190), người dùng kéo được; khi bubble mở rộng
  thì bottom nav vẫn tương tác được (bubble không chặn toàn bộ chiều rộng).

### 10.3 Handoff Drawer

- Mở từ Full Cabin Viewport hoặc từ bubble; trên **mobile** là bottom sheet, trên
  **desktop/expanded** là side panel bên phải (theo `AppResponsive`).
- Chọn đích: **Hiểu** (gửi context vào Global Chat của Hiểu) hoặc **Nhớ** (tạo thẻ ôn tập).
- Hiển thị preview handoff (schema §11) trước khi xác nhận.

> **Visual validation (2026-10-09):** đã hoàn tất — có đủ 2 visual reference Stitch:
> **Desktop** "I4U Desktop — C-27 Cabin Live / Full Viewport & Handoff Drawer" và
> **Mobile** "I4U Mobile — C-27 Cabin Live / 3 Display Forms & Safe-Area". Không gửi
> thêm prompt Stitch trừ khi phát hiện lỗi cụ thể: bubble che Mini Player, bubble che
> Bottom Navigation, Handoff Drawer cạnh tranh Context Panel, partial/final/translated
> khó phân biệt, hoặc mobile keyboard che caption.

## 11. Source context handoff schema + returnPath

Schema tối thiểu (10 trường bắt buộc — xem bản chính tắc ở doc 43):

| Trường | Kiểu | Ý nghĩa |
|---|---|---|
| `sourceType` | enum | workspace nguồn: `home/read/listen/understand/remember/cabin` |
| `sessionId` | string | phiên Cabin Live |
| `timestamp` | int (ms) | thời điểm tạo handoff |
| `originalCaption` | string | caption gốc (nguồn) |
| `translatedCaption` | string | caption đã dịch |
| `sourceLanguage` | string | mã ngôn ngữ nguồn (vd `vi`, `en`, `pi`) |
| `targetLanguage` | string | mã ngôn ngữ đích |
| `speakerTag` | string | nhãn người nói (`S1`, `S2`…; rỗng nếu không gán) |
| `sessionTitle` | string | tiêu đề phiên Cabin |
| `returnPath` | string | đường quay lại Cabin Live (xem dưới) |

**Chuỗi flow + returnPath**

```text
Nghe ──▶ Cabin Live ──▶ Hiểu ──▶ Nhớ ──▶ (quay lại Cabin Live)
         │                │        │
         │ handoff        │ handoff│ handoff về cabin
         ▼                ▼        ▼
   returnPath='cabin'  returnPath='cabin'  returnPath='cabin'
```

- `returnPath` là đường quay lại **Cabin Live đang mở** — cố định trong suốt chuỗi
  `Hiểu → Nhớ` (không đổi khi handoff giữa các workspace sau Cabin).
- Từ workspace bất kỳ trong chuỗi, nút "Quay lại Cabin" điều hướng theo `returnPath`.
- `returnPath` chỉ đổi khi đóng phiên Cabin và mở phiên mới.

## 12. Safe-area · Bottom Navigation stacking · Shortcut focus scope

- **Safe-area:** bubble cách mép dưới ít nhất `safeArea.bottom + 8` (không đè lên
  bottom nav/gesture bar); Full Cabin Viewport và Handoff Drawer dùng đúng
  `I4uSafeAreaPolicy` (C-02b/D-035) — không tự viết `viewInsets.bottom + N`.
- **Bottom Navigation stacking:** thứ tự z trong shell: nội dung workspace < bottom nav
  < Mini Player < WordlistBubble/LiveCaptionBubble. Bubble có thể che một phần nội dung
  nhưng không che bottom nav; khi Full Cabin Viewport mở thì shell (kể cả bottom nav) ẩn
  theo route full-screen.
- **Shortcut focus scope:** khi Cabin Live active (Viewport mở hoặc bubble đang nhận lệnh),
  phím tắt của Cabin (`Space` play/pause, `P` pause, `E` end, `H` handoff, `Tab` đổi display
  mode) chỉ hoạt động trong scope Cabin — không trigger shortcut của shell (command palette,
  đổi tab, quick actions). Thoát Cabin ⇒ trả focus về shell. Bubble đang thu gọn
  (auto-hide) không nhận phím tắt.

## 13. Responsive (mobile / tablet / desktop)

Theo `AppResponsive.classify(width)` (compact <600, medium 600–1024, expanded 1024–1440,
large ≥1440):

| Thành phần | compact (mobile) | medium (tablet) | expanded/large (desktop) |
|---|---|---|---|
| LiveCaptionBubble | 1 dòng thu gọn, tự ẩn 5s | 2 dòng | 2 dòng, neo được cả góc |
| Full Cabin Viewport | full-screen, 1 cột (nguồn trên, dịch dưới) | full-screen, 2 cột caption | 2 cột transcript + cột phải (context/handoff) |
| Handoff Drawer | bottom sheet | bottom sheet cao | side panel phải |
| Bottom nav / sidebar | bottom nav | bottom nav | sidebar trái (shell) + Cabin trong content |

Không đổi pixel ở các ngưỡng đã chốt (D-035); state machine không phụ thuộc kích thước —
chỉ presentation đổi.

## 14. Liên quan

- Doc 43: `43-c27-cabin-live-state-contract.vi.md` (hợp đồng máy móc + test mapping).
- `39-capability-breakdown.vi.md` mục C-27; `decision-log.vi.md` **D-036**.
- C-23 (Audio Library/Nghe), C-25 (Hiểu), C-26 (Nhớ), C-02b (policy responsive),
  I18N-001 (mọi nhãn Cabin đã có English — lô 5).
