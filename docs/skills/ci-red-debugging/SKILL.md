---
name: ci-red-debugging-github-actions
version: 1.1.0
language: vi
maturity: proven-in-battle
description: >
  Tự chẩn đoán và xử lý CI đỏ (Flutter / GitHub Actions) trong môi trường KHÔNG đọc
  được log CI và KHÔNG có Flutter SDK local — dùng chính CI làm "oracle 1-bit" kết hợp
  bisect có kỷ luật. Mục tiêu: giải phóng 100% công sức người dùng, không bắt họ mở
  VSCode/máy local để xem lỗi rồi gửi ngược lại.
use_when:
  - CI GitHub Actions đỏ trong repo Flutter và không tự sửa được ngay
  - "'gh run view --log' / '--log-failed' lỗi EOF hoặc trả chuỗi rỗng"
  - Sandbox không cài được Flutter/Dart SDK (storage.googleapis.com / pub.dev bị chặn)
  - Cần xác minh compile/test khi không thể chạy local
do_not_use_when:
  - Log tải được bình thường → đọc log trực tiếp, nhanh hơn hẳn
  - Đỏ do hạ tầng runner (mạng/lưu lượng GitHub) → chạy lại run trước khi phân tích
origin: phiên Task 3 In4Up (2026-08-20) — 15+ vòng CI đỏ được chẩn đoán tự động
---

# SKILL — Debug CI đỏ Flutter khi không có log, không có SDK

## 0. Chân lý nền tảng

Khi không đọc được log, **mỗi lần chạy CI là một oracle trả lời ĐÚNG/SAI cho đúng MỘT
giả thuyết** (~40–70 giây/vòng với Flutter). Bisect log₂(n) vòng định vị được mọi thủ
phan cấp file — miễn là mỗi vòng đổi đúng một biến số.

Sai lầm chết người: đứng yên "suy luận thêm" thay vì push một vòng xác nhận.
Suy luận là miễn phí nhưng thường sai; oracle tính bằng phút nhưng luôn đúng.

## 1. Khảo sát môi trường (làm 1 lần, ~30 giây)

```bash
# Host mở/chặn (000 = chặn)
for h in storage.googleapis.com pub.dev api.github.com results-receiver.actions.githubusercontent.com; do
  echo "$h -> $(curl -s -o /dev/null -m 8 -w '%{http_code}' "https://$h/" 2>/dev/null || echo 000)"
done

# Token có quyền gì với repo?
gh api /repos/<owner>/<repo> --jq '.permissions'

# Workflow nào tồn tại?
gh workflow list --all

# Đọc workflow QUA API (kể cả khi git local đang lỗi):
gh api repos/<o>/<r>/contents/.github/workflows/<f>.yml --jq .content | base64 -d
```

Ba thực tế đã ghi nhận trên Arena (nếu gặp lại thì đỡ mất công khám phá):
- `api.github.com`, `codeload.github.com` mở; `storage.googleapis.com`, `pub.dev`,
  `results-receiver.actions.githubusercontent.com` CHẶN ⇒ không SDK local, không log CI.
- Token GitHub App thường thiếu quyền `workflows` ⇒ KHÔNG tạo/sửa được file trong
  `.github/workflows/` (push chứa file đó bị reject cả nhánh — hãy tách riêng commit).
- `gh run list/watch/view` (metadata + step-level ✓/X) HOẠT ĐỘNG — đây là канал chính.

## 2. Vòng lặp oracle (lệnh chuẩn)

Dùng script kèm theo (tự commit + push + watch + báo step):

```bash
docs/skills/ci-red-debugging/scripts/ci_check.sh "ci: bisect B2 - <giả thuyết>"
```

Hoặc tay:

```bash
git add -A && git commit -q -m "ci: bisect <bước> — <giả thuyết>" && git push -q origin <branch>
sleep 15
RID=$(gh run list --workflow=<wf>.yml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch $RID --exit-status >/dev/null 2>&1; echo "RESULT: $?"    # 0=xanh 1=đỏ
gh run view $RID 2>&1 | grep -E "✓|X|^  - "                           # X step nào?
```

Luật chơi:
1. **Đọc step TRƯỚC, nội dung sau.** `X Analyze` và `X Run tests` là hai bệnh khác hẳn.
2. **Mỗi vòng đúng MỘT biến số.**
3. **Mỗi commit bisect phải tự thống nhất** (compile đứng một mình được) — nếu không,
   lỗi nhiễu do chính bản bisect làm oracle nói dối.
