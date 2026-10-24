# Priority-locale chrome leak report

Sinh tự động bởi `python3 tool/lang_ui_inventory.py --write-report`.
Đừng sửa tay — chạy lại tool sau mỗi wave bản dịch.

- Chrome strings quét được: **2577** trong **193** file presentation.
- `vietnamese`: chuỗi vẫn hiện tiếng Việt ở locale đó (vi phạm rule #5).
- `english`: chuỗi vẫn hiện English trên màn hình (kể cả khi fallback sang English) — đây là việc còn lại của các wave bản địa hoá tiếp theo.

| locale | vietnamese | english |
| --- | ---: | ---: |
| `zh` | 0 | 988 |
| `zh_TW` | 0 | 988 |
| `hi` | 0 | 989 |
| `si` | 0 | 989 |
| `my` | 0 | 1529 |
| `th` | 0 | 1479 |
| `ja` | 0 | 1478 |

## `zh` — theo khu vực

| khu vực | còn lại |
| --- | ---: |
| Read | 189 |
| Web Reader | 135 |
| Tools / WordList | 100 |
| Listen | 94 |
| YouTube | 81 |
| Other screens | 69 |
| Shared widgets | 55 |
| Memory | 44 |
| Tipiṭaka | 37 |
| Other features | 29 |
| Understand | 27 |
| Settings | 25 |
| PDF Reader | 23 |
| Grammar / Understand | 22 |
| Translation | 21 |
| AI Chat | 12 |
| Home | 8 |
| Other | 6 |
| Learn by heart | 5 |
| Video library | 3 |
| TTS | 2 |
| OCR | 1 |

## `zh_TW` — theo khu vực

| khu vực | còn lại |
| --- | ---: |
| Read | 189 |
| Web Reader | 135 |
| Tools / WordList | 100 |
| Listen | 94 |
| YouTube | 81 |
| Other screens | 69 |
| Shared widgets | 55 |
| Memory | 44 |
| Tipiṭaka | 37 |
| Other features | 29 |
| Understand | 27 |
| Settings | 25 |
| PDF Reader | 23 |
| Grammar / Understand | 22 |
| Translation | 21 |
| AI Chat | 12 |
| Home | 8 |
| Other | 6 |
| Learn by heart | 5 |
| Video library | 3 |
| TTS | 2 |
| OCR | 1 |

## `hi` — theo khu vực

| khu vực | còn lại |
| --- | ---: |
| Read | 189 |
| Web Reader | 135 |
| Tools / WordList | 100 |
| Listen | 94 |
| YouTube | 81 |
| Other screens | 69 |
| Shared widgets | 55 |
| Memory | 44 |
| Tipiṭaka | 37 |
| Other features | 30 |
| Understand | 27 |
| Settings | 25 |
| PDF Reader | 23 |
| Grammar / Understand | 22 |
| Translation | 21 |
| AI Chat | 12 |
| Home | 8 |
| Other | 6 |
| Learn by heart | 5 |
| Video library | 3 |
| TTS | 2 |
| OCR | 1 |

## `si` — theo khu vực

| khu vực | còn lại |
| --- | ---: |
| Read | 189 |
| Web Reader | 135 |
| Tools / WordList | 100 |
| Listen | 94 |
| YouTube | 81 |
| Other screens | 69 |
| Shared widgets | 55 |
| Memory | 44 |
| Tipiṭaka | 37 |
| Other features | 30 |
| Understand | 27 |
| Settings | 25 |
| PDF Reader | 23 |
| Grammar / Understand | 22 |
| Translation | 21 |
| AI Chat | 12 |
| Home | 8 |
| Other | 6 |
| Learn by heart | 5 |
| Video library | 3 |
| TTS | 2 |
| OCR | 1 |

## `my` — theo khu vực

| khu vực | còn lại |
| --- | ---: |
| Read | 248 |
| Web Reader | 167 |
| Tools / WordList | 115 |
| Listen | 114 |
| Other features | 112 |
| PDF Reader | 110 |
| YouTube | 106 |
| Other screens | 85 |
| Shared widgets | 65 |
| Memory | 57 |
| Tipiṭaka | 49 |
| Settings | 37 |
| Grammar / Understand | 34 |
| Translation | 33 |
| Cabin | 33 |
| Learn by heart | 32 |
| Understand | 28 |
| Other | 25 |
| Home | 21 |
| TTS | 18 |
| Dictionary | 18 |
| AI Chat | 14 |
| Video library | 5 |
| OCR | 3 |

## `th` — theo khu vực

| khu vực | còn lại |
| --- | ---: |
| Read | 244 |
| Web Reader | 157 |
| Listen | 113 |
| Tools / WordList | 110 |
| Other features | 108 |
| PDF Reader | 104 |
| YouTube | 100 |
| Other screens | 83 |
| Shared widgets | 64 |
| Memory | 53 |
| Tipiṭaka | 48 |
| Settings | 37 |
| Grammar / Understand | 33 |
| Cabin | 33 |
| Translation | 31 |
| Learn by heart | 30 |
| Understand | 28 |
| Other | 25 |
| Home | 21 |
| TTS | 18 |
| Dictionary | 18 |
| AI Chat | 13 |
| Video library | 5 |
| OCR | 3 |

## `ja` — theo khu vực

| khu vực | còn lại |
| --- | ---: |
| Read | 244 |
| Web Reader | 157 |
| Listen | 113 |
| Tools / WordList | 110 |
| Other features | 108 |
| PDF Reader | 104 |
| YouTube | 100 |
| Other screens | 82 |
| Shared widgets | 64 |
| Memory | 53 |
| Tipiṭaka | 48 |
| Settings | 37 |
| Grammar / Understand | 33 |
| Cabin | 33 |
| Translation | 31 |
| Learn by heart | 30 |
| Understand | 28 |
| Other | 25 |
| Home | 21 |
| TTS | 18 |
| Dictionary | 18 |
| AI Chat | 13 |
| Video library | 5 |
| OCR | 3 |

## Chi tiết (ưu tiên chuỗi còn tiếng Việt)

