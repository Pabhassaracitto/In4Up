# Priority-locale chrome leak report

Sinh tự động bởi `python3 tool/lang_ui_inventory.py --write-report`.
Đừng sửa tay — chạy lại tool sau mỗi wave bản dịch.

- Chrome strings quét được: **2616** trong **194** file presentation.
- `vietnamese`: chuỗi vẫn hiện tiếng Việt ở locale đó (vi phạm rule #5).
- `english`: chuỗi vẫn hiện English (fallback hợp lệ, nhưng là việc còn lại của wave bản địa hoá).

| locale | vietnamese | english |
| --- | ---: | ---: |
| `zh` | 181 | 163 |
| `zh_TW` | 180 | 163 |
| `hi` | 195 | 164 |
| `si` | 184 | 163 |
| `my` | 184 | 175 |
| `th` | 184 | 173 |
| `ja` | 184 | 172 |

## `zh` — theo khu vực

| khu vực | còn lại |
| --- | ---: |
| Tipiṭaka | 80 |
| Learn by heart | 71 |
| Tools / WordList | 28 |
| Web Reader | 26 |
| Listen | 21 |
| Read | 20 |
| Other screens | 18 |
| Cabin | 15 |
| Other features | 11 |
| YouTube | 10 |
| PDF Reader | 9 |
| Shared widgets | 7 |
| Settings | 7 |
| Grammar / Understand | 6 |
| TTS | 6 |
| Memory | 4 |
| Other | 3 |
| Understand | 2 |

## `zh_TW` — theo khu vực

| khu vực | còn lại |
| --- | ---: |
| Tipiṭaka | 80 |
| Learn by heart | 71 |
| Tools / WordList | 28 |
| Web Reader | 26 |
| Listen | 21 |
| Read | 20 |
| Other screens | 18 |
| Cabin | 15 |
| Other features | 11 |
| YouTube | 10 |
| PDF Reader | 9 |
| Shared widgets | 7 |
| Settings | 7 |
| Grammar / Understand | 6 |
| TTS | 6 |
| Memory | 4 |
| Understand | 2 |
| Other | 2 |

## `hi` — theo khu vực

| khu vực | còn lại |
| --- | ---: |
| Tipiṭaka | 80 |
| Learn by heart | 71 |
| Tools / WordList | 28 |
| Web Reader | 27 |
| Listen | 22 |
| Read | 21 |
| Other screens | 20 |
| YouTube | 15 |
| Cabin | 15 |
| Other features | 11 |
| PDF Reader | 9 |
| Settings | 8 |
| Shared widgets | 7 |
| Grammar / Understand | 6 |
| TTS | 6 |
| Dictionary | 4 |
| Memory | 4 |
| Understand | 2 |
| Other | 2 |
| Translation | 1 |

## `si` — theo khu vực

| khu vực | còn lại |
| --- | ---: |
| Tipiṭaka | 80 |
| Learn by heart | 71 |
| Tools / WordList | 28 |
| Web Reader | 26 |
| Listen | 21 |
| Read | 20 |
| Other screens | 18 |
| Cabin | 15 |
| Other features | 11 |
| YouTube | 10 |
| PDF Reader | 9 |
| Shared widgets | 7 |
| Settings | 7 |
| Grammar / Understand | 6 |
| TTS | 6 |
| Dictionary | 4 |
| Memory | 4 |
| Understand | 2 |
| Other | 2 |

## `my` — theo khu vực

| khu vực | còn lại |
| --- | ---: |
| Tipiṭaka | 80 |
| Learn by heart | 71 |
| Tools / WordList | 30 |
| Web Reader | 28 |
| Listen | 22 |
| Read | 21 |
| Other screens | 19 |
| Cabin | 15 |
| Other features | 12 |
| PDF Reader | 10 |
| YouTube | 10 |
| Settings | 8 |
| Shared widgets | 7 |
| TTS | 7 |
| Grammar / Understand | 6 |
| Dictionary | 4 |
| Memory | 4 |
| Understand | 3 |
| Other | 2 |

## `th` — theo khu vực

| khu vực | còn lại |
| --- | ---: |
| Tipiṭaka | 80 |
| Learn by heart | 71 |
| Tools / WordList | 29 |
| Web Reader | 28 |
| Listen | 21 |
| Read | 21 |
| Other screens | 19 |
| Cabin | 15 |
| Other features | 12 |
| PDF Reader | 10 |
| YouTube | 10 |
| Settings | 8 |
| Shared widgets | 7 |
| TTS | 7 |
| Grammar / Understand | 6 |
| Dictionary | 4 |
| Memory | 4 |
| Understand | 3 |
| Other | 2 |

## `ja` — theo khu vực

| khu vực | còn lại |
| --- | ---: |
| Tipiṭaka | 80 |
| Learn by heart | 71 |
| Tools / WordList | 29 |
| Web Reader | 28 |
| Listen | 21 |
| Read | 21 |
| Other screens | 18 |
| Cabin | 15 |
| Other features | 12 |
| PDF Reader | 10 |
| YouTube | 10 |
| Settings | 8 |
| Shared widgets | 7 |
| TTS | 7 |
| Grammar / Understand | 6 |
| Dictionary | 4 |
| Memory | 4 |
| Understand | 3 |
| Other | 2 |

## Chi tiết (ưu tiên chuỗi còn tiếng Việt)

### `zh`

- **Cabin** — `Bản dịch thời gian thực sẽ hiển thị tại đây...`
- **Cabin** — `Chưa có dữ liệu hội thoại.
Bấm nút Micro để bắt đầu phiên dịch cabin.`
- **Cabin** — `Chọn ngôn ngữ dịch (Đích)`
- **Cabin** — `Chọn ngôn ngữ nói (Gốc)`
- **Cabin** — `Dịch Live Cabin`
- **Cabin** — `Khuyên dùng tai nghe khi bật phát âm để tránh tiếng dịch lọt ngược vào micro!`
- **Cabin** — `Nói vào microphone để bắt đầu dịch cabin...`
- **Cabin** — `Sao chép văn bản`
- **Cabin** — `Xóa lịch sử`
- **Cabin** — `Đang nghe trực tiếp...`
- **Cabin** — `Đã chép câu dịch!`
- **Cabin** — `Đã sao chép toàn bộ nội dung dịch cabin vào bộ nhớ tạm!`
- **Cabin** — `Đọc dịch`
- **Grammar / Understand** — `Nhóm từ loạ`
- **Learn by heart** — `Bước {value0}/{value1}: {value2}`
- **Learn by heart** — `Bạn đang duy trì thói quen ghi nhớ rất tốt!`
- **Learn by heart** — `Bạn đã đạt 5 lần ôn tập thành công liên tiếp! Bạn có muốn làm bài Kiểm Tra Thực Chất (Assessment không gợi ý) để nhân đôi độ bền vững không?`
- **Learn by heart** — `Bản dịch ({value0})`
- **Learn by heart** — `Bản dịch ({value0}):`
- **Learn by heart** — `Bắt đầu đọc`
- **Learn by heart** — `CHẾ ĐỘ KHÔNG GỢI Ý`
- **Learn by heart** — `Chuẩn xác 100%`
- **Learn by heart** — `Chúc mừng bạn đã hoàn tất ghép bài!`
- **Learn by heart** — `Chạm để dừng & chấm điểm`
- **Learn by heart** — `Chỗ trống: chạm từ để ẩn khi ôn — không cần gõ {{c1::từ}}`
- **Learn by heart** — `CÂU CẦN ĐỌC TIẾP (DÒNG {value0})`
- **Learn by heart** — `CÂU MỒI DẪN DẮT (DÒNG {value0})`
- **Learn by heart** — `Cập nhật`
- **Learn by heart** — `Cố gắng nhẩm lại từng câu một cách trọn vẹn nhất trước khi mở văn bản đối chiếu.`
- **Learn by heart** — `Dựa trên thuật toán FSRS & chu kỳ quên tự nhiên.`
- **Learn by heart** — `Ghi nhận kết quả ({value0}) vào FSRS`
- **Learn by heart** — `Hoàn tất xích kệ ngôn! 🎉`
- **Learn by heart** — `Hành động này sẽ nạp lại toàn bộ 10 Kệ Pháp Cú và các bài kinh tụng chuẩn mẫu ban đầu. Bạn có muốn tiếp tục không?`
- **Learn by heart** — `Hành động và tâm ý tạo tác quả báo.`
- **Learn by heart** — `Hãy tự đọc toàn bài trong đầu`
- **Learn by heart** — `Hãy đọc nhẩm toàn bộ bài một lần cuối và chọn mức độ nhớ để FSRS tự động lên lịch nhắc ôn.`
- **Learn by heart** — `Học cuốn chiếu (Chunking Flow)`
- **Learn by heart** — `Không tìm thấy bài học phù hợp`
- **Learn by heart** — `Kiểm tra thực chất (Assessment)`
- **Learn by heart** — `Liên hệ thực tế đời sống (1 câu)`
- **Learn by heart** — `Lắng nghe câu mở đầu, sau đó tự đọc trọn vẹn phần còn lại`
- **Learn by heart** — `Mối nối liên hoàn (Xích kệ ngôn {value0}/{value1})`
- **Learn by heart** — `Nguyên văn ({value0})`
- **Learn by heart** — `Nguyên văn ({value0}):`
- **Learn by heart** — `Nhấn nút Mic bên dưới và đọc câu kinh vào điện thoại để chấm điểm thuộc lòng`
- **Learn by heart** — `Nối xích`
- **Learn by heart** — `Phụ đề / Chủ đề ngắn`
- **Learn by heart** — `Quên / vấp nhiều`
- **Learn by heart** — `So sánh với bản đọc nhẩm trong đầu và tự đánh giá thực chất (Trọng số x2):`
- **Learn by heart** — `Song ngữ ({value0} + {value1})`
- **Learn by heart** — `Sẵn sàng test`
- **Learn by heart** — `Số lần phát bài / đoạ`
- **Learn by heart** — `Số lần phát câu {value0}`
- **Learn by heart** — `TOÀN VĂN ĐỐI CHIẾU`
- **Learn by heart** — `Thuộc câu nối → Sang mối tiếp`
- **Learn by heart** — `Thuộc lòng xuất sắc! 🎉`
- **Learn by heart** — `Thêm bài học thuộc lòng mới`
- **Learn by heart** — `Thể loại`
- **Learn by heart** — `Thử thay đổi bộ lọc hoặc thêm bài mới vào danh sách`
- **Learn by heart** — `Thử thách Thuộc Lòng!`
- **Learn by heart** — `Tiêu đề bài kinh / kệ ngôn`
- **Learn by heart** — `Tuyệt vời! Bạn đã hoàn thành toàn bộ bài ôn tập hôm nay.`
- **Learn by heart** — `Tôi đã đọc xong trong đầu`
- **Learn by heart** — `Từ khóa ghi nhớ (phân cách bằng dấu phẩy)`
- **Learn by heart** — `Vui lòng cấp quyền Microphone để ghi âm`
- **Learn by heart** — `VĂN BẢN MỤC TIÊU CẦN ĐỌC`
- **Learn by heart** — `Xem câu tiếp theo`
- **Learn by heart** — `___ ? Hãy nhớ câu tiếp theo trong đầu ? ___`
- **Learn by heart** — `Ôn sau {value0}`
- **Learn by heart** — `Ý nghĩa cốt lõi (≤ 15 từ)`
- **Learn by heart** — `Đang phân tích & đối chiếu giọng đọc...`
- **Learn by heart** — `Đoạn {value0}`
- **Learn by heart** — `Đã ôn {value0} lần`
- **Learn by heart** — `Đến hạn ôn`
- **Learn by heart** — `Đọc bằng giọng nói (Voice Recall)`
- **Learn by heart** — `ĐỐI CHIẾU TOÀN VĂN`
- **Learn by heart** — `🎙️ Đang lắng nghe... Hãy đọc to trọn vẹn câu kinh`
- **Other** — `Chưa có nội dung`
- **Other screens** — `Lưu thất`
- **PDF Reader** — `Không trích xuất được text từ trang `
- **PDF Reader** — `ghi chú`
- **Shared widgets** — `App sẽ phân tích âm thanh và tạo mục lục như sách.

🟢 Chạy nền — đóng cửa sổ này cũng được, tiến trì`
- **TTS** — `Giọng Microsoft Edge Neural theo ngôn ngữ`
- **TTS** — `Mỗi ngôn ngữ chọn 1 giọng Edge. Tự động áp dụng khi phát bằng engine Microsoft Edge TTS (không ảnh hưởng Piper/giọng máy).`
- **TTS** — `Mỗi ngôn ngữ chọn 1 giọng đã import. Tự động ưu tiên phát khi dùng Sherpa TTS.`
- **TTS** — `Piper × : chưa có giọng HOẶC thiếu phonemizer (espeak-ng-data) — cài tại TTS → Quản lý model`
- **Tipiṭaka** — `Bạn có thể chọn trực tiếp DB Pa-Auk .db/.sqlite/.zip hoặc file tipitaka.sqlite đã chuẩn hóa. Với build developer, đặt file vào Documents/in4up/tipitaka/imports/ rồi bấm Quét thư mục import. Ứng dụng sẽ tự nhận diện, chuyển DB nguồn sang schema In4Up và giữ lại Python importer cho các DB rất lớn.`
- **Tipiṭaka** — `Bạn vẫn có thể import và đọc Tiếng Việt ngay. Nên import Pāli trước hoặc sau để đối chiếu tốt hơn; khi chưa có Pāli, xem song ngữ và căn hàng sẽ tạm giảm cấp.`
- **Tipiṭaka** — `Bản dịch vẫn đọc độc lập. Nên import Pāli để đối chiếu tốt hơn; song ngữ và căn hàng đang tạm giảm cấp.`
- **Tipiṭaka** — `Chi tiết kỹ thuật`
- **Tipiṭaka** — `Chia đôi màn hình`
- **Tipiṭaka** — `Chưa có cơ sở dữ liệu hợp lệ`
- **Tipiṭaka** — `Chưa import Pāli; bản dịch vẫn đọc độc lập.`
- **Tipiṭaka** — `Chưa thấy file. Hãy đặt .db/.sqlite/.zip vào thư mục Documents/in4up/tipitaka/imports rồi quét lại.`
- **Tipiṭaka** — `Có thể đối chiếu Pāli và bản dịch theo đoạn.`
- **Tipiṭaka** — `Cơ sở dữ liệu đã sẵn sàng`
- **Tipiṭaka** — `Gói ngôn ngữ Tipiṭaka`
- **Tipiṭaka** — `Hãy import DB Pa-Auk hoặc tải gói ngôn ngữ.`
- **Tipiṭaka** — `Học thuộc đoạn này`
- **Tipiṭaka** — `Import DB hoặc gói ngôn ngữ từ thiết bị`
- **Tipiṭaka** — `Import hoặc tải dữ liệu`
- **Tipiṭaka** — `Import một gói ngôn ngữ bất kỳ để bắt đầu. Pāli được khuyến nghị nhưng không bắt buộc.`
- **Tipiṭaka** — `Import thất bại: {value0}`
- **Tipiṭaka** — `Không gian đọc Tipiṭaka`
- **Tipiṭaka** — `Không thể kiểm tra cơ sở dữ liệu Tipiṭaka.`
- **Tipiṭaka** — `Không thể lưu vào Worklist: {value0}`
- **Tipiṭaka** — `Không thể mở cơ sở dữ liệu Tipiṭaka.`
- **Tipiṭaka** — `Không thể mở danh mục: {value0}`
- **Tipiṭaka** — `Không thể mở đoạn: {value0}`
- **Tipiṭaka** — `Không thể thêm vào Học thuộc lòng: {value0}`
- **Tipiṭaka** — `Không thể tải {value0}: {value1}`
- **Tipiṭaka** — `Không tìm thấy lại nguồn Tipiṭaka.`
- **Tipiṭaka** — `Kiểm tra lại DB`
- **Tipiṭaka** — `Lưu cụm từ vào Worklist`
- **Tipiṭaka** — `Lưu từ vào Worklist`
- **Tipiṭaka** — `Lưu đoạn vào Worklist`
- **Tipiṭaka** — `Mỗi gói ngôn ngữ có thể import độc lập.`
- **Tipiṭaka** — `Mở bài trong tab mới`
- **Tipiṭaka** — `Mở nguồn Tipiṭaka`
- **Tipiṭaka** — `Mở thêm một bài để dùng chế độ chia đôi.`
- **Tipiṭaka** — `Mở thư viện`
- **Tipiṭaka** — `Mở trang nguồn Pa-Auk`
- **Tipiṭaka** — `Mục chưa có tiêu đề`
- **Tipiṭaka** — `Mục lục chi tiết`
- **Tipiṭaka** — `Nhập từ khóa để tìm trong Tipiṭaka`
- **Tipiṭaka** — `Pāli không bắt buộc để tiếp tục đọc.`
- **Tipiṭaka** — `Quét thư mục import của developer`
- **Tipiṭaka** — `Quét thất bại: {value0}`
- **Tipiṭaka** — `Quản lý dữ liệu`
- **Tipiṭaka** — `Tam Tạng Chính Văn`
- **Tipiṭaka** — `Tipiṭaka chưa có dữ liệu`
- **Tipiṭaka** — `Tipiṭaka — Dữ liệu`
- **Tipiṭaka** — `Tác vụ Tipiṭaka gần đây`
- **Tipiṭaka** — `Tìm kiếm Tipiṭaka`
- **Tipiṭaka** — `Tạng → nhóm/bộ → bài kinh`
- **Tipiṭaka** — `Tải gói ngôn ngữ Pa-Auk`
- **Tipiṭaka** — `Tải và giải nén`
- **Tipiṭaka** — `Từ khóa Pāli / bản dịch…`
- **Tipiṭaka** — `nhóm/bộ`
- **Tipiṭaka** — `sách`
- **Tipiṭaka** — `tạng`
- **Tipiṭaka** — `Đang giải nén`
- **Tipiṭaka** — `Đang import`
- **Tipiṭaka** — `Đang xếp hàng`
- **Tipiṭaka** — `Đã hoàn tất`
- **Tipiṭaka** — `Đã import các file tìm thấy trong thư mục.`
- **Tipiṭaka** — `Đã import cơ sở dữ liệu Tipiṭaka.`
- **Tipiṭaka** — `Đã lưu vào Worklist.`
- **Tipiṭaka** — `Đã sao chép lựa chọn.`
- **Tipiṭaka** — `Đã thêm ngữ cảnh Tipiṭaka vào từ đã có.`
- **Tipiṭaka** — `Đã thêm đoạn vào Học thuộc lòng.`
- **Tipiṭaka** — `Đã tải và import {value0} trực tiếp vào thư viện Tipiṭaka.`
- **Tipiṭaka** — `Đóng tab`
- **Tipiṭaka** — `Đọc Tam Tạng theo ngôn ngữ đã import`
- **Tipiṭaka** — `Đọc bài từ vị trí hiện tại`
- **Tipiṭaka** — `Đọc toàn bộ nhóm/bộ`
- **Tipiṭaka** — `đoạn kinh`
- **Tipiṭaka** — `Ẩn thông báo`
- **Tools / WordList** — ` · 🔥 {value0} lặp nhiều`
- **Tools / WordList** — `.txt: Mỗi dòng 1 từ, hoặc văn bản thường
.csv/.txt bảng cột (cần dòng header): word, meaning, ipa, topic, example, example_simple, example_complex, language, image_url (tùy chọn — link ảnh .png/.webp hoặc animation Lottie .json; tải về máy để học offline)
Ngăn cột: tab, phẩy, chấm phẩy hoặc | — ý nghĩa có dấu phẩy thì bọc "nét nháy"
Từ/cụm ĐÃ CÓ trong WordList vẫn hiện (badge "đã có") — import chỉ bổ sung nghĩa/IPA/ví dụ/minh họa CHỖ TRỐNG + tag, không ghi đè`
- **Tools / WordList** — `Dán bảng có header: word, meaning, ipa, topic, example, language, image_url (tùy chọn — link ảnh/Lottie .json)
(tab hoặc dấu phẩy; meaning có dấu phẩy thì bọc "nét nháy")
Hoặc text thường / một từ mỗi dòng...`
- **Tools / WordList** — `Lọc theo thực thể, trạng thái, ngô`
- **Tools / WordList** — `Mở Listen Mode, nghe file bất kỳ rồi:
• Chạm 📌 "Dấu" để đánh dấu một điểm
• Chọn A–B rồi lưu thành đoạn học tập
• Mở "Âm mục" để tạo mục lục như sách

Mọi thứ bạn đánh dấu sẽ xuất hiện tại đây.`
- **Tools / WordList** — `Ngôn ngữ (chọn 1–n — đầu danh sách = chính)`
- **Tools / WordList** — `Thêm mục`
- **Tools / WordList** — `Thêm mục cho file`
- **Tools / WordList** — `Tên chương/mục`
- **Tools / WordList** — `mục`
- **Tools / WordList** — `nét nháy`
- **Tools / WordList** — `{value0} · {value1} điểm · {value2} đoạn · {value3} mục{value4}`
- **Tools / WordList** — `điểm`
- **Tools / WordList** — `đã có`
- **Tools / WordList** — `… và {value0} dòng nữa — dùng "Tìm kiếm" trong Listen Mode để tìm trong toàn bộ nội dung.`
- **Tools / WordList** — `▶️ Đang phát: {value0}`
- **Tools / WordList** — `✅ Đã import: +{value0} mới, cập nhật {value1} đã có`
- **Tools / WordList** — `🔍  Tìm tên file, nhãn, ghi chú, tag…`
- **Web Reader** — `Dừng đọc`
- **Web Reader** — `Hãy tạo ít nhất `
- **Web Reader** — `Ngôn ngữ áp cho tất cả`
- **Web Reader** — `Đang đọc bài web`
- **Web Reader** — `Đã tạm dừng bài đọc`

### `zh_TW`

- **Cabin** — `Bản dịch thời gian thực sẽ hiển thị tại đây...`
- **Cabin** — `Chưa có dữ liệu hội thoại.
Bấm nút Micro để bắt đầu phiên dịch cabin.`
- **Cabin** — `Chọn ngôn ngữ dịch (Đích)`
- **Cabin** — `Chọn ngôn ngữ nói (Gốc)`
- **Cabin** — `Dịch Live Cabin`
- **Cabin** — `Khuyên dùng tai nghe khi bật phát âm để tránh tiếng dịch lọt ngược vào micro!`
- **Cabin** — `Nói vào microphone để bắt đầu dịch cabin...`
- **Cabin** — `Sao chép văn bản`
- **Cabin** — `Xóa lịch sử`
- **Cabin** — `Đang nghe trực tiếp...`
- **Cabin** — `Đã chép câu dịch!`
- **Cabin** — `Đã sao chép toàn bộ nội dung dịch cabin vào bộ nhớ tạm!`
- **Cabin** — `Đọc dịch`
- **Grammar / Understand** — `Nhóm từ loạ`
- **Learn by heart** — `Bước {value0}/{value1}: {value2}`
- **Learn by heart** — `Bạn đang duy trì thói quen ghi nhớ rất tốt!`
- **Learn by heart** — `Bạn đã đạt 5 lần ôn tập thành công liên tiếp! Bạn có muốn làm bài Kiểm Tra Thực Chất (Assessment không gợi ý) để nhân đôi độ bền vững không?`
- **Learn by heart** — `Bản dịch ({value0})`
- **Learn by heart** — `Bản dịch ({value0}):`
- **Learn by heart** — `Bắt đầu đọc`
- **Learn by heart** — `CHẾ ĐỘ KHÔNG GỢI Ý`
- **Learn by heart** — `Chuẩn xác 100%`
- **Learn by heart** — `Chúc mừng bạn đã hoàn tất ghép bài!`
- **Learn by heart** — `Chạm để dừng & chấm điểm`
- **Learn by heart** — `Chỗ trống: chạm từ để ẩn khi ôn — không cần gõ {{c1::từ}}`
- **Learn by heart** — `CÂU CẦN ĐỌC TIẾP (DÒNG {value0})`
- **Learn by heart** — `CÂU MỒI DẪN DẮT (DÒNG {value0})`
- **Learn by heart** — `Cập nhật`
- **Learn by heart** — `Cố gắng nhẩm lại từng câu một cách trọn vẹn nhất trước khi mở văn bản đối chiếu.`
- **Learn by heart** — `Dựa trên thuật toán FSRS & chu kỳ quên tự nhiên.`
- **Learn by heart** — `Ghi nhận kết quả ({value0}) vào FSRS`
- **Learn by heart** — `Hoàn tất xích kệ ngôn! 🎉`
- **Learn by heart** — `Hành động này sẽ nạp lại toàn bộ 10 Kệ Pháp Cú và các bài kinh tụng chuẩn mẫu ban đầu. Bạn có muốn tiếp tục không?`
- **Learn by heart** — `Hành động và tâm ý tạo tác quả báo.`
- **Learn by heart** — `Hãy tự đọc toàn bài trong đầu`
- **Learn by heart** — `Hãy đọc nhẩm toàn bộ bài một lần cuối và chọn mức độ nhớ để FSRS tự động lên lịch nhắc ôn.`
- **Learn by heart** — `Học cuốn chiếu (Chunking Flow)`
- **Learn by heart** — `Không tìm thấy bài học phù hợp`
- **Learn by heart** — `Kiểm tra thực chất (Assessment)`
- **Learn by heart** — `Liên hệ thực tế đời sống (1 câu)`
- **Learn by heart** — `Lắng nghe câu mở đầu, sau đó tự đọc trọn vẹn phần còn lại`
- **Learn by heart** — `Mối nối liên hoàn (Xích kệ ngôn {value0}/{value1})`
- **Learn by heart** — `Nguyên văn ({value0})`
- **Learn by heart** — `Nguyên văn ({value0}):`
- **Learn by heart** — `Nhấn nút Mic bên dưới và đọc câu kinh vào điện thoại để chấm điểm thuộc lòng`
- **Learn by heart** — `Nối xích`
- **Learn by heart** — `Phụ đề / Chủ đề ngắn`
- **Learn by heart** — `Quên / vấp nhiều`
- **Learn by heart** — `So sánh với bản đọc nhẩm trong đầu và tự đánh giá thực chất (Trọng số x2):`
- **Learn by heart** — `Song ngữ ({value0} + {value1})`
- **Learn by heart** — `Sẵn sàng test`
- **Learn by heart** — `Số lần phát bài / đoạ`
- **Learn by heart** — `Số lần phát câu {value0}`
- **Learn by heart** — `TOÀN VĂN ĐỐI CHIẾU`
- **Learn by heart** — `Thuộc câu nối → Sang mối tiếp`
- **Learn by heart** — `Thuộc lòng xuất sắc! 🎉`
- **Learn by heart** — `Thêm bài học thuộc lòng mới`
- **Learn by heart** — `Thể loại`
- **Learn by heart** — `Thử thay đổi bộ lọc hoặc thêm bài mới vào danh sách`
- **Learn by heart** — `Thử thách Thuộc Lòng!`
- **Learn by heart** — `Tiêu đề bài kinh / kệ ngôn`
- **Learn by heart** — `Tuyệt vời! Bạn đã hoàn thành toàn bộ bài ôn tập hôm nay.`
- **Learn by heart** — `Tôi đã đọc xong trong đầu`
- **Learn by heart** — `Từ khóa ghi nhớ (phân cách bằng dấu phẩy)`
- **Learn by heart** — `Vui lòng cấp quyền Microphone để ghi âm`
- **Learn by heart** — `VĂN BẢN MỤC TIÊU CẦN ĐỌC`
- **Learn by heart** — `Xem câu tiếp theo`
- **Learn by heart** — `___ ? Hãy nhớ câu tiếp theo trong đầu ? ___`
- **Learn by heart** — `Ôn sau {value0}`
- **Learn by heart** — `Ý nghĩa cốt lõi (≤ 15 từ)`
- **Learn by heart** — `Đang phân tích & đối chiếu giọng đọc...`
- **Learn by heart** — `Đoạn {value0}`
- **Learn by heart** — `Đã ôn {value0} lần`
- **Learn by heart** — `Đến hạn ôn`
- **Learn by heart** — `Đọc bằng giọng nói (Voice Recall)`
- **Learn by heart** — `ĐỐI CHIẾU TOÀN VĂN`
- **Learn by heart** — `🎙️ Đang lắng nghe... Hãy đọc to trọn vẹn câu kinh`
- **Other screens** — `Lưu thất`
- **PDF Reader** — `Không trích xuất được text từ trang `
- **PDF Reader** — `ghi chú`
- **Shared widgets** — `App sẽ phân tích âm thanh và tạo mục lục như sách.

🟢 Chạy nền — đóng cửa sổ này cũng được, tiến trì`
- **TTS** — `Giọng Microsoft Edge Neural theo ngôn ngữ`
- **TTS** — `Mỗi ngôn ngữ chọn 1 giọng Edge. Tự động áp dụng khi phát bằng engine Microsoft Edge TTS (không ảnh hưởng Piper/giọng máy).`
- **TTS** — `Mỗi ngôn ngữ chọn 1 giọng đã import. Tự động ưu tiên phát khi dùng Sherpa TTS.`
- **TTS** — `Piper × : chưa có giọng HOẶC thiếu phonemizer (espeak-ng-data) — cài tại TTS → Quản lý model`
- **Tipiṭaka** — `Bạn có thể chọn trực tiếp DB Pa-Auk .db/.sqlite/.zip hoặc file tipitaka.sqlite đã chuẩn hóa. Với build developer, đặt file vào Documents/in4up/tipitaka/imports/ rồi bấm Quét thư mục import. Ứng dụng sẽ tự nhận diện, chuyển DB nguồn sang schema In4Up và giữ lại Python importer cho các DB rất lớn.`
- **Tipiṭaka** — `Bạn vẫn có thể import và đọc Tiếng Việt ngay. Nên import Pāli trước hoặc sau để đối chiếu tốt hơn; khi chưa có Pāli, xem song ngữ và căn hàng sẽ tạm giảm cấp.`
- **Tipiṭaka** — `Bản dịch vẫn đọc độc lập. Nên import Pāli để đối chiếu tốt hơn; song ngữ và căn hàng đang tạm giảm cấp.`
- **Tipiṭaka** — `Chi tiết kỹ thuật`
- **Tipiṭaka** — `Chia đôi màn hình`
- **Tipiṭaka** — `Chưa có cơ sở dữ liệu hợp lệ`
- **Tipiṭaka** — `Chưa import Pāli; bản dịch vẫn đọc độc lập.`
- **Tipiṭaka** — `Chưa thấy file. Hãy đặt .db/.sqlite/.zip vào thư mục Documents/in4up/tipitaka/imports rồi quét lại.`
- **Tipiṭaka** — `Có thể đối chiếu Pāli và bản dịch theo đoạn.`
- **Tipiṭaka** — `Cơ sở dữ liệu đã sẵn sàng`
- **Tipiṭaka** — `Gói ngôn ngữ Tipiṭaka`
- **Tipiṭaka** — `Hãy import DB Pa-Auk hoặc tải gói ngôn ngữ.`
- **Tipiṭaka** — `Học thuộc đoạn này`
- **Tipiṭaka** — `Import DB hoặc gói ngôn ngữ từ thiết bị`
- **Tipiṭaka** — `Import hoặc tải dữ liệu`
- **Tipiṭaka** — `Import một gói ngôn ngữ bất kỳ để bắt đầu. Pāli được khuyến nghị nhưng không bắt buộc.`
- **Tipiṭaka** — `Import thất bại: {value0}`
- **Tipiṭaka** — `Không gian đọc Tipiṭaka`
- **Tipiṭaka** — `Không thể kiểm tra cơ sở dữ liệu Tipiṭaka.`
- **Tipiṭaka** — `Không thể lưu vào Worklist: {value0}`
- **Tipiṭaka** — `Không thể mở cơ sở dữ liệu Tipiṭaka.`
- **Tipiṭaka** — `Không thể mở danh mục: {value0}`
- **Tipiṭaka** — `Không thể mở đoạn: {value0}`
- **Tipiṭaka** — `Không thể thêm vào Học thuộc lòng: {value0}`
- **Tipiṭaka** — `Không thể tải {value0}: {value1}`
- **Tipiṭaka** — `Không tìm thấy lại nguồn Tipiṭaka.`
- **Tipiṭaka** — `Kiểm tra lại DB`
- **Tipiṭaka** — `Lưu cụm từ vào Worklist`
- **Tipiṭaka** — `Lưu từ vào Worklist`
- **Tipiṭaka** — `Lưu đoạn vào Worklist`
- **Tipiṭaka** — `Mỗi gói ngôn ngữ có thể import độc lập.`
- **Tipiṭaka** — `Mở bài trong tab mới`
- **Tipiṭaka** — `Mở nguồn Tipiṭaka`
- **Tipiṭaka** — `Mở thêm một bài để dùng chế độ chia đôi.`
- **Tipiṭaka** — `Mở thư viện`
- **Tipiṭaka** — `Mở trang nguồn Pa-Auk`
- **Tipiṭaka** — `Mục chưa có tiêu đề`
- **Tipiṭaka** — `Mục lục chi tiết`
- **Tipiṭaka** — `Nhập từ khóa để tìm trong Tipiṭaka`
- **Tipiṭaka** — `Pāli không bắt buộc để tiếp tục đọc.`
- **Tipiṭaka** — `Quét thư mục import của developer`
- **Tipiṭaka** — `Quét thất bại: {value0}`
- **Tipiṭaka** — `Quản lý dữ liệu`
- **Tipiṭaka** — `Tam Tạng Chính Văn`
- **Tipiṭaka** — `Tipiṭaka chưa có dữ liệu`
- **Tipiṭaka** — `Tipiṭaka — Dữ liệu`
- **Tipiṭaka** — `Tác vụ Tipiṭaka gần đây`
- **Tipiṭaka** — `Tìm kiếm Tipiṭaka`
- **Tipiṭaka** — `Tạng → nhóm/bộ → bài kinh`
- **Tipiṭaka** — `Tải gói ngôn ngữ Pa-Auk`
- **Tipiṭaka** — `Tải và giải nén`
- **Tipiṭaka** — `Từ khóa Pāli / bản dịch…`
- **Tipiṭaka** — `nhóm/bộ`
- **Tipiṭaka** — `sách`
- **Tipiṭaka** — `tạng`
- **Tipiṭaka** — `Đang giải nén`
- **Tipiṭaka** — `Đang import`
- **Tipiṭaka** — `Đang xếp hàng`
- **Tipiṭaka** — `Đã hoàn tất`
- **Tipiṭaka** — `Đã import các file tìm thấy trong thư mục.`
- **Tipiṭaka** — `Đã import cơ sở dữ liệu Tipiṭaka.`
- **Tipiṭaka** — `Đã lưu vào Worklist.`
- **Tipiṭaka** — `Đã sao chép lựa chọn.`
- **Tipiṭaka** — `Đã thêm ngữ cảnh Tipiṭaka vào từ đã có.`
- **Tipiṭaka** — `Đã thêm đoạn vào Học thuộc lòng.`
- **Tipiṭaka** — `Đã tải và import {value0} trực tiếp vào thư viện Tipiṭaka.`
- **Tipiṭaka** — `Đóng tab`
- **Tipiṭaka** — `Đọc Tam Tạng theo ngôn ngữ đã import`
- **Tipiṭaka** — `Đọc bài từ vị trí hiện tại`
- **Tipiṭaka** — `Đọc toàn bộ nhóm/bộ`
- **Tipiṭaka** — `đoạn kinh`
- **Tipiṭaka** — `Ẩn thông báo`
- **Tools / WordList** — ` · 🔥 {value0} lặp nhiều`
- **Tools / WordList** — `.txt: Mỗi dòng 1 từ, hoặc văn bản thường
.csv/.txt bảng cột (cần dòng header): word, meaning, ipa, topic, example, example_simple, example_complex, language, image_url (tùy chọn — link ảnh .png/.webp hoặc animation Lottie .json; tải về máy để học offline)
Ngăn cột: tab, phẩy, chấm phẩy hoặc | — ý nghĩa có dấu phẩy thì bọc "nét nháy"
Từ/cụm ĐÃ CÓ trong WordList vẫn hiện (badge "đã có") — import chỉ bổ sung nghĩa/IPA/ví dụ/minh họa CHỖ TRỐNG + tag, không ghi đè`
- **Tools / WordList** — `Dán bảng có header: word, meaning, ipa, topic, example, language, image_url (tùy chọn — link ảnh/Lottie .json)
(tab hoặc dấu phẩy; meaning có dấu phẩy thì bọc "nét nháy")
Hoặc text thường / một từ mỗi dòng...`
- **Tools / WordList** — `Lọc theo thực thể, trạng thái, ngô`
- **Tools / WordList** — `Mở Listen Mode, nghe file bất kỳ rồi:
• Chạm 📌 "Dấu" để đánh dấu một điểm
• Chọn A–B rồi lưu thành đoạn học tập
• Mở "Âm mục" để tạo mục lục như sách

Mọi thứ bạn đánh dấu sẽ xuất hiện tại đây.`
- **Tools / WordList** — `Ngôn ngữ (chọn 1–n — đầu danh sách = chính)`
- **Tools / WordList** — `Thêm mục`
- **Tools / WordList** — `Thêm mục cho file`
- **Tools / WordList** — `Tên chương/mục`
- **Tools / WordList** — `mục`
- **Tools / WordList** — `nét nháy`
- **Tools / WordList** — `{value0} · {value1} điểm · {value2} đoạn · {value3} mục{value4}`
- **Tools / WordList** — `điểm`
- **Tools / WordList** — `đã có`
- **Tools / WordList** — `… và {value0} dòng nữa — dùng "Tìm kiếm" trong Listen Mode để tìm trong toàn bộ nội dung.`
- **Tools / WordList** — `▶️ Đang phát: {value0}`
- **Tools / WordList** — `✅ Đã import: +{value0} mới, cập nhật {value1} đã có`
- **Tools / WordList** — `🔍  Tìm tên file, nhãn, ghi chú, tag…`
- **Web Reader** — `Dừng đọc`
- **Web Reader** — `Hãy tạo ít nhất `
- **Web Reader** — `Ngôn ngữ áp cho tất cả`
- **Web Reader** — `Đang đọc bài web`
- **Web Reader** — `Đã tạm dừng bài đọc`

### `hi`

- **Cabin** — `Bản dịch thời gian thực sẽ hiển thị tại đây...`
- **Cabin** — `Chưa có dữ liệu hội thoại.
Bấm nút Micro để bắt đầu phiên dịch cabin.`
- **Cabin** — `Chọn ngôn ngữ dịch (Đích)`
- **Cabin** — `Chọn ngôn ngữ nói (Gốc)`
- **Cabin** — `Dịch Live Cabin`
- **Cabin** — `Khuyên dùng tai nghe khi bật phát âm để tránh tiếng dịch lọt ngược vào micro!`
- **Cabin** — `Nói vào microphone để bắt đầu dịch cabin...`
- **Cabin** — `Sao chép văn bản`
- **Cabin** — `Xóa lịch sử`
- **Cabin** — `Đang nghe trực tiếp...`
- **Cabin** — `Đã chép câu dịch!`
- **Cabin** — `Đã sao chép toàn bộ nội dung dịch cabin vào bộ nhớ tạm!`
- **Cabin** — `Đọc dịch`
- **Dictionary** — `Bấm Import thư mục để thêm bộ từ điển (.mdx + .mdd + .css), rồi chọn liên kết (không sao chép) hoặc sao chép vào app.`
- **Dictionary** — `Sao chép mdx + mdd + css vào bộ nhớ app để dùng ổn định khi di chuyển hoặc xoá nguồn. Bản gốc vẫn được giữ nguyên; app có thêm một bản sao nên tốn thêm dung lượng tương ứng.`
- **Dictionary** — `Thư mục từ điển không còn truy cập được — chọn lại. Chỉ mục SQLite trong app vẫn được giữ.`
- **Dictionary** — `Ưu tiên — chỉ lưu chỉ mục tra từ nhỏ trong app; không sao chép bộ từ điển (mdx/mdd vẫn ở thư mục gốc). Nếu nguồn không còn truy cập được, chọn lại; chỉ mục vẫn được giữ.`
- **Grammar / Understand** — `Nhóm từ loạ`
- **Learn by heart** — `Bước {value0}/{value1}: {value2}`
- **Learn by heart** — `Bạn đang duy trì thói quen ghi nhớ rất tốt!`
- **Learn by heart** — `Bạn đã đạt 5 lần ôn tập thành công liên tiếp! Bạn có muốn làm bài Kiểm Tra Thực Chất (Assessment không gợi ý) để nhân đôi độ bền vững không?`
- **Learn by heart** — `Bản dịch ({value0})`
- **Learn by heart** — `Bản dịch ({value0}):`
- **Learn by heart** — `Bắt đầu đọc`
- **Learn by heart** — `CHẾ ĐỘ KHÔNG GỢI Ý`
- **Learn by heart** — `Chuẩn xác 100%`
- **Learn by heart** — `Chúc mừng bạn đã hoàn tất ghép bài!`
- **Learn by heart** — `Chạm để dừng & chấm điểm`
- **Learn by heart** — `Chỗ trống: chạm từ để ẩn khi ôn — không cần gõ {{c1::từ}}`
- **Learn by heart** — `CÂU CẦN ĐỌC TIẾP (DÒNG {value0})`
- **Learn by heart** — `CÂU MỒI DẪN DẮT (DÒNG {value0})`
- **Learn by heart** — `Cập nhật`
- **Learn by heart** — `Cố gắng nhẩm lại từng câu một cách trọn vẹn nhất trước khi mở văn bản đối chiếu.`
- **Learn by heart** — `Dựa trên thuật toán FSRS & chu kỳ quên tự nhiên.`
- **Learn by heart** — `Ghi nhận kết quả ({value0}) vào FSRS`
- **Learn by heart** — `Hoàn tất xích kệ ngôn! 🎉`
- **Learn by heart** — `Hành động này sẽ nạp lại toàn bộ 10 Kệ Pháp Cú và các bài kinh tụng chuẩn mẫu ban đầu. Bạn có muốn tiếp tục không?`
- **Learn by heart** — `Hành động và tâm ý tạo tác quả báo.`
- **Learn by heart** — `Hãy tự đọc toàn bài trong đầu`
- **Learn by heart** — `Hãy đọc nhẩm toàn bộ bài một lần cuối và chọn mức độ nhớ để FSRS tự động lên lịch nhắc ôn.`
- **Learn by heart** — `Học cuốn chiếu (Chunking Flow)`
- **Learn by heart** — `Không tìm thấy bài học phù hợp`
- **Learn by heart** — `Kiểm tra thực chất (Assessment)`
- **Learn by heart** — `Liên hệ thực tế đời sống (1 câu)`
- **Learn by heart** — `Lắng nghe câu mở đầu, sau đó tự đọc trọn vẹn phần còn lại`
- **Learn by heart** — `Mối nối liên hoàn (Xích kệ ngôn {value0}/{value1})`
- **Learn by heart** — `Nguyên văn ({value0})`
- **Learn by heart** — `Nguyên văn ({value0}):`
- **Learn by heart** — `Nhấn nút Mic bên dưới và đọc câu kinh vào điện thoại để chấm điểm thuộc lòng`
- **Learn by heart** — `Nối xích`
- **Learn by heart** — `Phụ đề / Chủ đề ngắn`
- **Learn by heart** — `Quên / vấp nhiều`
- **Learn by heart** — `So sánh với bản đọc nhẩm trong đầu và tự đánh giá thực chất (Trọng số x2):`
- **Learn by heart** — `Song ngữ ({value0} + {value1})`
- **Learn by heart** — `Sẵn sàng test`
- **Learn by heart** — `Số lần phát bài / đoạ`
- **Learn by heart** — `Số lần phát câu {value0}`
- **Learn by heart** — `TOÀN VĂN ĐỐI CHIẾU`
- **Learn by heart** — `Thuộc câu nối → Sang mối tiếp`
- **Learn by heart** — `Thuộc lòng xuất sắc! 🎉`
- **Learn by heart** — `Thêm bài học thuộc lòng mới`
- **Learn by heart** — `Thể loại`
- **Learn by heart** — `Thử thay đổi bộ lọc hoặc thêm bài mới vào danh sách`
- **Learn by heart** — `Thử thách Thuộc Lòng!`
- **Learn by heart** — `Tiêu đề bài kinh / kệ ngôn`
- **Learn by heart** — `Tuyệt vời! Bạn đã hoàn thành toàn bộ bài ôn tập hôm nay.`
- **Learn by heart** — `Tôi đã đọc xong trong đầu`
- **Learn by heart** — `Từ khóa ghi nhớ (phân cách bằng dấu phẩy)`
- **Learn by heart** — `Vui lòng cấp quyền Microphone để ghi âm`
- **Learn by heart** — `VĂN BẢN MỤC TIÊU CẦN ĐỌC`
- **Learn by heart** — `Xem câu tiếp theo`
- **Learn by heart** — `___ ? Hãy nhớ câu tiếp theo trong đầu ? ___`
- **Learn by heart** — `Ôn sau {value0}`
- **Learn by heart** — `Ý nghĩa cốt lõi (≤ 15 từ)`
- **Learn by heart** — `Đang phân tích & đối chiếu giọng đọc...`
- **Learn by heart** — `Đoạn {value0}`
- **Learn by heart** — `Đã ôn {value0} lần`
- **Learn by heart** — `Đến hạn ôn`
- **Learn by heart** — `Đọc bằng giọng nói (Voice Recall)`
- **Learn by heart** — `ĐỐI CHIẾU TOÀN VĂN`
- **Learn by heart** — `🎙️ Đang lắng nghe... Hãy đọc to trọn vẹn câu kinh`
- **Other screens** — `Lưu thất`
- **Other screens** — `Tắt tự ẩn thanh chế độ`
- **Other screens** — `Đã tắt tự ẩn thanh chế độ`
- **PDF Reader** — `Không trích xuất được text từ trang `
- **PDF Reader** — `ghi chú`
- **Read** — `Chế độ Focus: giữ tiêu đề`
- **Settings** — `Chưa có API key cho OpenRouter. Dán key (sk-or-v1-…) vào ô trên, hoặc build lại bằng CI có secret OPENROUTER_API_KEY.`
- **Shared widgets** — `App sẽ phân tích âm thanh và tạo mục lục như sách.

🟢 Chạy nền — đóng cửa sổ này cũng được, tiến trì`
- **TTS** — `Giọng Microsoft Edge Neural theo ngôn ngữ`
- **TTS** — `Mỗi ngôn ngữ chọn 1 giọng Edge. Tự động áp dụng khi phát bằng engine Microsoft Edge TTS (không ảnh hưởng Piper/giọng máy).`
- **TTS** — `Mỗi ngôn ngữ chọn 1 giọng đã import. Tự động ưu tiên phát khi dùng Sherpa TTS.`
- **TTS** — `Piper × : chưa có giọng HOẶC thiếu phonemizer (espeak-ng-data) — cài tại TTS → Quản lý model`
- **Tipiṭaka** — `Bạn có thể chọn trực tiếp DB Pa-Auk .db/.sqlite/.zip hoặc file tipitaka.sqlite đã chuẩn hóa. Với build developer, đặt file vào Documents/in4up/tipitaka/imports/ rồi bấm Quét thư mục import. Ứng dụng sẽ tự nhận diện, chuyển DB nguồn sang schema In4Up và giữ lại Python importer cho các DB rất lớn.`
- **Tipiṭaka** — `Bạn vẫn có thể import và đọc Tiếng Việt ngay. Nên import Pāli trước hoặc sau để đối chiếu tốt hơn; khi chưa có Pāli, xem song ngữ và căn hàng sẽ tạm giảm cấp.`
- **Tipiṭaka** — `Bản dịch vẫn đọc độc lập. Nên import Pāli để đối chiếu tốt hơn; song ngữ và căn hàng đang tạm giảm cấp.`
- **Tipiṭaka** — `Chi tiết kỹ thuật`
- **Tipiṭaka** — `Chia đôi màn hình`
- **Tipiṭaka** — `Chưa có cơ sở dữ liệu hợp lệ`
- **Tipiṭaka** — `Chưa import Pāli; bản dịch vẫn đọc độc lập.`
- **Tipiṭaka** — `Chưa thấy file. Hãy đặt .db/.sqlite/.zip vào thư mục Documents/in4up/tipitaka/imports rồi quét lại.`
- **Tipiṭaka** — `Có thể đối chiếu Pāli và bản dịch theo đoạn.`
- **Tipiṭaka** — `Cơ sở dữ liệu đã sẵn sàng`
- **Tipiṭaka** — `Gói ngôn ngữ Tipiṭaka`
- **Tipiṭaka** — `Hãy import DB Pa-Auk hoặc tải gói ngôn ngữ.`
- **Tipiṭaka** — `Học thuộc đoạn này`
- **Tipiṭaka** — `Import DB hoặc gói ngôn ngữ từ thiết bị`
- **Tipiṭaka** — `Import hoặc tải dữ liệu`
- **Tipiṭaka** — `Import một gói ngôn ngữ bất kỳ để bắt đầu. Pāli được khuyến nghị nhưng không bắt buộc.`
- **Tipiṭaka** — `Import thất bại: {value0}`
- **Tipiṭaka** — `Không gian đọc Tipiṭaka`
- **Tipiṭaka** — `Không thể kiểm tra cơ sở dữ liệu Tipiṭaka.`
- **Tipiṭaka** — `Không thể lưu vào Worklist: {value0}`
- **Tipiṭaka** — `Không thể mở cơ sở dữ liệu Tipiṭaka.`
- **Tipiṭaka** — `Không thể mở danh mục: {value0}`
- **Tipiṭaka** — `Không thể mở đoạn: {value0}`
- **Tipiṭaka** — `Không thể thêm vào Học thuộc lòng: {value0}`
- **Tipiṭaka** — `Không thể tải {value0}: {value1}`
- **Tipiṭaka** — `Không tìm thấy lại nguồn Tipiṭaka.`
- **Tipiṭaka** — `Kiểm tra lại DB`
- **Tipiṭaka** — `Lưu cụm từ vào Worklist`
- **Tipiṭaka** — `Lưu từ vào Worklist`
- **Tipiṭaka** — `Lưu đoạn vào Worklist`
- **Tipiṭaka** — `Mỗi gói ngôn ngữ có thể import độc lập.`
- **Tipiṭaka** — `Mở bài trong tab mới`
- **Tipiṭaka** — `Mở nguồn Tipiṭaka`
- **Tipiṭaka** — `Mở thêm một bài để dùng chế độ chia đôi.`
- **Tipiṭaka** — `Mở thư viện`
- **Tipiṭaka** — `Mở trang nguồn Pa-Auk`
- **Tipiṭaka** — `Mục chưa có tiêu đề`
- **Tipiṭaka** — `Mục lục chi tiết`
- **Tipiṭaka** — `Nhập từ khóa để tìm trong Tipiṭaka`
- **Tipiṭaka** — `Pāli không bắt buộc để tiếp tục đọc.`
- **Tipiṭaka** — `Quét thư mục import của developer`
- **Tipiṭaka** — `Quét thất bại: {value0}`
- **Tipiṭaka** — `Quản lý dữ liệu`
- **Tipiṭaka** — `Tam Tạng Chính Văn`
- **Tipiṭaka** — `Tipiṭaka chưa có dữ liệu`
- **Tipiṭaka** — `Tipiṭaka — Dữ liệu`
- **Tipiṭaka** — `Tác vụ Tipiṭaka gần đây`
- **Tipiṭaka** — `Tìm kiếm Tipiṭaka`
- **Tipiṭaka** — `Tạng → nhóm/bộ → bài kinh`
- **Tipiṭaka** — `Tải gói ngôn ngữ Pa-Auk`
- **Tipiṭaka** — `Tải và giải nén`
- **Tipiṭaka** — `Từ khóa Pāli / bản dịch…`
- **Tipiṭaka** — `nhóm/bộ`
- **Tipiṭaka** — `sách`
- **Tipiṭaka** — `tạng`
- **Tipiṭaka** — `Đang giải nén`
- **Tipiṭaka** — `Đang import`
- **Tipiṭaka** — `Đang xếp hàng`
- **Tipiṭaka** — `Đã hoàn tất`
- **Tipiṭaka** — `Đã import các file tìm thấy trong thư mục.`
- **Tipiṭaka** — `Đã import cơ sở dữ liệu Tipiṭaka.`
- **Tipiṭaka** — `Đã lưu vào Worklist.`
- **Tipiṭaka** — `Đã sao chép lựa chọn.`
- **Tipiṭaka** — `Đã thêm ngữ cảnh Tipiṭaka vào từ đã có.`
- **Tipiṭaka** — `Đã thêm đoạn vào Học thuộc lòng.`
- **Tipiṭaka** — `Đã tải và import {value0} trực tiếp vào thư viện Tipiṭaka.`
- **Tipiṭaka** — `Đóng tab`
- **Tipiṭaka** — `Đọc Tam Tạng theo ngôn ngữ đã import`
- **Tipiṭaka** — `Đọc bài từ vị trí hiện tại`
- **Tipiṭaka** — `Đọc toàn bộ nhóm/bộ`
- **Tipiṭaka** — `đoạn kinh`
- **Tipiṭaka** — `Ẩn thông báo`
- **Tools / WordList** — ` · 🔥 {value0} lặp nhiều`
- **Tools / WordList** — `.txt: Mỗi dòng 1 từ, hoặc văn bản thường
.csv/.txt bảng cột (cần dòng header): word, meaning, ipa, topic, example, example_simple, example_complex, language, image_url (tùy chọn — link ảnh .png/.webp hoặc animation Lottie .json; tải về máy để học offline)
Ngăn cột: tab, phẩy, chấm phẩy hoặc | — ý nghĩa có dấu phẩy thì bọc "nét nháy"
Từ/cụm ĐÃ CÓ trong WordList vẫn hiện (badge "đã có") — import chỉ bổ sung nghĩa/IPA/ví dụ/minh họa CHỖ TRỐNG + tag, không ghi đè`
- **Tools / WordList** — `Dán bảng có header: word, meaning, ipa, topic, example, language, image_url (tùy chọn — link ảnh/Lottie .json)
(tab hoặc dấu phẩy; meaning có dấu phẩy thì bọc "nét nháy")
Hoặc text thường / một từ mỗi dòng...`
- **Tools / WordList** — `Lọc theo thực thể, trạng thái, ngô`
- **Tools / WordList** — `Mở Listen Mode, nghe file bất kỳ rồi:
• Chạm 📌 "Dấu" để đánh dấu một điểm
• Chọn A–B rồi lưu thành đoạn học tập
• Mở "Âm mục" để tạo mục lục như sách

Mọi thứ bạn đánh dấu sẽ xuất hiện tại đây.`
- **Tools / WordList** — `Ngôn ngữ (chọn 1–n — đầu danh sách = chính)`
- **Tools / WordList** — `Thêm mục`
- **Tools / WordList** — `Thêm mục cho file`
- **Tools / WordList** — `Tên chương/mục`
- **Tools / WordList** — `mục`
- **Tools / WordList** — `nét nháy`
- **Tools / WordList** — `{value0} · {value1} điểm · {value2} đoạn · {value3} mục{value4}`
- **Tools / WordList** — `điểm`
- **Tools / WordList** — `đã có`
- **Tools / WordList** — `… và {value0} dòng nữa — dùng "Tìm kiếm" trong Listen Mode để tìm trong toàn bộ nội dung.`
- **Tools / WordList** — `▶️ Đang phát: {value0}`
- **Tools / WordList** — `✅ Đã import: +{value0} mới, cập nhật {value1} đã có`
- **Tools / WordList** — `🔍  Tìm tên file, nhãn, ghi chú, tag…`
- **Translation** — `Đang tải...`
- **Web Reader** — `Dừng đọc`
- **Web Reader** — `Hãy tạo ít nhất `
- **Web Reader** — `Mở trong tab Nghe`
- **Web Reader** — `Ngôn ngữ áp cho tất cả`
- **Web Reader** — `Đang đọc bài web`
- **Web Reader** — `Đã tạm dừng bài đọc`
- **YouTube** — `Chưa có audio đã tải.`
- **YouTube** — `Chưa có lịch sử xem.`
- **YouTube** — `Lịch sử xem`
- **YouTube** — `Tải audio`
- **YouTube** — `Tải phụ đề`

### `si`

- **Cabin** — `Bản dịch thời gian thực sẽ hiển thị tại đây...`
- **Cabin** — `Chưa có dữ liệu hội thoại.
Bấm nút Micro để bắt đầu phiên dịch cabin.`
- **Cabin** — `Chọn ngôn ngữ dịch (Đích)`
- **Cabin** — `Chọn ngôn ngữ nói (Gốc)`
- **Cabin** — `Dịch Live Cabin`
- **Cabin** — `Khuyên dùng tai nghe khi bật phát âm để tránh tiếng dịch lọt ngược vào micro!`
- **Cabin** — `Nói vào microphone để bắt đầu dịch cabin...`
- **Cabin** — `Sao chép văn bản`
- **Cabin** — `Xóa lịch sử`
- **Cabin** — `Đang nghe trực tiếp...`
- **Cabin** — `Đã chép câu dịch!`
- **Cabin** — `Đã sao chép toàn bộ nội dung dịch cabin vào bộ nhớ tạm!`
- **Cabin** — `Đọc dịch`
- **Dictionary** — `Bấm Import thư mục để thêm bộ từ điển (.mdx + .mdd + .css), rồi chọn liên kết (không sao chép) hoặc sao chép vào app.`
- **Dictionary** — `Sao chép mdx + mdd + css vào bộ nhớ app để dùng ổn định khi di chuyển hoặc xoá nguồn. Bản gốc vẫn được giữ nguyên; app có thêm một bản sao nên tốn thêm dung lượng tương ứng.`
- **Dictionary** — `Thư mục từ điển không còn truy cập được — chọn lại. Chỉ mục SQLite trong app vẫn được giữ.`
- **Dictionary** — `Ưu tiên — chỉ lưu chỉ mục tra từ nhỏ trong app; không sao chép bộ từ điển (mdx/mdd vẫn ở thư mục gốc). Nếu nguồn không còn truy cập được, chọn lại; chỉ mục vẫn được giữ.`
- **Grammar / Understand** — `Nhóm từ loạ`
- **Learn by heart** — `Bước {value0}/{value1}: {value2}`
- **Learn by heart** — `Bạn đang duy trì thói quen ghi nhớ rất tốt!`
- **Learn by heart** — `Bạn đã đạt 5 lần ôn tập thành công liên tiếp! Bạn có muốn làm bài Kiểm Tra Thực Chất (Assessment không gợi ý) để nhân đôi độ bền vững không?`
- **Learn by heart** — `Bản dịch ({value0})`
- **Learn by heart** — `Bản dịch ({value0}):`
- **Learn by heart** — `Bắt đầu đọc`
- **Learn by heart** — `CHẾ ĐỘ KHÔNG GỢI Ý`
- **Learn by heart** — `Chuẩn xác 100%`
- **Learn by heart** — `Chúc mừng bạn đã hoàn tất ghép bài!`
- **Learn by heart** — `Chạm để dừng & chấm điểm`
- **Learn by heart** — `Chỗ trống: chạm từ để ẩn khi ôn — không cần gõ {{c1::từ}}`
- **Learn by heart** — `CÂU CẦN ĐỌC TIẾP (DÒNG {value0})`
- **Learn by heart** — `CÂU MỒI DẪN DẮT (DÒNG {value0})`
- **Learn by heart** — `Cập nhật`
- **Learn by heart** — `Cố gắng nhẩm lại từng câu một cách trọn vẹn nhất trước khi mở văn bản đối chiếu.`
- **Learn by heart** — `Dựa trên thuật toán FSRS & chu kỳ quên tự nhiên.`
- **Learn by heart** — `Ghi nhận kết quả ({value0}) vào FSRS`
- **Learn by heart** — `Hoàn tất xích kệ ngôn! 🎉`
- **Learn by heart** — `Hành động này sẽ nạp lại toàn bộ 10 Kệ Pháp Cú và các bài kinh tụng chuẩn mẫu ban đầu. Bạn có muốn tiếp tục không?`
- **Learn by heart** — `Hành động và tâm ý tạo tác quả báo.`
- **Learn by heart** — `Hãy tự đọc toàn bài trong đầu`
- **Learn by heart** — `Hãy đọc nhẩm toàn bộ bài một lần cuối và chọn mức độ nhớ để FSRS tự động lên lịch nhắc ôn.`
- **Learn by heart** — `Học cuốn chiếu (Chunking Flow)`
- **Learn by heart** — `Không tìm thấy bài học phù hợp`
- **Learn by heart** — `Kiểm tra thực chất (Assessment)`
- **Learn by heart** — `Liên hệ thực tế đời sống (1 câu)`
- **Learn by heart** — `Lắng nghe câu mở đầu, sau đó tự đọc trọn vẹn phần còn lại`
- **Learn by heart** — `Mối nối liên hoàn (Xích kệ ngôn {value0}/{value1})`
- **Learn by heart** — `Nguyên văn ({value0})`
- **Learn by heart** — `Nguyên văn ({value0}):`
- **Learn by heart** — `Nhấn nút Mic bên dưới và đọc câu kinh vào điện thoại để chấm điểm thuộc lòng`
- **Learn by heart** — `Nối xích`
- **Learn by heart** — `Phụ đề / Chủ đề ngắn`
- **Learn by heart** — `Quên / vấp nhiều`
- **Learn by heart** — `So sánh với bản đọc nhẩm trong đầu và tự đánh giá thực chất (Trọng số x2):`
- **Learn by heart** — `Song ngữ ({value0} + {value1})`
- **Learn by heart** — `Sẵn sàng test`
- **Learn by heart** — `Số lần phát bài / đoạ`
- **Learn by heart** — `Số lần phát câu {value0}`
- **Learn by heart** — `TOÀN VĂN ĐỐI CHIẾU`
- **Learn by heart** — `Thuộc câu nối → Sang mối tiếp`
- **Learn by heart** — `Thuộc lòng xuất sắc! 🎉`
- **Learn by heart** — `Thêm bài học thuộc lòng mới`
- **Learn by heart** — `Thể loại`
- **Learn by heart** — `Thử thay đổi bộ lọc hoặc thêm bài mới vào danh sách`
- **Learn by heart** — `Thử thách Thuộc Lòng!`
- **Learn by heart** — `Tiêu đề bài kinh / kệ ngôn`
- **Learn by heart** — `Tuyệt vời! Bạn đã hoàn thành toàn bộ bài ôn tập hôm nay.`
- **Learn by heart** — `Tôi đã đọc xong trong đầu`
- **Learn by heart** — `Từ khóa ghi nhớ (phân cách bằng dấu phẩy)`
- **Learn by heart** — `Vui lòng cấp quyền Microphone để ghi âm`
- **Learn by heart** — `VĂN BẢN MỤC TIÊU CẦN ĐỌC`
- **Learn by heart** — `Xem câu tiếp theo`
- **Learn by heart** — `___ ? Hãy nhớ câu tiếp theo trong đầu ? ___`
- **Learn by heart** — `Ôn sau {value0}`
- **Learn by heart** — `Ý nghĩa cốt lõi (≤ 15 từ)`
- **Learn by heart** — `Đang phân tích & đối chiếu giọng đọc...`
- **Learn by heart** — `Đoạn {value0}`
- **Learn by heart** — `Đã ôn {value0} lần`
- **Learn by heart** — `Đến hạn ôn`
- **Learn by heart** — `Đọc bằng giọng nói (Voice Recall)`
- **Learn by heart** — `ĐỐI CHIẾU TOÀN VĂN`
- **Learn by heart** — `🎙️ Đang lắng nghe... Hãy đọc to trọn vẹn câu kinh`
- **Other screens** — `Lưu thất`
- **PDF Reader** — `Không trích xuất được text từ trang `
- **PDF Reader** — `ghi chú`
- **Shared widgets** — `App sẽ phân tích âm thanh và tạo mục lục như sách.

🟢 Chạy nền — đóng cửa sổ này cũng được, tiến trì`
- **TTS** — `Giọng Microsoft Edge Neural theo ngôn ngữ`
- **TTS** — `Mỗi ngôn ngữ chọn 1 giọng Edge. Tự động áp dụng khi phát bằng engine Microsoft Edge TTS (không ảnh hưởng Piper/giọng máy).`
- **TTS** — `Mỗi ngôn ngữ chọn 1 giọng đã import. Tự động ưu tiên phát khi dùng Sherpa TTS.`
- **TTS** — `Piper × : chưa có giọng HOẶC thiếu phonemizer (espeak-ng-data) — cài tại TTS → Quản lý model`
- **Tipiṭaka** — `Bạn có thể chọn trực tiếp DB Pa-Auk .db/.sqlite/.zip hoặc file tipitaka.sqlite đã chuẩn hóa. Với build developer, đặt file vào Documents/in4up/tipitaka/imports/ rồi bấm Quét thư mục import. Ứng dụng sẽ tự nhận diện, chuyển DB nguồn sang schema In4Up và giữ lại Python importer cho các DB rất lớn.`
- **Tipiṭaka** — `Bạn vẫn có thể import và đọc Tiếng Việt ngay. Nên import Pāli trước hoặc sau để đối chiếu tốt hơn; khi chưa có Pāli, xem song ngữ và căn hàng sẽ tạm giảm cấp.`
- **Tipiṭaka** — `Bản dịch vẫn đọc độc lập. Nên import Pāli để đối chiếu tốt hơn; song ngữ và căn hàng đang tạm giảm cấp.`
- **Tipiṭaka** — `Chi tiết kỹ thuật`
- **Tipiṭaka** — `Chia đôi màn hình`
- **Tipiṭaka** — `Chưa có cơ sở dữ liệu hợp lệ`
- **Tipiṭaka** — `Chưa import Pāli; bản dịch vẫn đọc độc lập.`
- **Tipiṭaka** — `Chưa thấy file. Hãy đặt .db/.sqlite/.zip vào thư mục Documents/in4up/tipitaka/imports rồi quét lại.`
- **Tipiṭaka** — `Có thể đối chiếu Pāli và bản dịch theo đoạn.`
- **Tipiṭaka** — `Cơ sở dữ liệu đã sẵn sàng`
- **Tipiṭaka** — `Gói ngôn ngữ Tipiṭaka`
- **Tipiṭaka** — `Hãy import DB Pa-Auk hoặc tải gói ngôn ngữ.`
- **Tipiṭaka** — `Học thuộc đoạn này`
- **Tipiṭaka** — `Import DB hoặc gói ngôn ngữ từ thiết bị`
- **Tipiṭaka** — `Import hoặc tải dữ liệu`
- **Tipiṭaka** — `Import một gói ngôn ngữ bất kỳ để bắt đầu. Pāli được khuyến nghị nhưng không bắt buộc.`
- **Tipiṭaka** — `Import thất bại: {value0}`
- **Tipiṭaka** — `Không gian đọc Tipiṭaka`
- **Tipiṭaka** — `Không thể kiểm tra cơ sở dữ liệu Tipiṭaka.`
- **Tipiṭaka** — `Không thể lưu vào Worklist: {value0}`
- **Tipiṭaka** — `Không thể mở cơ sở dữ liệu Tipiṭaka.`
- **Tipiṭaka** — `Không thể mở danh mục: {value0}`
- **Tipiṭaka** — `Không thể mở đoạn: {value0}`
- **Tipiṭaka** — `Không thể thêm vào Học thuộc lòng: {value0}`
- **Tipiṭaka** — `Không thể tải {value0}: {value1}`
- **Tipiṭaka** — `Không tìm thấy lại nguồn Tipiṭaka.`
- **Tipiṭaka** — `Kiểm tra lại DB`
- **Tipiṭaka** — `Lưu cụm từ vào Worklist`
- **Tipiṭaka** — `Lưu từ vào Worklist`
- **Tipiṭaka** — `Lưu đoạn vào Worklist`
- **Tipiṭaka** — `Mỗi gói ngôn ngữ có thể import độc lập.`
- **Tipiṭaka** — `Mở bài trong tab mới`
- **Tipiṭaka** — `Mở nguồn Tipiṭaka`
- **Tipiṭaka** — `Mở thêm một bài để dùng chế độ chia đôi.`
- **Tipiṭaka** — `Mở thư viện`
- **Tipiṭaka** — `Mở trang nguồn Pa-Auk`
- **Tipiṭaka** — `Mục chưa có tiêu đề`
- **Tipiṭaka** — `Mục lục chi tiết`
- **Tipiṭaka** — `Nhập từ khóa để tìm trong Tipiṭaka`
- **Tipiṭaka** — `Pāli không bắt buộc để tiếp tục đọc.`
- **Tipiṭaka** — `Quét thư mục import của developer`
- **Tipiṭaka** — `Quét thất bại: {value0}`
- **Tipiṭaka** — `Quản lý dữ liệu`
- **Tipiṭaka** — `Tam Tạng Chính Văn`
- **Tipiṭaka** — `Tipiṭaka chưa có dữ liệu`
- **Tipiṭaka** — `Tipiṭaka — Dữ liệu`
- **Tipiṭaka** — `Tác vụ Tipiṭaka gần đây`
- **Tipiṭaka** — `Tìm kiếm Tipiṭaka`
- **Tipiṭaka** — `Tạng → nhóm/bộ → bài kinh`
- **Tipiṭaka** — `Tải gói ngôn ngữ Pa-Auk`
- **Tipiṭaka** — `Tải và giải nén`
- **Tipiṭaka** — `Từ khóa Pāli / bản dịch…`
- **Tipiṭaka** — `nhóm/bộ`
- **Tipiṭaka** — `sách`
- **Tipiṭaka** — `tạng`
- **Tipiṭaka** — `Đang giải nén`
- **Tipiṭaka** — `Đang import`
- **Tipiṭaka** — `Đang xếp hàng`
- **Tipiṭaka** — `Đã hoàn tất`
- **Tipiṭaka** — `Đã import các file tìm thấy trong thư mục.`
- **Tipiṭaka** — `Đã import cơ sở dữ liệu Tipiṭaka.`
- **Tipiṭaka** — `Đã lưu vào Worklist.`
- **Tipiṭaka** — `Đã sao chép lựa chọn.`
- **Tipiṭaka** — `Đã thêm ngữ cảnh Tipiṭaka vào từ đã có.`
- **Tipiṭaka** — `Đã thêm đoạn vào Học thuộc lòng.`
- **Tipiṭaka** — `Đã tải và import {value0} trực tiếp vào thư viện Tipiṭaka.`
- **Tipiṭaka** — `Đóng tab`
- **Tipiṭaka** — `Đọc Tam Tạng theo ngôn ngữ đã import`
- **Tipiṭaka** — `Đọc bài từ vị trí hiện tại`
- **Tipiṭaka** — `Đọc toàn bộ nhóm/bộ`
- **Tipiṭaka** — `đoạn kinh`
- **Tipiṭaka** — `Ẩn thông báo`
- **Tools / WordList** — ` · 🔥 {value0} lặp nhiều`
- **Tools / WordList** — `.txt: Mỗi dòng 1 từ, hoặc văn bản thường
.csv/.txt bảng cột (cần dòng header): word, meaning, ipa, topic, example, example_simple, example_complex, language, image_url (tùy chọn — link ảnh .png/.webp hoặc animation Lottie .json; tải về máy để học offline)
Ngăn cột: tab, phẩy, chấm phẩy hoặc | — ý nghĩa có dấu phẩy thì bọc "nét nháy"
Từ/cụm ĐÃ CÓ trong WordList vẫn hiện (badge "đã có") — import chỉ bổ sung nghĩa/IPA/ví dụ/minh họa CHỖ TRỐNG + tag, không ghi đè`
- **Tools / WordList** — `Dán bảng có header: word, meaning, ipa, topic, example, language, image_url (tùy chọn — link ảnh/Lottie .json)
(tab hoặc dấu phẩy; meaning có dấu phẩy thì bọc "nét nháy")
Hoặc text thường / một từ mỗi dòng...`
- **Tools / WordList** — `Lọc theo thực thể, trạng thái, ngô`
- **Tools / WordList** — `Mở Listen Mode, nghe file bất kỳ rồi:
• Chạm 📌 "Dấu" để đánh dấu một điểm
• Chọn A–B rồi lưu thành đoạn học tập
• Mở "Âm mục" để tạo mục lục như sách

Mọi thứ bạn đánh dấu sẽ xuất hiện tại đây.`
- **Tools / WordList** — `Ngôn ngữ (chọn 1–n — đầu danh sách = chính)`
- **Tools / WordList** — `Thêm mục`
- **Tools / WordList** — `Thêm mục cho file`
- **Tools / WordList** — `Tên chương/mục`
- **Tools / WordList** — `mục`
- **Tools / WordList** — `nét nháy`
- **Tools / WordList** — `{value0} · {value1} điểm · {value2} đoạn · {value3} mục{value4}`
- **Tools / WordList** — `điểm`
- **Tools / WordList** — `đã có`
- **Tools / WordList** — `… và {value0} dòng nữa — dùng "Tìm kiếm" trong Listen Mode để tìm trong toàn bộ nội dung.`
- **Tools / WordList** — `▶️ Đang phát: {value0}`
- **Tools / WordList** — `✅ Đã import: +{value0} mới, cập nhật {value1} đã có`
- **Tools / WordList** — `🔍  Tìm tên file, nhãn, ghi chú, tag…`
- **Web Reader** — `Dừng đọc`
- **Web Reader** — `Hãy tạo ít nhất `
- **Web Reader** — `Ngôn ngữ áp cho tất cả`
- **Web Reader** — `Đang đọc bài web`
- **Web Reader** — `Đã tạm dừng bài đọc`

### `my`

- **Cabin** — `Bản dịch thời gian thực sẽ hiển thị tại đây...`
- **Cabin** — `Chưa có dữ liệu hội thoại.
Bấm nút Micro để bắt đầu phiên dịch cabin.`
- **Cabin** — `Chọn ngôn ngữ dịch (Đích)`
- **Cabin** — `Chọn ngôn ngữ nói (Gốc)`
- **Cabin** — `Dịch Live Cabin`
- **Cabin** — `Khuyên dùng tai nghe khi bật phát âm để tránh tiếng dịch lọt ngược vào micro!`
- **Cabin** — `Nói vào microphone để bắt đầu dịch cabin...`
- **Cabin** — `Sao chép văn bản`
- **Cabin** — `Xóa lịch sử`
- **Cabin** — `Đang nghe trực tiếp...`
- **Cabin** — `Đã chép câu dịch!`
- **Cabin** — `Đã sao chép toàn bộ nội dung dịch cabin vào bộ nhớ tạm!`
- **Cabin** — `Đọc dịch`
- **Dictionary** — `Bấm Import thư mục để thêm bộ từ điển (.mdx + .mdd + .css), rồi chọn liên kết (không sao chép) hoặc sao chép vào app.`
- **Dictionary** — `Sao chép mdx + mdd + css vào bộ nhớ app để dùng ổn định khi di chuyển hoặc xoá nguồn. Bản gốc vẫn được giữ nguyên; app có thêm một bản sao nên tốn thêm dung lượng tương ứng.`
- **Dictionary** — `Thư mục từ điển không còn truy cập được — chọn lại. Chỉ mục SQLite trong app vẫn được giữ.`
- **Dictionary** — `Ưu tiên — chỉ lưu chỉ mục tra từ nhỏ trong app; không sao chép bộ từ điển (mdx/mdd vẫn ở thư mục gốc). Nếu nguồn không còn truy cập được, chọn lại; chỉ mục vẫn được giữ.`
- **Grammar / Understand** — `Nhóm từ loạ`
- **Learn by heart** — `Bước {value0}/{value1}: {value2}`
- **Learn by heart** — `Bạn đang duy trì thói quen ghi nhớ rất tốt!`
- **Learn by heart** — `Bạn đã đạt 5 lần ôn tập thành công liên tiếp! Bạn có muốn làm bài Kiểm Tra Thực Chất (Assessment không gợi ý) để nhân đôi độ bền vững không?`
- **Learn by heart** — `Bản dịch ({value0})`
- **Learn by heart** — `Bản dịch ({value0}):`
- **Learn by heart** — `Bắt đầu đọc`
- **Learn by heart** — `CHẾ ĐỘ KHÔNG GỢI Ý`
- **Learn by heart** — `Chuẩn xác 100%`
- **Learn by heart** — `Chúc mừng bạn đã hoàn tất ghép bài!`
- **Learn by heart** — `Chạm để dừng & chấm điểm`
- **Learn by heart** — `Chỗ trống: chạm từ để ẩn khi ôn — không cần gõ {{c1::từ}}`
- **Learn by heart** — `CÂU CẦN ĐỌC TIẾP (DÒNG {value0})`
- **Learn by heart** — `CÂU MỒI DẪN DẮT (DÒNG {value0})`
- **Learn by heart** — `Cập nhật`
- **Learn by heart** — `Cố gắng nhẩm lại từng câu một cách trọn vẹn nhất trước khi mở văn bản đối chiếu.`
- **Learn by heart** — `Dựa trên thuật toán FSRS & chu kỳ quên tự nhiên.`
- **Learn by heart** — `Ghi nhận kết quả ({value0}) vào FSRS`
- **Learn by heart** — `Hoàn tất xích kệ ngôn! 🎉`
- **Learn by heart** — `Hành động này sẽ nạp lại toàn bộ 10 Kệ Pháp Cú và các bài kinh tụng chuẩn mẫu ban đầu. Bạn có muốn tiếp tục không?`
- **Learn by heart** — `Hành động và tâm ý tạo tác quả báo.`
- **Learn by heart** — `Hãy tự đọc toàn bài trong đầu`
- **Learn by heart** — `Hãy đọc nhẩm toàn bộ bài một lần cuối và chọn mức độ nhớ để FSRS tự động lên lịch nhắc ôn.`
- **Learn by heart** — `Học cuốn chiếu (Chunking Flow)`
- **Learn by heart** — `Không tìm thấy bài học phù hợp`
- **Learn by heart** — `Kiểm tra thực chất (Assessment)`
- **Learn by heart** — `Liên hệ thực tế đời sống (1 câu)`
- **Learn by heart** — `Lắng nghe câu mở đầu, sau đó tự đọc trọn vẹn phần còn lại`
- **Learn by heart** — `Mối nối liên hoàn (Xích kệ ngôn {value0}/{value1})`
- **Learn by heart** — `Nguyên văn ({value0})`
- **Learn by heart** — `Nguyên văn ({value0}):`
- **Learn by heart** — `Nhấn nút Mic bên dưới và đọc câu kinh vào điện thoại để chấm điểm thuộc lòng`
- **Learn by heart** — `Nối xích`
- **Learn by heart** — `Phụ đề / Chủ đề ngắn`
- **Learn by heart** — `Quên / vấp nhiều`
- **Learn by heart** — `So sánh với bản đọc nhẩm trong đầu và tự đánh giá thực chất (Trọng số x2):`
- **Learn by heart** — `Song ngữ ({value0} + {value1})`
- **Learn by heart** — `Sẵn sàng test`
- **Learn by heart** — `Số lần phát bài / đoạ`
- **Learn by heart** — `Số lần phát câu {value0}`
- **Learn by heart** — `TOÀN VĂN ĐỐI CHIẾU`
- **Learn by heart** — `Thuộc câu nối → Sang mối tiếp`
- **Learn by heart** — `Thuộc lòng xuất sắc! 🎉`
- **Learn by heart** — `Thêm bài học thuộc lòng mới`
- **Learn by heart** — `Thể loại`
- **Learn by heart** — `Thử thay đổi bộ lọc hoặc thêm bài mới vào danh sách`
- **Learn by heart** — `Thử thách Thuộc Lòng!`
- **Learn by heart** — `Tiêu đề bài kinh / kệ ngôn`
- **Learn by heart** — `Tuyệt vời! Bạn đã hoàn thành toàn bộ bài ôn tập hôm nay.`
- **Learn by heart** — `Tôi đã đọc xong trong đầu`
- **Learn by heart** — `Từ khóa ghi nhớ (phân cách bằng dấu phẩy)`
- **Learn by heart** — `Vui lòng cấp quyền Microphone để ghi âm`
- **Learn by heart** — `VĂN BẢN MỤC TIÊU CẦN ĐỌC`
- **Learn by heart** — `Xem câu tiếp theo`
- **Learn by heart** — `___ ? Hãy nhớ câu tiếp theo trong đầu ? ___`
- **Learn by heart** — `Ôn sau {value0}`
- **Learn by heart** — `Ý nghĩa cốt lõi (≤ 15 từ)`
- **Learn by heart** — `Đang phân tích & đối chiếu giọng đọc...`
- **Learn by heart** — `Đoạn {value0}`
- **Learn by heart** — `Đã ôn {value0} lần`
- **Learn by heart** — `Đến hạn ôn`
- **Learn by heart** — `Đọc bằng giọng nói (Voice Recall)`
- **Learn by heart** — `ĐỐI CHIẾU TOÀN VĂN`
- **Learn by heart** — `🎙️ Đang lắng nghe... Hãy đọc to trọn vẹn câu kinh`
- **Other screens** — `Lưu thất`
- **PDF Reader** — `Không trích xuất được text từ trang `
- **PDF Reader** — `ghi chú`
- **Shared widgets** — `App sẽ phân tích âm thanh và tạo mục lục như sách.

🟢 Chạy nền — đóng cửa sổ này cũng được, tiến trì`
- **TTS** — `Giọng Microsoft Edge Neural theo ngôn ngữ`
- **TTS** — `Mỗi ngôn ngữ chọn 1 giọng Edge. Tự động áp dụng khi phát bằng engine Microsoft Edge TTS (không ảnh hưởng Piper/giọng máy).`
- **TTS** — `Mỗi ngôn ngữ chọn 1 giọng đã import. Tự động ưu tiên phát khi dùng Sherpa TTS.`
- **TTS** — `Piper × : chưa có giọng HOẶC thiếu phonemizer (espeak-ng-data) — cài tại TTS → Quản lý model`
- **Tipiṭaka** — `Bạn có thể chọn trực tiếp DB Pa-Auk .db/.sqlite/.zip hoặc file tipitaka.sqlite đã chuẩn hóa. Với build developer, đặt file vào Documents/in4up/tipitaka/imports/ rồi bấm Quét thư mục import. Ứng dụng sẽ tự nhận diện, chuyển DB nguồn sang schema In4Up và giữ lại Python importer cho các DB rất lớn.`
- **Tipiṭaka** — `Bạn vẫn có thể import và đọc Tiếng Việt ngay. Nên import Pāli trước hoặc sau để đối chiếu tốt hơn; khi chưa có Pāli, xem song ngữ và căn hàng sẽ tạm giảm cấp.`
- **Tipiṭaka** — `Bản dịch vẫn đọc độc lập. Nên import Pāli để đối chiếu tốt hơn; song ngữ và căn hàng đang tạm giảm cấp.`
- **Tipiṭaka** — `Chi tiết kỹ thuật`
- **Tipiṭaka** — `Chia đôi màn hình`
- **Tipiṭaka** — `Chưa có cơ sở dữ liệu hợp lệ`
- **Tipiṭaka** — `Chưa import Pāli; bản dịch vẫn đọc độc lập.`
- **Tipiṭaka** — `Chưa thấy file. Hãy đặt .db/.sqlite/.zip vào thư mục Documents/in4up/tipitaka/imports rồi quét lại.`
- **Tipiṭaka** — `Có thể đối chiếu Pāli và bản dịch theo đoạn.`
- **Tipiṭaka** — `Cơ sở dữ liệu đã sẵn sàng`
- **Tipiṭaka** — `Gói ngôn ngữ Tipiṭaka`
- **Tipiṭaka** — `Hãy import DB Pa-Auk hoặc tải gói ngôn ngữ.`
- **Tipiṭaka** — `Học thuộc đoạn này`
- **Tipiṭaka** — `Import DB hoặc gói ngôn ngữ từ thiết bị`
- **Tipiṭaka** — `Import hoặc tải dữ liệu`
- **Tipiṭaka** — `Import một gói ngôn ngữ bất kỳ để bắt đầu. Pāli được khuyến nghị nhưng không bắt buộc.`
- **Tipiṭaka** — `Import thất bại: {value0}`
- **Tipiṭaka** — `Không gian đọc Tipiṭaka`
- **Tipiṭaka** — `Không thể kiểm tra cơ sở dữ liệu Tipiṭaka.`
- **Tipiṭaka** — `Không thể lưu vào Worklist: {value0}`
- **Tipiṭaka** — `Không thể mở cơ sở dữ liệu Tipiṭaka.`
- **Tipiṭaka** — `Không thể mở danh mục: {value0}`
- **Tipiṭaka** — `Không thể mở đoạn: {value0}`
- **Tipiṭaka** — `Không thể thêm vào Học thuộc lòng: {value0}`
- **Tipiṭaka** — `Không thể tải {value0}: {value1}`
- **Tipiṭaka** — `Không tìm thấy lại nguồn Tipiṭaka.`
- **Tipiṭaka** — `Kiểm tra lại DB`
- **Tipiṭaka** — `Lưu cụm từ vào Worklist`
- **Tipiṭaka** — `Lưu từ vào Worklist`
- **Tipiṭaka** — `Lưu đoạn vào Worklist`
- **Tipiṭaka** — `Mỗi gói ngôn ngữ có thể import độc lập.`
- **Tipiṭaka** — `Mở bài trong tab mới`
- **Tipiṭaka** — `Mở nguồn Tipiṭaka`
- **Tipiṭaka** — `Mở thêm một bài để dùng chế độ chia đôi.`
- **Tipiṭaka** — `Mở thư viện`
- **Tipiṭaka** — `Mở trang nguồn Pa-Auk`
- **Tipiṭaka** — `Mục chưa có tiêu đề`
- **Tipiṭaka** — `Mục lục chi tiết`
- **Tipiṭaka** — `Nhập từ khóa để tìm trong Tipiṭaka`
- **Tipiṭaka** — `Pāli không bắt buộc để tiếp tục đọc.`
- **Tipiṭaka** — `Quét thư mục import của developer`
- **Tipiṭaka** — `Quét thất bại: {value0}`
- **Tipiṭaka** — `Quản lý dữ liệu`
- **Tipiṭaka** — `Tam Tạng Chính Văn`
- **Tipiṭaka** — `Tipiṭaka chưa có dữ liệu`
- **Tipiṭaka** — `Tipiṭaka — Dữ liệu`
- **Tipiṭaka** — `Tác vụ Tipiṭaka gần đây`
- **Tipiṭaka** — `Tìm kiếm Tipiṭaka`
- **Tipiṭaka** — `Tạng → nhóm/bộ → bài kinh`
- **Tipiṭaka** — `Tải gói ngôn ngữ Pa-Auk`
- **Tipiṭaka** — `Tải và giải nén`
- **Tipiṭaka** — `Từ khóa Pāli / bản dịch…`
- **Tipiṭaka** — `nhóm/bộ`
- **Tipiṭaka** — `sách`
- **Tipiṭaka** — `tạng`
- **Tipiṭaka** — `Đang giải nén`
- **Tipiṭaka** — `Đang import`
- **Tipiṭaka** — `Đang xếp hàng`
- **Tipiṭaka** — `Đã hoàn tất`
- **Tipiṭaka** — `Đã import các file tìm thấy trong thư mục.`
- **Tipiṭaka** — `Đã import cơ sở dữ liệu Tipiṭaka.`
- **Tipiṭaka** — `Đã lưu vào Worklist.`
- **Tipiṭaka** — `Đã sao chép lựa chọn.`
- **Tipiṭaka** — `Đã thêm ngữ cảnh Tipiṭaka vào từ đã có.`
- **Tipiṭaka** — `Đã thêm đoạn vào Học thuộc lòng.`
- **Tipiṭaka** — `Đã tải và import {value0} trực tiếp vào thư viện Tipiṭaka.`
- **Tipiṭaka** — `Đóng tab`
- **Tipiṭaka** — `Đọc Tam Tạng theo ngôn ngữ đã import`
- **Tipiṭaka** — `Đọc bài từ vị trí hiện tại`
- **Tipiṭaka** — `Đọc toàn bộ nhóm/bộ`
- **Tipiṭaka** — `đoạn kinh`
- **Tipiṭaka** — `Ẩn thông báo`
- **Tools / WordList** — ` · 🔥 {value0} lặp nhiều`
- **Tools / WordList** — `.txt: Mỗi dòng 1 từ, hoặc văn bản thường
.csv/.txt bảng cột (cần dòng header): word, meaning, ipa, topic, example, example_simple, example_complex, language, image_url (tùy chọn — link ảnh .png/.webp hoặc animation Lottie .json; tải về máy để học offline)
Ngăn cột: tab, phẩy, chấm phẩy hoặc | — ý nghĩa có dấu phẩy thì bọc "nét nháy"
Từ/cụm ĐÃ CÓ trong WordList vẫn hiện (badge "đã có") — import chỉ bổ sung nghĩa/IPA/ví dụ/minh họa CHỖ TRỐNG + tag, không ghi đè`
- **Tools / WordList** — `Dán bảng có header: word, meaning, ipa, topic, example, language, image_url (tùy chọn — link ảnh/Lottie .json)
(tab hoặc dấu phẩy; meaning có dấu phẩy thì bọc "nét nháy")
Hoặc text thường / một từ mỗi dòng...`
- **Tools / WordList** — `Lọc theo thực thể, trạng thái, ngô`
- **Tools / WordList** — `Mở Listen Mode, nghe file bất kỳ rồi:
• Chạm 📌 "Dấu" để đánh dấu một điểm
• Chọn A–B rồi lưu thành đoạn học tập
• Mở "Âm mục" để tạo mục lục như sách

Mọi thứ bạn đánh dấu sẽ xuất hiện tại đây.`
- **Tools / WordList** — `Ngôn ngữ (chọn 1–n — đầu danh sách = chính)`
- **Tools / WordList** — `Thêm mục`
- **Tools / WordList** — `Thêm mục cho file`
- **Tools / WordList** — `Tên chương/mục`
- **Tools / WordList** — `mục`
- **Tools / WordList** — `nét nháy`
- **Tools / WordList** — `{value0} · {value1} điểm · {value2} đoạn · {value3} mục{value4}`
- **Tools / WordList** — `điểm`
- **Tools / WordList** — `đã có`
- **Tools / WordList** — `… và {value0} dòng nữa — dùng "Tìm kiếm" trong Listen Mode để tìm trong toàn bộ nội dung.`
- **Tools / WordList** — `▶️ Đang phát: {value0}`
- **Tools / WordList** — `✅ Đã import: +{value0} mới, cập nhật {value1} đã có`
- **Tools / WordList** — `🔍  Tìm tên file, nhãn, ghi chú, tag…`
- **Web Reader** — `Dừng đọc`
- **Web Reader** — `Hãy tạo ít nhất `
- **Web Reader** — `Ngôn ngữ áp cho tất cả`
- **Web Reader** — `Đang đọc bài web`
- **Web Reader** — `Đã tạm dừng bài đọc`

### `th`

- **Cabin** — `Bản dịch thời gian thực sẽ hiển thị tại đây...`
- **Cabin** — `Chưa có dữ liệu hội thoại.
Bấm nút Micro để bắt đầu phiên dịch cabin.`
- **Cabin** — `Chọn ngôn ngữ dịch (Đích)`
- **Cabin** — `Chọn ngôn ngữ nói (Gốc)`
- **Cabin** — `Dịch Live Cabin`
- **Cabin** — `Khuyên dùng tai nghe khi bật phát âm để tránh tiếng dịch lọt ngược vào micro!`
- **Cabin** — `Nói vào microphone để bắt đầu dịch cabin...`
- **Cabin** — `Sao chép văn bản`
- **Cabin** — `Xóa lịch sử`
- **Cabin** — `Đang nghe trực tiếp...`
- **Cabin** — `Đã chép câu dịch!`
- **Cabin** — `Đã sao chép toàn bộ nội dung dịch cabin vào bộ nhớ tạm!`
- **Cabin** — `Đọc dịch`
- **Dictionary** — `Bấm Import thư mục để thêm bộ từ điển (.mdx + .mdd + .css), rồi chọn liên kết (không sao chép) hoặc sao chép vào app.`
- **Dictionary** — `Sao chép mdx + mdd + css vào bộ nhớ app để dùng ổn định khi di chuyển hoặc xoá nguồn. Bản gốc vẫn được giữ nguyên; app có thêm một bản sao nên tốn thêm dung lượng tương ứng.`
- **Dictionary** — `Thư mục từ điển không còn truy cập được — chọn lại. Chỉ mục SQLite trong app vẫn được giữ.`
- **Dictionary** — `Ưu tiên — chỉ lưu chỉ mục tra từ nhỏ trong app; không sao chép bộ từ điển (mdx/mdd vẫn ở thư mục gốc). Nếu nguồn không còn truy cập được, chọn lại; chỉ mục vẫn được giữ.`
- **Grammar / Understand** — `Nhóm từ loạ`
- **Learn by heart** — `Bước {value0}/{value1}: {value2}`
- **Learn by heart** — `Bạn đang duy trì thói quen ghi nhớ rất tốt!`
- **Learn by heart** — `Bạn đã đạt 5 lần ôn tập thành công liên tiếp! Bạn có muốn làm bài Kiểm Tra Thực Chất (Assessment không gợi ý) để nhân đôi độ bền vững không?`
- **Learn by heart** — `Bản dịch ({value0})`
- **Learn by heart** — `Bản dịch ({value0}):`
- **Learn by heart** — `Bắt đầu đọc`
- **Learn by heart** — `CHẾ ĐỘ KHÔNG GỢI Ý`
- **Learn by heart** — `Chuẩn xác 100%`
- **Learn by heart** — `Chúc mừng bạn đã hoàn tất ghép bài!`
- **Learn by heart** — `Chạm để dừng & chấm điểm`
- **Learn by heart** — `Chỗ trống: chạm từ để ẩn khi ôn — không cần gõ {{c1::từ}}`
- **Learn by heart** — `CÂU CẦN ĐỌC TIẾP (DÒNG {value0})`
- **Learn by heart** — `CÂU MỒI DẪN DẮT (DÒNG {value0})`
- **Learn by heart** — `Cập nhật`
- **Learn by heart** — `Cố gắng nhẩm lại từng câu một cách trọn vẹn nhất trước khi mở văn bản đối chiếu.`
- **Learn by heart** — `Dựa trên thuật toán FSRS & chu kỳ quên tự nhiên.`
- **Learn by heart** — `Ghi nhận kết quả ({value0}) vào FSRS`
- **Learn by heart** — `Hoàn tất xích kệ ngôn! 🎉`
- **Learn by heart** — `Hành động này sẽ nạp lại toàn bộ 10 Kệ Pháp Cú và các bài kinh tụng chuẩn mẫu ban đầu. Bạn có muốn tiếp tục không?`
- **Learn by heart** — `Hành động và tâm ý tạo tác quả báo.`
- **Learn by heart** — `Hãy tự đọc toàn bài trong đầu`
- **Learn by heart** — `Hãy đọc nhẩm toàn bộ bài một lần cuối và chọn mức độ nhớ để FSRS tự động lên lịch nhắc ôn.`
- **Learn by heart** — `Học cuốn chiếu (Chunking Flow)`
- **Learn by heart** — `Không tìm thấy bài học phù hợp`
- **Learn by heart** — `Kiểm tra thực chất (Assessment)`
- **Learn by heart** — `Liên hệ thực tế đời sống (1 câu)`
- **Learn by heart** — `Lắng nghe câu mở đầu, sau đó tự đọc trọn vẹn phần còn lại`
- **Learn by heart** — `Mối nối liên hoàn (Xích kệ ngôn {value0}/{value1})`
- **Learn by heart** — `Nguyên văn ({value0})`
- **Learn by heart** — `Nguyên văn ({value0}):`
- **Learn by heart** — `Nhấn nút Mic bên dưới và đọc câu kinh vào điện thoại để chấm điểm thuộc lòng`
- **Learn by heart** — `Nối xích`
- **Learn by heart** — `Phụ đề / Chủ đề ngắn`
- **Learn by heart** — `Quên / vấp nhiều`
- **Learn by heart** — `So sánh với bản đọc nhẩm trong đầu và tự đánh giá thực chất (Trọng số x2):`
- **Learn by heart** — `Song ngữ ({value0} + {value1})`
- **Learn by heart** — `Sẵn sàng test`
- **Learn by heart** — `Số lần phát bài / đoạ`
- **Learn by heart** — `Số lần phát câu {value0}`
- **Learn by heart** — `TOÀN VĂN ĐỐI CHIẾU`
- **Learn by heart** — `Thuộc câu nối → Sang mối tiếp`
- **Learn by heart** — `Thuộc lòng xuất sắc! 🎉`
- **Learn by heart** — `Thêm bài học thuộc lòng mới`
- **Learn by heart** — `Thể loại`
- **Learn by heart** — `Thử thay đổi bộ lọc hoặc thêm bài mới vào danh sách`
- **Learn by heart** — `Thử thách Thuộc Lòng!`
- **Learn by heart** — `Tiêu đề bài kinh / kệ ngôn`
- **Learn by heart** — `Tuyệt vời! Bạn đã hoàn thành toàn bộ bài ôn tập hôm nay.`
- **Learn by heart** — `Tôi đã đọc xong trong đầu`
- **Learn by heart** — `Từ khóa ghi nhớ (phân cách bằng dấu phẩy)`
- **Learn by heart** — `Vui lòng cấp quyền Microphone để ghi âm`
- **Learn by heart** — `VĂN BẢN MỤC TIÊU CẦN ĐỌC`
- **Learn by heart** — `Xem câu tiếp theo`
- **Learn by heart** — `___ ? Hãy nhớ câu tiếp theo trong đầu ? ___`
- **Learn by heart** — `Ôn sau {value0}`
- **Learn by heart** — `Ý nghĩa cốt lõi (≤ 15 từ)`
- **Learn by heart** — `Đang phân tích & đối chiếu giọng đọc...`
- **Learn by heart** — `Đoạn {value0}`
- **Learn by heart** — `Đã ôn {value0} lần`
- **Learn by heart** — `Đến hạn ôn`
- **Learn by heart** — `Đọc bằng giọng nói (Voice Recall)`
- **Learn by heart** — `ĐỐI CHIẾU TOÀN VĂN`
- **Learn by heart** — `🎙️ Đang lắng nghe... Hãy đọc to trọn vẹn câu kinh`
- **Other screens** — `Lưu thất`
- **PDF Reader** — `Không trích xuất được text từ trang `
- **PDF Reader** — `ghi chú`
- **Shared widgets** — `App sẽ phân tích âm thanh và tạo mục lục như sách.

🟢 Chạy nền — đóng cửa sổ này cũng được, tiến trì`
- **TTS** — `Giọng Microsoft Edge Neural theo ngôn ngữ`
- **TTS** — `Mỗi ngôn ngữ chọn 1 giọng Edge. Tự động áp dụng khi phát bằng engine Microsoft Edge TTS (không ảnh hưởng Piper/giọng máy).`
- **TTS** — `Mỗi ngôn ngữ chọn 1 giọng đã import. Tự động ưu tiên phát khi dùng Sherpa TTS.`
- **TTS** — `Piper × : chưa có giọng HOẶC thiếu phonemizer (espeak-ng-data) — cài tại TTS → Quản lý model`
- **Tipiṭaka** — `Bạn có thể chọn trực tiếp DB Pa-Auk .db/.sqlite/.zip hoặc file tipitaka.sqlite đã chuẩn hóa. Với build developer, đặt file vào Documents/in4up/tipitaka/imports/ rồi bấm Quét thư mục import. Ứng dụng sẽ tự nhận diện, chuyển DB nguồn sang schema In4Up và giữ lại Python importer cho các DB rất lớn.`
- **Tipiṭaka** — `Bạn vẫn có thể import và đọc Tiếng Việt ngay. Nên import Pāli trước hoặc sau để đối chiếu tốt hơn; khi chưa có Pāli, xem song ngữ và căn hàng sẽ tạm giảm cấp.`
- **Tipiṭaka** — `Bản dịch vẫn đọc độc lập. Nên import Pāli để đối chiếu tốt hơn; song ngữ và căn hàng đang tạm giảm cấp.`
- **Tipiṭaka** — `Chi tiết kỹ thuật`
- **Tipiṭaka** — `Chia đôi màn hình`
- **Tipiṭaka** — `Chưa có cơ sở dữ liệu hợp lệ`
- **Tipiṭaka** — `Chưa import Pāli; bản dịch vẫn đọc độc lập.`
- **Tipiṭaka** — `Chưa thấy file. Hãy đặt .db/.sqlite/.zip vào thư mục Documents/in4up/tipitaka/imports rồi quét lại.`
- **Tipiṭaka** — `Có thể đối chiếu Pāli và bản dịch theo đoạn.`
- **Tipiṭaka** — `Cơ sở dữ liệu đã sẵn sàng`
- **Tipiṭaka** — `Gói ngôn ngữ Tipiṭaka`
- **Tipiṭaka** — `Hãy import DB Pa-Auk hoặc tải gói ngôn ngữ.`
- **Tipiṭaka** — `Học thuộc đoạn này`
- **Tipiṭaka** — `Import DB hoặc gói ngôn ngữ từ thiết bị`
- **Tipiṭaka** — `Import hoặc tải dữ liệu`
- **Tipiṭaka** — `Import một gói ngôn ngữ bất kỳ để bắt đầu. Pāli được khuyến nghị nhưng không bắt buộc.`
- **Tipiṭaka** — `Import thất bại: {value0}`
- **Tipiṭaka** — `Không gian đọc Tipiṭaka`
- **Tipiṭaka** — `Không thể kiểm tra cơ sở dữ liệu Tipiṭaka.`
- **Tipiṭaka** — `Không thể lưu vào Worklist: {value0}`
- **Tipiṭaka** — `Không thể mở cơ sở dữ liệu Tipiṭaka.`
- **Tipiṭaka** — `Không thể mở danh mục: {value0}`
- **Tipiṭaka** — `Không thể mở đoạn: {value0}`
- **Tipiṭaka** — `Không thể thêm vào Học thuộc lòng: {value0}`
- **Tipiṭaka** — `Không thể tải {value0}: {value1}`
- **Tipiṭaka** — `Không tìm thấy lại nguồn Tipiṭaka.`
- **Tipiṭaka** — `Kiểm tra lại DB`
- **Tipiṭaka** — `Lưu cụm từ vào Worklist`
- **Tipiṭaka** — `Lưu từ vào Worklist`
- **Tipiṭaka** — `Lưu đoạn vào Worklist`
- **Tipiṭaka** — `Mỗi gói ngôn ngữ có thể import độc lập.`
- **Tipiṭaka** — `Mở bài trong tab mới`
- **Tipiṭaka** — `Mở nguồn Tipiṭaka`
- **Tipiṭaka** — `Mở thêm một bài để dùng chế độ chia đôi.`
- **Tipiṭaka** — `Mở thư viện`
- **Tipiṭaka** — `Mở trang nguồn Pa-Auk`
- **Tipiṭaka** — `Mục chưa có tiêu đề`
- **Tipiṭaka** — `Mục lục chi tiết`
- **Tipiṭaka** — `Nhập từ khóa để tìm trong Tipiṭaka`
- **Tipiṭaka** — `Pāli không bắt buộc để tiếp tục đọc.`
- **Tipiṭaka** — `Quét thư mục import của developer`
- **Tipiṭaka** — `Quét thất bại: {value0}`
- **Tipiṭaka** — `Quản lý dữ liệu`
- **Tipiṭaka** — `Tam Tạng Chính Văn`
- **Tipiṭaka** — `Tipiṭaka chưa có dữ liệu`
- **Tipiṭaka** — `Tipiṭaka — Dữ liệu`
- **Tipiṭaka** — `Tác vụ Tipiṭaka gần đây`
- **Tipiṭaka** — `Tìm kiếm Tipiṭaka`
- **Tipiṭaka** — `Tạng → nhóm/bộ → bài kinh`
- **Tipiṭaka** — `Tải gói ngôn ngữ Pa-Auk`
- **Tipiṭaka** — `Tải và giải nén`
- **Tipiṭaka** — `Từ khóa Pāli / bản dịch…`
- **Tipiṭaka** — `nhóm/bộ`
- **Tipiṭaka** — `sách`
- **Tipiṭaka** — `tạng`
- **Tipiṭaka** — `Đang giải nén`
- **Tipiṭaka** — `Đang import`
- **Tipiṭaka** — `Đang xếp hàng`
- **Tipiṭaka** — `Đã hoàn tất`
- **Tipiṭaka** — `Đã import các file tìm thấy trong thư mục.`
- **Tipiṭaka** — `Đã import cơ sở dữ liệu Tipiṭaka.`
- **Tipiṭaka** — `Đã lưu vào Worklist.`
- **Tipiṭaka** — `Đã sao chép lựa chọn.`
- **Tipiṭaka** — `Đã thêm ngữ cảnh Tipiṭaka vào từ đã có.`
- **Tipiṭaka** — `Đã thêm đoạn vào Học thuộc lòng.`
- **Tipiṭaka** — `Đã tải và import {value0} trực tiếp vào thư viện Tipiṭaka.`
- **Tipiṭaka** — `Đóng tab`
- **Tipiṭaka** — `Đọc Tam Tạng theo ngôn ngữ đã import`
- **Tipiṭaka** — `Đọc bài từ vị trí hiện tại`
- **Tipiṭaka** — `Đọc toàn bộ nhóm/bộ`
- **Tipiṭaka** — `đoạn kinh`
- **Tipiṭaka** — `Ẩn thông báo`
- **Tools / WordList** — ` · 🔥 {value0} lặp nhiều`
- **Tools / WordList** — `.txt: Mỗi dòng 1 từ, hoặc văn bản thường
.csv/.txt bảng cột (cần dòng header): word, meaning, ipa, topic, example, example_simple, example_complex, language, image_url (tùy chọn — link ảnh .png/.webp hoặc animation Lottie .json; tải về máy để học offline)
Ngăn cột: tab, phẩy, chấm phẩy hoặc | — ý nghĩa có dấu phẩy thì bọc "nét nháy"
Từ/cụm ĐÃ CÓ trong WordList vẫn hiện (badge "đã có") — import chỉ bổ sung nghĩa/IPA/ví dụ/minh họa CHỖ TRỐNG + tag, không ghi đè`
- **Tools / WordList** — `Dán bảng có header: word, meaning, ipa, topic, example, language, image_url (tùy chọn — link ảnh/Lottie .json)
(tab hoặc dấu phẩy; meaning có dấu phẩy thì bọc "nét nháy")
Hoặc text thường / một từ mỗi dòng...`
- **Tools / WordList** — `Lọc theo thực thể, trạng thái, ngô`
- **Tools / WordList** — `Mở Listen Mode, nghe file bất kỳ rồi:
• Chạm 📌 "Dấu" để đánh dấu một điểm
• Chọn A–B rồi lưu thành đoạn học tập
• Mở "Âm mục" để tạo mục lục như sách

Mọi thứ bạn đánh dấu sẽ xuất hiện tại đây.`
- **Tools / WordList** — `Ngôn ngữ (chọn 1–n — đầu danh sách = chính)`
- **Tools / WordList** — `Thêm mục`
- **Tools / WordList** — `Thêm mục cho file`
- **Tools / WordList** — `Tên chương/mục`
- **Tools / WordList** — `mục`
- **Tools / WordList** — `nét nháy`
- **Tools / WordList** — `{value0} · {value1} điểm · {value2} đoạn · {value3} mục{value4}`
- **Tools / WordList** — `điểm`
- **Tools / WordList** — `đã có`
- **Tools / WordList** — `… và {value0} dòng nữa — dùng "Tìm kiếm" trong Listen Mode để tìm trong toàn bộ nội dung.`
- **Tools / WordList** — `▶️ Đang phát: {value0}`
- **Tools / WordList** — `✅ Đã import: +{value0} mới, cập nhật {value1} đã có`
- **Tools / WordList** — `🔍  Tìm tên file, nhãn, ghi chú, tag…`
- **Web Reader** — `Dừng đọc`
- **Web Reader** — `Hãy tạo ít nhất `
- **Web Reader** — `Ngôn ngữ áp cho tất cả`
- **Web Reader** — `Đang đọc bài web`
- **Web Reader** — `Đã tạm dừng bài đọc`

### `ja`

- **Cabin** — `Bản dịch thời gian thực sẽ hiển thị tại đây...`
- **Cabin** — `Chưa có dữ liệu hội thoại.
Bấm nút Micro để bắt đầu phiên dịch cabin.`
- **Cabin** — `Chọn ngôn ngữ dịch (Đích)`
- **Cabin** — `Chọn ngôn ngữ nói (Gốc)`
- **Cabin** — `Dịch Live Cabin`
- **Cabin** — `Khuyên dùng tai nghe khi bật phát âm để tránh tiếng dịch lọt ngược vào micro!`
- **Cabin** — `Nói vào microphone để bắt đầu dịch cabin...`
- **Cabin** — `Sao chép văn bản`
- **Cabin** — `Xóa lịch sử`
- **Cabin** — `Đang nghe trực tiếp...`
- **Cabin** — `Đã chép câu dịch!`
- **Cabin** — `Đã sao chép toàn bộ nội dung dịch cabin vào bộ nhớ tạm!`
- **Cabin** — `Đọc dịch`
- **Dictionary** — `Bấm Import thư mục để thêm bộ từ điển (.mdx + .mdd + .css), rồi chọn liên kết (không sao chép) hoặc sao chép vào app.`
- **Dictionary** — `Sao chép mdx + mdd + css vào bộ nhớ app để dùng ổn định khi di chuyển hoặc xoá nguồn. Bản gốc vẫn được giữ nguyên; app có thêm một bản sao nên tốn thêm dung lượng tương ứng.`
- **Dictionary** — `Thư mục từ điển không còn truy cập được — chọn lại. Chỉ mục SQLite trong app vẫn được giữ.`
- **Dictionary** — `Ưu tiên — chỉ lưu chỉ mục tra từ nhỏ trong app; không sao chép bộ từ điển (mdx/mdd vẫn ở thư mục gốc). Nếu nguồn không còn truy cập được, chọn lại; chỉ mục vẫn được giữ.`
- **Grammar / Understand** — `Nhóm từ loạ`
- **Learn by heart** — `Bước {value0}/{value1}: {value2}`
- **Learn by heart** — `Bạn đang duy trì thói quen ghi nhớ rất tốt!`
- **Learn by heart** — `Bạn đã đạt 5 lần ôn tập thành công liên tiếp! Bạn có muốn làm bài Kiểm Tra Thực Chất (Assessment không gợi ý) để nhân đôi độ bền vững không?`
- **Learn by heart** — `Bản dịch ({value0})`
- **Learn by heart** — `Bản dịch ({value0}):`
- **Learn by heart** — `Bắt đầu đọc`
- **Learn by heart** — `CHẾ ĐỘ KHÔNG GỢI Ý`
- **Learn by heart** — `Chuẩn xác 100%`
- **Learn by heart** — `Chúc mừng bạn đã hoàn tất ghép bài!`
- **Learn by heart** — `Chạm để dừng & chấm điểm`
- **Learn by heart** — `Chỗ trống: chạm từ để ẩn khi ôn — không cần gõ {{c1::từ}}`
- **Learn by heart** — `CÂU CẦN ĐỌC TIẾP (DÒNG {value0})`
- **Learn by heart** — `CÂU MỒI DẪN DẮT (DÒNG {value0})`
- **Learn by heart** — `Cập nhật`
- **Learn by heart** — `Cố gắng nhẩm lại từng câu một cách trọn vẹn nhất trước khi mở văn bản đối chiếu.`
- **Learn by heart** — `Dựa trên thuật toán FSRS & chu kỳ quên tự nhiên.`
- **Learn by heart** — `Ghi nhận kết quả ({value0}) vào FSRS`
- **Learn by heart** — `Hoàn tất xích kệ ngôn! 🎉`
- **Learn by heart** — `Hành động này sẽ nạp lại toàn bộ 10 Kệ Pháp Cú và các bài kinh tụng chuẩn mẫu ban đầu. Bạn có muốn tiếp tục không?`
- **Learn by heart** — `Hành động và tâm ý tạo tác quả báo.`
- **Learn by heart** — `Hãy tự đọc toàn bài trong đầu`
- **Learn by heart** — `Hãy đọc nhẩm toàn bộ bài một lần cuối và chọn mức độ nhớ để FSRS tự động lên lịch nhắc ôn.`
- **Learn by heart** — `Học cuốn chiếu (Chunking Flow)`
- **Learn by heart** — `Không tìm thấy bài học phù hợp`
- **Learn by heart** — `Kiểm tra thực chất (Assessment)`
- **Learn by heart** — `Liên hệ thực tế đời sống (1 câu)`
- **Learn by heart** — `Lắng nghe câu mở đầu, sau đó tự đọc trọn vẹn phần còn lại`
- **Learn by heart** — `Mối nối liên hoàn (Xích kệ ngôn {value0}/{value1})`
- **Learn by heart** — `Nguyên văn ({value0})`
- **Learn by heart** — `Nguyên văn ({value0}):`
- **Learn by heart** — `Nhấn nút Mic bên dưới và đọc câu kinh vào điện thoại để chấm điểm thuộc lòng`
- **Learn by heart** — `Nối xích`
- **Learn by heart** — `Phụ đề / Chủ đề ngắn`
- **Learn by heart** — `Quên / vấp nhiều`
- **Learn by heart** — `So sánh với bản đọc nhẩm trong đầu và tự đánh giá thực chất (Trọng số x2):`
- **Learn by heart** — `Song ngữ ({value0} + {value1})`
- **Learn by heart** — `Sẵn sàng test`
- **Learn by heart** — `Số lần phát bài / đoạ`
- **Learn by heart** — `Số lần phát câu {value0}`
- **Learn by heart** — `TOÀN VĂN ĐỐI CHIẾU`
- **Learn by heart** — `Thuộc câu nối → Sang mối tiếp`
- **Learn by heart** — `Thuộc lòng xuất sắc! 🎉`
- **Learn by heart** — `Thêm bài học thuộc lòng mới`
- **Learn by heart** — `Thể loại`
- **Learn by heart** — `Thử thay đổi bộ lọc hoặc thêm bài mới vào danh sách`
- **Learn by heart** — `Thử thách Thuộc Lòng!`
- **Learn by heart** — `Tiêu đề bài kinh / kệ ngôn`
- **Learn by heart** — `Tuyệt vời! Bạn đã hoàn thành toàn bộ bài ôn tập hôm nay.`
- **Learn by heart** — `Tôi đã đọc xong trong đầu`
- **Learn by heart** — `Từ khóa ghi nhớ (phân cách bằng dấu phẩy)`
- **Learn by heart** — `Vui lòng cấp quyền Microphone để ghi âm`
- **Learn by heart** — `VĂN BẢN MỤC TIÊU CẦN ĐỌC`
- **Learn by heart** — `Xem câu tiếp theo`
- **Learn by heart** — `___ ? Hãy nhớ câu tiếp theo trong đầu ? ___`
- **Learn by heart** — `Ôn sau {value0}`
- **Learn by heart** — `Ý nghĩa cốt lõi (≤ 15 từ)`
- **Learn by heart** — `Đang phân tích & đối chiếu giọng đọc...`
- **Learn by heart** — `Đoạn {value0}`
- **Learn by heart** — `Đã ôn {value0} lần`
- **Learn by heart** — `Đến hạn ôn`
- **Learn by heart** — `Đọc bằng giọng nói (Voice Recall)`
- **Learn by heart** — `ĐỐI CHIẾU TOÀN VĂN`
- **Learn by heart** — `🎙️ Đang lắng nghe... Hãy đọc to trọn vẹn câu kinh`
- **Other screens** — `Lưu thất`
- **PDF Reader** — `Không trích xuất được text từ trang `
- **PDF Reader** — `ghi chú`
- **Shared widgets** — `App sẽ phân tích âm thanh và tạo mục lục như sách.

🟢 Chạy nền — đóng cửa sổ này cũng được, tiến trì`
- **TTS** — `Giọng Microsoft Edge Neural theo ngôn ngữ`
- **TTS** — `Mỗi ngôn ngữ chọn 1 giọng Edge. Tự động áp dụng khi phát bằng engine Microsoft Edge TTS (không ảnh hưởng Piper/giọng máy).`
- **TTS** — `Mỗi ngôn ngữ chọn 1 giọng đã import. Tự động ưu tiên phát khi dùng Sherpa TTS.`
- **TTS** — `Piper × : chưa có giọng HOẶC thiếu phonemizer (espeak-ng-data) — cài tại TTS → Quản lý model`
- **Tipiṭaka** — `Bạn có thể chọn trực tiếp DB Pa-Auk .db/.sqlite/.zip hoặc file tipitaka.sqlite đã chuẩn hóa. Với build developer, đặt file vào Documents/in4up/tipitaka/imports/ rồi bấm Quét thư mục import. Ứng dụng sẽ tự nhận diện, chuyển DB nguồn sang schema In4Up và giữ lại Python importer cho các DB rất lớn.`
- **Tipiṭaka** — `Bạn vẫn có thể import và đọc Tiếng Việt ngay. Nên import Pāli trước hoặc sau để đối chiếu tốt hơn; khi chưa có Pāli, xem song ngữ và căn hàng sẽ tạm giảm cấp.`
- **Tipiṭaka** — `Bản dịch vẫn đọc độc lập. Nên import Pāli để đối chiếu tốt hơn; song ngữ và căn hàng đang tạm giảm cấp.`
- **Tipiṭaka** — `Chi tiết kỹ thuật`
- **Tipiṭaka** — `Chia đôi màn hình`
- **Tipiṭaka** — `Chưa có cơ sở dữ liệu hợp lệ`
- **Tipiṭaka** — `Chưa import Pāli; bản dịch vẫn đọc độc lập.`
- **Tipiṭaka** — `Chưa thấy file. Hãy đặt .db/.sqlite/.zip vào thư mục Documents/in4up/tipitaka/imports rồi quét lại.`
- **Tipiṭaka** — `Có thể đối chiếu Pāli và bản dịch theo đoạn.`
- **Tipiṭaka** — `Cơ sở dữ liệu đã sẵn sàng`
- **Tipiṭaka** — `Gói ngôn ngữ Tipiṭaka`
- **Tipiṭaka** — `Hãy import DB Pa-Auk hoặc tải gói ngôn ngữ.`
- **Tipiṭaka** — `Học thuộc đoạn này`
- **Tipiṭaka** — `Import DB hoặc gói ngôn ngữ từ thiết bị`
- **Tipiṭaka** — `Import hoặc tải dữ liệu`
- **Tipiṭaka** — `Import một gói ngôn ngữ bất kỳ để bắt đầu. Pāli được khuyến nghị nhưng không bắt buộc.`
- **Tipiṭaka** — `Import thất bại: {value0}`
- **Tipiṭaka** — `Không gian đọc Tipiṭaka`
- **Tipiṭaka** — `Không thể kiểm tra cơ sở dữ liệu Tipiṭaka.`
- **Tipiṭaka** — `Không thể lưu vào Worklist: {value0}`
- **Tipiṭaka** — `Không thể mở cơ sở dữ liệu Tipiṭaka.`
- **Tipiṭaka** — `Không thể mở danh mục: {value0}`
- **Tipiṭaka** — `Không thể mở đoạn: {value0}`
- **Tipiṭaka** — `Không thể thêm vào Học thuộc lòng: {value0}`
- **Tipiṭaka** — `Không thể tải {value0}: {value1}`
- **Tipiṭaka** — `Không tìm thấy lại nguồn Tipiṭaka.`
- **Tipiṭaka** — `Kiểm tra lại DB`
- **Tipiṭaka** — `Lưu cụm từ vào Worklist`
- **Tipiṭaka** — `Lưu từ vào Worklist`
- **Tipiṭaka** — `Lưu đoạn vào Worklist`
- **Tipiṭaka** — `Mỗi gói ngôn ngữ có thể import độc lập.`
- **Tipiṭaka** — `Mở bài trong tab mới`
- **Tipiṭaka** — `Mở nguồn Tipiṭaka`
- **Tipiṭaka** — `Mở thêm một bài để dùng chế độ chia đôi.`
- **Tipiṭaka** — `Mở thư viện`
- **Tipiṭaka** — `Mở trang nguồn Pa-Auk`
- **Tipiṭaka** — `Mục chưa có tiêu đề`
- **Tipiṭaka** — `Mục lục chi tiết`
- **Tipiṭaka** — `Nhập từ khóa để tìm trong Tipiṭaka`
- **Tipiṭaka** — `Pāli không bắt buộc để tiếp tục đọc.`
- **Tipiṭaka** — `Quét thư mục import của developer`
- **Tipiṭaka** — `Quét thất bại: {value0}`
- **Tipiṭaka** — `Quản lý dữ liệu`
- **Tipiṭaka** — `Tam Tạng Chính Văn`
- **Tipiṭaka** — `Tipiṭaka chưa có dữ liệu`
- **Tipiṭaka** — `Tipiṭaka — Dữ liệu`
- **Tipiṭaka** — `Tác vụ Tipiṭaka gần đây`
- **Tipiṭaka** — `Tìm kiếm Tipiṭaka`
- **Tipiṭaka** — `Tạng → nhóm/bộ → bài kinh`
- **Tipiṭaka** — `Tải gói ngôn ngữ Pa-Auk`
- **Tipiṭaka** — `Tải và giải nén`
- **Tipiṭaka** — `Từ khóa Pāli / bản dịch…`
- **Tipiṭaka** — `nhóm/bộ`
- **Tipiṭaka** — `sách`
- **Tipiṭaka** — `tạng`
- **Tipiṭaka** — `Đang giải nén`
- **Tipiṭaka** — `Đang import`
- **Tipiṭaka** — `Đang xếp hàng`
- **Tipiṭaka** — `Đã hoàn tất`
- **Tipiṭaka** — `Đã import các file tìm thấy trong thư mục.`
- **Tipiṭaka** — `Đã import cơ sở dữ liệu Tipiṭaka.`
- **Tipiṭaka** — `Đã lưu vào Worklist.`
- **Tipiṭaka** — `Đã sao chép lựa chọn.`
- **Tipiṭaka** — `Đã thêm ngữ cảnh Tipiṭaka vào từ đã có.`
- **Tipiṭaka** — `Đã thêm đoạn vào Học thuộc lòng.`
- **Tipiṭaka** — `Đã tải và import {value0} trực tiếp vào thư viện Tipiṭaka.`
- **Tipiṭaka** — `Đóng tab`
- **Tipiṭaka** — `Đọc Tam Tạng theo ngôn ngữ đã import`
- **Tipiṭaka** — `Đọc bài từ vị trí hiện tại`
- **Tipiṭaka** — `Đọc toàn bộ nhóm/bộ`
- **Tipiṭaka** — `đoạn kinh`
- **Tipiṭaka** — `Ẩn thông báo`
- **Tools / WordList** — ` · 🔥 {value0} lặp nhiều`
- **Tools / WordList** — `.txt: Mỗi dòng 1 từ, hoặc văn bản thường
.csv/.txt bảng cột (cần dòng header): word, meaning, ipa, topic, example, example_simple, example_complex, language, image_url (tùy chọn — link ảnh .png/.webp hoặc animation Lottie .json; tải về máy để học offline)
Ngăn cột: tab, phẩy, chấm phẩy hoặc | — ý nghĩa có dấu phẩy thì bọc "nét nháy"
Từ/cụm ĐÃ CÓ trong WordList vẫn hiện (badge "đã có") — import chỉ bổ sung nghĩa/IPA/ví dụ/minh họa CHỖ TRỐNG + tag, không ghi đè`
- **Tools / WordList** — `Dán bảng có header: word, meaning, ipa, topic, example, language, image_url (tùy chọn — link ảnh/Lottie .json)
(tab hoặc dấu phẩy; meaning có dấu phẩy thì bọc "nét nháy")
Hoặc text thường / một từ mỗi dòng...`
- **Tools / WordList** — `Lọc theo thực thể, trạng thái, ngô`
- **Tools / WordList** — `Mở Listen Mode, nghe file bất kỳ rồi:
• Chạm 📌 "Dấu" để đánh dấu một điểm
• Chọn A–B rồi lưu thành đoạn học tập
• Mở "Âm mục" để tạo mục lục như sách

Mọi thứ bạn đánh dấu sẽ xuất hiện tại đây.`
- **Tools / WordList** — `Ngôn ngữ (chọn 1–n — đầu danh sách = chính)`
- **Tools / WordList** — `Thêm mục`
- **Tools / WordList** — `Thêm mục cho file`
- **Tools / WordList** — `Tên chương/mục`
- **Tools / WordList** — `mục`
- **Tools / WordList** — `nét nháy`
- **Tools / WordList** — `{value0} · {value1} điểm · {value2} đoạn · {value3} mục{value4}`
- **Tools / WordList** — `điểm`
- **Tools / WordList** — `đã có`
- **Tools / WordList** — `… và {value0} dòng nữa — dùng "Tìm kiếm" trong Listen Mode để tìm trong toàn bộ nội dung.`
- **Tools / WordList** — `▶️ Đang phát: {value0}`
- **Tools / WordList** — `✅ Đã import: +{value0} mới, cập nhật {value1} đã có`
- **Tools / WordList** — `🔍  Tìm tên file, nhãn, ghi chú, tag…`
- **Web Reader** — `Dừng đọc`
- **Web Reader** — `Hãy tạo ít nhất `
- **Web Reader** — `Ngôn ngữ áp cho tất cả`
- **Web Reader** — `Đang đọc bài web`
- **Web Reader** — `Đã tạm dừng bài đọc`

