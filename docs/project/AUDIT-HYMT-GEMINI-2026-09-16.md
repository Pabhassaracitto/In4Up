# Audit nhận định Gemini — Hy-MT GGUF

- Ngày: 2026-09-16
- Card liên quan: `HYMT-002`, `HYMT-001`
- Files đã kiểm tra:
  - `lib/features/translation/engines/hymt_engine.dart`
  - `lib/features/translation/translation_service.dart`
  - `packages/in4up_ai/lib/src/engine/ai_native_bindings.dart`
  - `docs/project/KANBAN.md`

## Kết luận nhanh

| Nhận định | Đúng tới đâu | Kết luận |
|---|---|---|
| GGUF/llama.cpp không được chạy trên main isolate | Đúng về nguyên tắc; code Hy-MT hiện đã làm phần chính này | Không cần chuyển lại sang `compute()` một cách máy móc |
| Có thể dùng `compute()` cho Hy-MT | Không phải lựa chọn tốt cho model sống lâu + FFI handle | Giữ `Isolate.spawn` chuyên dụng, bổ sung protocol/health/queue |
| Hy-MT hiện timeout khoảng 15–18 giây | Không đúng với code hiện tại | Hy-MT đang có timeout 2 phút ở engine và 2 phút ở service; 15 giây là warm-up của Gemma, không phải Hy-MT |
| Chỉ cần tăng timeout | Chưa đủ | Cần queue, request id, phát hiện isolate chết, retry có giới hạn và chunk text |

## 1. Phần background worker/isolate

Phần lõi đã có sẵn:

- `hymt_engine.dart` import `dart:isolate`.
- `ensureLoaded()` tạo isolate bằng `Isolate.spawn(_isolateEntry, ...)`.
- `_isolateEntry()` mới gọi:
  - `AiNativeBindings.tryLoad()`;
  - `native.create(...)` để load model GGUF;
  - `native.generate(...)` để suy luận.
- `AiNativeBindings.create()` và `AiNativeBindings.generate()` không được gọi
  trực tiếp từ UI widget.
- `threads: 4`, `contextSize: 2048`, `maxTokens: 512` hiện đã được truyền ở
  đường Hy-MT native.

Vì vậy, nhận định “Hy-MT đang chạy toàn bộ inference trên main thread” **không
phù hợp với source hiện tại**. `compute()` cũng không nên được dùng thay thế
một cách đơn giản: model/FFI handle không nên serialize qua `compute`, còn
model 600 MB nên được giữ trong một isolate chuyên dụng.

Có một điểm cần audit thêm: `AiNativeBindings.tryLoad()` được gọi ở main isolate
bởi `isAvailable()` và đầu `translate()`. Hàm này chỉ mở dynamic library và lookup
symbol, chưa gọi `create()`/`generate()` nên chưa phải load GGUF. Tuy nhiên agent
bổ sung phải xác nhận trên từng nền tảng rằng dynamic library open không khởi tạo
model hoặc chạy inference; nếu không chắc, chuyển capability check về handshake
của Hy-MT isolate.

## 2. Timeout thực tế

Code hiện tại không có timeout 15–18 giây cho Hy-MT:

- `ensureLoaded()`:
  - handshake SendPort: `45 seconds`;
  - chờ native `create()` hoàn tất: `2 minutes`.
- `HyMtEngine.translate()` chờ reply native: `2 minutes`.
- `TranslationService._runEngineChain()` bọc Hy-MT thêm một timeout: `2 minutes`.
- HTTP download Hy-MT có `connectTimeout 45 seconds`, `receiveTimeout 60 minutes`;
  đây là timeout tải file, không phải timeout inference.
- `packages/in4up_ai/.../ai_engine_gemma.dart` có warm-up timeout `15 seconds`,
  nhưng đó là Gemma/AI Chat, không phải Hy-MT.
- Online translation chain có timeout `12 seconds`, cũng không phải Hy-MT.

Do đó, thông báo owner “Timeout Hy-MT” hiện có thể xuất hiện sau khoảng 2 phút,
hoặc sau một request/isolate trước đó bị kẹt. Không nên sửa bằng cách tìm một
con số 15–18 giây không tồn tại trong Hy-MT.

## 3. Phần chưa được giải quyết

Dù đã có isolate, source hiện tại vẫn còn các lỗ hổng mà Gemini chỉ ra gián tiếp:

1. `_isolateEntry()` nhận `_Req` nhưng không có request id, busy state, heartbeat
   hoặc thông báo `started/done`.
2. Nếu native generate kẹt hoặc isolate chết, `reply.first` chỉ chờ tới timeout;
   không có `addOnExitListener`/restart/retry riêng cho Hy-MT.
3. `_sendPort` có thể còn khác null sau khi isolate gặp lỗi cho tới khi request
   timeout; request sau không có health check chắc chắn.
