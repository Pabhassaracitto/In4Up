# in2up – Advanced Audio Player & Language Learning Ecosystem

in2up is a cross‑platform multimedia application built with Flutter, optimized for intensive language learning, Dharma listening, and high‑fidelity audio playback. [github](https://github.com/Pabhassaracitto/in2up)
At its core is the **UltraTimeStretch** Engine V2, a native C++ DSP backend accessed via Dart FFI for extreme time‑stretching with natural voice quality. [github](https://github.com/Pabhassaracitto/in2up)

## Table of Contents

- [Core Technology](#core-technology)
- [Key Features](#key-features)
- [Architecture](#architecture)
- [Getting Started](#getting-started)
- [Platform Notes](#platform-notes)
- [Roadmap](#roadmap)
- [License](#license)
- [Tiếng Việt](#tiếng-việt)

## Core Technology

- UltraTimeStretch Engine V2 (native C++ DSP via Dart FFI) for extreme time‑stretching. [github](https://github.com/Pabhassaracitto/in2up)
- Playback speed range from 0.05x to 10.0x while preserving voice clarity. [github](https://github.com/Pabhassaracitto/in2up)
- Multi‑Resolution Phase Vocoder and Harmonic‑Percussive Separation to reduce artifacts at ultra‑slow speeds. [github](https://github.com/Pabhassaracitto/in2up)
- Formant preservation using cepstral analysis to avoid the “chipmunk effect” when changing speed or pitch. [github](https://github.com/Pabhassaracitto/in2up)
- SIMD optimization (NEON/AVX) for low‑latency processing on Android, iOS, and Windows. [github](https://github.com/Pabhassaracitto/in2up)

## Key Features

### 1. Adaptive Learning Modes

- LISTEN Mode  
  Modern rolling waveform UI with fixed playhead, A‑B looping and configurable gap duration between loops for better internalization. [github](https://github.com/Pabhassaracitto/in2up)
- READ Mode  
  Interactive text reader with CEFR‑based highlighting (A1–C2) and part‑of‑speech highlighting (Noun, Verb, etc.), plus multi‑engine translation (Google, DeepLX, Libre, Zalo AI). [github](https://github.com/Pabhassaracitto/in2up)
- UNDERSTAND Mode  
  Audio‑text synchronization (LRC/SRT) with Shadowing Mode, recording user speech and scoring pronunciation at phoneme level. [github](https://github.com/Pabhassaracitto/in2up)
- MEMORY Mode – “Memory Garden”  
  Vocabulary SRS using SM‑2 (Anki‑style) with visual growth stages: Seed → Sprout → Tree → Branch → Bud → Bloom. [github](https://github.com/Pabhassaracitto/in2up)

### 2. Rich Content Sources

- YouTube Explorer: Search, download audio, and fetch multi‑language captions to convert into learning materials. [github](https://github.com/Pabhassaracitto/in2up)
- Cloud & Local Library: Stream or play audio from Google Drive or local storage. [github](https://github.com/Pabhassaracitto/in2up)
- Integrated Readers: Built‑in PDF Reader and Web Reader that extract text for instant analysis and “Text Studio” processing. [github](https://github.com/Pabhassaracitto/in2up)

### 3. Smart Sync & Offline‑First

- Cross‑device sync using Firebase Auth and Cloud Firestore for vocabulary and learning progress. [github](https://github.com/Pabhassaracitto/in2up)
- Offline‑first design with local storage in Hive for instant access without network. [github](https://github.com/Pabhassaracitto/in2up)

## Architecture

### Tech Stack

- Framework: Flutter (Dart). [github](https://github.com/Pabhassaracitto/in2up)
- Native Engine: C++ UltraTimeStretch core via Dart FFI. [github](https://github.com/Pabhassaracitto/in2up)
- Backend & Sync: Firebase Auth, Cloud Firestore, Hive for local DB. [github](https://github.com/Pabhassaracitto/in2up)
- Platforms: Android, iOS, Windows (with CMake‑built native libraries). [github](https://github.com/Pabhassaracitto/in2up)

### lib/ Structure

- `audio/` – Core playback services and UltraTimeStretch bindings. [github](https://github.com/Pabhassaracitto/in2up)
- `features/` – PDF/Web readers, YouTube downloader, TTS, translation, etc. [github](https://github.com/Pabhassaracitto/in2up)
- `models/` – Data models for vocabulary, segments, playback state, etc. [github](https://github.com/Pabhassaracitto/in2up)
- `providers/` – State management for player, text analysis, memory algorithms. [github](https://github.com/Pabhassaracitto/in2up)
- `screens/` – UI screens for different learning modes and tools. [github](https://github.com/Pabhassaracitto/in2up)
- `ffi/` – Dart FFI bindings to native C++ audio processor. [github](https://github.com/Pabhassaracitto/in2up)

## Getting Started

### Prerequisites

- Flutter SDK (3.0.0+). [github](https://github.com/Pabhassaracitto/in2up)
- Firebase project (google‑services.json for Android, GoogleService‑Info.plist for iOS). [github](https://github.com/Pabhassaracitto/in2up)
- C++ toolchain and CMake for native engine builds, especially on Windows. [github](https://github.com/Pabhassaracitto/in2up)

### Clone & Install

```bash
git clone https://github.com/Pabhassaracitto/in2up.git
cd in2up

# Install Dart/Flutter dependencies
flutter pub get
```

### Configure Firebase

- Android: place `google-services.json` under `android/app/` from your Firebase Console project. [github](https://github.com/Pabhassaracitto/in2up)
- iOS/macOS: place `GoogleService-Info.plist` under `ios/Runner/` and configure Xcode project as usual. [github](https://github.com/Pabhassaracitto/in2up)

### Run

```bash
# Android / iOS
flutter run

# Windows (ensure native libs are built via CMake)
flutter run -d windows
```

> Note: This project is intended for personal educational use.  
> Please respect copyright when downloading external content (e.g. YouTube). [github](https://github.com/Pabhassaracitto/in2up)

## Platform Notes

- Android/iOS: UltraTimeStretch engine built as native libraries, accessed via FFI. [github](https://github.com/Pabhassaracitto/in2up)
- Windows: Requires CMake build; see `windows/` and `native/` folders for C++ configuration and scripts. [github](https://github.com/Pabhassaracitto/in2up)

## Roadmap

- Improved Shadowing feedback with richer pronunciation analytics.  
- More TTS / translation engines and better offline support.  
- UI/UX refinements for waveform editor and Memory Garden.

## License
This project is released under the **in2up Source-Available License (Non-Commercial)**.  
You may use, copy, and modify the source code for personal, educational, and non-commercial research purposes.  
Commercial use of in2up, in whole or in part, requires prior written permission from the author.

See the [LICENSE](./LICENSE) file for the full terms.

***

## Tiếng Việt

### Giới thiệu

in2up là ứng dụng nghe nhạc và học tập đa nền tảng, tối ưu cho nghe Pháp thoại, luyện nghe tiếng Anh và thưởng thức âm nhạc chất lượng cao. [github](https://github.com/Pabhassaracitto/in2up)
Ứng dụng sử dụng bộ xử lý âm thanh **UltraTimeStretch V2** (C++ native + Dart FFI) cho phép thay đổi tốc độ cực rộng mà vẫn giữ giọng nói tự nhiên. [github](https://github.com/Pabhassaracitto/in2up)

### Công nghệ cốt lõi

- Tốc độ phát từ 0.05x đến 10.0x. [github](https://github.com/Pabhassaracitto/in2up)
- Phase Vocoder đa phân giải, tách Harmonic‑Percussive, bảo toàn Formant để tránh biến dạng giọng nói. [github](https://github.com/Pabhassaracitto/in2up)
- Tối ưu SIMD (NEON/AVX) cho Android, iOS, Windows. [github](https://github.com/Pabhassaracitto/in2up)

### Hệ sinh thái học tập

- Chế độ NGHE: Giao diện waveform rolling, lặp A‑B, khoảng lặng tùy chỉnh. [github](https://github.com/Pabhassaracitto/in2up)
- Chế độ ĐỌC: Highlight theo CEFR, loại từ, tra từ và dịch thuật đa nguồn. [github](https://github.com/Pabhassaracitto/in2up)
- Chế độ HIỂU: Đồng bộ âm thanh – phụ đề, Shadowing và chấm điểm phát âm theo âm vị. [github](https://github.com/Pabhassaracitto/in2up)
- Vườn Trí Nhớ: Ôn tập từ vựng với thuật toán SM‑2, mô phỏng quá trình “cây” phát triển. [github](https://github.com/Pabhassaracitto/in2up)

### Nguồn nội dung

- YouTube Explorer: Tìm kiếm, tải audio và captions từ YouTube. [github](https://github.com/Pabhassaracitto/in2up)
- Trình đọc PDF & Web: Trích xuất văn bản để đọc và phân tích. [github](https://github.com/Pabhassaracitto/in2up)
- Cloud Storage: Kết nối Google Drive để stream / tải file cá nhân. [github](https://github.com/Pabhassaracitto/in2up)

### Cài đặt nhanh

```bash
git clone https://github.com/Pabhassaracitto/in2up.git
cd in2up
flutter pub get
flutter run
```

> Lưu ý: Cần cấu hình Firebase (google‑services.json / GoogleService‑Info.plist) và build thư viện native bằng CMake trên Windows. [github](https://github.com/Pabhassaracitto/in2up)
