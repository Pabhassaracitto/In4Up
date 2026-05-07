#!/bin/bash
# ios/llama_build.sh
# Chạy script này 1 lần để build xcframework

set -e

LLAMA_DIR="../native/llama_cpp/vendor/llama.cpp"
BRIDGE_DIR="../native/llama_cpp"
OUTPUT_DIR="./Runner/Frameworks"

mkdir -p "$OUTPUT_DIR"

echo "🔨 Building llama.cpp for iOS..."

# ── Build cho device (arm64) ──────────────────────────────
# LƯU Ý: Đây là hướng dẫn, trong môi trường này ta chỉ tạo file script.
# xcodebuild build \
#   -project Runner.xcodeproj \
#   -scheme Runner \
#   -sdk iphoneos \
#   -arch arm64 \
#   ONLY_ACTIVE_ARCH=YES \
#   BUILD_DIR=./build/device

# ── Build cho simulator (arm64 + x86_64) ─────────────────
# xcodebuild build \
#   -project Runner.xcodeproj \
#   -scheme Runner \
#   -sdk iphonesimulator \
#   -arch arm64 -arch x86_64 \
#   BUILD_DIR=./build/simulator

echo "✅ iOS build script created"
