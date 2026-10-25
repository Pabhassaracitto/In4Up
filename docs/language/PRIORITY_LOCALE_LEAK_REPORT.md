# Priority-locale chrome leak report

Sinh tự động bởi `python3 tool/lang_ui_inventory.py --write-report`.
Đừng sửa tay — chạy lại tool sau mỗi wave bản dịch.

- Chrome strings quét được: **2675** trong **197** file presentation.
- `vietnamese`: chuỗi vẫn hiện tiếng Việt ở locale đó (vi phạm rule #5).
- `english`: chuỗi vẫn hiện English trên màn hình (kể cả khi fallback sang English) — đây là việc còn lại của các wave bản địa hoá tiếp theo.

| locale | vietnamese | english |
| --- | ---: | ---: |
| `zh` | 0 | 442 |
| `zh_TW` | 0 | 442 |
| `hi` | 0 | 446 |
| `si` | 0 | 447 |
| `my` | 0 | 987 |
| `th` | 0 | 935 |
| `ja` | 0 | 934 |

## `zh` — theo khu vực

| khu vực | còn lại |
| --- | ---: |
| Tools / WordList | 99 |
| Other screens | 69 |
| Shared widgets | 55 |
| Memory | 44 |
| Tipiṭaka | 37 |
| Other features | 30 |
| PDF Reader | 27 |
| Understand | 27 |
| Grammar / Understand | 22 |
| Translation | 20 |
| AI Chat | 12 |

## `zh_TW` — theo khu vực

| khu vực | còn lại |
| --- | ---: |
| Tools / WordList | 99 |
| Other screens | 69 |
| Shared widgets | 55 |
| Memory | 44 |
| Tipiṭaka | 37 |
| Other features | 30 |
| PDF Reader | 27 |
| Understand | 27 |
| Grammar / Understand | 22 |
| Translation | 20 |
| AI Chat | 12 |

## `hi` — theo khu vực

| khu vực | còn lại |
| --- | ---: |
| Tools / WordList | 99 |
| Other screens | 69 |
| Shared widgets | 55 |
| Memory | 44 |
| Tipiṭaka | 37 |
| Other features | 31 |
| PDF Reader | 27 |
| Understand | 27 |
| Grammar / Understand | 22 |
| Translation | 20 |
| AI Chat | 12 |
| Listen | 2 |
| Web Reader | 1 |

## `si` — theo khu vực

| khu vực | còn lại |
| --- | ---: |
| Tools / WordList | 99 |
| Other screens | 69 |
| Shared widgets | 55 |
| Memory | 44 |
| Tipiṭaka | 37 |
| Other features | 31 |
| PDF Reader | 27 |
| Understand | 27 |
| Grammar / Understand | 22 |
| Translation | 20 |
| AI Chat | 12 |
| Listen | 3 |
| Web Reader | 1 |

## `my` — theo khu vực

| khu vực | còn lại |
| --- | ---: |
| PDF Reader | 114 |
| Tools / WordList | 114 |
| Other features | 113 |
| Other screens | 83 |
| Shared widgets | 65 |
| Read | 59 |
| Memory | 57 |
| Tipiṭaka | 49 |
| Grammar / Understand | 34 |
| Web Reader | 33 |
| Translation | 33 |
| Cabin | 33 |
| Understand | 28 |
| Learn by heart | 27 |
| YouTube | 26 |
| Listen | 23 |
| Dictionary | 20 |
| Other | 18 |
| TTS | 16 |
| AI Chat | 14 |
| Home | 13 |
| Settings | 11 |
| Video library | 2 |
| OCR | 2 |

## `th` — theo khu vực

| khu vực | còn lại |
| --- | ---: |
| Other features | 109 |
| Tools / WordList | 109 |
| PDF Reader | 108 |
| Other screens | 81 |
| Shared widgets | 64 |
| Read | 55 |
| Memory | 53 |
| Tipiṭaka | 48 |
| Grammar / Understand | 33 |
| Cabin | 33 |
| Translation | 31 |
| Understand | 28 |
| Learn by heart | 25 |
| Web Reader | 23 |
| YouTube | 20 |
| Listen | 20 |
| Dictionary | 20 |
| Other | 18 |
| TTS | 16 |
| AI Chat | 13 |
| Home | 13 |
| Settings | 11 |
| Video library | 2 |
| OCR | 2 |

## `ja` — theo khu vực

| khu vực | còn lại |
| --- | ---: |
| Other features | 109 |
| Tools / WordList | 109 |
| PDF Reader | 108 |
| Other screens | 80 |
| Shared widgets | 64 |
| Read | 55 |
| Memory | 53 |
| Tipiṭaka | 48 |
| Grammar / Understand | 33 |
| Cabin | 33 |
| Translation | 31 |
| Understand | 28 |
| Learn by heart | 25 |
| Web Reader | 23 |
| YouTube | 20 |
| Listen | 20 |
| Dictionary | 20 |
| Other | 18 |
| TTS | 16 |
| AI Chat | 13 |
| Home | 13 |
| Settings | 11 |
| Video library | 2 |
| OCR | 2 |

## Chi tiết (ưu tiên chuỗi còn tiếng Việt)

