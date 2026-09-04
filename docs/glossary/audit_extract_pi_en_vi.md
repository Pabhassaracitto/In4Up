# Audit — trích xuất PDF meditation vocabulary (v2, x-column clustering)

- Tổng dòng: 819 — {'heading': 11, 'term': 780, 'other': 22, 'prose': 6}
- Glossary entries sinh ra: 1070 (pi→vi: 712, en→vi: 489; bỏ: 118 câu/dài, dup: 131)
- Row term thiếu PI: 20
- Row term thiếu VI: 42
- Row term thiếu EN: 55
- Row term thiếu MY: 197

## Vấn đề đã biết của PDF (không phải lỗi parser)

1. **Cột Burmese sai codepoint** (font NotoSansMyanmar trong PDF map glyph sai:
   'Đ'→U+1012, 'N'→U+1014, ...) — MY chỉ dùng tham khảo, không vào glossary.
2. **Một số ô PI/MY mất text** (font hỏng, chỉ còn 1-2 từ cuối: 'Visuddhi',
   '8', '25'...) — dòng tương ứng ⚠ trong master, chủ bổ sung tay.
3. **Ô Pali bị truncate** trong bản gốc: 'Ānāpānassat' (thiếu i), 'Sat'
   (thiếu isambojjhaṅga), 'Pīt' (thiếu i), 'Sammāsat' (thiếu i), 'Jāt',
   'Gilāna' — giữ nguyên theo PDF + đánh dấu ⚠.

## Danh sách dòng cần review (⚠)

| # | trang | PI | VI | EN | lý do |
|---|---|---|---|---|---|
| 10 | 3 | — | Hơi thở vi tế | Subtle breath | orphan (không có PI anchor); thiếu PI (bổ sung tay) |
| 14 | 4 | — | Bốn chi pháp để an tịnh  | The four factors make the brea | orphan (không có PI anchor); thiếu PI (bổ sung tay) |
| 19 | 4 | — | Định tướng xuất hiện | Appearance of the signs | orphan (không có PI anchor); thiếu PI (bổ sung tay) |
| 102 | 19 | — | Ba cửa vào niết bàn | The three entrances to nibbāna | orphan (không có PI anchor); thiếu PI (bổ sung tay) |
| 135 | 25 | — | Nên hành thiền tâm từ đế | Loving kindness should be deve | orphan (không có PI anchor); thiếu PI (bổ sung tay) |
| 150 | 28 | — | Rải tâm từ đến người đán | Extending loving kindness towa | orphan (không có PI anchor); thiếu PI (bổ sung tay) |
| 157 | 29 | — | Hai mươi hai nhóm để rải | The twenty-two categories of p | orphan (không có PI anchor); thiếu PI (bổ sung tay); thiếu MY+ZH (row loãng) |
| 255 | 46 | — | 54 loại sắc ở mắt | The 54 types of materiality in | orphan (không có PI anchor); thiếu PI (bổ sung tay) |
| 266 | 48 | — | Tất cả 8 yếu tố đều giốn | All the eight factors are same | orphan (không có PI anchor); thiếu PI (bổ sung tay) |
| 267 | 48 | — | 42 thân phần 32 thân phầ | The 42 parts of the body The f | orphan (không có PI anchor); thiếu PI (bổ sung tay) |
| 375 | 68 | — | Hai loại tâm | Two types of consciousness | orphan (không có PI anchor); thiếu PI (bổ sung tay) |
| 378 | 68 | — | Lộ trình ý môn của sơ th | A Mind-door thought process of | orphan (không có PI anchor); thiếu PI (bổ sung tay) |
| 385 | 69 | — | Sơ thiền gồm 34 tâm sở | The first jhāna consists of 34 | orphan (không có PI anchor); thiếu PI (bổ sung tay) |
| 390 | 70 | aññasamānacetasika no. 3-13 | tợ tha từ 3-13 | — | thiếu MY+ZH (row loãng) |
| 392 | 70 | sobhanacetasika no. 28-46 | hảo số 28-46 | — | thiếu MY+ZH (row loãng) |
| 440 | 78 | — | Đối tượng xuất hiện ở tâ | — | orphan (không có PI anchor); thiếu PI (bổ sung tay) |
| 463 | 83 | — | 11 loại thọ và tưởng | The eleven types of feeling an | orphan (không có PI anchor); thiếu PI (bổ sung tay) |
| 528 | 93 | — | Bốn cách để phân biệt sự | — | orphan (không có PI anchor); thiếu PI (bổ sung tay) |
| 533 | 94 | — | Bảy giai đoạn thanh tịnh | The Seven Stages Of Purificati | orphan (không có PI anchor); thiếu PI (bổ sung tay) |
| 542 | 96 | — | Mười sáu tầng tuệ minh s | The Sixteen Insight-knowledges | orphan (không có PI anchor); thiếu PI (bổ sung tay) |
| 560 | 99 | -to | 10 To trong nhóm vô thườ | The Forty Perceptions There Ar | orphan (không có PI anchor) |
| 571 | 100 | — | 25 To trong nhóm khổ | -to There Are Twenty-five "-to | orphan (không có PI anchor); thiếu PI (bổ sung tay) |
| 597 | 105 | — | Có 5 “To” trong nhóm vô  | -to There Are Five “-to” In Th | orphan (không có PI anchor); thiếu PI (bổ sung tay) |
| 618 | 108 | Bhikkhu Bodhi | — | — | thiếu MY+ZH (row loãng) |
| 638 | 111 | Uddhacca | — | — | thiếu MY+ZH (row loãng) |
| 670 | 112 | Dutiyaṃ Jhānaṃ | Nhị thiền | — | thiếu MY+ZH (row loãng) |
| 672 | 112 | Tatiyaṃ Jhānaṃ | Tam thiền | — | thiếu MY+ZH (row loãng) |
| 678 | 113 | Āpo | Nước | Water | thiếu MY+ZH (row loãng) |
| 679 | 113 | Tejo | Lửa | Fire | thiếu MY+ZH (row loãng) |
| 680 | 113 | Vāyo | Gió | Wind | thiếu MY+ZH (row loãng) |
| 697 | 114 | Vikkhepapaṭibāhanato | Chú tâm | — | thiếu MY+ZH (row loãng) |
| 715 | 115 | Sota | Nhĩ | Ear | thiếu MY+ZH (row loãng) |
| 716 | 115 | Ghāna | Tỹ | Nose | thiếu MY+ZH (row loãng) |
| 717 | 115 | Jivhā | Thiệt | Tongue | thiếu MY+ZH (row loãng) |
| 720 | 115 | Gandho | Mùi | Odour | thiếu MY+ZH (row loãng) |
| 763 | 118 | Jāt | — | Birth Sinh | thiếu MY+ZH (row loãng) |
| 764 | 118 | Jarā | Lão | Ageing | thiếu MY+ZH (row loãng) |
| 771 | 118 | Sañña-Vipallasa | — | — | thiếu MY+ZH (row loãng) |
| 786 | 119 | Generate And Grow] | Hai cõi Cõi phàm | — | thiếu MY+ZH (row loãng) |
| 801 | 121 | Pahāna Pariññā | — | — | thiếu MY+ZH (row loãng) |

