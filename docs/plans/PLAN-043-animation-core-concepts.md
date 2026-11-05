# PLAN-043 (phụ) — Nháp 100 khái niệm cốt lõi cho gói animation tuyển chọn (LOTTIE-LIB-001 Pha 2)

- **Trạng thái:** ✅ Owner duyệt 2026-11-05; Pha 2 đã code: 100 concept, 100 animation Lottie gốc In4Up CC0 (~289KB), catalog offline tìm VI/EN. Analyze + PLAN-043 tests CI 🟢 run `41964276729`; còn nghiệm thu trên máy. Không kéo theo Pha 3/provider bên thứ ba.
- **Mục đích:** danh sách khái niệm sẽ được tuyển animation Lottie giấy phép
  mở, gắn vào **Nút Khái niệm** (CONCEPT-001) để mọi ngôn ngữ dùng chung.
  Cột "Từ khoá tìm (EN)" là từ khoá dùng khi săn/tuyển trên kho Lottie và
  cũng là từ khoá nút "Tìm trên LottieFiles" điền sẵn ở Pha 1.
- **Tiêu chí chọn:** (1) có hình/chuyển động trực quan (animation hơn ảnh
  tĩnh rõ rệt: hành động, thời tiết, cảm xúc, chuyển động cơ học);
  (2) thuộc 1.000 từ thông dụng đầu tiên của người mới học;
  (3) ít phụ thuộc văn hoá để dùng xuyên ngôn ngữ.

## A. Hành động cơ thể (18)
run · walk · jump · swim · climb · dance · sit · stand · sleep · wake up ·
eat · drink · cook · read · write · speak · listen · think

## B. Cảm xúc & trạng thái (10)
happy · sad · angry · surprised · afraid · love/heart · laugh · cry ·
tired · sick

## C. Động vật (12)
dog · cat · bird · fish · butterfly · bee · horse · cow · pig · chicken ·
snake · elephant

## D. Thiên nhiên & thời tiết (12)
sun · moon · star · rain · snow · wind · cloud · lightning · fire ·
water/wave · tree · flower

## E. Đồ vật & nhà cửa (12)
house · door · key · book · phone · computer · light/lamp · clock ·
chair · bed · cup · car

## F. Đi lại & nơi chốn (8)
bicycle · bus · train · airplane · boat · school · hospital · market/shop

## G. Ăn uống (8)
apple · banana · bread · egg · milk · coffee · rice · cake

## H. Con người & cơ thể (8)
hand · eye · ear · mouth · head · baby · man · woman

## I. Khái niệm có chuyển động đặc trưng (12)
grow (cây lớn) · fall (lá rơi) · fly · open/close (cửa) · up/down (mũi tên) ·
hot/cold (nhiệt kế) · day/night (xoay) · music (nốt nhạc bay) ·
money (xu rơi) · gift (hộp mở) · question (?) · check/yes-no (✓/✗)

**Tổng: 100 khái niệm.** Khi triển khai Pha 2, mỗi mục cần: 1 file
`.json/.lottie` (≤200KB mục tiêu), giấy phép ghi rõ trong chỉ mục
(nguồn + tác giả + license), ảnh tĩnh frame đầu làm thumbnail.

## Lịch sử
- 2026-11-03 | created (nháp) | agent `arena/d2aeb948-in4up` | soạn theo tiêu chí trên, chờ owner duyệt/cắt.
- 2026-11-05 | proposed→approved→implemented (Pha 2) | agent `arena/d2aeb948-in4up` | owner duyệt nguyên danh mục 100 mục; dùng script `tool/generate_concept_animations.py` sinh 100 Lottie JSON gốc hình học CC0 + catalog `assets/animations/concept_animation_pack.json`; toàn bộ assets ~289KB, ≤200KB từng file. App tìm offline bằng EN/VI (bỏ dấu), hiển thị animation ở lưới chỉ khi hiện, chạm → xem trước lớn → lưu bytes offline; cùng picker có thể gắn vào `ConceptNode.imageRef`. Tile hiển thị chính frame Lottie (không tách PNG thumbnail riêng). Tests `vocab_animation_library_test.dart` được thêm vào PLAN-043 CI; Analyze + PLAN-043 tests 🟢 run `41964276729` (commit `663838d`). Còn nghiệm thu máy; Pha 3 chưa được duyệt.
- 2026-11-06 | approved→approved (định danh sau rebase) | agent `arena/d2aeb948-in4up` | đổi PLAN-041 thành PLAN-043 để tránh trùng với READ-UI-120 đã có trên tip 251e.
