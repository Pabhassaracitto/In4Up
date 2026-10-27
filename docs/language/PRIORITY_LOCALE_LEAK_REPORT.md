# Priority-locale chrome leak report

Sinh tự động bởi `python3 tool/lang_ui_inventory.py --write-report`.
Đừng sửa tay — chạy lại tool sau mỗi wave bản dịch.

- Chrome strings quét được: **4340** trong **308** file presentation.
- `vietnamese`: chuỗi vẫn hiện tiếng Việt ở locale đó (vi phạm rule #5).
- `english`: chuỗi vẫn hiện English trên màn hình (kể cả khi fallback sang English) — đây là việc còn lại của các wave bản địa hoá tiếp theo.

| locale | vietnamese | english |
| --- | ---: | ---: |
| `zh` | 0 | 0 |
| `zh_TW` | 0 | 0 |
| `hi` | 0 | 0 |
| `si` | 0 | 0 |
| `my` | 0 | 0 |
| `th` | 0 | 0 |
| `ja` | 0 | 0 |

## `zh` — theo khu vực

| khu vực | còn lại |
| --- | ---: |

## `zh_TW` — theo khu vực

| khu vực | còn lại |
| --- | ---: |

## `hi` — theo khu vực

| khu vực | còn lại |
| --- | ---: |

## `si` — theo khu vực

| khu vực | còn lại |
| --- | ---: |

## `my` — theo khu vực

| khu vực | còn lại |
| --- | ---: |

## `th` — theo khu vực

| khu vực | còn lại |
| --- | ---: |

## `ja` — theo khu vực

| khu vực | còn lại |
| --- | ---: |

## Chi tiết (ưu tiên chuỗi còn tiếng Việt)

