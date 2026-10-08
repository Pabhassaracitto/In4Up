# I4U UX — Nhật ký quyết định

> Đây là nguồn ghi nhận các quyết định UX đã thống nhất, các câu hỏi đang mở và lý do thay đổi.

## D-001 — Bắt đầu bằng bản đồ UX, chưa code

- **Ngày:** 2026-10-04
- **Trạng thái:** đã thống nhất
- **Quyết định:** Trước khi sửa UI/code, xây dựng bản đồ toàn app theo bốn tầng: Global Shell → Workspace → Context Bar → Tools.
- **Lý do:** Giảm rủi ro sửa từng màn hình riêng lẻ nhưng làm IA tổng thể phức tạp hơn.

## D-002 — Dùng Google Stitch để thử mockup nhanh

- **Ngày:** 2026-10-04
- **Trạng thái:** đề xuất, chờ xác nhận công cụ
- **Quyết định:** Ưu tiên Google Stitch cho mockup UI nhanh; dùng Google Sheets/Slides/Drawings làm bản đồ và kiểm kê nếu cần.
- **Lý do:** Stitch phù hợp thử nhiều phương án từ prompt; tài liệu/bảng giúp lưu quyết định độc lập với mockup.

## D-003 — Giữ mô hình năm workspace làm giả thuyết ban đầu

- **Ngày:** 2026-10-04
- **Trạng thái:** bản nháp, cần user xác nhận sau audit
- **Quyết định:** Tiếp tục dùng Home, Nghe, Đọc, Hiểu, Nhớ làm năm workspace ban đầu.
- **Lý do:** Phù hợp mục tiêu người dùng và kiến trúc `MainShell` hiện có.

## D-004 — Agent phải được chia theo capability

- **Ngày:** 2026-10-04
- **Trạng thái:** đã thống nhất
- **Quyết định:** Mỗi agent có branch riêng, một capability rõ ràng, tối đa 1–3 commit, không refactor ngoài phạm vi.
- **Lý do:** Dễ review, rebase, cherry-pick và merge.

## D-005 — Chốt thứ tự và vai trò của Đọc/Nghe

- **Ngày:** 2026-10-04
- **Trạng thái:** đã thống nhất
- **Quyết định:** Navigation mặc định là `Home — Đọc — Nghe — Hiểu — Nhớ`.
- **Lý do:** Đọc thường là nguồn nội dung nền để tra cứu, nghe, hiểu và ghi nhớ. Đây là thứ tự mặc định, không ngăn người dùng bắt đầu từ Nghe hoặc tùy chỉnh workspace gần nhất.

## D-006 — Dùng Đọc, không dùng Thấy làm workspace

- **Ngày:** 2026-10-04
- **Trạng thái:** đã thống nhất
- **Quyết định:** `Đọc` mô tả workspace xử lý nội dung chữ. `Thấy` không dùng làm nhãn workspace vì mô tả giác quan, không mô tả mục tiêu học tập.

## D-007 — Xem là media mode trong Nghe

- **Ngày:** 2026-10-04
- **Trạng thái:** đã thống nhất
- **Quyết định:** `Xem` không phải workspace cấp 1 và không mặc định thuộc `Hiểu`. Nó là media mode/source trong `Nghe`, có thể chuyển nội dung sang `Đọc`, `Hiểu` hoặc `Nhớ`.
- **Mô hình:** `Nghe → Nghe | Xem`; trong Xem có video, audio, phụ đề, transcript và các tool theo ngữ cảnh.
- **Lý do:** Xem thường là hành động tiếp nhận media; Hiểu là hành động phân tích/giải thích nội dung.

## D-008 — Chat là global nhưng contextual

- **Ngày:** 2026-10-04
- **Trạng thái:** đã thống nhất
- **Quyết định:** Chat là capability global, nhưng prompt, hành động gợi ý và dữ liệu context thay đổi theo workspace/tab/nội dung đang mở.
- **Lý do:** Giữ khả năng truy cập nhất quán nhưng tránh biến Chat thành một trải nghiệm chung chung.

