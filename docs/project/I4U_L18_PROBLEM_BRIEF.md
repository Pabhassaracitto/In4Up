# I4U L18 Problem — bản chuẩn hoá yêu cầu

> Nguồn: owner, 2026-09-30. Mục tiêu của tài liệu này là sửa lại câu chữ để
> người đọc và AI agent cùng hiểu đúng, sau đó chia thành các lane nhỏ trên
> Kanban. Các card tương ứng: `I4U18-*` trong `docs/project/KANBAN.md`.

## 0. Nguyên tắc xử lý

1. **Không làm một PR khổng lồ.** Chia thành lane ít đụng file nhau: AI/Server,
   Dictionary/Model import, Video/Listen, Tipiṭaka, Read/PDF/OCR/IPA, Docs.
2. **Không để CI đỏ khi bàn giao.** Mỗi lane phải có bằng chứng: test local nếu
   chạy được, hoặc CI run xanh; docs-only tối thiểu chạy `git diff --check`.
3. **Commit ít nhưng rõ.** Mỗi lane nên có 1–3 commit logic, thêm 1 commit
   checkpoint Kanban nếu cần. Không squash mù, không force-push nhánh chung.
4. **Giảm xung đột.** Agent chỉ sửa vùng được giao; đừng tự động merge nhánh khác.
   Riêng Tipiṭaka/PDF/Home phải đọc thêm `origin/arena/01a06931-in4up` vì nhánh
   đó đang làm nội dung liên quan.
5. **i18n rule #5.** Chuỗi UI mới phải có English fallback; locale khác tiếng Việt
   không được thấy chrome UI tiếng Việt.

## 1. Bản yêu cầu đã chỉnh câu chữ

### 1. Home

Rà soát lại Tab Home. Các lỗi cụ thể hiện được tách ở mục Chat/AI và Settings
import model bên dưới.

### 2. Từ điển

Từ điển vẫn chưa import được ổn định. Bộ từ điển thực tế thường gồm nhiều file
liên quan, ví dụ `.mdx`, `.mdd`, `.css` hoặc thư mục asset đi kèm. Cần hỗ trợ rõ
hai cách:

- **Link/index thư mục hoặc file nguồn** để dùng ngay, tránh copy dữ liệu lớn.
- **Import/copy vào app storage** khi người dùng muốn dữ liệu ổn định lâu dài.

Khi thiếu file phụ, app phải báo thiếu file nào và cho biết còn dùng được ở chế
độ giảm cấp hay không.

### 3. Home Chat và lựa chọn Server/API

Home Chat trả lời chậm. Có lúc app trả lời bằng thông báo kiểu "mình chưa tạo
được câu trả lời cho tin nhắn này" kèm một đoạn tóm tắt tiếng Anh không liên
quan, ví dụ "The conversation is about a simple task...". Cần:

- Có timeout/hủy request rõ ràng, không kẹt spinner.
- Không hiển thị fallback sai ngữ cảnh.
- Cho phép chọn engine **Server & API** cho chat/analysis bên cạnh AI local.

### 4. Video

Dù đã thêm video, app hiện chỉ thêm từng file đơn lẻ. Cần cho phép quét cả thư
mục, hiển thị thư viện trực quan hơn, dễ thấy file, dễ lọc/chọn và phát. Nên hỗ
trợ ghép phụ đề cùng tên, recent/favorite và giữ vị trí phát gần nhất.

### 5. Tipiṭaka — import ngôn ngữ và phụ thuộc Pali

Khi import pack ngôn ngữ, ví dụ Tiếng Việt, app báo chưa thấy Pali tương ứng.
Cần UX rõ ràng hơn:

- Không nên bắt buộc pack dịch phụ thuộc Pali để import/đọc độc lập.
- Chỉ các tính năng đối chiếu song ngữ/căn hàng mới cần Pali.
- Nếu thiếu Pali, app nên gợi ý: "Nên import Pali trước để đối chiếu tốt hơn",
  nhưng vẫn cho dùng bản dịch ở chế độ độc lập nếu dữ liệu hợp lệ.

### 6. Tipiṭaka — tiêu đề, cây thư viện, mục lục, tab, split view, TTS

Hiện tiêu đề ba tạng đang lộ mã kỹ thuật, ví dụ:

`Vi diệu pháp - Abh01a Att - ABH01A_ATT abh01a_att`

Cần đổi sang tiêu đề đúng nội dung Tam Tạng, ưu tiên cấu trúc cây:

`Tam Tạng Chính Văn → Tạng (Kinh/Luật/Luận) → nhóm/bộ → bài kinh`

Bổ sung:

- Nút xem mục lục chi tiết trong từng bài.
- Mở nhiều tab kiểu Obsidian.
- Chia màn hình để xem hai tab cùng lúc, phục vụ đối chiếu.
- Đọc TTS theo đoạn/bài.
- Đọc tham chiếu nhánh `arena/01a06931-in4up` trước khi triển khai vì nhánh đó
  đang làm nội dung liên quan.

### 7. Hướng dẫn sử dụng

Bổ sung hướng dẫn sử dụng cho các luồng nhiều bước hoặc dễ lỗi: import model,
Server/API, từ điển, Tipiṭaka, thư viện media, PDF/OCR/TTS và IPA. Tối thiểu có
bản tiếng Việt và English fallback.

### 8. Tab Nghe