4. Commit bisect phải **chạm path trong `paths:` filter** của workflow, nếu không CI
   sẽ không chạy mà bạn tưởng "xanh".

## 3. Cây quyết định

```
ĐỎ
├─ Step ANALYZE đỏ
│   ├─ B1: Lỗi file trong phạm vi analyze? → rà checklist bẫy (mục 5)
│   ├─ B2: Đoán lint? → KHÔNG đoán — tải rule-set thật:
│   │     gh api repos/flutter/packages/contents/packages/flutter_lints/lib/flutter.yaml?ref=main --jq .content | base64 -d
│   │     (kèm include package:lints/recommended.yaml từ dart-lang/lints)
│   │     flutter_lints 6.0 đã GIẢM mạnh rule — "lint quen thuộc" nhiều khi không còn
│   └─ B3: Bisect NỘI DUNG file: skeleton tối thiểu → trả từng nửa
│
├─ Step RUN TESTS đỏ
│   ├─ T1: Thay TOÀN BỘ test bằng 1 test không-thể-sai (expect(1,1))
│   │     Vẫn đỏ  ⇒ LỖI LOAD SUITE (import-chain compile gãy) → bisect IMPORT
│   │     Xanh   ⇒ ASSERTION sai → bisect theo NỬA nhóm test
│   ├─ Nhớ: flutter analyze ≠ flutter test compile (CFE). Có construct analyzer
│   │     chấp nhận nhưng CFE từ chối — đặc biệt tên class đi qua EXPORT chain.
│   └─ Test "không-thể-sai" mà đỏ = load failure — đây là phép phân biệt rẻ nhất.
│
└─ Step KHÁC (pub get / setup) → thường là hạ tầng: re-run 1 lần rồi hẵng phân tích
```

## 4. Giao thức bisect (thứ tự các vòng)

1. **Cô lập FILE**: git rm file nghi vấn (hoặc dời khỏi paths-filter), push.
   Đỏ tiếp ⇒ thủ phạm ở file khác. Xanh ⇒ đúng file.
2. **Cô lập KHỐI**: skeleton tối thiểu của file (class rỗng + 1 hàm), push cho xanh
   nền, rồi trả nội dung theo NỬA: imports → helpers → bodies.
3. **Cô lập IMPORT**: skeleton + từng import với usage tối thiểu (nhớ: import không
   dùng ⇒ warning ⇒ tự đỏ — phải dùng nó). Cảnh giác cặp A + B-mà-export-A.
4. **Cô lập TEST**: như mục 3 (T1 trước tiên!), rồi chặt nửa nhóm test.
5. **Chốt**: fix + khôi phục toàn bộ phần đã rút trong MỘT commit, push xác nhận xanh,
   ghi postmortem vào comment code/ADR + dòng "khi_nào_dùng" của skill này nếu có loại bẫy mới.

Quy ước: commit bisect đặt tên `ci: bisect <mã vòng> - <vừa làm gì>`; mở PR thì
squash-merge để lịch sử sạch.

## 5. Checklist bẫy ĐÃ TRẢ GIÁ THẬT (rà trước khi push)