## Dòng term KHÔNG có PI (bổ sung tay hoặc kiểm tra lại)

| trang | VI | EN | ZH |
|---|---|---|---|
| 3 | Hơi thở vi tế | Subtle breath | 微細息 |
| 4 | Bốn chi pháp để an tịnh hơi thở | The four factors make the breath calm | 四種能使呼吸平息的因 |
| 4 | Định tướng xuất hiện | Appearance of the signs | 禪相的現象 |
| 19 | Ba cửa vào niết bàn | The three entrances to nibbāna | 涅槃的三⾨ |
| 25 | Nên hành thiền tâm từ đến bốn loại người | Loving kindness should be developed towa | 應當對四類⼈修慈⼼ |
| 28 | Rải tâm từ đến người đáng kính yêu | Extending loving kindness towards a pers | 對敬愛的⼈散發慈愛 |
| 29 | Hai mươi hai nhóm để rải tâm từ | The twenty-two categories of pervasion | — |
| 46 | 54 loại sắc ở mắt | The 54 types of materiality in the eye | 眼睛裡的 種⾊法 |
| 48 | Tất cả 8 yếu tố đều giống như tổng hợp n | All the eight factors are same as cakkhu | 與眼⼗法聚的前⼋項相同 |
| 48 | 42 thân phần 32 thân phần đầu giống như  | The 42 parts of the body The first 32 pa | 四⼗⼆身分 |
| 68 | Hai loại tâm | Two types of consciousness | 兩種⼼ |
| 68 | Lộ trình ý môn của sơ thiền | A Mind-door thought process of the first | 初禪的意⾨⼼路過程 |
| 69 | Sơ thiền gồm 34 tâm sở | The first jhāna consists of 34 mentality | 初禪的三⼗四個名法 |
| 78 | Đối tượng xuất hiện ở tâm cận tử | — | 臨死速⾏⼼的所緣 |
| 83 | 11 loại thọ và tưởng | The eleven types of feeling and percepti | ⼗⼀種受及想 |
| 93 | Bốn cách để phân biệt sự thực chân đế | — | 四個⽅法闡明究竟法的本質 |
| 94 | Bảy giai đoạn thanh tịnh | The Seven Stages Of Purification | 七清淨 |
| 96 | Mười sáu tầng tuệ minh sát | The Sixteen Insight-knowledges | ⼗六觀智 |
| 100 | 25 To trong nhóm khổ | -to There Are Twenty-five "-to" In The S | 苦組有廿五個「 |
| 105 | Có 5 “To” trong nhóm vô ngã | -to There Are Five “-to” In The Non-self | 無我組有五個「 |