4. `HyMtEngine.maxCharsPerRequest = 2000` mới chỉ là metadata. Không thấy
   orchestration chunk câu dài theo giới hạn này trong `TranslationService`;
   `translateBatch()` chỉ lặp theo danh sách dòng.
5. Timeout load và timeout inference bị lặp ở hai tầng; cần policy có tên và
   request-scoped, tránh trạng thái mập mờ.
6. Chưa có test seam cho queue, isolate exit, retry một lần, chunk/ghép thứ tự và
   “không spinner vô hạn”.

## 4. Các đợt A/B vừa rồi đã sửa chưa?

- Nhóm A / `BATCH OWNER 2026-09-15` **không có card Hy-MT**, nên không sửa lỗi
  này.
- Nhóm B / `BATCH OWNER 2026-09-16` có `HYMT-002`; KANBAN mới ghi nhận root
  cause và hướng sửa, chưa có bằng chứng commit + CI + nghiệm thu cho phần queue,
  health/restart/chunk.
- Trên tip session hiện tại, chưa có một commit implementation mới của
  `HYMT-002`. Vì vậy phải coi lỗi **chưa được sửa hoàn tất**.

## 5. Prompt bổ sung giao agent

```text
BỔ SUNG HYMT-002-SUPP — audit Gemini và hoàn thiện Hy-MT, không làm lại phần đã có

Đọc trước:
- AGENTS.md và docs/GOVERNANCE.md
- docs/project/KANBAN.md card HYMT-001/HYMT-002
- docs/project/AUDIT-HYMT-GEMINI-2026-09-16.md
- lib/features/translation/engines/hymt_engine.dart
- lib/features/translation/translation_service.dart

Kết luận nền bắt buộc:
- Hy-MT đã dùng Isolate.spawn; không chuyển sang compute() nếu không có lý do
  kỹ thuật. Mọi native create/generate phải tiếp tục nằm trong Hy-MT isolate.
- Timeout Hy-MT thực tế là khoảng 2 phút, không phải 15–18 giây. 15 giây của
  Gemma warm-up và 12 giây online translation không được dùng làm bằng chứng
  cho Hy-MT.
- Không chỉ tăng timeout. Trước hết phải làm request có kết cục và có recovery.

Phạm vi implementation:
1. Thêm protocol có requestId + started/done/error/health cho Hy-MT isolate.
2. Serialize request bằng coordinator/queue; không cho hai native.generate chạy
   đồng thời trên cùng handle. Request sau phải chờ hoặc nhận trạng thái busy có
   cấu trúc, không tự timeout mù.
3. Đăng ký theo dõi isolate exit/error. Khi isolate chết hoặc native không reply:
   dispose port/handle, spawn lại và retry tối đa một lần; nếu vẫn lỗi trả
   TranslationResult.failure có nguyên nhân rõ. Không retry vô hạn và không load
   song song hai model 600 MB.
4. Tách rõ timeout model-load và timeout inference theo request. Dùng constant
   có tên, log requestId/thời gian/model, không đặt một con số tùy ý để che lỗi.
5. Chứng minh `maxCharsPerRequest` có hiệu lực. Với text dài, chia ở ranh giới
   câu/cụm, giữ đúng thứ tự, không mất/nhân đoạn; nếu Hy-MT prompt không thể
   ghép an toàn thì trả lỗi rõ thay vì ghép sai. Câu ngắn không bị chunk vô ích.
6. Audit `AiNativeBindings.tryLoad()` trên main: chỉ được capability check; nếu
   platform/plugin có side effect load model thì chuyển check vào handshake
   isolate. Không gọi create/generate từ main.
7. UI/translation service phải hiện “Đang dịch bằng Hy-MT offline, có thể chậm”
   và luôn kết thúc ở success/error hữu hạn; không spinner vô hạn.

Test/AT bắt buộc:
- Unit test queue/request id và chunk/ghép thứ tự.
- Test isolate chết/không reply: retry một lần, request kết thúc, request kế
  tiếp vẫn dùng được hoặc báo lỗi rõ.
- Câu EN→VI ngắn trả kết quả; text 2000+ ký tự không mất đoạn.
- Hai request liên tiếp không chạy native song song và không trả “not ready” giả.
- Ghi benchmark cold-load và inference thực tế trên máy owner; không khẳng định
  timeout 15–18 giây nếu log không chứng minh.
- flutter analyze, test liên quan, App Analyze + Locale CI xanh.

Commit map, không squash:
1. test/protocol + queue seam (hoặc test + fix nếu test chỉ đỏ trước sửa)
2. isolate health/restart/retry + timeout policy
3. chunk/UI/i18n nếu cần
4. KANBAN checkpoint + audit evidence
PR phải dùng .github/pull_request_template.md và ghi rõ phần background isolate
đã có từ trước, phần bổ sung nào mới được sửa.
```
