# Attribution — assets/iconize (ICONIZE-001, ADR-0013)

Nội dung thư mục này do `tool/iconize/build_icon_assets.py` sinh ra.
KHÔNG sửa tay — chạy lại tool để tái sinh (output tất định).

## icons_bundle.bin

SVG từ **Twemoji** (https://github.com/jdecked/twemoji)
— Copyright 2020 Twitter, Inc and other contributors; duy trì bởi Jdecked
và cộng đồng. Đồ họa phát hành theo **CC-BY 4.0**
(https://creativecommons.org/licenses/by/4.0/).
Dòng attribution này PHẢI xuất hiện trong màn About của app khi tính năng
Iconize phát hành (tiêu chí nghiệm thu Khối E, blueprint mục 7.2).

## concreteness.bin (kèm xếp hạng tần suất SUBTLEX)

Dẫn xuất từ: Brysbaert, M., Warriner, A.B., & Kuperman, V. (2014).
*Concreteness ratings for 40 thousand generally known English word lemmas.*
Behavior Research Methods, 46, 904–911. Dữ liệu công bố miễn phí cho
nghiên cứu/sử dụng; citation bắt buộc giữ nguyên.

## icon_index.bin

Map lemma→emoji dẫn xuất lúc build từ **Unicode CLDR** annotations
(https://github.com/unicode-org/cldr-json) — Unicode License v3
(https://www.unicode.org/license.txt). Dữ liệu CLDR chỉ dùng lúc build,
không bundle trong app.

## irregular_lemmas.json

Bảng curated của dự án In4Up (nguồn: `tool/iconize/data/irregular_lemmas.json`),
cùng giấy phép với repo.