## D-009 — Học thuộc thuộc workspace Nhớ

- **Ngày:** 2026-10-04
- **Trạng thái:** đã thống nhất
- **Quyết định:** `Học thuộc` là mode/sub-workspace quan trọng trong `Nhớ`, cùng với Ôn tập, Từ vựng, Bài tập và Thống kê. Có thể khởi tạo từ Đọc, Nghe, Xem hoặc Hiểu.
- **Lý do:** Học thuộc là phương pháp củng cố, không phải mục tiêu điều hướng cấp 1.

## D-010 — Chọn Google Stitch

- **Ngày:** 2026-10-04
- **Trạng thái:** đã thống nhất
- **Quyết định:** Dùng Google Stitch để tạo mockup nhanh theo từng nhóm: Shell, Workspace, Media flow và Learning flow.
- **Lý do:** Không dùng một prompt khổng lồ; thiết kế từng capability để dễ so sánh và giao việc.

## D-011 — Bắt đầu thiết kế bằng Global Shell

- **Ngày:** 2026-10-04
- **Trạng thái:** đang thực hiện
- **Quyết định:** Vòng mockup đầu tiên trong Google Stitch tập trung vào Global Shell: mobile, desktop, contextual Chat, Quick Actions và Command Palette.
- **Lý do:** Shell quyết định cách người dùng đi qua toàn bộ workspace; cần chốt trước khi thiết kế từng màn hình chi tiết.

## D-012 — Kết quả Stitch vòng 1 xác nhận Global Shell nhưng cần giảm mật độ

- **Ngày:** 2026-10-04
- **Trạng thái:** đã đánh giá, chờ revision mockup
- **Quyết định:** Giữ cấu trúc 5 workspace, responsive shell, contextual Chat, Quick Actions, Command Palette và Xem trong Nghe. Trước khi code cần giảm mật độ Reader, tách rõ Chat với Context Panel, và kiểm tra shortcut.
- **Lý do:** Mockup đã đúng kiến trúc nhưng có nguy cơ phơi bày quá nhiều metadata/tool cùng lúc.

## D-013 — Không nâng major version chỉ vì mockup UX

- **Ngày:** 2026-10-04
- **Trạng thái:** nguyên tắc phát hành
- **Quyết định:** Chưa chuyển lên 2.x chỉ vì thiết kế mới. Chỉ nâng major khi implementation tạo breaking change về navigation contract, public API, data migration hoặc behavior mà người dùng phải thích nghi lại.
- **Lý do:** Mockup và visual refresh không tự động là breaking release.

## D-014 — Chốt Global Shell sau vòng Stitch 2

- **Ngày:** 2026-10-04
- **Trạng thái:** đủ ổn định để chuyển sang wireframe Workspace
- **Quyết định:** Giữ kết quả Prompt 5 làm baseline Global Shell: Quick Actions tách khỏi Command Palette, sidebar tối giản, Reader minimal, Tool Panel tách khỏi Global Chat, Mini Player có state model và shortcut trung tính.
- **Lý do:** Các vấn đề lớn của vòng 1 đã được giải quyết; các điểm còn lại phù hợp hơn với prototype tương tác và kiểm thử trong workspace thật.

## D-015 — Sáu trạng thái Mini Player

- **Ngày:** 2026-10-04
- **Trạng thái:** baseline UX, cần kiểm chứng thiết bị
- **Quyết định:** Dùng các trạng thái Idle, Playing, Loading, Transcript, Collapsed và Expanded. Trên mobile phải tính theo safe area/bottom nav/keyboard thay vì khóa cứng khoảng cách 68px.
- **Lý do:** Player là thành phần xuyên workspace nhưng cần không che nội dung và không làm mất vùng chạm accessibility.

## D-016 — Home Command Center đạt baseline

