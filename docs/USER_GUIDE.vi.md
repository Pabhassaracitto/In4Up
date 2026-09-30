# In4Up — Hướng dẫn sử dụng các luồng import và học ngoại tuyến

> Cập nhật: 2026-09-30 · Card `I4U18-DOCS-001`
>
> Tên nút dưới đây dùng giao diện tiếng Việt. Nếu dùng locale khác, vị trí nút
> không đổi nhưng nhãn sẽ được dịch hoặc hiện tiếng Anh. Model, từ điển, sách,
> audio và video **không nằm trong Git**; hãy chọn từ thiết bị hoặc tải khi app
> yêu cầu.

## 1. Trước khi bắt đầu

- Nên còn trống ít nhất gấp đôi dung lượng file sẽ import; app cần chỗ để giải
  nén hoặc sao chép.
- Với file lớn, giữ app ở tiền cảnh và dùng Wi-Fi ổn định. Android có thể dừng
  tác vụ khi tối ưu pin; mở **Home → Quản lý Model AI → Dừng tối ưu mức sử
  dụng pin** nếu việc tải thường bị ngắt.
- Chỉ dùng dữ liệu bạn có quyền sử dụng. Không gửi API key, file model hoặc nội
  dung có bản quyền vào issue/log công khai.
- Sao lưu file gốc. Xóa dữ liệu ứng dụng cũng xóa dữ liệu đã import vào vùng
  riêng của app.

### Khả năng của giao diện hiện tại

| Luồng | Hiện hỗ trợ | Giới hạn cần biết |
|---|---|---|
| Piper/eSpeak/Whisper/Zipformer | Import hoặc tải trong **Quản lý Model AI** | Piper cần đủ voice + phonemizer; Zipformer cần đủ 4 nhóm file |
| Server/API/BYOK | OpenAI-compatible cloud, Ollama, LM Studio; routing theo chức năng | HTTP không mã hóa chỉ được chấp nhận trong LAN riêng |
| Từ điển | Import `.mdx`, bật/tắt/xóa, tra offline | Picker hiện chỉ nhận `.mdx`; chưa có UI liên kết `.mdd`/CSS rời |
| Tipiṭaka | Import `.db/.sqlite/.sqlite3/.zip`, tải pack Pa-Auk | Nên cài Pāli trước bản dịch |
| Audio | Quét thư viện Android, tìm kiếm, import nhiều file thành playlist | Playlist tạo từ bộ file vừa chọn; chưa phải playlist đặt tên lâu dài |
| Video | Thêm từng file và phát local | Chưa có quét thư mục, bộ lọc hoặc playlist video trong UI hiện tại |
| PDF/OCR/TTS/IPA | PDF text-layer; OCR Android/iOS; TTS theo câu; IPA trong Read mode | OCR không chạy trên desktop/web; PDF scan phải OCR trước |

## 2. Import model Piper, eSpeak và STT offline

Đi tới **Home → Quản lý Model AI**. Trạng thái “Đã cài/Sẵn sàng” trên đúng thẻ
mới là dấu hiệu hoàn tất; thông báo “đã chọn file” chưa đủ.

### 2.1 Piper TTS và `espeak-ng-data`

Piper cần hai phần:

1. **Giọng**: file `<voice>.onnx`, thường kèm `<voice>.onnx.json`; một số bundle
   Sherpa còn có `tokens.txt` hoặc `<voice>_tokens.txt`.
2. **Phonemizer**: thư mục `espeak-ng-data` có `phontab`. Phần này dùng chung
   cho mọi giọng và là bắt buộc.

Cách dễ nhất:

1. Trong thẻ **3. TTS — Piper**, bấm **Tải giọng**.
2. Chọn giọng và đợi thanh tiến độ kết thúc. App tự tải, giải nén và cài.
3. Nếu hàng `espeak-ng-data` vẫn báo **CHƯA có**, bấm nút tải phonemizer tại
   hàng đó.
4. Chạm giọng vừa cài để chọn cho ngôn ngữ tương ứng.
5. Mở **Settings/Cài đặt → Text-to-Speech**, đặt Piper trong thứ tự nguồn và
   thử một câu ngắn.

Import file có sẵn:

- **Import thư mục**: chọn thư mục đã giải nén chứa voice và
  `espeak-ng-data`; đây là lựa chọn tốt nhất cho bundle đầy đủ.
