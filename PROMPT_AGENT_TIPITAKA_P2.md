# Prompt giao việc — I4U Tipiṭaka hiển thị Phase 2 (TPI-DISPLAY-03)

> Nguồn: owner 2026-10-05. Tiếp nối lane TPI-DISPLAY-01/02 (đã done, xem
> `docs/project/KANBAN.md`). Nền phân tích + kế hoạch dài hạn:
> `docs/tipitaka_display_optimization_plan.md` (tham chiếu
> `opentipitaka.org/texts/vin01m_mul?ui=vi&lang=vi`).
>
> Mục tiêu Phase 2: (0) đưa Phase 1 qua oracle runtime, rồi (1) ấn bản song
> hành, (2) highlight/ghi chú đoạn, (3) footnote apparatus, (4) share+citation,
> (5) bundle Noto Serif, (6) rà VRI attribution.

---

## 0. Luật chung (đọc trước khi code)

1. **Đọc trước:** `AGENTS.md` (5 quy tắc vàng), `docs/GOVERNANCE.md`, card
   `TPI-DISPLAY-01/02/03` trong `docs/project/KANBAN.md`,
   `docs/tipitaka_display_optimization_plan.md`, `docs/tipitaka_database.md`,
   và skill `docs/skills/i18n-localization/SKILL.md` khi đụng UI.
2. **Branch:** trong Arena Agent Mode chỉ làm trên branch session được cấp.
   Làm ngoài phiên thì tạo topic branch từ tip mới nhất của
   `arena/01a0251e-in4up` (fetch đúng refspec — GOVERNANCE mục 2a).
3. **Rule #5 i18n (vàng):** mọi nhãn chrome mới = `context.uiText('…')` VÀ phải
   có key + English trong một catalog (`priority_ui_overrides.dart` là nơi
   repo đang dùng cho Tipiṭaka; KHÔNG chạy `tool/generate_arbs.py`). Máy bắt:
   `test/tipitaka_dictionary_i18n_coverage_test.dart` quét ngược
   `lib/features/tipitaka/**` — chạy test này trước khi bàn giao.
4. **Không để đỏ:** sandbox Arena không có Flutter SDK ⇒ push sớm, dùng CI
   GitHub Actions làm oracle (`.github/workflows/app_analyze.yml`): analyze
   0 error + `flutter test` full. CI đỏ thì đọc
   `docs/skills/ci-red-debugging/SKILL.md`.
5. **Commit ít nhưng đủ ý:** mỗi hạng mục 1 commit logic; docs/KANBAN 1 commit.
   Luôn `git fetch` + rebase trên `origin/arena/01a0251e-in4up` trước khi PR.