- **Ngày:** 2026-10-04
- **Trạng thái:** đủ ổn định để chuyển sang Đọc
- **Quyết định:** Home trả lời ba câu hỏi: đang làm gì, nên làm gì tiếp, điều gì cần chú ý. Giữ một Continue Card chính, tối đa 3–4 Next Actions và Needs Attention nhẹ; không mở rộng thành dashboard nhiều card.
- **Lý do:** Giữ Home là command center yên tĩnh, không cạnh tranh với Global Shell hoặc các workspace.

## D-017 — Đọc Minimal Reader đạt baseline

- **Ngày:** 2026-10-04
- **Trạng thái:** đủ ổn định để chuyển sang Contextual Tool Panel
- **Quyết định:** Giữ Reader theo nguyên tắc Content as Sovereign: văn bản là trung tâm, tool panel đóng mặc định, progress nhẹ, vocabulary anchor tinh tế, selected-text action theo ngữ cảnh và không có dashboard/statistics mặc định.
- **Lý do:** Prompt 7 đã thể hiện đúng progressive disclosure mà không làm mất khả năng tra cứu, dịch, phát âm hoặc lưu vào Nhớ.

## D-018 — Contextual Tool Panel có interaction baseline 11 state

- **Ngày:** 2026-10-04
- **Trạng thái:** đủ chi tiết để làm interaction contract sau khi sửa các mâu thuẫn mobile
- **Quyết định:** Dùng 11 state làm baseline: desktop closed/dictionary/notes/SRS/pinned/preserved và mobile peek/expanded/keyboard/saved/dismissed. Không coi đây là một enum duy nhất; state được tạo từ các thuộc tính visibility, active tool, context anchor, scroll lock, keyboard và save feedback.
- **Lý do:** Đặc tả đã bao phủ visibility, primary actions, close gestures, preservation, overflow và keyboard avoidance.

## D-019 — Một surface đáy nổi tại một thời điểm trên mobile

- **Ngày:** 2026-10-04
- **Trạng thái:** nguyên tắc cần giữ
- **Quyết định:** Bottom navigation không bị che; Mini Player, Peek Dock và Bottom Sheet không được chồng gây mất vùng chạm. Khi một surface mở, các surface đáy khác phải thu gọn, ẩn hoặc được bố trí theo safe-area động.
- **Lý do:** Tránh mobile shell trở thành nhiều lớp nổi chồng nhau và bảo toàn navigation/accessibility.

## D-020 — Nghe Workspace đạt architecture baseline

- **Ngày:** 2026-10-04
- **Trạng thái:** đủ ổn định để đặc tả state chi tiết
- **Quyết định:** Giữ Nghe/Xem trong cùng workspace; phân biệt Select và Play; Continue Listening là primary action; Mini Player nằm trên bottom navigation; Expanded Player chứa transcript và tool theo ngữ cảnh.
- **Lý do:** Prompt 9 đã giải quyết đúng quan hệ giữa library, playback, transcript và shell mà không tạo thêm workspace cấp 1.

## D-021 — Audio Library có interaction baseline 14 state

- **Ngày:** 2026-10-04
- **Trạng thái:** đủ ổn định để chuyển sang Xem trong Nghe
- **Quyết định:** Dùng 14 state làm baseline cho Empty/Populated/Selected/Playing/Import/Expanded/Transcript/Pitch/A-B/Feedback. Giữ Select vs Play, Continue Listening, safe-area và capability fallback.
- **Lý do:** Đặc tả đã bao phủ đầy đủ flow chính và failure states mà không biến Audio Library thành dashboard kỹ thuật.

## D-022 — Xem trong Nghe đạt architecture baseline

- **Ngày:** 2026-10-04
- **Trạng thái:** đủ ổn định để đặc tả state detail
- **Quyết định:** Xem là media mode/source trong Nghe; giữ video, audio, subtitle và transcript trong cùng context; chỉ chuyển sang Hiểu qua hành động chủ động `Hiểu nội dung này`.
- **Lý do:** Prompt 10 giữ được media learning mà không tạo workspace cấp 1 thứ sáu.

## D-023 — Chế độ Xem có interaction baseline 14 state

