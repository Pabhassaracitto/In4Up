#!/usr/bin/env sh
# Kiểm tra ba OpenAI-compatible API của In4Up Server Box.
set -u

HOST="${1:-127.0.0.1}"
OLLAMA_PORT="${OLLAMA_PORT:-11434}"
SPEACHES_PORT="${SPEACHES_PORT:-8000}"
KOKORO_PORT="${KOKORO_PORT:-8880}"
TIMEOUT="${HEALTH_TIMEOUT:-10}"
FAILED=0

check() {
  name="$1"
  url="$2"
  printf '%-12s %s ... ' "$name" "$url"
  tmp="${TMPDIR:-/tmp}/in4up-health-$$"
  code="$(curl --silent --show-error --location \
    --connect-timeout "$TIMEOUT" --max-time "$TIMEOUT" \
    --output "$tmp" --write-out '%{http_code}' "$url" 2>/dev/null || true)"
  if [ "$code" = "200" ] && grep -q '"data"' "$tmp" 2>/dev/null; then
    echo "OK (HTTP 200)"
  else
    echo "LỖI (HTTP ${code:-không kết nối})"
    [ -s "$tmp" ] && { printf '  Phản hồi: '; head -c 300 "$tmp"; echo; }
    FAILED=1
  fi
  rm -f "$tmp"
}

check "Ollama" "http://${HOST}:${OLLAMA_PORT}/v1/models"
check "Speaches" "http://${HOST}:${SPEACHES_PORT}/v1/models"
check "Kokoro" "http://${HOST}:${KOKORO_PORT}/v1/models"

if [ "$FAILED" -ne 0 ]; then
  echo "Có dịch vụ chưa sẵn sàng. Xem: docker compose logs --tail=100"
  exit 1
fi

echo "Cả 3 dịch vụ đã sẵn sàng. Base URL dùng trong app là các URL trên bỏ /models."
