# ADR-0022: TTS VieNeu-TTS Native Audio C++ (GGUF)

## Trạng thái
Accepted

## Bối cảnh
TTS hiện tại phụ thuộc platform (Windows TTS / Edge voice) — không có giọng Việt
chất lượng cao, ổn định, offline trên Android/Linux cho module Tipiṭaka. Cần
một engine đọc tiếng Việt on-device, không cần mạng, không cần Python runtime.

## Quyết định
Sử dụng **audio.cpp** (github.com/0xShug0/audio.cpp, commit be1286e0, Apache-2.0)
làm runtime GGUF, kết hợp với **VieNeu-TTS v3 Turbo**
(pnnbao-ump/VieNeu-TTS-v3-Turbo-GGUF, Apache-2.0).

### Các thành phần chính
| Thành phần | Đường dẫn | Mô tả |
|------------|-----------|-------|
| C wrapper | `native/tts_vieneu/vieneu_tts.h` / `.cpp` | Thin C ABI over audio.cpp C API |
| Android CMake | `android/app/src/main/cpp/ai/CMakeLists.txt` | Target `vieneu_tts`, link `libaudiocpp.so`, CPU only |
| Dart FFI core | `packages/in4up_stt/lib/tts/vieneu_tts_core.dart` | FFI bridge + worker isolate + WAV 16-bit LE encoder |
| TTS Engine | `lib/features/tts/engines/vieneu_tts_engine.dart` | `VieneuTtsEngine` implements `TtsEngine`, vi-VN only |
| TTS Service | `lib/features/tts/tts_service.dart` | `vieneu_tts` priority 0, language filter, fallback an toàn |
| i18n | `lib/l10n/app_{en,vi,hi,zh,zh_TW,si}.arb` | 2 key mới + `ttsLicenseSection` |
| Settings UI | `lib/features/tts/widgets/tts_settings_section.dart` | `_LicenseSection` / `_LicenseTile` Apache-2.0 credit |
| ADR | `docs/adr/0022-tts-vieneu-native-audio-cpp.md` | Bản ghi này |
| KANBAN | `docs/project/KANBAN.md` | Ticket TTS-VIENEU-001 |

### Quyết định kỹ thuật
1. **Mô hình mặc định**: `vieneu-v3-turbo-q8_0.gguf` (~170 MB), không bundle vào
   APK, tải sau cài đặt (giống Hy-MT import .gguf thủ công).
2. **Chỉ đọc tiếng Việt**: lọc theo `languageCode` của đoạn Tipiṭaka; Pali 'hi'
   và Anh 'en' fallback qua engine khác. Không đọc Pali/mūla gốc.
3. **CPU backend only**: tắt CUDA/Vulkan/Metal/RKNN/LLAMAFILE/NATIVE_CPU.
4. **Worker isolate riêng**: toàn bộ nạp model + synthesize chạy trong isolate
   qua `packages/in4up_stt/lib/tts/vieneu_tts_core.dart` — không block UI thread.
5. **Graceful skip**: nếu submodule audio.cpp thiếu, CMake chỉ WARNING, app vẫn
   build, Dart engine báo chưa sẵn sàng → fallback TTS cũ, không crash.
6. **License**: audio.cpp + VieNeu-TTS đều Apache-2.0, tương thích với in4up
   Source-Available Non-Commercial License; credit trong Settings.

## Hệ quả
- Tích hợp native C++ qua FFI tăng độ phức tạp build (cần NDK, audio.cpp submodule)
- Worker isolate tránh block UI khi nạp 170 MB GGUF + synthesize đoạn dài
- Fallback an toàn: nếu model chưa import, TtsService tự chuyển sang Piper/Offline/Edge

## Ngoài phạm vi (ticket riêng sau)
- GPU backend (CUDA/Vulkan/Metal/RKNN)
- Mô hình bf16 (chỉ Q8_0 ban đầu)
- Tùy chọn giọng đọc đa ngôn ngữ (chỉ vi-VN)

## Liên kết
- PR: #132 (từ `arena/5f49ec81-in4up` lên `arena/01a0251e-in4up`)
- Ticket: TTS-VIENEU-001