- **Ngày:** 2026-10-04
- **Trạng thái:** đủ ổn định để chuyển sang Hiểu
- **Quyết định:** Đóng vòng UX Xem với 14 state: video minimal, transcript sync/manual, selected subtitle, Lexicon Inspector, handoff, subtitle modes, shadowing, reduced video và context preservation.
- **Lý do:** Đặc tả đã giải quyết bố cục desktop, immersion, transcript recovery, handoff và mobile ergonomics mà không tạo workspace mới.

## D-024 — Hiểu và Nhớ đạt architecture baseline, cần state detail

- **Ngày:** 2026-10-04
- **Trạng thái:** architecture đạt; chưa đóng interaction contract
- **Quyết định:** Giữ Hiểu là workspace có source context và AI Coach có cấu trúc; giữ Nhớ là workspace umbrella cho Ôn tập, Học thuộc, Từ vựng, Bài tập và Thống kê. Global Chat không bị trộn với AI Coach.
- **Lý do:** Prompt 11 và 12 đã chốt IA, nhưng cần đặc tả loading/error/session/keyboard/sync trước khi code.

## D-025 — Bổ sung coverage matrix cho prompt detail

- **Ngày:** 2026-10-04
- **Trạng thái:** đang thực hiện
- **Quyết định:** Theo dõi riêng architecture prompt và state/detail prompt. Không xem một mockup Desktop/Mobile tổng quan là đủ đặc tả cho implementation.
- **Lý do:** Các state ảnh hưởng navigation, data preservation, keyboard, safe area, loading/error và destructive action cần contract rõ.

## D-026 — Chuẩn hóa tên file prompt detail

- **Ngày:** 2026-10-04
- **Trạng thái:** đã thống nhất
- **Quyết định:** Mọi prompt detail từ nay phải có cả số prompt và số state trong tiêu đề/tên file, ví dụ `Prompt 11 Detail — 16 states`.
- **Lý do:** Chỉ dùng tên hệ thống làm người dùng khó tìm đúng prompt khi copy sang Stitch.

## D-027 — Global Shell và Home đạt interaction baseline

- **Ngày:** 2026-10-04
- **Trạng thái:** baseline đạt; cần chỉnh shortcut/data integrity trước code
- **Quyết định:** Global Shell có 18 state và Home có 14 state đủ để đóng UX baseline. Giữ 5 workspace, progressive disclosure, context return, safe-area và non-gamified Home.
- **Lý do:** Các state chính của shell/Home đã được mô tả; phần còn lại là chuẩn hóa shortcut, conflict sync, metadata và layer stacking.

## D-028 — Global Shell, Home và Đọc đã đủ coverage detail

- **Ngày:** 2026-10-04
- **Trạng thái:** interaction baseline hoàn chỉnh; UX Freeze còn chờ policy cross-cutting
- **Quyết định:** Coverage detail cho Global Shell (18), Home (14) và Đọc (16) đã đủ để bàn giao UX baseline. Trước khi code cần chốt shortcut registry, layer policy mobile, router/back policy, offline conflict, Focus Rhythm wording và semantic reading anchor.
- **Lý do:** Các màn hình/state đã được mô tả đầy đủ; phần còn lại là các policy dùng xuyên hệ thống.

## D-029 — Pre-Freeze Resolutions đã đóng 7 cross-cutting policies

- **Ngày:** 2026-10-04
- **Trạng thái:** UX Freeze candidate
- **Quyết định:** Chấp nhận 7 resolution về shortcut governance, mobile layer stacking, Replace/Split panel, hierarchical back, offline conflict, Calm Focus Rhythm và semantic anchoring làm hợp đồng kiến trúc trước production.
- **Lý do:** Các blocker xuyên hệ thống đã có policy thống nhất, không còn cần thêm mockup lớn.

## D-030 — Tách logic chức năng của baseline khỏi bố cục UX mới

