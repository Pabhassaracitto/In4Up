"""Chạy corpus vàng qua engine.py, in bảng điểm theo từng trường + case sai.

Chạy: python3 tool/grammar_probe/run_probe.py [--verbose]
"""

from __future__ import annotations

import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import engine  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))

FIELDS = ["type", "question", "polarity", "tense", "aspect", "voice", "pattern"]


def main():
    verbose = "--verbose" in sys.argv
    path = next((a for a in sys.argv[1:] if a.endswith(".json")),
                os.path.join(HERE, "corpus.json"))
    corpus = json.load(open(path, encoding="utf-8"))
    cases = corpus["cases"]

    counters = {f: [0, 0] for f in FIELDS}
    counters["phrase.kind"] = [0, 0]
    counters["phrase.span"] = [0, 0]
    counters["outer.span"] = [0, 0]
    counters["clause_role"] = [0, 0]
    counters["conditional"] = [0, 0]
    counters["sentence_span"] = [0, 0]
    counters["supported"] = [0, 0]

    failures = []
    runtime = []

    for case in cases:
        t0 = time.perf_counter()
        got = engine.analyze(case["text"], case["anchor"])
        runtime.append((time.perf_counter() - t0) * 1e6)
        exp = case["expect"]
        bad = []

        if "supported" in exp:
            counters["supported"][1] += 1
            if got["supported"] == exp["supported"]:
                counters["supported"][0] += 1
            else:
                bad.append(f"supported: got={got['supported']} want={exp['supported']}")

        if "phrase" in exp:
            want = exp["phrase"]
            have = got.get("phrase") or {}
            counters["phrase.kind"][1] += 1
            if have.get("kind") == want["kind"]:
                counters["phrase.kind"][0] += 1
            else:
                bad.append(f"phrase.kind: got={have.get('kind')} want={want['kind']}")
            counters["phrase.span"][1] += 1
            if (have.get("span") or "").strip() == want["span"]:
                counters["phrase.span"][0] += 1
            else:
                bad.append(f"phrase.span: got={have.get('span')!r} want={want['span']!r}")

        if "outer" in exp:
            counters["outer.span"][1] += 1
            have = got.get("outer") or {}
            if have.get("span", "").strip() == exp["outer"]["span"]:
                counters["outer.span"][0] += 1
            else:
                bad.append(f"outer.span: got={have.get('span')!r} want={exp['outer']['span']!r}")

        if "sentence" in exp:
            for f, want in exp["sentence"].items():
                counters[f][1] += 1
                have = (got.get("sentence") or {}).get(f)
                if have == want:
                    counters[f][0] += 1
                else:
                    bad.append(f"sentence.{f}: got={have} want={want}")

        if "clause_role" in exp:
            counters["clause_role"][1] += 1
            if got.get("clause_role") == exp["clause_role"]:
                counters["clause_role"][0] += 1
            else:
                bad.append(f"clause_role: got={got.get('clause_role')} want={exp['clause_role']}")

        if "conditional" in exp:
            counters["conditional"][1] += 1
            if got.get("conditional") == exp["conditional"]:
                counters["conditional"][0] += 1
            else:
                bad.append(f"conditional: got={got.get('conditional')} want={exp['conditional']}")

        if "sentence_span" in exp:
            counters["sentence_span"][1] += 1
            if (got.get("sentence_span") or "") == exp["sentence_span"]:
                counters["sentence_span"][0] += 1
            else:
                bad.append(f"sentence_span: got={got.get('sentence_span')!r} want={exp['sentence_span']!r}")

        if bad:
            failures.append((case["id"], case["text"], case["anchor"], bad))

    print("=" * 78)
    print(f"SPIKE cụm từ + cấu trúc câu — {os.path.basename(path)} "
          f"({len(cases)} case)")
    print("=" * 78)
    for key, (ok, total) in counters.items():
        if total == 0:
            continue
        pct = 100.0 * ok / total
        bar = "█" * int(pct / 5)
        print(f"{key:<15} {ok:>3}/{total:<3} {pct:6.1f}%  {bar}")
    print("-" * 78)
    print(f"runtime: trung bình {sum(runtime)/len(runtime):.0f} µs/câu, "
          f"max {max(runtime):.0f} µs (Python; Dart sẽ nhanh hơn)")
    print(f"case sai: {len(failures)}/{len(cases)}")
    print("=" * 78)

    for cid, text, anchor, bad in failures:
        print(f"\n[{cid}] {text!r} anchor={anchor!r}")
        for b in bad:
            print(f"    - {b}")

    if verbose:
        print("\n--- chi tiết tất cả case ---")
        for case in cases:
            got = engine.analyze(case["text"], case["anchor"])
            print(f"\n{case['id']}: {got['phrase']} | {got['outer']} | {got['sentence']}")

    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
