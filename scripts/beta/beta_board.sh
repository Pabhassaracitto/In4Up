#!/usr/bin/env bash
# beta_board.sh — bảng trạng thái nhánh tổng hợp Beta (BETA-1.29.0)
#
# Đọc: tip nhánh beta + CI của tip + các PR đang mở vào nhánh beta (kèm check).
# Không sửa gì trong repo, chỉ đọc (git/gh).
#
# Dùng:
#   scripts/beta/beta_board.sh                  # bảng cho nhánh hiện tại
#   scripts/beta/beta_board.sh <nhánh-beta>     # chỉ định nhánh beta khác
#
# Tài liệu điều phối: docs/project/BETA-1.29.0.md
set -euo pipefail

beta_branch="${1:-$(git rev-parse --abbrev-ref HEAD)}"
repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

command -v gh >/dev/null || { echo "cần gh CLI" >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "gh chưa đăng nhập" >&2; exit 1; }

echo "═══ BETA BOARD — $(date -u '+%Y-%m-%d %H:%M UTC') ═══"
echo "nhánh beta : $beta_branch"

git fetch -q origin "$beta_branch" 2>/dev/null || true
tip="$(git rev-parse --short "origin/$beta_branch" 2>/dev/null || git rev-parse --short HEAD)"
tip_date="$(git log -1 --format='%ci' "origin/$beta_branch" 2>/dev/null || git log -1 --format='%ci' HEAD)"
version="$(git show "origin/$beta_branch:pubspec.yaml" 2>/dev/null | awk '/^version:/{print $2; exit}' || awk '/^version:/{print $2; exit}' pubspec.yaml)"
echo "tip        : $tip  ($tip_date)"
echo "pubspec    : ${version:-?}   (giữ 1.28.0+28 tới cổng G4)"
echo

echo "── CI gần nhất trên $beta_branch ──"
gh run list --branch "$beta_branch" --limit 6 \
  --json name,conclusion,status,headSha,createdAt,url \
  --jq '.[] | "  \(.conclusion // .status)\t\(.name[0:44])\t\(.headSha[0:7])\t\(.createdAt[0:16])\t\(.url)"' \
  || echo "  (không đọc được run)"
echo

echo "── PR đang mở vào $beta_branch (hợp đồng land §3) ──"
prs="$(gh pr list --base "$beta_branch" --state open --limit 50 \
  --json number,title,headRefName,mergeable,statusCheckRollup,updatedAt 2>/dev/null || echo '[]')"
count="$(printf '%s' "$prs" | jq 'length')"

if [ "$count" = "0" ]; then
  echo "  (chưa có PR nào — chưa nhánh con nào land)"
else
  printf '%s' "$prs" | jq -r '
    def tally:
      [ .[]? | (.conclusion // .state // .status // "?") ] as $s
      | "ok=\($s|map(select(.=="SUCCESS" or .=="NEUTRAL" or .=="SKIPPED"))|length)"
        + " fail=\($s|map(select(.=="FAILURE" or .=="CANCELLED" or .=="TIMED_OUT" or .=="ACTION_REQUIRED"))|length)"
        + " pending=\($s|map(select(.=="PENDING" or .=="IN_PROGRESS" or .=="QUEUED" or .=="EXPECTED" or .=="?") )|length)";
    .[] | "  #\(.number) [\(.mergeable)] \(.headRefName)\n      \(.title[0:96])\n      check: \(.statusCheckRollup // [] | tally)"'
fi
echo

echo "── Nhắc cổng (BETA-1.29.0.md §5) ──"
cat <<'TXT'
  G1  rà diff: phạm vi lane · version chưa bump · KANBAN/PLAN không bị sửa trên nhánh con
  G2  CI trên beta tip sau mỗi đợt: app_analyze + listen_queue_tests (+ deploy-web khi cần)
  G3  owner nghiệm thu máy thật — hub không tuyên bố thay owner
  G4  bump 1.29.0+29 MỘT lần → tag 1.29.0-beta.N (prerelease) → build 4 nền tảng
  G5  PR base arena/01a0251e-in4up (251e) — chỉ sau khi G3 xong
TXT
