# Nghiệm thu tra cứu và bộ từ điển thật

Trạng thái: **chưa chạy trên thiết bị**. Checklist này không phải kết quả đo.
Cần bản app chứa các thay đổi của nhánh thử nghiệm, thiết bị Android thật và
các bộ LAAD3/Lạc Việt được người dùng sở hữu hợp pháp. Không đưa MDX/MDD hoặc
định nghĩa có bản quyền vào Git, nhật ký công khai hay PR. Ghi phiên bản app,
thiết bị, Android, RAM, vùng lưu trữ và ID commit; che đường dẫn/URI cá nhân.

## An toàn trước khi thử

- Sao lưu nguồn MDX/MDD/CSS ở ngoài app và dữ liệu người dùng; không xoá bộ cũ
  để thử. Dùng bản sao và đủ dung lượng trống. Linked vẫn tạo DB chứa nghĩa;
  copy còn cần chỗ cho bundle. Ghi DB/WAL và bundle riêng, tránh đếm file chung
  hai lần; SAF/cloud không báo size thì ghi không biết.
- Đối chiếu bằng Eudic/MDict/GoldenDict đã đọc được **chính bộ đó**. Ghi tên
  từ và phần bị thiếu (ví dụ "thiếu ví dụ thứ 3"), không sao chép nội dung gốc.

## 1. Import và mở rộng

1. Thử LACVITED và LAAD3, lần lượt liên kết và sao chép trên bản sao, nếu đủ
   dung lượng. LAAD3 có MDX, CSS và MDD chính khoảng 1,22 GB + phần phụ; chọn
   đúng cả bundle. Ghi số file/size, thời gian import, số entry app báo, DB/WAL
   và kết quả; không mặc định 583.525/76.370 entry là con số bắt buộc nếu phiên
   bản bộ khác. Ghi lỗi cụ thể và dừng nếu hệ thống thiếu dung lượng.
2. Với `retain`, `meditation` và các từ có trong bộ, thêm mục dài, IPA, ví dụ,
   Unicode, alias/chuyển hướng, mục có ảnh. Tra tại màn Từ điển, pop → chi tiết
   ở Đọc, PDF và nơi có WordAnalysisSheet. Đối chiếu xem kết quả nhanh, nút mở
   đầy đủ, mục theo từng bộ và các ví dụ có nhất quán. So hai bộ bật đồng thời,
   đổi thứ tự và lọc riêng; thử từ không có và tra nhanh hai từ liên tiếp.
3. Mở từng nguồn trong chi tiết. Ảnh phải bấm tải, tối đa bốn ảnh PNG/JPEG được
   hỗ trợ; hiện sau văn bản. Chỉ một số kiểu chữ nội tuyến được hỗ trợ; tệp
   CSS, âm thanh, ảnh inline chưa hỗ trợ nên ghi là giới hạn đã biết, không đánh dấu đạt fidelity gốc. Thử thiếu MDD/phần phụ,
   nhập lại/liên kết lại, đóng sheet hoặc đổi mục khi ảnh đang tải.
4. Với DB nhập bằng bản parser cũ: so sánh bộ cũ với một bản nhập **mới riêng**
   từ nguồn đã sao lưu. Nếu khác, ghi phiên bản và từ ví dụ; không tự xóa DB cũ,
   không khẳng định reimport sẽ sửa mọi lỗi. Kiểm tra từ có >10 record/một bộ:
   các mặt tra cứu phải cảnh báo chưa đủ. Mở màn Từ điển và bấm tải thêm,
   kiểm nội dung sau mỗi lần; trần 100 record/bộ, trần redirect 512 nên vẫn
   có thể chưa đầy đủ. Các popup chưa tự phân trang.

## 2. SAF, hiệu năng và tính bền

1. Chọn thư mục qua SAF, thoát/mở lại app, tra rồi tải ảnh; thử thu hồi quyền,
   di chuyển nguồn, liên kết lại và thử ảnh. Kiểm tra lỗi/thiếu tài nguyên được
   báo mà không xóa SQLite hay lấy nhầm ảnh từ bộ khác. Không thu hồi quyền của
   nguồn duy nhất chưa sao lưu. Nếu provider treo, ghi lại; huỷ có thể chờ I/O.
2. Ghi tối thiểu 3 lần cold (mở lại app) và 3 lần warm cho tra từ và tải ảnh;
   ghi median/range, cách đo và bộ nhớ trước/đỉnh/sau, thao tác cuộn có giật hoặc
   app bị hệ điều hành đóng. Android Studio profiler hoặc `adb shell dumpsys
   meminfo <tên-package>` (PSS theo thời điểm) có thể dùng; PSS lấy mẫu không
   chứng minh đỉnh thực. Ghi cả thiết bị và dung lượng trống. Không nhận xét đạt
   hiệu năng chỉ vì không crash hoặc chỉ vì test ảo 1,22 GB xanh.
3. Thử ngắt giữa các bước và khởi động lại, kiểm chứng không mất file gốc, DB
   và các bộ khác; không thay đổi/ghi đè file nguồn trong khi app đang đọc.

## Mẫu biên bản (không có nội dung bản quyền)

| Mục | App/commit + thiết bị | Bộ/mode | Các bước + từ | Kết quả / mong đợi | Số đo / chứng cứ | Pass/Fail/Blocked |
|---|---|---|---|---|---|---|
| Import, tra, mở rộng | | | | | | |
| SAF, thu hồi quyền, relink | | | | | | |
| LAAD3 cold/warm/RAM | | | | | | |

Cảnh báo đã nối tới màn Từ điển, hành động Đọc, pop Đọc/WordActions,
WordAnalysis và PDF qua WordInsight; vẫn cần kiểm thử các đường khác và trường
hợp lỗi khởi tạo manifest. Quản lý bộ chỉ hiển thị kích thước file SQLite tại
thời điểm đọc, không gồm WAL/SHM hay nguồn. Cần đối chiếu Unicode SQLite và
máy thật trước khi đóng mục 1–2.

## 3. Chọn chữ từ ứng dụng Android khác

Chọn từ trong ứng dụng khác → chọn In4Up từ menu chọn văn bản; thử lúc In4Up
đang đóng, đang mở, xoay màn hình và quay lại app nguồn. Thử văn bản Unicode,
ký tự `&`, chuỗi rỗng và trên 64 rune; không được tự mở link/tệp hay thay thế
văn bản nguồn. Từ tra thành công được lưu vào lịch sử tra trong app như tra ở
màn Từ điển; có thể xóa lịch sử trong app. Không đọc clipboard hoặc chụp màn
hình. Đây không phải bong bóng nổi, và cần ghi thiết bị/Android/app nguồn.