6. **Không đụng** vùng bảo vệ (AGENTS.md #1–#3): UltraTimeStretch FFI,
   3-skill SM-2, khả năng reopen đúng vị trí nguồn mọi loại (PDF/Audio/Web/
   Tipiṭaka) — điểm #3 đặc biệt liên quan: **đừng phá hợp đồng
   `TipitakaSourceAnchor`** khi làm highlight/share.

## 1. Hiện trạng code (đã có — đọc nhanh bản đồ này thay vì dò mù)

```
lib/features/tipitaka/
├── models/
│   ├── book.dart               # TipitakaBook + TipitakaBookIndex (edition MUL/ATT/TIK)
│   ├── segment.dart            # TipitakaSegment (pali + vi/en/my/th + translations map)
│   ├── collection.dart         # 3 Tạng
│   └── reader_appearance.dart  # ★ settings đọc lưu bền (mode/lang/theme/fontScale)
├── services/
│   ├── tipitaka_markup.dart    # ★ parser CSCD dùng chung (clean/block kind/pb/paranum)
│   ├── reading_position_store.dart  # ★ vị trí đọc px theo book_id ("Đọc tiếp")
│   ├── db_service.dart         # schema + import + queries (getBookById ★ mới)
│   └── …worklist/task/language_pack/source_resolver…
├── screens/
│   ├── library_screen.dart     # cây Tam Tạng + thẻ "Đọc tiếp"
│   ├── workspace_screen.dart   # Obsidian-style đa tab + split view (GIỮ NGUYÊN API)
│   ├── reader_screen.dart      # ★ trang sách 1 cột, SliverAppBar, tải 2 chiều
│   ├── search_screen.dart      # ★ deep-link vào đúng đoạn
│   └── download_screen.dart / language_pack_screen.dart / task_overlay.dart
└── widgets/tipitaka_source_link.dart
```

Test liên quan: `test/tipitaka_workspace_retention_test.dart` (workspace giữ
state qua split — **đừng đổi API `TipitakaWorkspaceScreen`**,
`readerBuilder` là điểm thay reader trong test),
`test/tipitaka_independent_language_import_test.dart`,
`test/tipitaka_dictionary_i18n_coverage_test.dart`.
Demo DB QA: `assets/db/tipitaka.sqlite` (Mahāvaṃsa ~10k đoạn, có hangnum/
gatha/`<pb>` — đủ để kiểm hiển thị mà không cần import lớn).

## 2. VIỆC SỐ 0 (bắt buộc đầu tiên): chạy oracle cho Phase 1

Phase 1 (3 commit c7b7237→a445f12 sau rebase + 0f7fe18) chưa từng qua
`flutter analyze`/`flutter test` thật (sandbox thiếu SDK). Trên máy dev hoặc CI:

```
flutter pub get
flutter analyze
flutter test
flutter test test/tipitaka_dictionary_i18n_coverage_test.dart \
            test/tipitaka_workspace_retention_test.dart
```

Nghiệm thu tay trên thiết bị: đổi mode/ngôn ngữ/nền Sepia-tối/cỡ chữ → restart
app (settings phải giữ); mở sách → cuộn sâu → back → mở lại (về đúng chỗ);
split view pane hẹp (không overflow); TTS đoạn/bài; EN locale không chrome VN.
Lỗi phát sinh → fix trong 1 commit riêng, cập nhật KANBAN TPI-DISPLAY-01/02.

## 3. Các hạng mục Phase 2 (theo ưu tiên)

### P4b — Ấn bản song hành Mūla ↔ Aṭṭhakathā/Ṭīkā ở split view
- Workspace đã hỗ trợ split 2 pane sống song song. Việc: nút "Mở bản đối
  chiếu" trong reader/appbar: từ `TipitakaBookIndex` của book hiện tại suy ra
  code đối ứng (`VIN01M_MUL` → `VIN01A_ATT`…), `getBooksByCollection` tìm book
  có code khớp, mở thành tab và bật split.
- AT: mở Pārājika Mūla → bấm → pane phải hiện Aṭṭhakathā cùng vùng; không có
  ấn bản đối ứng → snackbar rõ ràng (i18n đủ key).

### P4c — Highlight / ghi chú đoạn (bookmark nội dung)
- Bảng mới (không đụng schema hiện có — thêm bảng phụ `tipitaka_highlights` vào
  `_createSchema` + `_ensureSchema` kiểu `_ensureColumn`, có migration-safe):
  id, book_id, segment_id, color, note, updated_at. UI: long-press đoạn →
  chọn màu/ghi chú; danh sách highlight trong Library tab phụ.
- AT: tạo/sửa/xóa highlight; đổi DB → highlight lạc book bị ẩn an toàn.

### P5a — Footnote / apparatus `\[(...)\]` thành chú thích chạm-mở
- Data đã có sẵn trong pali_text (vd `\[(syā.) (sī.)…\]`). Parse bằng
  `tipitaka_markup.dart` (mở rộng, KHÔNG tạo parser mới): văn bản chính sạch
  hơn, chú thích dưới đoạn dạng chip mở rộng; giữ tùy chọn hiển thị inline.
- AT: demo DB đoạn có apparatus → hiển thị gọn; toggle inline/off trong
  settings (thêm field vào `TipitakaReaderAppearance` — nhớ migrate đọc cũ
  an toàn bằng `?? default`).

### P5b — Chia sẻ đoạn + citation chuẩn
- `share_plus` đã có: action share ở meta bar (đã có cơ chế overflow menu) →
  text "Pāli\n<dịch>\n— <citation> (In4Up Tipiṭaka)"; citation = reference
  segment, fallback 'Đoạn N'. Copy kèm citation vào selection sheet hiện có.
- AT: citation đúng dạng học thuật khi reference có sẵn (vd DN 1.1).

### P5c — Bundle Noto Serif thật
- Tải TTF (Regular/Italic/Bold) → `assets/fonts/noto_serif/`, khai báo trong
  `pubspec.yaml` `flutter/fonts`, dùng `fontFamily: 'NotoSerifTipitaka'` trước
  fallback stack hiện có trong `tipitaka_markup.dart`. Kiểm full dấu Pāli (ṃ ṇ
  ḍ ṭ ḷ) + tiếng Việt trên 3 nền tảng; lưu ý giấy phép OFL kèm file license.

### P6 — Đồng bộ cuộn 2 pane split (Pāli ↔ dịch/bản đối ứng)
- ScrollController đôi + map order_index song song; toggle bật/tắt. Chỉ làm
  sau P4b; phức tạp vì 2 pane có thể khác book — chỉ sync khi cùng book/code
  khác ấn bản.

### Việc thường trực — Rà VRI attribution (license)
- Dữ liệu Pāli gốc VRI/CSCD là CC-BY-NC ("non-commercial", phải ghi nguồn).
  Kiểm màn Quản lý dữ liệu (`download_screen.dart`) + docs phát hành đã có
  dòng attribution "Vipassana Research Institute" chưa; thiếu thì thêm
  (i18n đủ key) + nhắc lại trong `docs/Bangiao/bangiao_tipitaka.md`.

## 4. Định nghĩa "xong" của Phase 2

- Kard TPI-DISPLAY-03 chuyển doing→done trên KANBAN kèm bằng chứng CI run xanh
  (analyze 0 error + flutter test) + checklist nghiệm thu thiết bị từng AT.
- Mỗi hạng mục: 1 commit logic; PR mở về `arena/01a0251e-in4up` sau khi rebase
  tip mới nhất; body PR liệt kê AT đã kiểm.
