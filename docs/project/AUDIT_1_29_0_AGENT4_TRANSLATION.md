# Audit v1.29.0 §6 — Agent 4: dịch và thứ tự ưu tiên engine

## Bàn giao

- Nhánh: `arena/804287f0-in4up`.
- Base được giao: `7a5f446cf0e1e1f32892be5d9a758408150a7e63` của
  `arena/60e35d65-in4up`. PR **vào hub đó**, không vào main/251e.
- Đây là **Agent 4 của audit v1.29.0**, không phải sửa lại lane L4 bong bóng
  dịch của audit v1.28.0.
- Trạng thái: **lane hồi quy dịch và oracle tổng xanh; chờ nghiệm thu máy**.
  Không merge, tag, release hay tự xuất bản. Không đổi version/KANBAN/PLAN/
  tài liệu hub.
- Quyết định chi tiết: [ADR-0033](../adr/0033-read-translation-engine-priority.md).

## Đã đối chiếu / phạm vi

[PSRC-191](https://linear.app/in4up/issue/PSRC-191/sap-xep-giao-dien-translation-engines-gon-va-de-nhin)
đã Done ngày 2026-11-12. Phần có sẵn là chia nhóm sheet, gói offline mở sẵn,
nhóm nâng cao thu gọn, tải gói sống ngoài sheet và kiểm tra URL khi Lưu.
Giữ nguyên phần đó; bổ sung một nhóm **ưu tiên engine đóng sẵn**, không làm
lại giao diện PSRC-191 và không đổi trạng thái issue.

Không thêm provider, không tải model tự động. Registry engine/API/URL vẫn là
các engine và cấu hình đã có trên base.

### Chứng cứ trước sửa (đọc code, chưa tái hiện máy)

- Base `translateLine()` ghi bản dịch nhưng không mở chế độ hiện kết quả.
- Base `translateAll()` chỉ mở `stackedBelow` sau khi dịch hết bài.
- `routingOrder` cũ là một danh sách khác chuỗi thực thi, không có thứ tự
  người dùng; UI chỉ có `lastUsedEngine` singleton, không có provenance theo
  yêu cầu.
- Sandbox không có Flutter/Dart SDK hoặc Android/Linux GUI. Không có ảnh,
  logcat hay tuyên bố đã kiểm thử thiết bị; bảng AT dưới đây là các bước cần
  người nghiệm thu chạy trên bản build từ hub.

## Thay đổi hành vi

1. Dịch một dòng/cả bài mở kết quả **trên–dưới trước await đầu tiên** nếu đang
   ẩn; giữ lựa chọn hai cột và làm mờ đã đặt. Lượt dịch không bật lại kết quả
   nếu người dùng chủ động ẩn trong lúc chờ.
2. Có trạng thái đang dịch/thành công/một phần/thất bại/đã dừng; số dòng
   thành công/lỗi, chi tiết lỗi xuống dòng và thử lại. Dòng đầu thành công
   thông báo ngay, kể cả trước đó đã có dòng lỗi. Huỷ/đổi tài liệu/dispose
   không áp kết quả đang bay lên tài liệu mới.
3. Cùng một ô chọn engine ở toolbar và sheet dùng chung. Chọn Google/online
   là ý định tường minh rời “Chỉ offline”; kéo thả chỉ đổi ưu tiên, không tự
   cho phép mạng.
4. Kéo tay nắm hoặc dùng nút lên/xuống; lưu ID vào
   `translation_engine_priority_v1`, chuẩn hoá ID cũ/trùng, khôi phục được
   thứ tự tự động. Từ điển cố định cuối. Ràng buộc model offline và chính
   sách Server & API vẫn có hiệu lực.
5. Phân biệt engine ưu tiên với engine trả kết quả theo **request**; fallback
   không sửa lại lựa chọn người dùng. Giữ provenance qua glossary, pivot và
   dòng hỗn hợp. Cache cũ chỉ có văn bản: hiện rõ “không chạy engine”, không
   bịa tên engine gốc.
6. Cùng một snapshot **thứ tự/tag** cho cache, các mẩu câu và bước pivot trong
   một request. Ưu tiên mới áp dụng từ request sau; bật Chỉ offline vẫn ngăn
   các lượt gọi online tiếp theo. Đổi route/model LLM hiện có không trả cache
   của cấu hình trước. Không hứa đóng băng mọi cài đặt backend: LLM vẫn tự
   resolve provider bên trong engine.

## File chung cần hub / agent từ–IPA phối hợp

| File | Phần sửa | Phần không sửa |
|---|---|---|
| `lib/features/translation/translation_toolbar.dart` | toolbar, listener service, sheet/picker/nhóm priority | **từ `class _TranslateButton` trở xuống giữ nguyên byte-for-byte** so với base, gồm `TranslationLineDisplay` |
| `lib/features/translation/text_provider_translation.dart` | vòng đời lượt dịch, hiện kết quả, trạng thái và seam test | hợp đồng chọn nguồn/đổi vai PSRC-237/238 giữ nguyên |
| `lib/features/translation/translation_service.dart` | một thứ tự dùng chung, persistence/snapshot/cache/provenance | không thêm engine/provider, không tải model |
| `lib/features/translation/engines/translation_engine.dart` | metadata kết quả bổ sung, tuỳ chọn | constructor/caller cũ vẫn hợp lệ |
| `lib/core/language/priority_ui_overrides.dart` | import + spread map của lane | không sửa các bản dịch đã có |
| `lib/features/translation/engines/llm_mt_prompts.dart` | sửa thay nhóm regex bằng literal `$1` làm mất bản dịch có Markdown | không đổi prompt/provider/backend |
| `.github/workflows/read_translation_tests.yml` | workflow/job độc lập của lane; **`app_analyze.yml` không còn diff so với base** | không bỏ/tắt cổng cũ, không chạm publish |
| `scripts/ci/emit_failure_annotation.py` | giữ lỗi Flutter trước/sau `[E]`, giới hạn byte UTF-8, escape newline; 4 test Python | lỗi test vẫn trả exit code thật; nhánh lỗi build cũ vẫn giữ |
| `test/yt_audit_2026_10_20_batch1_test.dart` | thay pin “4 bản sao guard” bằng pin guard chung trước nhánh nhận kết quả | giữ kiểm tra không nhận nguyên văn và log bỏ qua |
| `test/deeplx_engine_test.dart`, `test/llm_mt_engine_test.dart` | fixture HTTP khai UTF-8 bằng content-type; fake trả bản dịch, không echo; case no-network có provider thật sự | không sửa network/parser để chiều fixture latin1 |
| `test/translation_glossary_test.dart`, `test/translation_source_language_test.dart` | fake dịch sang ngôn ngữ đích, vẫn giữ slot và marker nguồn | không nới guard nhận nguyên văn, không bỏ assertion nguồn/model |
| `test/read_mode/psrc_237_role_swap_test.dart`, `psrc_238_source_language_test.dart` | pin guard cho phép xuống dòng; pin error chrome ở panel mới | giữ đủ 5 call-site chặn đổi vai và ưu tiên gợi ý cặp trùng |
| `test/linux_shell_regression_test.dart`, `translation_ipa_integration_test.dart` | singleton factory cùng service giả, tránh IO/timer thật trong widget tests | không sửa shell/renderer để chiều test |

**Không sửa** `text_line_widget.dart`, `word_tap_plain_text.dart`,
`colored_text_widget.dart`, renderer IPA, dịch vụ từ điển, provider TTS/native/FFI.
Test tích hợp dựng `TextLineWidget` thật với các dependency giả, không chỉ
kiểm tra một wrapper có nhãn IPA tự đặt.

## Kiểm thử tự động

### Lệnh CI của lane

Job `read-translation-regressions` trong workflow riêng
**`Read translation regression tests`**
(`.github/workflows/read_translation_tests.yml`), Flutter 3.44.1; bước test
timeout 6 phút, job 12 phút. Trả nguyên exit code, không `|| true`, không bỏ
qua file test bị thiếu. Log artifact: `read-translation-test-log`.
`app_analyze.yml` được trả về **giống hệt base** để tránh chồng sửa oracle hub.

```sh
flutter test \
  test/translation/engine_priority_test.dart \
  test/read_mode/translation_result_visibility_test.dart \
  test/read_mode/translation_ipa_integration_test.dart \
  test/read_mode/translation_blur_test.dart \
  test/translation_cache_engine_test.dart \
  test/translation_glossary_test.dart test/llm_mt_engine_test.dart \
  test/deeplx_engine_test.dart test/translation_source_language_test.dart \
  test/read_mode/psrc_237_role_swap_test.dart \
  test/read_mode/psrc_238_source_language_test.dart \
  test/translation/engine_sheet_layout_test.dart \
  test/yt_audit_2026_10_20_batch1_test.dart \
  test/linux_shell_regression_test.dart \
  --concurrency=1 -r expanded
```

Coverage mới: hiện trước khi engine hoàn thành; giữ hai cột/blur; hiển thị
thành công/một phần/lỗi/thử lại/huỷ; bỏ kết quả trễ/dispose/đổi đích từ nơi
khác; cập nhật ngay dòng thành công đầu; priority thật sự đổi thứ tự chạy;
round-trip/ghi nhanh/khởi tạo chậm; hai picker đồng bộ; drag và nút thay thế;
offline→Google; thiếu model/mất mạng/exception/timeout/nguyên văn; LLM policy
và custom priority; snapshot trước model readiness; provenance hỗn hợp và
cache; sheet PSRC-191 đóng/mở lại; **renderer thật × 3 chế độ IPA × 2 bố cục**
ở 320px; bản dịch UI en/hi/zh/zh_TW/si + English fallback cho JA.

### Bằng chứng / kết quả

**Mã được xác nhận: `5a7194a2b3eba4fde444cf8f11a996a773ac9668`.**
Tài liệu bàn giao được commit riêng sau đó; không thay mã đã test.

- **Lane dịch xanh:**
  [44558482506](https://github.com/Pabhassaracitto/In4Up/actions/runs/44558482506),
  job `135680931525`, 1m30s. Cả bước self-test chẩn đoán (4 ca Python) và
  lệnh **14 file Flutter ở trên** đã chạy thành công, không phải skipped.
- **Oracle tổng xanh, 4/4 job:**
  [44558482389](https://github.com/Pabhassaracitto/In4Up/actions/runs/44558482389).
  `analyze-and-locale-test`, `knowledge-regressions`, `vocabulary-tools` và
  `web-build-validation` đều **success**. Gồm full-app analyze, Rule 5 locale,
  Linux shell, Read actions + mixed-language, PSRC-237/238, API/Hy-MT, dịch
  màn hình và các cổng hồi quy có sẵn; không bỏ/tắt step để làm xanh.
- **Build web xanh, không publish:**
  [44558482452](https://github.com/Pabhassaracitto/In4Up/actions/runs/44558482452).
  Bước **Publish to gh-pages skipped**. Guard main-only của base giữ nguyên;
  lane không sửa workflow deploy và không chạy phát hành thủ công.
- Workflow VieNeu arm64 tự chạy do path helper CI:
  [44558482272](https://github.com/Pabhassaracitto/In4Up/actions/runs/44558482272),
  **còn chạy tại checkpoint**; không sửa native/FFI, không coi job này là
  bằng chứng đã thử app hay model dịch trên thiết bị.
- Local: `git diff --check`; parse YAML + `bash -n` lệnh workflow; parser
  Dart WASM; `python3 -m unittest discover -s test -p test_ci_failure_annotations.py`
  **4/4** và `python3 test/test_import_tipitaka.py` **1/1**.
  Local parser **không tương đương** Flutter analyze/test/compiler.

Các CI đỏ trung gian đã được dùng làm bằng chứng sửa lỗi, không che đi:
UTF-8 của HTTP fixture; echo nguồn bị guard từ chối; getter singleton khởi
IO/timer khi test renderer; drag/drop cần frame; source-pin PSRC-237/238 cần
nhận xuống dòng và error panel mới. Run riêng cuối ở trên đã xanh sau các sửa
đó. Giữ đủ guard/expectation, không bỏ test hay hạ điều kiện để né lỗi.

### i18n / file hub giữ

Nhãn lane nằm trong `translation_ui_labels.dart`: English + hi/zh/zh_TW/si,
đăng ký runtime qua priority map có sẵn, mọi chỗ render dùng `uiText`/shim.
Tái dùng “Online” và “Đã dừng dịch” đã đăng ký, không khai trùng const map.
Không sửa ARB/JSON/native generated pack do hub giữ độc quyền. Hub có thể
nhập map này vào catalog chung khi tích hợp; không cần đoán bản dịch.

`python3 tool/generate_legacy_ui_fallbacks.py` đang dừng bởi **875 reviewed
overrides không còn khớp extractor**; tái chạy với các nguồn Dart đã sửa được
thay bằng nội dung base vẫn cùng lỗi. Không xoá override hay nới generator
để làm xanh giả; không coi kiểm generator là đã đạt.

## Nghiệm thu máy — tất cả còn chờ

Ghi rõ nền tảng, thiết bị, commit/build, thời gian và ảnh/log khi tick.

- [ ] **Hiện mặc định:** mở bài EN→VI, đặt Ẩn, dịch một dòng rồi cả bài.
      Kết quả nằm dưới nguồn ngay khi dòng đầu về; trạng thái chạy → xong.
- [ ] **Lựa chọn người dùng:** hai cột + làm mờ vẫn giữ; chủ động ẩn khi đang
      dịch thì kết thúc vẫn ẩn. Bấm Dịch lần sau mở lại bản đã có.
- [ ] **Chuyển engine:** Chỉ offline + cặp thiếu model/không có từ điển phù
      hợp → lỗi rõ; chọn Google ở toolbar tắt Chỉ offline và dịch được khi có
      mạng. Sheet phản ánh ngay.
- [ ] **Fallback:** ưu tiên ML Kit/Hy-MT thiếu model, cho phép online → kết
      quả chỉ đúng engine thực tế, nhãn ưu tiên không bị tự đổi.
- [ ] **Lưu thứ tự:** kéo ML Kit lên trước Google; đóng/mở sheet, chuyển màn
      dùng sheet chung, khởi động lại app: thứ tự vẫn đúng. Kiểm cả nút lên/xuống.
- [ ] **Cổng mạng:** kéo Google lên đầu không tự tắt Chỉ offline; bật Chỉ
      offline không gửi request API; provider/routing LLM tắt vẫn được tôn trọng.
- [ ] **Cache:** dịch cùng câu, đổi priority/model API, dịch lại: không nhận
      cache của cấu hình trước; cache hit không tự nhận engine đang được chọn.
- [ ] **Lỗi/huỷ:** tắt mạng, endpoint lỗi, thử lại; huỷ/đổi tài liệu/rời Đọc
      khi đang chạy: không spinner vô hạn, không bản dịch cũ chèn sang bài mới.
- [ ] **Từ/IPA:** IPA Ẩn/Dòng hiện tại/Tất cả × trên–dưới/hai cột; dịch một
      dòng/cả bài, tra từ và đổi vai như cũ; không mất văn bản/IPA.
- [ ] **Giao diện:** 320px/landscape/font lớn; lỗi và engine dài không overflow.
      EN + JA (fallback), hi/zh/zh_TW/si: chrome mới không còn tiếng Việt;
      văn bản nguồn tiếng Việt và output engine vẫn giữ nguyên.

## Giới hạn / rủi ro còn lại

- Chưa đo chất lượng/tốc độ Hy-MT, ML Kit, Google hoặc provider LLM trên máy
  thật; fake engine chứng minh routing/hiển thị, không chứng minh model chạy.
- Huỷ vô hiệu kết quả ở phía tài liệu; không hứa dừng ngay một lời gọi native
  đang chạy, không chạm FFI để giết worker. Budget engine cũ vẫn hữu hạn.
- Thứ tự là cấu hình cục bộ thiết bị. Các nơi trong cùng isolate dùng chung
  notifier; worker/isolate khác đọc preference khi khởi tạo/warm-up như trước.
  Không thêm cơ chế phát sự kiện xuyên isolate hoặc đồng bộ tài khoản/cloud.
- Cache cũ không lưu provenance: hiện đúng giới hạn đó thay vì suy engine gốc.
- Hub giữ KANBAN/PLAN, i18n tổng, version và quyền land/phát hành. Chỉ tick
  trạng thái tương ứng bằng chứng; **không tự chuyển Done** khi còn chờ máy.
