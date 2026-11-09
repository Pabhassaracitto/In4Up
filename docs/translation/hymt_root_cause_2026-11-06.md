# Vì sao dịch bằng Hy-MT KHÔNG hoạt động — khảo sát & nguyên nhân chính yếu

> Card: `HYMT-003` / `HYMT-004` / `HYMT-006` · Ngày: 2026-11-06 · Branch
> `arena/12de4993-in4up`
>
> Triệu chứng (owner): "Dù đã thử nhiều bản 1.5, 1.8 và 2 bản 1 GB" — Hy-MT
> (~600 MB) chạy trên app Flutter **không chịu dịch**: không phản hồi hoặc trả
> về rỗng. Nhận định tham khảo của Gemini nêu 3 nhóm nguyên nhân (engine/định
> dạng, thiếu prompt template, OOM). Tài liệu này khảo sát **trong code thật**
> của repo và đối chiếu với tài liệu chính thức của model để chỉ ra nguyên nhân
> **chính yếu**, xếp theo mức độ chắc chắn.

---

## TL;DR — 3 nguyên nhân, theo đúng thứ tự nhân quả

| # | Nguyên nhân | Bằng chứng | Trạng thái |
|---|---|---|---|
| **1** | **File model 2-bit mặc định (`Hy-MT1.5-1.8B-2bit.gguf`, 601 MB) cần kernel `q2_0c` từ llama.cpp PR **#19357** — PR này CHƯA merge. llama.cpp đã pin trong repo (`third_party/llama.cpp` = `d7fa69b7`) hiểu `q2_0` theo layout khác ⇒ `llama_model_load_from_file()` trả **NULL**. | `hymt_engine.dart` (URL cũ) · `ggml.h` pinned: `QK2_0 = 64` · PR #19357: `Q2_0C`, block 512 · HF model card: "This gguf depends on Q2_0c kernel … PR #19357" | ✅ đã sửa (đổi model mặc định + chẩn đoán) |
| **2** | **Prompt thiếu khung lượt của Hy-MT**: model cần `<｜hy_begin▁of▁sentence｜><｜hy_User｜>…<｜hy_Assistant｜>` (chat_template.jinja chính thức). App gửi chuỗi thô ⇒ model không thấy ranh giới lượt ⇒ **nhả rỗng / nhả lại nguyên prompt** — đúng "không chịu dịch". | `hymt_prompts.dart` cũ: chỉ có câu chỉ thị · `tokenizer_config.json` + `chat_template.jinja` của `tencent/HY-MT1.5-1.8B` · HF discussion: template sai ⇒ output rác `"onse"` | ✅ đã sửa (khung 2 lớp: Dart + native) |
| **3** | **Lỗi bị "nuốt"**: mọi thất bại (load NULL, quant lạ, output rỗng) bị gộp thành 1 câu chung, log thật của llama.cpp rơi vào logcat. Người dùng thử hết bản này tới bản khác mà không biết vì sao. | `_validateModelFile` cũ chỉ check magic + size · `in4up_ai_create` không đọc log llama | ✅ đã sửa (inspect GGUF + ring buffer log) |

Các nguyên nhân Gemini nêu — **kiểm tra lại trên code**:

| Nhận định | Kết luận sau khảo sát |
|---|---|
| 1. Định dạng/engine chưa khớp (GGUF + llama.cpp FFI) | **ĐÚNG một phần** — engine ĐÃ đúng (GGUF + llama.cpp FFI trong `Isolate`, `packages/in4up_ai/native/`). Nhưng **quant** của file mặc định không khớp engine đã pin. Đây chính là nguyên nhân #1 ở trên, không phải "nạp thẳng file vào package dịch chuẩn". |
| 2. Thiếu prompt template | **ĐÚNG và là nguyên nhân #2.** Nhưng lưu ý: model **không** cần system prompt (model card: *"No system prompt — all instruction must be in the user message"*) và **không** dùng `<|en|>`/`<|vi|>`; nó cần **token khung lượt** `<｜hy_User｜>` / `<｜hy_Assistant｜>`. |
| 3. OOM / bị Android kill | **ĐÚNG là rủi ro thật nhưng KHÔNG phải nguyên nhân chính** ở đây: app đã bật `android:largeHeap="true"`, model 2-bit 601 MB ≈ 850 MB–1 GB RSS khi chạy (đo trên demo Tencent: Snapdragon 865 / 8 GB RAM). Nếu OOM, isolate chết và app báo `isolate_dead`, khác hẳn triệu chứng "im lặng". Tài liệu này giữ nguyên các guard của HYMT-002 (heartbeat, restart, timeout hữu hạn) và thêm log để OOM **nhìn thấy được**. |
| (gợi ý) Test bằng Python/llama.cpp trước | **ĐÚNG cách làm.** Lệnh đối chứng ở §5 dưới đây — nếu `llama-cli` mainline cũng từ chối file 2-bit thì đó là bằng chứng dứt điểm cho nguyên nhân #1. |

