# ADR-0028 — I4U Dictionary: giữ nguồn, tra nhanh và xem theo từng bộ

- Ngày: 2026-11-09. Trạng thái: **triển khai từng phần; chưa nghiệm thu CI/thiết bị**.
- Owner đồng ý làm khuyến nghị trước mắt; giai đoạn MDX trực tiếp + SQLite chỉ mục
  để xét sau khi bản hiện tại tốt, **không mặc nhiên triển khai**.

## Bối cảnh và quyết định

Nguồn là MDX + MDD/CSS/asset, SQLite hiện chứa cả `headword` **và** `definition`,
không chỉ chỉ mục nhỏ. Mode imported sao chép bundle vào app; mode linked giữ
bundle ở nguồn nhưng vẫn tạo DB đầy đủ. Không xóa/sửa file gốc, không tự đổi
mode hoặc migrate DB. MDD/CSS và media không được parser hiện nay giải quyết.
Cần test một bộ thật có quyền sử dụng (chưa được owner cung cấp), đối chiếu với
MDict/GoldenDict: mục dài, nhiều loại từ, ví dụ, IPA, ảnh/âm thanh, CSS, liên
kết/chuyển hướng, Unicode, đa block; lưu kết quả không chứa dữ liệu bản quyền.

Giữ hai tầng: (1) tra nhanh hiện dùng cleaner/merge có giới hạn, (2) xem tách
riêng từng nguồn, không dùng kết quả đã gộp hoặc giới hạn nghĩa/ví dụ. **Bản
triển khai này mới là văn bản an toàn từ definition đã import**, không phải
hiển thị nguyên bản MDX. Nó dùng parser HTML → TextSpan (đậm/nghiêng/dòng/li),
không thực thi script, CSS, link, network, ảnh, âm thanh hay file, nói rõ trong
UI. Không đưa nội dung ngoài vào WebView có quyền rộng. Không tự ý bật JS.
Các mục sâu quá 100 cấp bị giới hạn để bảo vệ stack; media-only có thể trống.

## Những sửa đổi trong đợt này

- `DictSourceEntries` được dùng ở `DictionaryScreen`, `DictResultSheet` và
  `DictEntryDetailSheet`. Nếu cleaner không tạo được nghĩa, vẫn hiện mục nhập
  theo nguồn thay vì báo không tìm thấy. Nguồn được tách riêng; không khử trùng.
- PDF `WordInsight` trước có thể hiển thị `_merged` cục bộ nhưng truyền
  `online.entries` rỗng khi mở chi tiết. `withDictionaryFallback` giữ nguyên
  entries cục bộ cho cùng từ khi nâng cấp mạng thiếu entries. Không ghi đè dữ
  liệu người dùng, không trộn từ khác. Còn các nguyên nhân khác cần thiết bị.
- MDX parser lấy toàn bộ record qua ranh giới block trước khi giải mã, và giữ
  mọi key trỏ tới cùng offset. Test tổng hợp có ký tự UTF-8 bị chia giữa block
  và alias. Các DB đã nhập bằng parser cũ **không tự được sửa**: cần import lại
  sau khi xác minh nguồn, không xóa dữ liệu gốc. Các giới hạn engine 3, mã hóa,
  LZO và bảng mã khác UTF-8/UTF-16 vẫn còn.
- UI mode linked không còn hứa sai rằng DB là chỉ mục nhỏ.

## Chưa hoàn thành — bắt buộc chuyển tiếp

1. Renderer nguyên bản thật: CSS + MDD + font/ảnh/âm thanh, đường dẫn nội bộ,
   liên kết và chuyển hướng (`@@@LINK=`), bố cục, ngày/đêm, accessibility;
   sandbox nội dung, giới hạn tài nguyên, không mạng/file tùy ý, không JS mặc
   định. Khảo sát đa nền tảng trước khi chọn WebView hay renderer khác.
2. Đối chiếu fixture thực tế/kiểm thử nhập, đo thời gian/RAM/dung lượng (bao gồm
   tệp DB/WAL và bundle), bộ lớn, alias và nội dung qua block; có thể phải reimport.
   Không có số benchmark và chưa khẳng định tính đầy đủ của mọi file MDX.
3. `DictDbService.lookup` giới hạn 10 record mỗi bộ; lookup hiện nuốt lỗi DB.
   Bổ sung phân trang/trạng thái lỗi thay vì báo không tìm thấy, kiểm tra Unicode
   và alias, và cache/race khi bộ từ điển thay đổi. Xem thêm màn ngoài PDF/Read/
   YouTube để xác định các đường mở rộng còn mất entry.
4. Thêm báo cáo dung lượng thực từng DB/bundle, không nhầm SAF URI với path,
   không cộng hai lần file dùng chung. Các nguồn cloud/SD có thể không biết size;
   hỗ trợ trạng thái không xác định.
5. Android bôi đen `ACTION_PROCESS_TEXT`/chia sẻ, sau đó bong bóng tra từ riêng;
   OCR/MediaProjection chỉ khi người dùng yêu cầu. Không âm thầm theo dõi
   clipboard. iOS/desktop có giới hạn riêng; ADR-0018 ghi trạng thái hiện hữu.
6. Chỉ khi owner duyệt sau nghiệm thu: xem xét MDX đọc trực tiếp + DB chỉ mục,
   fingerprint/đổi nguồn, tương thích, cache khối và benchmark. Chưa cam kết.

## Bàn giao kiểm thử

Các test `test/dictionary/mdx_parser_test.dart`, `dict_source_entries_test.dart`,
`test/word_lookup/word_insight_service_test.dart` bao phủ fixture tổng hợp và
trường hợp giữ entries. Phải chạy Flutter analyze/tests + CI và QA máy thật;
không dùng test giả như bằng chứng đã hỗ trợ MDD/CSS hoặc mọi bộ MDX.