- **Ngày:** 2026-10-08
- **Trạng thái:** quyết định đang áp dụng
- **Quyết định:** `origin/arena/01a0251e-in4up` là nguồn tham chiếu ưu tiên cho business logic, data flow, safety và các regression fix. Kiến trúc UX/UI mới của `arena/01a10675-in4up` có quyền tổ chức lại bố cục, entry point, panel, sheet và navigation để đạt progressive disclosure và trải nghiệm nhất quán.
- **Không được làm:** không copy nguyên si toolbar, action placement, sheet stacking hoặc navigation cũ chỉ vì chúng đã tồn tại.
- **Bắt buộc giữ:** semantics của chức năng, source context, data preservation, accessibility, failure recovery và test regression từ baseline.
- **Nguyên tắc:** preserve capability, redesign presentation. Nếu logic cũ gắn chặt với UI cũ, tách logic thành callback/service seam trước khi đưa vào UX shell mới.
- **Lý do:** nhánh 251e ưu tiên hoàn thiện chức năng/logic; dự án này đang ưu tiên UX architecture riêng, không biến UX mới thành lớp vỏ của giao diện cũ.

## D-031 — C-31 đóng bằng máy bắt 6 vùng, không bằng "đã review"

- **Ngày:** 2026-10-07
- **Trạng thái:** đang áp dụng
- **Quyết định:** State preservation QA (C-31) được coi là có bằng chứng chỉ khi có bộ kịch bản chạy được cho **cả 6 vùng** (source return, reading anchor, draft, playback, route return, offline event/conflict), và báo cáo nối vào `I4uQualityRun` của C-30. Vùng thiếu máy bắt ⇒ `uncoveredAreas` khác rỗng ⇒ **fail**, không được tính là đạt; việc chỉ kết luận được trên thiết bị thật nằm ở danh sách QA tay và không bao giờ tự động PASS.
- **Hệ quả:** một số hành vi trước đây được coi là "chi tiết triển khai" nay thành bất biến phải giữ: sự kiện hệ thống (nguồn đổi revision) không được xoá nháp người học; `source` của phiên ôn sống suốt phiên (rule vàng #3); lớp phủ đóng phải khôi phục đúng trạng thái Mini Player trước đó (`docs/ux/36` §2); conflict review chỉ đánh dấu "không tính mastery" chứ không xoá event.
- **Lý do:** nhánh nền `arena/01a10675-in4up` đỏ CI từ run 37682387649 vì lỗi cú pháp `main_shell.dart`; cả 8 run đều đỏ ở `Analyze full app` và **mọi bước test bị skip** — tức hợp đồng UX đợt trước chưa từng được máy kiểm chứng lần nào. Từ nay mỗi capability UX phải chứng minh bằng một lệnh chạy được, không chỉ bằng tài liệu.

## D-032 — C-30 tách bằng chứng "logic" khỏi bằng chứng "đo trên widget"

- **Ngày:** 2026-10-08
- **Trạng thái:** đang áp dụng
- **Quyết định:** Responsive/accessibility QA (C-30) chạy theo hai tầng bằng chứng: (1) kịch bản logic thuần bảo vệ **policy** (dải cỡ chữ, inset bàn phím, thứ tự lớp, ngưỡng breakpoint); (2) bằng chứng đo trên **widget thật** (nhãn semantics, kích thước vùng chạm, bàn phím che input, xoay máy). Vùng nào không thể kết luận bằng logic (`screen-reader-labels`, `touch-targets`) thì **chỉ** được tính khi có bằng chứng widget; thiếu bằng chứng ⇒ `isComplete = false` và là blocker, không phải pass rỗng.
- **Hệ quả:** một báo cáo C-30 xanh mà không chạy widget test là báo cáo giả — test tự kiểm điều này. Kèm luật đo: nút icon phải kiểm **cả** kích thước lẫn `MaterialTapTargetSize` (M3: 40×40 widget + padded ⇒ vùng chạm 48), không chỉ nhìn một con số.
- **Lý do:** C-31 đã chứng minh giá trị của máy bắt; nhưng a11y/responsive không thể suy ra từ số học. Đồng thời C-30 phát hiện policy C-02 (`AppResponsive`/`I4uSafeAreaPolicy`/`I4uOverlayPolicy`) **chưa được nối vào app** — điều này sẽ bị che mất nếu chỉ kiểm widget theo cách "chạy được là xanh".

## D-033 — Chrome shell: bọc `uiText` + đăng ký English ở cả hai đường catalog

- **Ngày:** 2026-10-08
- **Trạng thái:** đang áp dụng
- **Quyết định:** 7 nhãn chrome hard-code trong `lib/widgets/shell/` (command palette + global chat)
  được bọc `context.uiText(...)` và đăng ký English ở **cả hai** nơi: `priority_ui_overrides.dart`
  (đường runtime — `AppUITranslations.translate` đọc map này trước) và
  `tool/legacy_ui_english_overrides.json` (nguồn của generator `.dart`). Chỉ đăng ký `en`.
  Nội dung user/AI trong chat render bằng `material.Text` (import có tiền tố) để **không** bao giờ
  đi qua cơ chế dịch chrome.
- **Hệ quả:** kiểm bằng `test/shell_chrome_i18n_coverage_test.dart` (3 tầng: nguồn phải bọc; catalog
  phải dịch được ở mọi locale ≠ vi; runtime ở locale `en` không còn ký tự Việt). Test C-30 ghim
  `locale: vi` — đo chrome, không đo dịch.
- **Lý do:** bước CI *"Rule 5 test"* chỉ quét catalog đã sinh, nên literal hard-code trong widget là
  điểm mù thật (C-30 §4.2 tìm ra nó). Đăng ký ở `priority_ui_overrides` sửa được runtime ngay;
  ghi thêm vào JSON nguồn để khi generator sống lại (card `I18N-001`) thì hai đường không lệch nhau.
  Chỉ `en` theo tiền lệ 15 key Tipiṭaka: rule #5 quy định fallback là English, không bịa bản dịch T2
  chưa ai review.

## Câu hỏi mở hiện tại

- O-001: Review/Stats là Context Bar hay sub-workspace của Nhớ?
- O-002: Shortcut Registry schema và precedence đã đủ để triển khai chưa?
- O-003: SRS event merge/scheduler deterministic rule sẽ được đặc tả ở model nào?
- O-004: Reading anchor fallback khi source revision thay đổi sẽ dùng fingerprint/search mức nào?
- O-005: UX Freeze được chốt sau khi hoàn thành component/capability breakdown hay ngay bây giờ?
- O-002: Pitch/IPA engine hỗ trợ những nguồn audio nào và hiển thị fallback ra sao?
- O-003: Offline audio và transcript sync được biểu diễn ở mức nào trong Library?
- O-004: Transcript selection trong Expanded Player mở popover, Context Panel hay Tool Panel của Đọc?
- O-005: Xem mặc định dùng Original only hay nhớ subtitle mode gần nhất?
- O-006: Shadowing lưu bản thu ở đâu và hiển thị feedback ở tầng nào?
- O-002: Khi Notes đang nhập mà selection/context thay đổi, hỏi xác nhận hay giữ context cũ?
- O-003: State Saved nên là sheet giữ nguyên hay toast sau khi sheet đóng?
- O-004: Shortcut registry chính thức sẽ được chốt ở giai đoạn nào?
- O-002: Bảng shortcut chính thức nào không xung đột với browser/OS?
- O-003: Khi Chat và Context Panel cùng được yêu cầu, dùng replace, split hay một surface có tab?
- O-004: Mini Player Idle có hiển thị persistent hay chỉ hiện entry point khi có audio gần đây?
- O-005: Các điểm neo tối giản trong Reader cần affordance nào để không bị ẩn?
- O-002: Quick Actions và Command Palette là một surface với hai cách mở, hay hai surface khác nhau?
- O-003: `Nghe | Xem` hay `Âm thanh | Video` là nhãn Context Bar phù hợp hơn?
- O-004: Chat trên desktop mặc định là panel phải hay mở dạng overlay?