- **Import file**: chọn đồng thời `.onnx`, `.onnx.json` và file tokens nếu bundle
  có. Android SAF không luôn cho app đọc cả thư mục; khi app yêu cầu, dùng
  **Import file** và chọn nhiều file một lần.

Lỗi thường gặp:

| Hiện tượng | Cách xử lý |
|---|---|
| Import xong nhưng không thấy giọng | Kiểm tra file `.onnx` không rỗng/hỏng; import lại cả `.onnx.json` và tokens nếu có; đóng/mở lại màn để quét trạng thái |
| Báo thiếu `phontab`/phonemizer | Cài `espeak-ng-data`; không đổi tên hoặc chỉ chọn riêng một file bên trong thư mục này |
| App fallback sang giọng hệ thống | Chọn giọng Piper cho đúng ngôn ngữ, rồi kiểm tra Piper đứng trước engine online/hệ thống |
| Tải dừng giữa chừng | Đổi mạng, tắt tối ưu pin cho In4Up, xóa bản tải lỗi rồi tải/import lại |

### 2.2 Whisper — STT file, tạo transcript/LRC

1. Trong **Quản lý Model AI**, tìm **1. STT — Whisper**.
2. Ở cấp model cần dùng (`tiny`, `base`…), bấm **Tải về** hoặc **Import** file
   `ggml-*.bin`.
3. Chờ thẻ báo model hợp lệ. File phải có dung lượng thực, không phải trang HTML
   tải nhầm hoặc file chưa tải hết.
4. Mở **Nghe**, chọn audio → **Tạo lời/LRC**, chọn ngôn ngữ (`auto` nếu không
   chắc) và model.
5. Với Hindi/CJK hoặc chữ ngoài Latin, ưu tiên `base`/`small` nếu `tiny` trả
   chữ Latin sai.

### 2.3 Zipformer — STT mic trực tiếp/offline

Mỗi profile cần đủ:

```text
tokens.txt
encoder*.onnx
decoder*.onnx
joiner*.onnx
```

1. Tại **5. STT Offline — Zipformer**, chọn đúng thẻ:
   - VI offline + VAD: dùng cho Cabin và file/LRC.
   - EN streaming: dùng cho Cabin token-by-token, **không** dùng để bóc file.
2. Bấm **Tải về**, hoặc **Import thư mục/Import file** và chọn đủ bốn nhóm file.
3. Chờ badge sẵn sàng, rồi mở **Cabin**, chọn đúng ngôn ngữ và engine offline.

Nếu báo “không nhận diện được model”, đừng đổi tên file tùy ý: kiểm tra chọn đúng
profile, đủ encoder/decoder/joiner/tokens, archive đã giải nén hoàn toàn và không
trộn file của hai model.

> Chi tiết layout và đường dẫn dành cho developer/ADB:
> [`project/MODELS.md`](project/MODELS.md).

## 3. Cấu hình Server, API, BYOK và local server

Đi tới **Home → Quản lý Model AI → Server & API (mây / LAN)**.

### 3.1 Cloud BYOK

1. Bấm **Thêm provider**.
2. Chọn preset Gemini, Groq, OpenRouter hoặc OpenAI; đặt **Tên hiển thị**.
3. Dán API key do chính provider cấp. App không kèm key.
4. Bấm **Kiểm tra kết nối**.
5. Bấm **Tải danh sách model**, rồi chọn model cho Chat/STT/TTS nếu provider có
   endpoint tương ứng.
6. **Lưu**, bật công tắc provider.
7. Trong phần **Định tuyến**, chọn theo từng chức năng:
   - **Ưu tiên offline**: dùng model máy trước, API là dự phòng.
   - **Ưu tiên online**: dùng API trước, offline là dự phòng.
   - **Chỉ offline**: không gửi request API.

API key được che trên màn hình nhưng cấu hình hiện được lưu cục bộ trong app;
không dùng key đặc quyền trên thiết bị dùng chung. Đặt hạn mức/giới hạn chi phí ở
trang provider và thu hồi key khi mất thiết bị.

### 3.2 Ollama hoặc LM Studio trong LAN

1. Trên máy tính, khởi động server OpenAI-compatible và nạp ít nhất một model.
2. Cho server lắng nghe trên địa chỉ LAN, không chỉ `127.0.0.1`; cho phép qua
   firewall **chỉ trong mạng riêng**.
3. Điện thoại và máy tính phải cùng Wi-Fi. Tìm IP máy tính, ví dụ
   `192.168.1.10`.
4. Thêm preset:
   - Ollama: `http://192.168.1.10:11434`
   - LM Studio: `http://192.168.1.10:1234`