| # | Bẫy | Dấu hiệu | Tránh thế nào |
|---|---|---|---|
| 5.1 | Phạm vi analyze hẹp hơn tưởng tượng | analyze xanh mà test đỏ (compile kéo chain) | Đọc paths/dirs trong lệnh analyze của workflow; coi file ngoài scope là "chưa từng được analyze" |
| 5.2 | **Export-chain trap** (bẫy đắt nhất) | (a) cùng file import X trực tiếp + import Y mà Y export X ⇒ analyze đỏ; (b) nhắc tên class QUA export của file khác ⇒ analyze xanh nhưng flutter test LOAD đỏ | Trong lib: đọc dữ liệu qua FIELD (`entry.a.b`). Trong test: fixture JSON (`Model.fromJson`) — JSON đúng format lưu trữ thật hơn nữa |
| 5.3 | Ảo giác escape của tool-output | "regex bị nhân đôi backslash" | Kiểm byte thật: `grep -F 'RegExp(r' f | od -c` — output công cụ hiển thị qua JSON luôn nhân đôi `\` |
| 5.4 | Float round-trip assertion | `0.4-0.1 != 0.3` sau khi serialize left/top/right/bottom | Giá trị dyadic (0.125/0.25/0.375) hoặc `closeTo` |
| 5.5 | Sandbox tái bản giữa phiên | `git log` về commit nền, files thành untracked, mất remote-tracking refs | `cp` file đang sửa → /tmp TRƯỚC; `git config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'; git fetch; git reset --hard origin/<branch>`; cp ngược lại |
| 5.6 | Dual-view file layer | edit_tool báo OK mà bash grep không thấy (và ngược lại); "nothing to commit" ma | KHÔNG song song lệnh ghi-file với git; sau khi ghi bằng tool, xác nhận bằng grep/md5sum TRƯỚC khi commit |
| 5.7 | paths-filter | push xong không có run mới | Đảm bảo commit chạm path match của trigger |
| 5.8 | Bisect gây đỏ tự thân | file bisect cắt bằng script python bị vỡ cú pháp ⇒ đỏ oan, đổ lỗi nhầm cho code đang nghi vấn | MỌI file bisect phải qua balance-check (phiên bản xử lý CẢ nháy đơn lẫn nháy kép) trước khi push; vòng T9–T10 từng đỏ oan vì thế |
| 5.9 | Cắt normalize/dọn dòng bằng regex | `\s+`/`[ \t]+` gộp run nhưng KHÔNG xóa space sát `\n` (`'b \n'` giữ nguyên) | Chuẩn hóa per-line: split('\n') → collapse+trim từng dòng → join; nghĩ "line edges" trước khi dùng replaceAll toàn chuỗi |
| 5.10 | show-combinator + export-chain | `show X, Y` với tên KHÔNG dùng thật (đặc biệt tên đến qua export của file khác) ⇒ CI analyze đỏ; lấy tên hàm SM-2 vào test bằng MỌI đường (import trực tiếp = B6, show-từ-export) đều gãy | Chỉ show đúng tên đang dùng; khi test cần đối chiếu thuật toán, dùng phép so sánh tương đương nội bộ (compact-vs-compact) thay vì gọi hàm ngoài qua export |
| 5.11 | Underscore local variable | `final _ = expr;` ⇒ `no_leading_underscores_for_local_identifiers` (có trong lints/recommended — CI fatal) | Dùng trực tiếp `expect(Class.method, isNotNull)` hoặc đặt tên có nghĩa |

## 6. Khi nào PHẢI lên tiếng với người dùng

- **≥ 5–6 vòng bisect không hội tụ** (điều kiện: mỗi vòng phải thu được THÔNG TIN MỚI;
  2 vòng liên tiếp không thêm thông tin = đang quay vòng, dừng).
- Cần quyền cao hơn (workflows) hoặc log thật: đưa URL thẳng
  `https://github.com/<o>/<r>/actions/runs/<runId>/job/<jobId>` và đề nghị dán
  đúng đoạn đỏ của step — 30 giây của người dùng thay cho 1 giờ đoán.
  ✅ ĐÃ THỰC CHIẾN (Task 4): người dùng dán Expected/Actual từ log — fix đúng
  ngay vòng kế tiếp sau 11 vòng mù. LUÔN dọn "run đầy đủ" trước khi hỏi.
- Agent thường KHÔNG có thị giác — ảnh chụp màn hình log không đọc được: xin dán
  CHỮ (không phải screenshot), và lưu ý ảnh có thể không tới được filesystem sandbox.
- Remote có commit lạ/không phải của mình ⇒ hỏi trước khi rebase/force.

## 7. Phòng bệnh

1. File test import tối thiểu — ít import, ít thức gãy load.
2. Fixture JSON đúng format store thật (Hive/SharedPreferences đều là JSON anyway).
3. Float: nghĩ "round-trip qua gì?" trước khi `==`.
4. Commit nhỏ, **push ngay** — push là backup (bẫy 5.5 không mất được thứ đã push).
5. Postmortem bằng comment ngay tại chỗ vỡ — agent kế tiếp (và chính bạn ở turn sau)
   không trả giá lần hai.

## 8. Tài liệu liên quan trong repo

- `docs/playbooks/` (nếu có) — bản mở rộng của skill này.
- `tool/ci/README.md` — cách bật workflow khi token thiếu quyền `workflows`.
- `docs/adr/0001-sm2-canonical-formula.md` — ví dụ postmortem chuẩn.
