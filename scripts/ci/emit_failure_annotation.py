#!/usr/bin/env python3
"""Đưa các dòng lỗi của một log build lên *annotation* GitHub Actions.

Vì sao cần script này: log workflow và artifact của Actions nằm ở blob storage
(`results-receiver.actions.githubusercontent.com`, `productionresultssa*.blob...`)
mà sandbox agent bị chặn egress ⇒ `gh run view --log` trả EOF. Annotation thì đọc
được qua `repos/{owner}/{repo}/check-runs/{id}/annotations`, nên nó là kênh DUY
NHẤT để chẩn đoán lỗi từ xa.

Chiến lược chọn dòng (theo thứ tự, ghép lại, khử trùng lặp theo số dòng):
  1. Cửa sổ ngữ cảnh từ "What went wrong" / "A problem occurred" / "FAILURE:".
  2. Mọi "CMake Error" / "CMake Warning (dev)" / "ninja: build stopped" /
     "FAILED:" kèm 8 dòng sau (lỗi CMake nằm ở CUỐI output configure).
  3. `tail_lines` dòng cuối log (lỗi thật thường ở đó).
  4. Nếu không có gì khớp: toàn bộ tail.

Yêu cầu định dạng: message của workflow command phải là MỘT dòng; xuống dòng được
mã hoá `%0A`, và `%` phải thành `%25` TRƯỚC khi ghép (nếu không sẽ mã hoá luôn
các `%0A` vừa tạo).

Dùng:
    python3 scripts/ci/emit_failure_annotation.py <log> [max_lines] [tail_lines]
rồi trong workflow:
    errs="$(python3 scripts/ci/emit_failure_annotation.py /tmp/build.log)"
    echo "::error title=...::${errs:-exit=$code}"
"""

from __future__ import annotations

import re
import sys

# Các mẫu lỗi của Gradle / CMake / NDK / clang / ninja / Java.
PATTERNS = (
    r"What went wrong"
    r"|^e: "
    r"|error:"
    r"|fatal error"
    r"|CMake Error"
    r"|undefined reference"
    r"|cannot find"
    r"|No matching client"
    r"|Execution failed"
    r"|> Task .*FAILED"
    r"|ninja: build stopped"
    r"|Caused by"
    r"|ld: "
    r"|clang\+\+: error"
    r"|Could not (resolve|find|determine)"
    r"|A problem occurred"
)

# Dòng mở đầu khối lỗi của Gradle.
CONTEXT_START = r"What went wrong|A problem occurred|FAILURE: Build failed"

# Khối lỗi CMake/ninja — cần kèm vài dòng sau mới đủ ngữ cảnh.
BLOCK_START = r"CMake Error|CMake Warning \(dev\)|ninja: build stopped|FAILED:"

MAX_ANNOTATION = 60_000  # GitHub cắt message annotation quanh 64 KB


def _collect(lines: list[str], max_lines: int, tail_lines: int) -> list[str]:
    picked: list[int] = []
    seen: set[int] = set()

    def add(start: int, count: int) -> None:
        for index in range(start, min(start + count, len(lines))):
            if index not in seen:
                seen.add(index)
                picked.append(index)

    start = None
    for index, line in enumerate(lines):
        if re.search(CONTEXT_START, line):
            start = index
            break
    if start is not None:
        add(start, max_lines)

    for index, line in enumerate(lines):
        if re.search(BLOCK_START, line):
            add(index, 9)

    add(max(0, len(lines) - tail_lines), tail_lines)

    if not picked:
        matcher = re.compile(PATTERNS)
        for index, line in enumerate(lines):
            if matcher.search(line):
                add(index, 1)
                if len(picked) >= max_lines:
                    break

    return [lines[index] for index in picked[: max_lines + 40]]


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("usage: emit_failure_annotation.py <log> [max_lines] [tail_lines]",
              file=sys.stderr)
        return 2

    path = argv[1]
    max_lines = int(argv[2]) if len(argv) > 2 else 60
    tail_lines = int(argv[3]) if len(argv) > 3 else 25

    with open(path, encoding="utf-8", errors="replace") as handle:
        lines = [line.rstrip("\n") for line in handle]

    escaped = [line[:300].replace("%", "%25") for line in _collect(lines, max_lines, tail_lines)]
    message = "%0A".join(escaped)
    if len(message) > MAX_ANNOTATION:
        message = message[:MAX_ANNOTATION]

    print(message)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
