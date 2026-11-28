# Nên xem/quản lý KANBAN ở đâu? (GitHub · Notion · Drive · Vercel)

- **Ngày:** 2026-11-27 · trả lời câu hỏi owner: *“KANBAN đang ở GitHub thì nên
  xem ở GitHub luôn, hay cho nó liên kết quản lý ở Notion, hay Drive? Có nên
  dùng Vercel không?”*

## 1. Số đo hiện trạng (không suy đoán)

| Thứ | Số đo |
|---|---|
| `docs/project/KANBAN.md` | **10.300 dòng · 1.052 KB (1,1 MB)** |
| Card chi tiết (`###`) | **294** |
| ID có card | 260 |
| ID trong bảng tổng quan | 250 |
| **Card KHÔNG có trong bảng tổng quan** | **44** (vd `AI-PROV-BUILTIN-001`, `AUDIT-0103`, `DICT-MDD-001`) |
| File trong repo link tới `KANBAN.md` | **66** |
| Luật ghi | `GOVERNANCE.md` §3 — status-only, append-only |
| Notion connector | **đang tắt** (`disconnected`) |
| Drive | đã bật; tìm `In4Up` trong Drive = **0 file** |
| Linear | 2 team (`PSRC`, `UIUX`), 2 project (`I4U`, `VDP`), **1 document** |
| Site web | `gh-pages` → https://pabhassaracitto.github.io/In4Up/ |

**Vấn đề thật nằm ở chỗ khác, không phải ở công cụ:** 44 card chi tiết không
xuất hiện trong bảng tổng quan ⇒ ngay trên GitHub, mở file ra cũng **không thấy
đủ việc**. Đổi công cụ không sửa được điều này; sửa bảng tổng quan thì được.

## 2. Từng lựa chọn

### GitHub (khuyến nghị: **xem ở đây, là nguồn sự thật duy nhất**)
- **Được:** cùng chỗ với code/PR/release; 66 file đã link tới; PR template buộc
  khai Card; `blame`/`diff` miễn phí; không quota; agent ghi được.
- **Không được:** 1,1 MB Markdown — `Ctrl+F` được nhưng khó "nhìn" như board;
  GitHub Projects cần **kéo-thả tay**, không tự đồng bộ file.
- **Sửa điểm yếu (nên làm):** thêm **mục lục theo trạng thái** ở đầu file
  (doing / proposed / chờ nghiệm thu máy) để mở là thấy việc đang chạy, và bổ
  sung 44 card còn thiếu vào bảng tổng quan bằng script (một lần, sinh ra từ
  chính các card ⇒ không lệch tay).

### Notion (**chỉ để đọc/báo cáo, không làm nguồn sự thật**)
- **Được:** hiển thị đẹp, chia sẻ cho người ngoài repo, có board/kanban view.
- **Không được:** connector đang **tắt**; Notion API cần `parent` page và có
  giới hạn block/gói miễn phí; **hai chiều = lệch dữ liệu**; agent ghi Notion
  qua connector được nhưng kết quả không nằm cạnh code.
- **Cách đúng nếu muốn Notion:** coi Notion là **bản xuất một chiều**. Một script
  (`tool/kanban_export_notion.py`) đọc KANBAN.md → sinh Markdown/CSV → owner dán
  hoặc upload. Không sửa trên Notion.

### Drive (**không nên**)
- **Được:** lưu trữ/backup, chia sẻ file.
- **Không được:** không có cấu trúc dữ liệu, không diff/lịch sử theo dòng, không
  link tới PR, sửa đồng thời dễ hỏng; và Drive hiện **chưa có file In4Up nào**.
- **Cách đúng nếu muốn Drive:** chỉ dùng làm **bản lưu PDF/CSV** của KANBAN theo
  mốc release (một chiều, giống Notion).

### Vercel (**không nên — không giải quyết việc gì ở đây**)
- Vercel là nơi **host web**, không phải nơi quản lý issue.
- Repo này **đã có** chỗ host web miễn phí: `gh-pages` → Pages của GitHub, tự
  deploy khi `main` đổi. Thêm Vercel = thêm một pipeline thứ hai cho cùng một
  `build/web`, phải khai lại `base-href`, cấu hình lại cách publish.
- **Ngoại lệ duy nhất đáng cân nhắc:** nếu muốn **mỗi push có một preview URL**
  (giống preview tôi dựng bằng nhánh `preview/*`). Nhưng hiện tại nhánh
  `preview/arena-395208ef-in4up` + Pages đã phủ nhu cầu đó, không tốn tài khoản.
- Nếu vẫn muốn thử: chỉ nên dùng cho **site web**, tuyệt đối không đưa KANBAN
  lên đó.

## 3. Kiến trúc đề xuất (một nguồn sự thật + nhiều cửa đọc)

```
       (nguồn sự thật DUY NHẤT, agent ghi được)
        GitHub: docs/project/KANBAN.md
                     │
     ┌───────────────┼────────────────┬──────────────────┐
     │               │                │                  │
  GitHub UI      script export     script export     GitHub Issues
  đọc trực tiếp   → Notion (1 chiều) → Drive PDF/CSV   (yêu cầu thô vào,
                                                        card KANBAN là sổ cái)
```

Nguyên tắc: **chỉ MỘT chỗ ghi** (KANBAN.md). Mọi nơi khác là bản xuất hoặc cửa
vào. Vi phạm nguyên tắc này (ghi ở 2 nơi) là nguồn gốc của mọi lệch trạng thái —
và hiện repo đã có 2 nơi (KANBAN + Linear) nên **không nên thêm nơi thứ ba ghi được**.

## 4. Việc cụ thể nên làm ngay (nhỏ, có lợi ngay)

1. **Sinh mục lục trạng thái** ở đầu KANBAN.md (doing / proposed / chờ máy) — mở
   file là thấy việc đang chạy, không phải `Ctrl+F`.
2. **Bổ sung 44 card thiếu** vào bảng tổng quan bằng script đọc từ card (một lần).
3. **`tool/kanban_index.py --check`** trong CI: báo khi có card mới chưa vào bảng
   tổng quan ⇒ 44 lỗi trên không quay lại.
4. *(tuỳ chọn)* `tool/kanban_export.py --format md|csv` để dán sang Notion hoặc
   lưu PDF vào Drive theo mốc release.

Ba việc đầu đều **không đụng** Linear/GitHub Issues, không đổi `pubspec`, và
không tạo thêm nguồn sự thật nào.
