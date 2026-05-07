#!/bin/bash
# scripts/setup_llama.sh

set -e

LLAMA_DIR="native/llama_cpp/vendor/llama.cpp"

echo "📦 Lấy llama.cpp source..."

mkdir -p native/llama_cpp/vendor

# Clone phiên bản stable (không phải latest để tránh breaking changes)
if [ ! -d "$LLAMA_DIR" ]; then
  git clone \
    --depth 1 \
    --branch b3228 \
    https://github.com/ggerganov/llama.cpp.git \
    "$LLAMA_DIR"
else
  echo "Found existing llama.cpp at $LLAMA_DIR"
fi

echo "✅ llama.cpp đã sẵn sàng tại: $LLAMA_DIR"
echo ""
echo "Các bước tiếp theo:"
echo "  Android: cd android && ./gradlew assembleDebug"
echo "  iOS:     cd ios && ./llama_build.sh"
