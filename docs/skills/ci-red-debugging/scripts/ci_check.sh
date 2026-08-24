#!/usr/bin/env bash
# ci_check.sh — vòng lặp CI-oracle 1 lệnh
# (skill: docs/skills/ci-red-debugging/SKILL.md)
#
# Dùng:
#   docs/skills/ci-red-debugging/scripts/ci_check.sh "ci: bisect B2 - <giả thuyết>"
#       → commit (nếu có thay đổi) + push + đợi run mới + watch + báo step
#   docs/skills/ci-red-debugging/scripts/ci_check.sh
#       → chỉ theo dõi run của HEAD hiện tại
#
# Biến môi trường:
#   CI_WORKFLOW    tên file workflow (mặc định knowledge_tests.yml)
#   CI_WAIT_NEW_RUN  giây chờ run mới đăng ký (mặc định 90)

set -uo pipefail

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
WF="${CI_WORKFLOW:-knowledge_tests.yml}"
POLL_DEADLINE=$(( $(date +%s) + ${CI_WAIT_NEW_RUN:-90} ))

if [[ $# -ge 1 ]]; then
  if [[ -n "$(git status --porcelain)" ]]; then
    git add -A && git commit -q -m "$1" || { echo "LỖI: không commit được"; exit 2; }
  else
    echo "(không có thay đổi để commit)"
  fi
  git push -q origin "$BRANCH" || { echo "LỖI: push thất bại (remote/permission?)"; exit 2; }
  echo "PUSHED -> $BRANCH"
fi

HEAD_SHA="$(git rev-parse HEAD)"
RID=""
while :; do
  RID="$(gh run list --workflow="$WF" --limit 5 --json databaseId,headSha \
    --jq ".[] | select(.headSha == \"$HEAD_SHA\") | .databaseId" | head -1)"
  [[ -n "$RID" ]] && break
  if [[ $(date +%s) -gt $POLL_DEADLINE ]]; then
    echo "LỖI: $(( ${CI_WAIT_NEW_RUN:-90} ))s không thấy run cho ${HEAD_SHA:0:7}."
    echo "     Kiểm tra paths-filter của $WF có khớp file vừa push không (bẫy 5.7)."
    exit 3
  fi
  sleep 5
done
echo "RUN=$RID (branch $BRANCH, commit ${HEAD_SHA:0:7})"

if gh run watch "$RID" --exit-status >/dev/null 2>&1; then
  echo "KẾT QUẢ: ✅ XANH"
  gh run view "$RID" 2>/dev/null | grep "✓" | head -8
  exit 0
fi

echo "KẾT QUẢ: ❌ ĐỎ — từng bước:"
gh run view "$RID" 2>/dev/null | grep -E "✓|X|^  - " | head -12
echo
echo "URL nếu cần người dùng dán log:"
gh run view "$RID" --json url --jq '.url' 2>/dev/null
exit 1
