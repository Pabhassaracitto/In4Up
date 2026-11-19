# ADR-0033 — Tab Đọc: kết quả dịch hiện ngay, một thứ tự engine dùng chung

- **Ngày:** 2026-11-19
- **Trạng thái:** triển khai trên `arena/804287f0-in4up`, đề nghị review qua PR;
  **chờ nghiệm thu máy**, không tự merge/phát hành.
- **Nguồn:** owner, audit v1.29.0 mục 6, Prompt Agent 4.
- **Đối chiếu:** [PSRC-191](https://linear.app/in4up/issue/PSRC-191/sap-xep-giao-dien-translation-engines-gon-va-de-nhin)
  đã Done (2026-11-12). Giữ `EngineSheetSection`, nhóm gói offline mở sẵn,
  nhóm nâng cao thu gọn, tải gói sống ngoài sheet, validate DeepLX trước Lưu.
  Không nhập lại hay viết lại phần PSRC-191 đã có trên base.

## Bằng chứng từ mã nền

Chưa tái hiện trên thiết bị trong sandbox (không có Flutter SDK / Android).
Các nhánh lỗi có thể quan sát trực tiếp trên base `7a5f446`:

1. `TranslationMixin.translateLine()` ghi `line.translation` nhưng không đổi
   `translationDisplayMode`; một dòng dịch xong có thể vẫn `hidden`.
2. `translateAll()` mở `stackedBelow` **sau** vòng lặp, không phải từ đầu lượt;
   kết quả đầu đã có nhưng chưa nhìn thấy khi phần còn lại còn chạy.
3. `TranslationService.routingOrder` chỉ là danh sách viết riêng; thiếu vị trí
   LLM thực tế, không có thứ tự người dùng. `lastUsedEngine` là trạng thái
   singleton, có thể thuộc một yêu cầu khác.
4. Sheet PSRC-191 đã có nhóm và trạng thái/model: chỉ cần bổ sung điều khiển
   ưu tiên vào cấu trúc đó, không cần thiết kế lại sheet lần nữa.

## D1 — Dịch là ý định xem kết quả

- Lượt dịch một dòng và cả bài đều mở `stackedBelow` **trước await đầu tiên**
  nếu bố cục đang ẩn. Giữ lựa chọn `sideBySide` và làm mờ do người dùng đặt.
- Có kết quả dòng đầu thì thông báo cho UI ngay, không chờ đủ 5 dòng.
- Người dùng chủ động ẩn trong lúc chạy thì hoàn thành **không bật lại**.
- Lượt bấm Dịch khi đã có bản dịch vẫn mở lại phần kết quả, không gọi engine
  thừa. Không tạo một provenance giả cho bản dịch nạp từ nguồn bên ngoài.
- Trạng thái hữu hạn: idle / translating / succeeded / partial / failed /
  cancelled; đếm số dòng thành công/lỗi của lượt. Huỷ/đổi tài liệu làm vô hiệu
  kết quả còn đang bay. Lỗi model giữ nguyên thông tin, không tự kết luận là
  lỗi mạng sau 5 lần thất bại.

## D2 — Kéo thả phù hợp, nhưng không phải registry provider mới

Dùng danh sách đánh số + tay nắm kéo như cài đặt giọng đọc, thêm nút lên/xuống
cho bàn phím/trợ năng. Danh sách nằm trong một `EngineSheetSection` **đóng sẵn**;
ô chọn engine ưu tiên hiện ngay trên thanh dịch và đầu sheet.

- Chỉ sắp các engine **đã đăng ký**: DeepLX (khi có endpoint hợp lệ), Google,
  MyMemory, Libre, Hy-MT, ML Kit, LLM API hiện có. Không thêm nhà cung cấp.
- Từ điển là last resort cố định; không kéo lên trước engine dịch câu.
- Khi chưa tuỳ chỉnh: giữ thứ tự mặc định và vị trí LLM theo Server & API.
- Sau khi tuỳ chỉnh: thứ tự ID tường minh quyết định ưu tiên, kể cả giữa
  online/offline; ràng buộc **Chỉ offline**, lựa chọn Hy-MT/ML Kit cũ và
  provider/routing LLM tắt vẫn có hiệu lực. Thứ tự không phải lệnh tải model.
- Chọn Google/engine online là thao tác **tường minh tắt Chỉ offline** (có gợi
  ý ngay dưới ô chọn). Kéo thả **không** tắt ràng buộc mạng đó.
- Chọn Hy-MT/ML Kit đưa nó lên đầu, trả lựa chọn engine offline cũ về Auto
  để vẫn có fallback. Không tự tải model hay gọi endpoint để dựng danh sách.
- “Khôi phục thứ tự tự động” bỏ custom order, không thay đổi cổng Chỉ offline.

## D3 — Một nguồn cấu hình, một chuỗi thực thi

`TranslationService` phát thay đổi bằng `ChangeNotifier`; toolbar và mọi
`TranslationEngineSettingsSheet` (kể cả nơi mở sheet dùng chung) quan sát chính
service đó. `_routingEngines` là nguồn cho cả nhãn `routingOrder` và thực thi,
không giữ một bản thứ tự trong State của mỗi màn.

- Khoá mới: `translation_engine_priority_v1`, `List<String>` ID ổn định.
  Loại trùng/ID đã bỏ, nối các ID hợp lệ còn thiếu, không tạo engine từ ID lạ.
- Giữ khoá cũ `translation_offline_only`, `translation_offline_engine`,
  `translation_deeplx_url`; không phá cấu hình đang có.
- Chỉ đọc khởi tạo một lần; request đợi cùng `settingsReady`. Cờ sửa theo
  từng trường tránh đọc chậm ghi đè thao tác mới. Hàng đợi ghi tuần tự tránh
  kéo nhiều lần rồi khởi động lại về thứ tự cũ. Trường chưa sửa không bị
  bản ghi sớm ghi đè bằng default.
- Đây là cấu hình **cục bộ thiết bị** như trước, không thêm giao thức đồng bộ
  tài khoản/cloud. Một Flutter isolate khác đọc cấu hình khi khởi tạo/warm-up;
  không tuyên bố có phát sự kiện live xuyên isolate/thiết bị.
- Cache tag bao gồm thứ tự, chính sách offline, endpoint và route/provider/model
  LLM hiện có (không lấy key/header). Đổi ưu tiên phải dịch lại, không lấy bản
  của engine cũ. Mỗi request chụp cùng thứ tự/tag cho các mẩu và bước pivot,
  không gán nhầm kết quả đang bay vào cache của cấu hình mới.
- Snapshot này **không đóng băng toàn bộ backend**: LLM vẫn tự resolve provider
  ở trong engine; cổng Chỉ offline đọc live để chặn các lời gọi online tiếp
  theo khi người dùng vừa bật nó. Không hứa hủy tức thì request đã gửi.

## D4 — Phân biệt ưu tiên, đang chạy và kết quả thực tế

`TranslationResult.route` bổ sung provenance theo **request**: ID/tên ưu tiên,
engine thực tế, danh sách đã thử, cờ fallback. Không đọc singleton “lần trước”
để giải thích một dòng kết quả. Truyền provenance qua glossary, pivot và nội
dung hỗn hợp; giữ `engineName` cũ để caller khác không bị đổi hợp đồng.

- Toolbar: ô ưu tiên luôn thấy; lúc chạy hiện trạng thái/engine hoạt động;
  thành công hiện engine trả kết quả; fallback hiện `ưu tiên → thực tế`.
- Lỗi không bị cắt còn một dòng; có nút thử lại. Thành công một phần không
  bị coi là hoàn tất thành công.
- Cache hiện rõ “không chạy engine”. Cache cũ chỉ lưu văn bản, **không biết**
  engine gốc; không tự nhận nó là engine đang được chọn. Không đổi định dạng
  cache trong lane này.
- Timeout hữu hạn giữ budget cũ cho online / ML Kit / Hy-MT / LLM. Engine ném
  lỗi, thiếu model, trả nguyên văn hoặc mất mạng đều đi tiếp theo thứ tự hợp lệ.

## D5 — Ranh giới từ/IPA và review

Không sửa `lib/screens/read_mode/widgets/text_line_widget.dart`,
`word_tap_plain_text.dart`, `colored_text_widget.dart`, dịch vụ IPA hay từ điển.
Phần `TranslationLineDisplay` và các class bên dưới trong toolbar giữ nguyên
byte-for-byte so với base. Test tích hợp dùng **TextLineWidget thật**, tiêm
provider/IPA/audio giả, kiểm đủ hidden / activeLine / all và stacked / side-by-side.

Các file cần phối hợp khi land: `translation_toolbar.dart` (chỉ toolbar/sheet),
`text_provider_translation.dart`, `translation_service.dart`,
`engines/translation_engine.dart`, `engines/llm_mt_prompts.dart`,
`core/language/priority_ui_overrides.dart` (import + spread map riêng) và helper
chẩn đoán CI `scripts/ci/emit_failure_annotation.py`.

- Giữ cấu trúc PSRC-191. Test sheet thật ở 320px phát hiện thêm ListTile cần
  Material phía trên decoration và hàng probe bị tràn; chỉ sửa hai điểm này,
  không thay cách chia nhóm/tải model.
- `llm_mt_prompts.dart`: sửa `replaceAll(..., r'$1')` thành `replaceAllMapped`
  để không biến bản dịch có Markdown thành chữ `$1`; có test chữ/slot bảo vệ.
- Test thật của renderer/shell dùng `debugSetInstance` trả service giả, không
  khởi tạo Hive/provider/native/timer chỉ vì một getter hiển thị. Chờ hoàn tất
  công việc cache trước khi kiểm widget; không sửa renderer để chiều test.
- Job riêng ở `.github/workflows/read_translation_tests.yml`.
  **`app_analyze.yml` giống hệt base**, tránh đụng oracle hub giữ độc quyền.
  Chẩn đoán giữ tên tất cả test lỗi + Expected/Actual, trong giới hạn byte UTF-8
  và số annotation; 4 test Python khóa hành vi này, không nuốt exit code test.

Không sửa KANBAN/PLAN, version, native/FFI, tag/release.

Kiểm thử và checklist máy: `docs/project/AUDIT_1_29_0_AGENT4_TRANSLATION.md`.
