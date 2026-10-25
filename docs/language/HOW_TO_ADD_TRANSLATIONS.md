# Dịch giao diện: hướng dẫn "như em bé 10 tuổi"

> Đọc xong bài này là bạn tự làm được một **đợt dịch** (một "wave") mà không cần
> biết lập trình. Làm đúng 5 bước, mỗi bước chỉ là **copy một dòng lệnh** hoặc
> **dán một khối chữ**.
>
> Bạn không cần mở app, không cần cài Flutter. Chỉ cần mở Terminal trong thư mục
> dự án `In4Up` và làm theo thứ tự.

---

## 0. Hiểu chuyện gì đang xảy ra (30 giây)

App có rất nhiều câu tiếng Việt viết thẳng trong code, ví dụ `'Đăng nhập'`.

Ta **không sửa code**. Ta chỉ mở một quyển "từ điển" tên là
`tool/priority_native_pack.json`, ghi vào đó:

```
"Đăng nhập": { en: "Sign in", zh: "登录", my: "ဝင်ရောက်မည်", ... }
```

Rồi chạy một cái máy để nó sinh ra file Dart. App đọc file đó và hiện đúng ngôn
ngữ. Hết.

Ba nhân vật bạn sẽ gặp:

| Tên | Nó là gì | Bạn làm gì với nó |
| --- | --- | --- |
| `tool/priority_native_pack.json` | quyển từ điển (bạn viết) | **sửa tay** |
| `lib/core/language/generated_priority_native_pack.dart` | file máy sinh ra | **KHÔNG BAO GIỜ sửa tay** |
| `tool/lang_ui_inventory.py` | "máy dò" chuỗi còn thiếu | chỉ **chạy** nó |

---

## 1. Bước 1 — Xem còn thiếu gì (chạy máy dò)

```bash
python3 tool/lang_ui_inventory.py
```

Nó in ra một bảng:

```
locale   vietnamese   english
------------------------------
zh                0       988
zh_TW             0       988
hi                0       989
```

Đọc như sau:

- **vietnamese** = số câu đang hiện **tiếng Việt** ở ngôn ngữ đó. **Con số này
  phải là 0.** Nếu khác 0 thì đó là lỗi nặng (người Trung Quốc thấy tiếng Việt).
- **english** = số câu đang hiện **tiếng Anh** vì chưa ai dịch. Đây chính là
  việc bạn sắp làm cho nó **nhỏ đi**.

Bây giờ xem chi tiết **một** ngôn ngữ, ví dụ tiếng Trung:

```bash
python3 tool/lang_ui_inventory.py --locale zh --list
```

Kết quả trông như thế này (rút gọn):

```
[Home]
  (english) Đăng nhập
  (english) NHỊP ĐIỆU HỌC TẬP
```

👉 Mỗi dòng là **một câu cần dịch**. Phần trong ngoặc `[Home]` là khu vực của
app. Phần sau `(english)` là **câu gốc tiếng Việt**.

> Mẹo: **đừng làm cả 988 câu một lúc**. Chọn **một khu vực** (ví dụ `[Home]`),
> làm 10–20 câu, chạy lại máy dò, thấy số tụt xuống là thắng. Xong lại làm tiếp.

---

## 2. Bước 2 — Mở quyển từ điển

Mở file này bằng bất kỳ trình soạn thảo nào:

```
tool/priority_native_pack.json
```

Nó là một danh sách, mỗi mục có dạng:

```json
  "Gửi": {
    "en": "Send",
    "hi": "भेजें",
    "zh": "发送",
    "zh_TW": "傳送",
    "si": "යවන්න",
    "my": "ပို့မည်",
    "th": "ส่ง",
    "ja": "送信"
  },
```

Các mục xếp theo thứ tự abc của câu gốc. Chú ý 2 điều nhỏ xíu nhưng quan trọng:

1. Cuối mỗi mục (trừ mục cuối cùng) có **dấu phẩy** `,`.
2. Trong chữ, nếu có dấu ngoặc kép `"` thì phải viết thành `\"`.
   (Ví dụ: `"Xóa \"từ\" này?"`)

---

## 3. Bước 3 — Thêm một câu (ví dụ thật, làm theo y nguyên)

Giả sử máy dò báo:

```
[Home]
  (english) Đăng nhập
```

Nghĩa là: ở tab Home, câu `Đăng nhập` đang hiện "Sign in" với người Trung Quốc.
Ta muốn họ thấy `登录`.

**3a.** Mở `tool/priority_native_pack.json`.

**3b.** Tìm chỗ có chữ gần giống (thứ tự abc: `Đ` nằm cuối file, sau các chữ
`T`, `X`, `Ư`…). Nếu chưa có mục `Đăng nhập` thì dán **nguyên khối** này vào
(cẩn thận dấu phẩy ở cuối):

```json
  "Đăng nhập": {
    "en": "Sign in",
    "hi": "साइन इन करें",
    "zh": "登录",
    "zh_TW": "登入",
    "si": "පිවිසෙන්න",
    "my": "ဝင်ရောက်မည်",
    "th": "เข้าสู่ระบบ",
    "ja": "ログイン"
  },
```

**3c.** Lưu file.

### Quy tắc vàng khi viết bản dịch