5. Local server thường không cần key; để trống nếu server của bạn không yêu
   cầu. Kiểm tra kết nối, tải model, chọn model và lưu.

Không nhập `localhost`/`127.0.0.1` trên điện thoại: đó là chính điện thoại. URL
HTTP công khai bị chặn; endpoint ngoài LAN phải dùng HTTPS.

Lỗi kết nối nhanh:

- **timeout/no network**: cùng Wi-Fi chưa, IP có đổi, VPN/AP isolation hoặc
  firewall có chặn cổng không?
- **unauthorized/401**: key sai/hết hạn hoặc provider yêu cầu header khác chuẩn
  OpenAI.
- **0 model/invalid response**: server chưa nạp model hoặc không hỗ trợ
  `GET /v1/models`.
- Provider test xanh nhưng chức năng vẫn offline: kiểm tra provider đang bật,
  model cho đúng capability đã chọn và routing không ở **Chỉ offline**.

## 4. Import/link từ điển MDX, MDD và CSS

Mở **Từ điển/Quản lý từ điển** từ quick actions hoặc màn công cụ, bấm **+** và
chọn `.mdx`. Chờ card hiện tên, số entry lớn hơn 0 và công tắc bật. Sau đó mở
Read mode, chạm một từ để xem kết quả MDX; khi lưu từ, nghĩa/IPA khả dụng có thể
được điền từ kết quả này.

Chuẩn bị bộ từ điển:

```text
MyDictionary.mdx       # bắt buộc, entry và HTML định nghĩa
MyDictionary.mdd       # tùy chọn, ảnh/audio/font
style.css              # tùy chọn, kiểu trình bày
```

**Giới hạn hiện tại:** picker production hiện chỉ nhận `.mdx`. API nội bộ có chỗ
cho MDD nhưng màn quản lý chưa cho chọn/link `.mdd`; CSS rời cũng chưa có UI
link. Vì vậy:

- Import MDX để dùng phần chữ trước.
- Giữ MDD/CSS cạnh MDX và không đổi basename để sẵn sàng cho bản có nút liên kết
  tài nguyên.
- Không hiểu “import MDX thành công” là MDD audio/image hoặc CSS đã được liên
  kết. Nếu định nghĩa tham chiếu resource rời, ảnh/âm thanh/style có thể thiếu.

Nếu số entry bằng 0 hoặc import không xuất hiện: thử một MDX v1/v2 không mã hóa,
chép file về bộ nhớ cục bộ trước (không chọn placeholder cloud), bảo đảm còn đủ
chỗ trống và thử file nhỏ đã biết tốt. File lạ/hỏng phải báo lỗi, không nên làm
app crash.

## 5. Import Tipiṭaka pack và Pāli

1. Mở **Thư viện Tipiṭaka** → biểu tượng **Dữ liệu/Storage**.
2. Chọn một trong hai cách:
   - **Import DB hoặc gói ngôn ngữ từ thiết bị**: nhận `.db`, `.sqlite`,
     `.sqlite3` hoặc `.zip`.
   - **Tải gói ngôn ngữ Pa-Auk**: tải và chuẩn hóa trực tiếp.
3. Cài **Pāli (Roman)** trước. Sau khi thành công, cài bản dịch Việt/Anh/ngôn ngữ
   mong muốn.
4. Bấm **Kiểm tra lại DB**. Trạng thái hợp lệ phải hiện số tạng, sách, đoạn và
   danh sách ngôn ngữ.
5. Bấm **Mở thư viện**, chọn tạng → sách → đoạn; thử tìm một cụm Pāli và chuyển
   ngôn ngữ/song ngữ.

Nếu ZIP không nhận: xác nhận bên trong có SQLite thật, file tải đủ và còn chỗ
trống để giải nén. Nếu có bản dịch nhưng thiếu Pāli/không ghép được câu, import
pack Pāli trước rồi import lại bản dịch. DB rất lớn có thể được chuẩn hóa bằng
script developer mô tả tại [`tipitaka_database.md`](tipitaka_database.md).

## 6. Video và thư viện Nghe

### 6.1 Audio: quét, tìm và playlist

1. Mở **Nghe → Thư viện**.
2. Lần đầu, bấm **Cấp quyền & quét**. Trên Android mới, cấp quyền Audio/Music;
   app không cần toàn quyền file nếu MediaStore trả dữ liệu đúng.