Thư viện nghe cần lọc và tổ chức thêm theo:

- Album.
- Tác giả/nghệ sĩ.
- Yêu thích.
- Playlist/list thủ công.
- Playlist/list thông minh, ví dụ gần đây, chưa nghe, theo thư mục hoặc tag.

Không được phá transcript/LRC và vị trí phát đã lưu.

### 9. Tab Đọc IPA

Ở chế độ dòng, khi mở file Word/DOCX, nội dung chưa hiện đúng. Ngoài ra, người
dùng không biết phải chạm vào đâu để hiện IPA. Cần:

- Sửa line mode cho file Word/DOCX.
- Thêm hướng dẫn dạng bottom snackbar/sheet trong vài giây, đủ thời gian đọc.
- Có cách mở lại hướng dẫn qua Help/tooltip.

### 10. Tab Viết — Tầng 2 AI local và lựa chọn LLM

Dù đã thêm AI local như Gemma 2B, Tab Viết vẫn báo các lỗi như:

- "AI chưa trả về phần tóm tắt rõ ràng".
- Chưa có chủ điểm.
- Chưa có gợi ý hành động cụ thể từ AI.

Các commit trước từng hoạt động tốt nên cần kiểm regression. Đồng thời cần lựa
chọn để dùng LLM qua **Server & API** cho phần tóm tắt/chủ điểm/hành động khi
người dùng muốn hoặc khi AI local lỗi.

### 11. Dịch Hy-MT

Dịch bằng Hy-MT vẫn chưa hoạt động ổn định. Cần kiểm lại đường dẫn model, validator,
load native, lỗi thiếu/hỏng file và thông báo lỗi. Không được trả kết quả rỗng
như thể dịch thành công.

### 12. Tích hợp nhà cung cấp AI

Cần khả năng tích hợp các nhà cung cấp AI để người dùng tự cấu hình trong app.
Hướng an toàn cho v1:

- BYOK: người dùng tự nhập API key hoặc server URL.
- Preset cho provider phổ biến hoặc local server OpenAI-compatible.
- Không hard-code key, không log key.
- OAuth/đăng nhập trực tiếp chỉ làm sau nếu SDK/ToS phù hợp và owner chốt.

### 13. Settings/Home — import model offline

Import model đang nhận diện sai trong nhiều trường hợp:

- Chọn nhiều file có kèm thư mục `espeak` nhưng app không tự nhập nên báo thiếu.
- Chọn cả thư mục thì app báo không tìm thấy `.onnx` và `.txt` dù file thật có.
- STT offline chọn đúng file hoặc đúng thư mục vẫn báo không nhận dạng được.

Cần validator thống nhất cho Piper/eSpeak/STT, quét đệ quy, báo thiếu file cụ thể
và hướng dẫn chọn lại.

### 14. OCR cho PDF trong Tab Đọc

Khi mở file PDF, vùng đọc bị load/spinner mãi ở phần OCR. Cần phân biệt PDF có
text layer và PDF scan, có timeout/hủy rõ ràng, không chạy OCR vô hạn ngay khi
không cần.

### 15. PDF Reader — TTS play/pause/next line

Các nút điều khiển TTS trong PDF Reader chưa đúng:

- Đang phát, bấm Pause nhưng âm vẫn tiếp tục.
- Bấm chuyển dòng sau thì app lướt nhanh qua nhiều dòng, không kịp đọc.
- Bấm Play/Stop/Pause nhưng playback không dừng ngay.

Nhận định: `flutter clean` có thể loại trừ build cache cũ, nhưng các lỗi này có
khả năng cao là lỗi state machine/cancel callback trong code. Không nên dùng
`flutter clean` như lời giải chính.

## 2. Mapping sang Kanban

| Card | Phạm vi |
|---|---|
| `I4U18-HOME-AI-001` | Home Chat, Tab Viết AI local, Server/API, BYOK/provider |
| `I4U18-DICT-001` | Từ điển MDX/MDD/CSS import/link folder |
| `I4U18-VIDEO-LIB-001` | Video folder scan + thư viện phát |
| `I4U18-TIPITAKA-001` | Tipiṭaka import pack, title tree, TOC, multi-tab, split, TTS |
| `I4U18-LISTEN-LIB-001` | Tab Nghe album/tác giả/yêu thích/playlist |
| `I4U18-READ-IPA-001` | Word/DOCX line mode + hướng dẫn IPA |
| `I4U18-TRANSLATE-001` | Hy-MT + LLM translation routing |
| `I4U18-MODEL-IMPORT-001` | eSpeak/Piper/STT offline import validator |
| `I4U18-PDF-OCR-TTS-001` | OCR spinner + PDF TTS play/pause/next |
| `I4U18-DOCS-001` | Hướng dẫn sử dụng |

## 3. Acceptance chung cho toàn batch

- Không có lỗi đỏ mới trong analyze/test/CI.
- Không lộ API key/token trong log, code, test hoặc docs.
- Không phá dữ liệu người dùng đã import: dictionary, model, audio, video, PDF,
  Tipiṭaka pack.
- Không phá reopen nguồn: PDF page/rect, audio timestamp, video timestamp, file
  path/content URI.
- Không hard-code tiếng Việt vào chrome UI khi locale khác `vi`.
- Mỗi lane cập nhật Kanban bằng trạng thái trung thực và bằng chứng thật.