| Quy tắc | Đúng | Sai |
| --- | --- | --- |
| Đủ **8** ngôn ngữ: `en, hi, zh, zh_TW, si, my, th, ja` | đủ 8 | thiếu `th` |
| Không để tiếng Việt trong bản dịch | `"zh": "登录"` | `"zh": "Đăng nhập"` |
| Giữ nguyên `{value0}`, `{value1}` nếu câu gốc có | gốc `Lỗi: {value0}` → `"zh": "错误：{value0}"` | bỏ mất `{value0}` |
| Thuật ngữ kỹ thuật/thương hiệu được để nguyên | `AI`, `PDF`, `YouTube`, `Whisper`, `LRC`, `Pāli`, `Tipiṭaka`, `WordList`, `OpenRouter` | dịch `PDF` thành `便携文档` |

---

## 4. Bước 4 — Bảo cái máy sinh file Dart

Chạy đúng 2 dòng này, **theo thứ tự**:

```bash
python3 tool/generate_priority_native_pack.py
python3 tool/generate_priority_native_pack.py --check
```

- Dòng 1 ghi lại file
  `lib/core/language/generated_priority_native_pack.dart`. **Đừng mở file đó ra
  sửa** — nó bị ghi đè mỗi lần chạy.
- Dòng 2 là "máy kiểm tra". Nó phải in ra chữ `OK`.

---

## 5. Bước 5 — Kiểm tra "số đã tụt chưa"

Chạy lại máy dò:

```bash
python3 tool/lang_ui_inventory.py --locale zh --list
```

Nếu câu `Đăng nhập` **biến mất** khỏi danh sách → bạn vừa dịch xong 1 câu. 🎉

Muốn thấy toàn cảnh:

```bash
python3 tool/lang_ui_inventory.py
```

Số ở cột `english` của `zh` phải **nhỏ hơn** lúc đầu.

Cuối cùng, lưu lại báo cáo (để người khác đọc):

```bash
python3 tool/lang_ui_inventory.py --write-report
```

Nó ghi file `docs/language/PRIORITY_LOCALE_LEAK_REPORT.md`. File này **máy sinh
ra**, cũng đừng sửa tay.

---

## 6. Nếu sai thì sao? (hộp cứu thương)

| Máy báo gì | Nghĩa là | Sửa thế nào |
| --- | --- | --- |
| `Expecting ',' delimiter` hoặc `Expecting property name` | JSON của bạn sai dấu phẩy / thiếu ngoặc | Mở file, xem dòng báo lỗi: thường là **thiếu `,`** giữa 2 mục, hoặc **thừa `,`** ở mục cuối |
| `thiếu locale` / `missing locale` | Mục nào đó không đủ 8 ngôn ngữ | Thêm đủ `en, hi, zh, zh_TW, si, my, th, ja` |
| `còn tiếng Việt` / `Vietnamese` | Bạn dán câu tiếng Việt vào ô `zh`/`my`… | Dịch lại ô đó |
| `placeholder` / `{value0}` | Câu gốc có `{value0}` mà bản dịch làm mất | Chép lại `{value0}` vào đúng chỗ trong câu dịch |
| `lệch` (drift) khi chạy `--check` | Bạn quên chạy dòng `generate_priority_native_pack.py` | Chạy lại dòng 1 của Bước 4 |
| Số `english` **không tụt** dù đã thêm | Câu bạn thêm không khớp **từng ký tự** với câu gốc | Copy câu gốc từ kết quả `--list` rồi dán làm key; đừng tự gõ lại (dễ sai dấu cách, dấu `…` vs `...`) |
| Máy báo chuỗi có `\n` (ví dụ câu dài nhiều dòng) | Câu đó là nhiều dòng ghép lại | Trong JSON, mỗi dòng cách nhau bằng `\n` (viết liền, không xuống dòng thật) |

---

## 7. Một "đợt" (wave) hoàn chỉnh — checklist

1. `python3 tool/lang_ui_inventory.py` → ghi lại số `english` của `zh`.
2. Chọn **một khu vực** trong `--locale zh --list`.
3. Dán 10–20 mục vào `tool/priority_native_pack.json` (đủ 8 ngôn ngữ).
4. `python3 tool/generate_priority_native_pack.py`
5. `python3 tool/generate_priority_native_pack.py --check` → thấy `OK`.
6. `python3 tool/lang_ui_inventory.py --write-report` → mở báo cáo xem số đã tụt.
7. Lặp lại từ bước 2 với khu vực tiếp theo.

> **Tuyệt đối không:** dịch máy lúc chạy app, sửa file `generated_*`, đổi
> `tool/lang_rollout_floors.json`, hay thêm key vào 26 file `lib/l10n/app_*.arb`
> (ARB chỉ dành cho chuỗi UI mới khai báo bằng key, không dùng cho chrome cũ).

---

## 8. Tham khảo thêm

- `docs/language/PRIORITY_NATIVE_PACK.md` — vì sao có pack này (dành cho người
  hiểu code).
- `docs/language/PRIORITY_LOCALE_LEAK_REPORT.md` — bảng rò rỉ mới nhất (máy sinh).
- `docs/adr/0002-language-rollout-tiers.md` — chính sách ngôn ngữ của repo.
- `AGENTS.md` điều #5 — luật: locale khác `vi` **không bao giờ** được thấy tiếng
  Việt.
