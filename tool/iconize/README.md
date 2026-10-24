# tool/iconize — Build tool asset cho ICONIZE-001 (lane 001a)

Sinh core bundle `assets/iconize/` cho Iconize Engine (ADR-0013, blueprint
`docs/iconize_visual_context_blueprint.md`). Loader Dart (lane ICONIZE-001b)
**phải đọc đúng đặc tả dưới đây** — file này là hợp đồng format.

## Chạy

```bash
# 1. Tải nguồn (KHÔNG commit vào repo — để ngoài, ví dụ /tmp/iconize_src):
#    - Brysbaert: github.com/ArtsEngine/concreteness
#        → Concreteness_ratings_Brysbaert_et_al_BRM.txt
#    - CLDR en annotations: github.com/unicode-org/cldr-json
#        → cldr-json/cldr-annotations-full/annotations/en/annotations.json
#    - Twemoji SVG: git clone --depth 1 --filter=blob:none --sparse \
#        https://github.com/jdecked/twemoji && git sparse-checkout set assets/svg
# 2. Build (từ gốc repo):
python3 tool/iconize/build_icon_assets.py \
  --brysbaert /tmp/iconize_src/brysbaert_concreteness.txt \
  --cldr      /tmp/iconize_src/cldr_annotations_en.json \
  --twemoji   /tmp/iconize_src/twemoji/assets/svg \
  --out       assets/iconize --max-icons 2000
```

Tool tự `verify()` sau khi ghi (đọc lại, binary-search "cat", kiểm SVG payload).
Chạy lại cho output **tất định** (sort ổn định mọi bước) — diff git sạch.

## Luật chọn từ (khớp ADR-0013 + blueprint mục 10)

- Danh từ `Dom_Pos=Noun` với `Conc.M ≥ 4.0`; tính từ `Adjective` với `≥ 4.5`.
- Động từ KHÔNG vào index v1 (chốt #1 — default giữ chữ).
- Xếp hạng: điểm match (tts exact 100 > "X face" 90 > keyword 60) →
  SUBTLEX giảm dần → alphabet. Cắt tại `--max-icons`.
- Tần suất dùng cột **SUBTLEX ngay trong file Brysbaert** (CC0) — thay cho
  COCA ở câu hỏi mở #5 (COCA không tải tự do; SUBTLEX-US chính là nguồn
  blueprint chỉ định để xếp hạng, nay khỏi cần file thứ hai).
- Loại emoji da (skin-tone) + cờ quốc gia (regional indicator) từ gốc.

## Đặc tả format (little-endian, mọi file .bin)

### Header chung (16 byte)

| offset | size | nội dung |
|---|---|---|
| 0 | 8 | magic ASCII `ICNB0001` |
| 8 | 4 | u32 version = 1 |
| 12 | 4 | u32 count |

### concreteness.bin — word → (concreteness, POS)

Chỉ chứa từ đơn `Conc.M ≥ 3.5` (engine chỉ cần quyết định quanh ngưỡng
4.0/4.5 — từ dưới 3.5 chắc chắn giữ chữ, khỏi tra).

```
header(16) · u32 offsets[count] (relative vào blob) · blob
record: u16 wordLen · word utf8 · u8 conc10 (Conc.M × 10) · u8 pos
pos: 0=NOUN 1=VERB 2=ADJ 3=OTHER
Sắp xếp theo word (byte order) → binary search qua offsets.
```

### icon_index.bin — "lemma|POS" → iconId

```
header(16) · u32 offsets[count] · blob
record: u16 keyLen · key utf8 ("cat|NOUN", "red|ADJ") · u16 iconId
Sắp xếp theo key (byte order). iconId = chỉ số TOC trong icons_bundle.bin.
```

### icons_bundle.bin — SVG Twemoji đóng gói

```
header(16)
TOC: count × 14 byte: u32 dataOff · u32 dataLen · u32 nameOff · u16 nameLen
name blob (ASCII, tên = codepoint Twemoji, vd "1f431")
data blob (SVG bytes thô)
dataOff/nameOff relative vào blob tương ứng; data blob bắt đầu ngay sau
name blob (= 16 + 14×count + tổng nameLen).
```

### irregular_lemmas.json

Map `dạng biến đổi → lemma` (JSON phẳng), nguồn curated tại
`tool/iconize/data/irregular_lemmas.json`. Lemmatizer lane 001b: tra bảng này
TRƯỚC, rồi mới áp luật đuôi (-s/-es/-ies/-ed/-ing).

## Giấy phép nguồn (attribution trong assets/iconize/ATTRIBUTION.md)

| Nguồn | Giấy phép | Vai trò |
|---|---|---|
| Twemoji (jdecked/twemoji) | CC-BY 4.0 | SVG icon |
| Unicode CLDR annotations | Unicode License v3 | map emoji→keyword lúc build (không bundle) |
| Brysbaert et al. 2014 concreteness (kèm SUBTLEX) | miễn phí nghiên cứu/sử dụng, citation bắt buộc | lọc + xếp hạng |

Lưu ý dung lượng: blueprint ước tính core ~2.1 MB; số thật in ra khi build —
ghi nhận chênh lệch (nếu có) vào lịch sử card KANBAN, không sửa ước tính cũ.
