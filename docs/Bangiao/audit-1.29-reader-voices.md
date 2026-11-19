# Audit 1.29.0 · mục 2: engine và giọng theo nơi đọc

PDF, web, Tipiṭaka và tab Đọc vốn đã dùng cùng `TtsService`. Khác biệt nằm trước và trong router: PDF ghim `en-US` ngay cả khi đọc trang Việt, PDF/web và một số luồng khác đổi locale trên singleton; lần phát đầu không đợi khôi phục thứ tự engine. Luồng xuất âm thanh web có thứ tự riêng. Đây là kết quả đọc mã, không phải chẩn đoán từ log của thiết bị báo lỗi.

**Quy tắc:** trong Đọc → Cài đặt Text Studio → Giọng đọc & engine, các cài đặt cũ là **cấu hình chung**. Mở **Ghi đè theo nơi đọc**, chạm tên nơi đọc để chọn engine; nút giọng bên phải cho phép chọn giọng riêng với Piper, VieNeu, Edge hoặc hệ thống. Giữ **Kế thừa cấu hình chung** ở mục giọng nếu chỉ muốn đổi engine. Một giọng riêng chỉ áp dụng cho engine và ngôn ngữ tương thích; các ngôn ngữ khác dùng bộ chọn giọng chung. Chọn kế thừa ở mục engine sẽ xóa cả ghi đè. Không sao chép cấu hình chung vào từng màn hình.

Engine riêng được thử trước, sau đó là đường phát chung (gồm ưu tiên giọng Edge đã chọn). Không bật lại engine đã tắt, không gọi online trong chế độ chỉ offline. Giữa câu, chỉ chuyển phần chưa đọc sang engine kế. Fallback không ghi đè lựa chọn đã lưu. Nhãn **Lần phát gần nhất** là nguồn âm thực tế, không phải tên engine đặt trước; khi đang đọc, tab Đọc, Tipiṭaka, PDF và web cũng hiển thị nhãn nguồn. Xuất âm thanh web chỉ thử các backend hỗ trợ xuất file (VieNeu/Piper WAV, Edge MP3), không thay đổi nhãn lần phát.

## Kiểm tra trên Android

1. Cài bản từ nhánh thử lên máy có giọng hệ thống EN và VI. Import Piper tiếng Việt và một giọng Anh có thể phân biệt; kiểm tra cả hai model đọc được. Chọn **Chỉ Offline**, kéo Piper lên đầu, đặt giọng theo ngôn ngữ. Để cả bốn nơi ở chế độ kế thừa.
2. Đọc một câu tiếng Việt ở tab Đọc, một đoạn web và PDF có **text layer** (để ngôn ngữ PDF ở **Tự động**); thử cả đọc liên tục lẫn chạm từ. Nghe và so nhãn nguồn: phải là Piper hoặc Cache · Sherpa Piper, không phải System TTS. Thử lại PDF với ngôn ngữ VI chỉ định.
3. Đặt **riêng PDF = Offline (Máy)**. Đọc lại cùng câu để kiểm tra cache không lấn lựa chọn: chỉ PDF dùng System TTS. Đổi PDF sang Piper và chọn một giọng riêng; tab Đọc vẫn dùng giọng chung. Thử thay engine riêng cho web từ nhãn trên thanh nghe và Tipiṭaka từ cài đặt trình đọc.
4. Kiểm tra PSRC-230: tab Đọc phát song ngữ EN → VI. Trong Tipiṭaka, thử bản dịch EN/VI và đoạn Pāli (định tuyến `hi`). Không ép model Việt đọc câu Anh hoặc Hindi; thiếu giọng phù hợp phải chuyển nguồn. Không thay engine dịch để làm phép thử này.
5. **Fallback:** chọn Piper riêng cho PDF; thử một câu/ngôn ngữ không có model tương thích (hoặc tắt Piper trong cấu hình chung). Kỳ vọng dùng engine hợp lệ kế tiếp, nhãn đổi, PDF vẫn ghi đè Piper. Bật lại/cài model, đọc lại phải quay về Piper. Tắt mọi engine: không tự bật giọng hệ thống.
6. Buộc dừng ứng dụng, mở lại và phát PDF ngay trước khi mở cài đặt. Kiểm tra engine, giọng, ngôn ngữ PDF và trạng thái kế thừa/ghi đè. Chuyển PDF về kế thừa, đổi cấu hình chung, khởi động lại: PDF phải theo cấu hình **mới**. Kiểm tra thêm Next/Pause/Stop không kích hoạt fallback của phiên đã hủy.

**Kiểm thử Flutter:** `flutter test test/tts_candidate_router_test.dart test/tts/language_voice_routing_test.dart test/psrc187_tts_chunking_test.dart test/tts/psrc245_engine_order_merge_test.dart test/pdf_reader/pdf_tts_machine_test.dart`. Không thay đổi engine dịch, ghi âm hoặc chấm điểm Shadowing.