---

## 1. Đường đi thật của một lượt dịch Hy-MT trong app

```
TranslationService.translateText
  └─ _translateWithPipeline → _planSteps  (hỏi hymt.hasModel → đọc 8MB header)
      └─ _runEngineChain → HyMtEngine.translate
          ├─ HyMtSlot.acquire()                 (single-flight, HYMT-002)
          ├─ HyMtIsolateBackend.restart()       (Isolate.spawn)
          │     └─ AiNativeBindings.create() → in4up_ai_create()
          │           └─ llama_model_load_from_file()   ← ❗ nguyên nhân #1
          └─ cho từng chunk ≤500 ký tự:
                HyMtPrompts.build()             ← ❗ nguyên nhân #2
                native.generate() → in4up_ai_generate()
                      └─ llama_tokenize + llama_decode + sampler loop
                HyMtPrompts.cleanOutput()       (0 ký tự còn lại ⇒ "trả về rỗng")
```

Hai điểm ❗ là nơi duy nhất có thể biến một lượt dịch thành "không có gì xảy ra".

---

## 2. Nguyên nhân #1 — quant của file mặc định không khớp llama.cpp đã pin

### 2.1 Bằng chứng trong repo

`lib/features/translation/engines/hymt_engine.dart` (trước bản này):

```dart
static const fileName = 'Hy-MT1.5-1.8B-2bit.gguf';
static const downloadUrl =
    'https://huggingface.co/tencent/Hy-MT1.5-1.8B-2bit-GGUF/resolve/main/'
    'Hy-MT1.5-1.8B-2bit.gguf?download=true';
```

`.gitmodules` + `git ls-tree HEAD third_party/`:

```
160000 commit d7fa69b7de2186b16c1024572273130d631038d7  third_party/llama.cpp
```

`android/app/src/main/cpp/ai/CMakeLists.txt` build thẳng submodule này thành
`libin4up_ai_native.so` (không dùng bản prebuilt nào khác).

### 2.2 Bằng chứng từ llama.cpp đã pin

Trong `ggml/include/ggml.h` của commit `d7fa69b7`:

```
GGML_TYPE_Q1_0 = 41,
GGML_TYPE_Q2_0 = 42,
```

`ggml/src/ggml-common.h`:

```
#define QK1_0 128
#define QK2_0 64        // ← block 64 phần tử
uint8_t qs[QK2_0 / 4];  // 2 bits per element
```

### 2.3 Bằng chứng từ phía model

