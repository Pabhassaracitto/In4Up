#!/usr/bin/env python3
"""Đưa các dòng lỗi của một log build lên *annotation* GitHub Actions.

Vì sao cần script này: log workflow và artifact của Actions nằm ở blob storage
(`results-receiver.actions.githubusercontent.com`, `productionresultssa*.blob...`)
mà sandbox agent bị chặn egress ⇒ `gh run view --log` trả EOF. Annotation thì đọc
được qua `repos/{owner}/{repo}/check-runs/{id}/annotations`, nên nó là kênh DUY
NHẤT để chẩn đoán lỗi từ xa.

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
    r"|CMake Warning at"
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

MAX_ANNOTATION = 60_000  # GitHub cắt message annotation quanh 64 KB


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("usage: emit_failure_annotation.py <log> [max_lines] [tail_lines]",
              file=sys.stderr)
        return 2

    path = argv[1]
    max_lines = int(argv[2]) if len(argv) > 2 else 60
    tail_lines = int(argv[3]) if len(argv) > 3 else 30

    with open(path, encoding="utf-8", errors="replace") as handle:
        lines = [line.rstrip("\n") for line in handle]

    matcher = re.compile(PATTERNS)
    picked = [line for line in lines if matcher.search(line)][:max_lines]
    if not picked:
        # Không khớp mẫu nào ⇒ gửi phần đuôi để không mù hoàn toàn.
        picked = lines[-tail_lines:]

    escaped = [line[:280].replace("%", "%25") for line in picked]
    message = "%0A".join(escaped)
    if len(message) > MAX_ANNOTATION:
        message = message[:MAX_ANNOTATION]

    print(message)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
