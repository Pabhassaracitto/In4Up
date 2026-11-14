#!/usr/bin/env python3
"""Phát lỗi của một log build thành *annotation* GitHub Actions (nhiều phần).

Vì sao cần script này: log workflow và artifact của Actions nằm ở blob storage
(`results-receiver.actions.githubusercontent.com`, `productionresultssa*.blob...`)
mà sandbox agent bị chặn egress ⇒ `gh run view --log` trả EOF. Annotation thì đọc
được qua `repos/{owner}/{repo}/check-runs/{id}/annotations` ⇒ đây là kênh DUY
NHẤT để chẩn đoán lỗi từ xa.

Giới hạn thực tế đo được: MỘT message của `::error::` bị cắt quanh **4096 ký tự**
(run 43320370093: annotation dừng giữa output ninja). Vì vậy script:
  * ưu tiên nội dung quan trọng (dòng "What went wrong", khối `FAILED:` của
    ninja kèm 10 dòng sau, mọi dòng `error:`), rồi tới đuôi log;
  * cắt thành nhiều `::error title=... (i/n)::` để tổng dung lượng lớn hơn.

Định dạng: message workflow command phải là MỘT dòng; xuống dòng = `%0A`, và `%`
phải thành `%25` TRƯỚC khi ghép (nếu không sẽ mã hoá luôn các `%0A` vừa tạo).

Dùng:
    python3 scripts/ci/emit_failure_annotation.py <log> [title] [max_chunks]
"""

from __future__ import annotations

import re
import sys

CHUNK = 3800  # chừa biên so với ngưỡng cắt ~4096 ký tự của một annotation

# Mở đầu khối lỗi của Gradle.
CONTEXT_START = r"What went wrong|A problem occurred|FAILURE: Build failed"

# Khối lỗi ninja/CMake — cần kèm vài dòng sau mới đủ ngữ cảnh.
BLOCK_START = r"^FAILED:|CMake Error|ninja: build stopped"

# Dòng lỗi trình biên dịch / liên kết.
ERROR_LINE = (
    r"error:"
    r"|undefined reference"
    r"|fatal error"
    r"|cannot find"
    r"|ld: "
    r"|Caused by"
    r"|Execution failed"
    r"|No matching client"
    # Xcode/Swift: `** BUILD FAILED **`, `error: ...`, `The following build
    # commands failed`, `<unknown>:0: error:`
    r"|\*\* BUILD FAILED \*\*"
    r"|The following build commands failed"
    # MSVC (Windows): `error C2039:`, `error LNK2019:`, `error MSB3073:`
    r"|error (?:C|LNK|MSB|RC)\d+"
    # Gradle/Kotlin
    r"|^e: "
    r"|What went wrong"
    # `flutter test` không nạp được file test (lỗi biên dịch) — dòng này là
    # thứ DUY NHẤT phân biệt "test hỏng" với "test không compile được".
    r"|Failed to load"
    r"|Compilation failed"
    r"|Error: "
)


def _priority_lines(lines: list[str]) -> list[str]:
    """Chọn dòng theo mức quan trọng (khử trùng theo chỉ số dòng gốc)."""
    picked: list[int] = []
    seen: set[int] = set()

    def add(start: int, count: int) -> None:
        for index in range(start, min(start + count, len(lines))):
            if index not in seen:
                seen.add(index)
                picked.append(index)

    # 1. Dòng mở đầu khối lỗi Gradle + 3 dòng sau (tên task hỏng).
    for index, line in enumerate(lines):
        if re.search(CONTEXT_START, line):
            add(index, 4)
            break

    # 2. Khối FAILED của ninja + 10 dòng sau: đây là chỗ nêu file/lỗi biên dịch.
    for index, line in enumerate(lines):
        if re.search(BLOCK_START, line):
            add(index, 11)

    # 3. Mọi dòng lỗi biên dịch/liên kết rời.
    for index, line in enumerate(lines):
        if re.search(ERROR_LINE, line):
            add(index, 3)

    # 3b. `flutter test` báo "loading <file>" rồi in lỗi biên dịch NGAY SAU đó
    # (không có tiền tố `error:`), nên phải kèm theo 10 dòng sau dòng "loading".
    for index, line in enumerate(lines):
        if re.search(r"loading |: loading ", line):
            add(index, 10)

    # 4. Đuôi log (thường có "BUILD FAILED in", thống kê).
    add(max(0, len(lines) - 8), 8)

    return [lines[index] for index in picked]


def _chunks(text: str) -> list[str]:
    return [text[start:start + CHUNK] for start in range(0, len(text), CHUNK)]


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("usage: emit_failure_annotation.py <log> [title] [max_chunks]",
              file=sys.stderr)
        return 2

    path = argv[1]
    title = argv[2] if len(argv) > 2 else "build failure"
    max_chunks = int(argv[3]) if len(argv) > 3 else 4

    try:
        with open(path, encoding="utf-8", errors="replace") as handle:
            lines = [line.rstrip("\n") for line in handle]
    except OSError as exc:
        print(f"::error title={title}::không đọc được log {path}: {exc}")
        return 0

    selected = _priority_lines(lines)
    # 600 ký tự: dòng lỗi MSVC/Xcode thường dài (đường dẫn + mã lỗi + gợi ý).
    escaped = [line[:600].replace("%", "%25") for line in selected]
    parts = _chunks("%0A".join(escaped))[:max_chunks]

    for ordinal, part in enumerate(parts, start=1):
        suffix = f" ({ordinal}/{len(parts)})" if len(parts) > 1 else ""
        print(f"::error title={title}{suffix}::{part}")

    if not parts:
        print(f"::error title={title}::log rỗng")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