[HuggingFace `AngelSlim/Hy-MT1.5-1.8B-2bit-GGUF`](https://huggingface.co/AngelSlim/Hy-MT1.5-1.8B-2bit-GGUF) (nguồn gốc của `tencent/Hy-MT1.5-1.8B-2bit-GGUF`, file **601 MB** đúng như app tải):

> **❕❕ This gguf depends on Q2_0c kernel, which is released at [PR #19357](https://github.com/ggml-org/llama.cpp/pull/19357).**
> ```bash
> git fetch origin pull/19357/head:pr-19357-sme2-int2
> git checkout pr-19357-sme2-int2
> ```

Trạng thái PR (kiểm tra qua API ngày 2026-11-06): **`state: open`, `merged: false`**.
Diff của PR này thêm `GGML_TYPE_Q2_0C = 40` (kernel int2 + KleidiAI SME2) — một
kiểu block **khác** `GGML_TYPE_Q2_0 = 42` của mainline.

Mô tả độc lập về layout (từ một PR chuyển model này sang ONNX Runtime) xác nhận
điều tương tự: *"Mainline llama.cpp **refuses to load** these files because every
tensor after the first Q1_0 entry lands at the wrong offset"*.

### 2.4 Hệ quả

* `llama_model_load_from_file()` trả `NULL` → `in4up_ai_create()` trả `NULL`.
* Dart: `_LoadResult(ready: false, ...)` → **`loadFailed`**.
* Nhưng validator cũ chỉ kiểm tra **magic `GGUF`** + **kích thước ≥ 481 MB**:
  file 601 MB này **qua hết** ⇒ app báo "Không nạp được Hy-MT GGUF…", người
  dùng thấy file vẫn nằm đó, nên thử bản khác — **đúng triệu chứng "thử 1.5,
  1.8 và 2 bản 1 GB"**.
* File ~1 GB cũng hỏng nếu là bản quant tương tự (`STQ1_0`/`Q2_0C`) — kích
  thước **không** phải dấu hiệu an toàn.

> Vì sao người dùng khó phát hiện: model 2-bit là bản **được quảng cáo cho
> mobile** ("574 MB on-device") nên nó là lựa chọn tự nhiên nhất — nhưng nó phụ
> thuộc một kernel **chưa merge vào llama.cpp chính thức**.

---

## 3. Nguyên nhân #2 — thiếu khung lượt `<｜hy_User｜>` (kể cả khi model load được)

`HyMtPrompts.build()` (trước bản này) chỉ trả câu chỉ thị + văn bản:

```dart
'Translate the following segment into $targetName, without additional explanation.\n\n$text'
```

Nhưng chat template chính thức của `tencent/HY-MT1.5-1.8B`
(`chat_template.jinja`) là:

```jinja
<｜hy_begin▁of▁sentence｜>
{% if system %}{{ system }}<｜hy_place▁holder▁no▁3｜>{% endif %}
{% for m in messages %}
  {% if m.role == 'user' %}<｜hy_User｜>{{ m.content }}{% endif %}
  {% if m.role == 'assistant' %}<｜hy_Assistant｜>{{ m.content }}<｜hy_place▁holder▁no▁2｜>{% endif %}
{% endfor %}
{% if add_generation_prompt %}<｜hy_Assistant｜>{% endif %}
```

Tức prompt đúng phải là:

```
<｜hy_begin▁of▁sentence｜><｜hy_User｜>Translate the following segment into Vietnamese, without additional explanation.\n\nHello<｜hy_Assistant｜>
```

Không có `<|im_start|>`, không có `user:` / `assistant:`. Đây **không** phải chat
model thông thường (tokenizer: `bos = <｜hy_begin▁of▁sentence｜>`,
`eos = <｜hy_place▁holder▁no▁2｜>`), và model card ghi rõ **không dùng system
prompt**.

Khi thiếu khung, hành vi quan sát được (và đã được cộng đồng ghi lại):

* model coi cả chuỗi là văn bản thô ⇒ nhả **rỗng** ngay token đầu (EOG), hoặc
* nhả **lại nguyên prompt** / vài token rác rồi dừng (HF discussion chính thức
  của `tencent/HY-MT1.5-1.8B-GGUF` ghi nhận output chỉ là `"onse"` khi template
  sai, và đưa ra template đúng).

Trong app, cả hai trường hợp rơi vào `cleanOutput()` → chuỗi rỗng →
`emptyOutput` ⇒ UI hiện "Hy-MT trả về rỗng" hoặc không có gì.

---

## 4. Nguyên nhân #3 — thông tin chẩn đoán bị nuốt

Ba thứ khác nhau bị gộp thành một câu:

1. file cắt (validator cũ bắt được, nhưng thông báo chung),
2. **quant không hỗ trợ** (validator cũ **không** bắt được),
3. **output rỗng vì prompt** (không có log nào).

Đồng thời mọi dòng log của llama.cpp (`unknown model architecture`, `failed to
load tensor`, `out of memory`…) đi vào stderr của tiến trình — trên Android bản
release người dùng không thấy gì. Không có log thì không thể phân biệt 3 nguyên
nhân trên, nên vòng lặp "thử bản khác" không bao giờ kết thúc.

---

## 5. Đối chứng độc lập (làm được ngay, không cần build app)

Trên PC/Linux (hoặc Termux), dùng llama.cpp **mainline** đúng commit đã pin:

```bash
git clone https://github.com/ggml-org/llama.cpp.git
cd llama.cpp && git checkout d7fa69b7de2186b16c1024572273130d631038d7
cmake -B build && cmake --build build -j
# (1) file 2-bit mà app cũ tải về:
./build/bin/llama-cli -m Hy-MT1.5-1.8B-2bit.gguf -p "Translate ...: Hello" -n 32
#  → dự kiến: error loading model: unknown/wrong tensor type  → NULL
# (2) file mainline Q4_K_M:
./build/bin/llama-cli -m HY-MT1.5-1.8B-Q4_K_M.gguf \
  -p "<｜hy_begin▁of▁sentence｜><｜hy_User｜>Translate the following segment into Vietnamese, without additional explanation.

Hello<｜hy_Assistant｜>" -n 64 -st
#  → dự kiến: "Xin chào"
```

Nếu (1) lỗi và (2) chạy ⇒ nguyên nhân #1 + #2 được chứng minh dứt điểm, đúng như
kết luận của tài liệu này.

---

## 6. Đã sửa gì trong bản này

### 6.1 Chọn đúng file model (nguyên nhân #1)

`hymt_engine.dart`:

```dart
static const fileName = 'HY-MT1.5-1.8B-Q4_K_M.gguf';        // 1,13 GB, mainline
static const downloadUrl =
    'https://huggingface.co/tencent/HY-MT1.5-1.8B-GGUF/resolve/main/'
    'HY-MT1.5-1.8B-Q4_K_M.gguf?download=true';
static const expectedBytes = 1150 * 1024 * 1024;
static const legacyBlockedFileName = 'Hy-MT1.5-1.8B-2bit.gguf';
```

`tencent/HY-MT1.5-1.8B-GGUF` có Q4_K_M (1,13 GB), Q6_K (1,47 GB), Q8_0
(1,91 GB) — **tất cả là quant mainline** và kiến trúc `hunyuan-dense` đã được
llama.cpp hỗ trợ từ PR #21395 (merged 2026-04-05, trước commit đã pin).

### 6.2 Chẩn đoán bằng header GGUF thật (nguyên nhân #1 + #3)

Native mới `in4up_ai_inspect_gguf()` đọc trực tiếp GGUF KV + tensor đầu tiên,
trả về `arch`, `quant`, `has_chat_template`, `n_tensors`, `supported` — **không
cần load model vào RAM**:

| phát hiện | hành vi |
|---|---|
| quant `q2_0` / `STQ1_0` / `UNKNOWN:43` | từ chối kèm giải thích + chỉ sang Q4_K_M |
| arch ≠ `hunyuan-*` | "không phải model Hy-MT (kiến trúc …)" |
| size < 400 MB | "bị cắt (… MB)" |
| native cũ không có symbol | chỉ check magic/size, **không** kết luận sai là hỏng |

Dart: `lib/features/translation/engines/hymt_model_probe.dart` (thuần, test
được), dùng ở `importFromUser()`, `downloadModel()`, `modelIssue()`.
Kết quả được cache theo `(path, size, mtime)` để `_planSteps` không đọc lại 8 MB
mỗi lượt dịch.

### 6.3 Khung lượt Hy-MT (nguyên nhân #2) — 2 lớp

* Dart `HyMtPrompts.build()` bọc `<｜hy_begin▁of▁sentence｜><｜hy_User｜> … <｜hy_Assistant｜>`
  (`withTurnTokens: false` để tắt khi cần), tách `instruction()` riêng.
* Native `frame_prompt()` **tự thêm** nếu prompt chưa có (idempotent), chỉ với
  arch `hunyuan*` ⇒ mọi caller đều đúng, kể cả caller không đi qua Dart.

### 6.4 Sampling theo khuyến nghị Tencent — CHỈ cho Hunyuan (nguyên nhân #2, phần "chất lượng")

`--temp 0.7 --top-k 20 --top-p 0.6 --repeat-penalty 1.05`, nhưng **chỉ áp khi
`general.architecture` chứa `hunyuan`**. Lý do: `in4up_ai_generate` là API
**dùng chung** với AI chat (`ai_engine_gemma` + `ai_service_facade` truyền
`temperature 0.2/0.4`). Áp `top-k 20` + `top-p 0.6` toàn cục sẽ làm câu trả lời
chat local ngắn/cụt/đơn điệu — một regression không liên quan tới Hy-MT.

Nhánh `else` (model chat) **giữ nguyên** sampler của v1.23.0: `temp` + `dist`.

Cả 6 API mới (`llama_log_set`, `llama_model_meta_val_str`,
`llama_sampler_init_penalties/top_k/top_p`, `llama_vocab_n_tokens`) đã được
**xác minh biên dịch** với header **thật** của đúng commit đã pin
(`d7fa69b7`): `g++ -std=c++17 -Wall -Wextra -Werror -fsyntax-only` → exit 0.
(`llama_sampler_init_penalties` đúng 5 tham số:
`n_vocab, penalty_last_n, penalty_repeat, penalty_freq, penalty_present`.)

### 6.5 Log llama.cpp được giữ lại (nguyên nhân #3)

* Ring buffer 16 KB trong native + `in4up_ai_last_log()`.
* Lỗi load/generate ở Dart **đính kèm** log thật.
* `llama_backend_init/free` đổi sang **đếm tham chiếu**: Hy-MT và AI chat dùng
  chung `libin4up_ai_native.so`; trước đây destroy model này có thể gọi
  `llama_backend_free()` trong khi model kia còn sống.

### 6.6 Test hồi quy

* `test/hymt_prompt_test.dart` — token khung đúng từng ký tự (U+FF5C/U+2581),
  thứ tự BOS→User→body→Assistant, `cleanOutput` cắt token khung, không phá bản
  dịch có ký tự `｜`.
* `test/hymt_model_probe_test.dart` — file 2-bit 601 MB bị chặn, quant lạ bị
  chặn, sai arch, file cắt, native cũ không kết luận sai; hằng số model/URL mới.
* `test/hymt_engine_runtime_test.dart` — cập nhật phép tách chunk để tính cả
  khung lượt (phân hoạch vẫn chính xác: join == text gốc).

---

## 7. Rủi ro còn lại (nói thẳng)

1. **Q4_K_M nặng hơn**: 1,13 GB trên đĩa, RSS khi chạy ~1,3–1,5 GB. Trên máy
   3–4 GB RAM, Hy-MT có thể bị Android kill (OOM). Giờ đã **nhìn thấy** qua log
   + `isolate_dead`, nhưng chưa có test trên máy yếu. Nếu cần nhẹ hơn: build
   llama.cpp kèm PR #19357 rồi quay lại 2-bit (đánh đổi: phải tự bảo trì fork).
2. **Tốc độ**: chưa đo trên máy owner. Q4_K_M trên CPU 4 thread dự kiến chậm
   hơn 2-bit (2-bit có kernel SME2/int2 chuyên dụng). Với chunk ≤500 ký tự +
   timeout hữu hạn của HYMT-002, mỗi chunk vẫn phải về trong hạn.
3. **`q2_0` block-64 của mainline không tương thích file AngelSlim** — kết luận
   này dựa trên tài liệu PR/model card + layout trong header llama.cpp, chưa
   chạy được trên thiết bị trong sandbox. Cần nghiệm thu bằng §5.
4. **Prompt tiếng Trung cho cặp ZH↔XX**: giữ nguyên như model card. Với cặp
   XX↔XX dùng tiếng Anh — đúng.
6. **Nâng cấp từ bản cũ**: file 2-bit 601 MB **không tự bị xoá** (giữ để không
   xoá dữ liệu người dùng khi họ lỡ chọn nhầm). Cài đặt dịch phát hiện file
   này và mời xoá (nút "Xoá" riêng); nút Xoá model chính cũng dọn luôn file
   legacy. Người chưa tải lại sẽ thấy câu "cần Q4_K_M" thay vì lỗi chung.
7. **Test Hy-MT giờ nằm trong CI**: trước đây **không workflow nào** chạy
   `test/hymt_*` ⇒ lỗi Hy-MT không thể bị CI bắt. Đã thêm step
   "Hy-MT tests — khung lượt + chẩn đoán model + chunk runtime" vào
   `app_analyze.yml` (chạy 5 file, thuần logic, không cần native/model).
5. Nhánh này **chưa chạy được `flutter test` trong sandbox** (không có Flutter
   SDK) — CI `app_analyze.yml` là oracle.

---

## 8. Nguồn

* Model card + chat template: <https://huggingface.co/tencent/HY-MT1.5-1.8B>
  (`tokenizer_config.json`, `chat_template.jinja`), GGUF:
  <https://huggingface.co/tencent/HY-MT1.5-1.8B-GGUF>
* Yêu cầu kernel `Q2_0c`: <https://huggingface.co/AngelSlim/Hy-MT1.5-1.8B-2bit-GGUF>
  (mục Deployment) và <https://github.com/ggml-org/llama.cpp/pull/19357>
  (open, not merged).
* Template sai ⇒ output rác: <https://huggingface.co/tencent/HY-MT1.5-1.8B-GGUF/discussions/6>
* Hỗ trợ `hunyuan-dense` trong llama.cpp: PR #21395 (merged 2026-04-05).
* Code trong repo: `lib/features/translation/engines/hymt_*.dart`,
  `packages/in4up_ai/native/in4up_ai_native.cpp`,
  `android/app/src/main/cpp/ai/CMakeLists.txt`, `.gitmodules`.
