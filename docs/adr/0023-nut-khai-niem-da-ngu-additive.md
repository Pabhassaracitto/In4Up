# ADR-0023: Nút Khái niệm đa ngữ (ConceptNode) — kho mới additive + `conceptId` tuỳ chọn trên `WordEntry`

- **Ngày:** 2026-11-03
- **Trạng thái:** ĐÃ QUYẾT ĐỊNH (owner duyệt hướng qua bản trực quan `docs/plans/PLAN-043-visual.html`; triển khai Pha A ở card `CONCEPT-001`)
- **Phạm vi Pha A:** model `ConceptNode` + kho `concept_nodes_v1`, `WordEntry.conceptId`, gợi ý nối có người duyệt, màn Khái niệm (list/detail). Các pha B–E (thêm ngôn ngữ từ khái niệm, ôn theo khái niệm, mã ngoài, quan hệ mở rộng) ngoài phạm vi ADR này — mở ADR tiếp khi làm.

## Bối cảnh

PLAN-043 mục 1 (yêu cầu owner 2026-11-02): học đa ngữ theo trục
**ý nghĩa → âm thanh/IPA → chữ viết**. Hiện trạng: mỗi `WordEntry` là một đảo
(`word` + `meaning` chuỗi tự do + tag `languages[]`); "dog (EN)" và "chó (VI)"
không biết nhau là cùng một khái niệm, ảnh phải tìm lặp lại cho từng ngôn ngữ,
và không có đường học "nhìn khái niệm → bật ra từ ở ngôn ngữ đích".

Tham vấn ngôn ngữ học + thiết kế Pha A–E: `docs/plans/PLAN-043-worklist-da-ngu-khai-niem-trung-tam.md` mục 1.
Owner chốt: **chỉ Pha A trước** (nối + xem), nghiệm thu trên máy rồi mới tính tiếp.

## Quyết định

### 1. Kho mới `ConceptNode`, không sửa schema cũ ngoài MỘT trường tuỳ chọn

- `lib/models/concept_node.dart` — `ConceptNode`:
  `id` (UUID v4, bất biến, KHÔNG dẫn xuất từ nội dung — cùng kỷ luật
  `KnowledgeUnit.unitId`), `gloss` (định nghĩa trục ngắn), `domain`
  (miền nghĩa tự do: "động vật"…), `imageRef` (ảnh/animation dùng chung,
  cùng ngữ nghĩa path như `WordEntry.imageUrl`), `relations`
  (danh sách `{type, conceptId}` — Pha A chỉ lưu/đọc, UI quan hệ để Pha E),
  `externalIds` (map tuỳ chọn cho Pha D), `createdAt/updatedAt`.
  JSON đọc chịu thiếu trường (additive như mọi model của dự án).
- Lưu ở Hive box riêng `concept_nodes_v1` (`Box<String>` JSON như
  `vocabulary_v2`), do `VocabularyProvider` quản cùng vòng đời tải từ.
- `WordEntry.conceptId: String?` — `toJson` **chỉ ghi khi khác null/rỗng**
  (đúng lối `imageUrl2` ADR-0013); `fromJson` dữ liệu cũ không có key ⇒
  `null`. Entry `conceptId == null` hành xử **nguyên như hôm nay** ở mọi màn.

### 2. Ba bất biến sư phạm/dữ liệu

1. **SM-2 nằm ở `WordEntry` (từng từ của từng ngôn ngữ), KHÔNG nằm ở khái
   niệm** (quy tắc vàng #2). `ConceptNode` không có điểm số; màn khái niệm
   chỉ *tổng hợp hiển thị* (độ phủ ngôn ngữ, điểm từng cánh đọc từ entry).
2. **Không tự gộp/nối**: máy chỉ sinh *đề xuất* nối (cặp dịch, trùng nghĩa
   chuẩn hoá, trùng ảnh) — người dùng bấm xác nhận mới ghi; cặp đã "Bỏ qua"
   được ghi nhớ (prefs) để không gợi ý lại. Đúng luật "trùng chữ không tự
   merge" của MVA (AT2). Mọi nối đều tháo được (unlink không xoá entry).
3. **Ảnh khái niệm là lớp phủ, không ghi đè ảnh entry**: `imageRef` của
   khái niệm dùng khi entry chưa có ảnh riêng; entry có `imageUrl` thì ảnh
   riêng vẫn thắng. Xoá khái niệm ⇒ tháo nối mọi entry thành viên, KHÔNG
   xoá entry hay file ảnh.

### 3. Đồng bộ (sync)

Pha A: `conceptId` đi theo JSON `WordEntry` nên tự lên Firestore qua
`VocabSyncService` như mọi trường khác; **kho `concept_nodes_v1` chưa sync**
ở Pha A (máy khác nhận entry có `conceptId` lạ thì hiển thị như chưa nối —
không lỗi, không mất dữ liệu từ). Sync khái niệm để quyết định riêng khi
Pha B cần (tránh mở rộng bề mặt conflict khi chưa nghiệm thu Pha A).

## Hệ quả

- Dữ liệu cũ: 0 thay đổi hành vi; app cũ đọc file mới bỏ qua key `conceptId`.
- `KnowledgeGraphScreen` hiện tại (parent/child) giữ nguyên; khái niệm là
  lớp độc lập, hợp nhất hiển thị để Pha E tính.
- Serializer phải rà: `WordEntry.toJson/fromJson` (2 nhánh), nơi copy entry
  (import smart-fill KHÔNG được ghi đè `conceptId` của entry đã có).

## Nghiệm thu Pha A (CONCEPT-001)

1. Mở dữ liệu cũ (không một entry nào có `conceptId`) → mọi màn nguyên trạng.
2. Từ màn Gợi ý nối: nối "dog (EN)" + "chó (VI)" → màn Khái niệm hiện ảnh
   chung + 2 cánh ngôn ngữ, nghe được từng cánh đúng ngôn ngữ.
3. Tháo một cánh khỏi khái niệm → entry còn nguyên (kèm SM-2, ảnh riêng).
4. Xoá khái niệm → mọi thành viên về `conceptId = null`, không mất từ nào.
5. Ôn/học ở một entry không đổi lịch SM-2 của entry cùng khái niệm khác.