3. Kéo để refresh hoặc bấm **Quét thư viện**. Gõ tên/artist ở ô tìm kiếm để lọc.
4. Chạm một mục để phát. Nếu quét không thấy file, sang **Gần đây → Thêm audio**
   để chọn thủ công.
5. Để tạo playlist nhanh, mở ngăn thư viện audio → **Chọn nhiều file**. App sao
   chép file vào vùng bền của app, phát bài đầu và hiện danh sách để chọn bài.

Playlist này là danh sách của lần chọn hiện tại; bấm **Xóa** chỉ xóa danh sách
hiển thị, không xóa file gốc. Không di chuyển/xóa file gốc MediaStore giữa lúc
đang quét. Nếu file `content://` không phát, import thủ công để app tạo bản sao
cục bộ.

### 6.2 Video local

1. Mở **Xem/Video** → **Thêm video**.
2. Chọn `mp4`, `mkv`, `webm`, `mov`, `avi` hoặc `m4v`.
3. Chờ app đọc duration và card xuất hiện; chạm card để phát.

Bản hiện tại thêm từng video, chưa có quét thư mục/MediaStore, bộ lọc hay
playlist video. Nếu codec/container không phát dù file có trong danh sách, thử
MP4 H.264/AAC hoặc remux file; app phải hiện lỗi thay vì màn đen.

## 7. PDF, OCR, TTS và IPA

### 7.1 PDF có lớp chữ

1. Mở **Đọc → Thư viện Đọc → Máy → Mở PDF**.
2. Dùng mục lục/tìm kiếm/chuyển trang để tới nội dung.
3. Bấm Play trên thanh TTS để đọc theo câu; chỉnh tốc độ và ngôn ngữ. TTS tô
   câu hiện tại và có thể tự sang trang.
4. Chạm hoặc chọn chữ để xem nghĩa, lưu WordList hay đọc đoạn chọn.

Nếu tìm kiếm/selection/TTS không lấy được chữ, PDF có thể là ảnh scan.

### 7.2 OCR ảnh và PDF scan

- Android/iOS: trong **Thư viện Đọc**, chọn **Quét ảnh** → **Chụp & quét tài
  liệu** (Android) hoặc **Chọn ảnh có sẵn**. Xem preview, sửa lỗi rồi nạp vào
  Read mode.
- Trong PDF scan, bấm **Quét chữ trang này** trên thanh TTS. App render trang,
  OCR, cho sửa và nạp văn bản. OCR trang hiện tại không tạo text layer vĩnh viễn
  trong file PDF gốc.
- Desktop/web: nút OCR không hiện vì ML Kit OCR hiện chỉ hỗ trợ Android/iOS.

Chụp thẳng trang, đủ sáng, tránh bóng/gáy cong. Chọn đúng recognizer script khi
có; Pāḷi Roman thuộc Latin. Luôn đọc lại dấu Pāli (`ā ī ū ṃ ṅ ñ ṭ ḍ ṇ ḷ`) trước
khi lưu hoặc dùng TTS.

### 7.3 TTS và IPA trong Read mode

- Nút loa/Play đọc dòng hoặc câu bằng engine đã xếp trong **Cài đặt →
  Text-to-Speech**. Khi Piper lỗi/thiếu giọng, app có thể fallback sang engine hệ
  thống.
- Nút **IPA/abc** ở thanh đáy tuần hoàn: **Tắt → Dòng hiện tại → Toàn văn**.
- Khi IPA đang bật, dùng panel chú giải để bật/tắt nhóm màu âm vị; chạm word-chip
  để nghe phát âm. IPA của từ lưu ưu tiên MDX khi từ điển có dữ liệu, sau đó các
  nguồn fallback có sẵn.

Nếu không có IPA, kiểm tra ngôn ngữ văn bản và thử từ tiếng Anh chuẩn; không phải
mọi ngôn ngữ/Pāli đều có G2P đóng gói. IPA là gợi ý phát âm, không thay thế việc
đối chiếu từ điển chuyên ngành.

## 8. Khi cần báo lỗi

Ghi lại: phiên bản/build, thiết bị + OS, locale, đường đi tới màn lỗi, tên và
**kích thước** file (không cần gửi file có bản quyền), thông báo nguyên văn, và
kết quả thử lại. Với API, che toàn bộ key/token; chỉ cung cấp provider, base URL
đã xóa thông tin riêng, HTTP status và mã lỗi. Dùng checklist nghiệm thu tại
[`manual_qa_I4U18_DOCS_001.md`](manual_qa_I4U18_DOCS_001.md).
