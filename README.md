VipSound - Advanced Audio Player & Language Learning Ecosystem
VipSound is a powerful, cross-platform multimedia application built with Flutter, designed specifically for intensive language learning, Dharma listening, and high-fidelity audio manipulation. It features the proprietary UltraTimeStretch Engine V2, allowing users to slow down or speed up audio to extreme degrees while maintaining natural voice quality.
🚀 Core Technology: UltraTimeStretch Engine V2
Unlike standard players, VipSound utilizes a native C++ backend via Dart FFI to handle digital signal processing (DSP)
.
Extreme Speed Range: Supports playback speeds from 0.05x to 10.0x
.
Superior Clarity: Implements a Multi-Resolution Phase Vocoder and Harmonic-Percussive Separation to eliminate artifacts at ultra-slow speeds
.
Formant Preservation: Employs cepstral analysis to prevent the "chipmunk effect," keeping voices natural even when the pitch is shifted or speed is altered
.
High Performance: Optimized with SIMD (NEON/AVX) for low-latency processing on Android, iOS, and Windows
.
🛠 Key Features
1. Adaptive Learning Modes
The app is organized into four primary "Learning Spheres"
:
LISTEN Mode: Features a modern Rolling Waveform UI with a fixed playhead. It supports precision A-B Looping with customizable Gap Durations (khoảng lặng) between loops to allow for mental processing
.
READ Mode: An interactive text reader that performs Syntax Highlighting based on CEFR levels (A1-C2) and Word Types (Nouns, Verbs, etc.). It integrates a multi-engine translation system (Google, DeepLX, Libre, Zalo AI)
.
UNDERSTAND Mode: Synchronizes text (LRC/SRT) with audio. It includes a sophisticated Shadowing Mode that records user speech and provides phoneme-level accuracy scores using the CMU Dictionary and G2P rules
.
MEMORY Mode (The Memory Garden): A vocabulary management system based on the SM-2 Spaced Repetition algorithm. Words are visualized as plants that grow through 6 stages: Seed → Sprout → Tree → Branch → Bud → Bloom
.
2. Comprehensive Content Sources
YouTube Explorer: Search, download audio, and fetch multi-language captions directly from YouTube to convert them into study materials
.
Cloud & Local Library: Seamlessly browse and stream audio files from Google Drive or local storage
.
Integrated Readers: Built-in PDF Reader and Web Reader capable of extracting text for instant analysis and "Text Studio" processing
.
3. Smart Synchronization
Cross-Device Sync: Uses Firebase Auth and Cloud Firestore to keep your vocabulary and progress synced across platforms
.
Offline First: All data is stored locally in Hive for instant access without an internet connection
.
📦 Project Structure (lib/)
audio/: Manages core playback services and the UltraTimeStretch engine interface
.
features/: Modular components like PDF/Web readers, YouTube downloader, and TTS services
.
models/: Data structures for vocabulary, segments, and playback states
.
providers/: State management for player logic, text analysis, and memory algorithms
.
ffi/: Dart FFI bindings for the native C++ audio processor
.
🔨 Getting Started
Prerequisites
Flutter SDK (v3.0.0 or higher)
Firebase project setup (Android: google-services.json, iOS: GoogleService-Info.plist)
C++ Compiler (for building native audio libraries)
Installation
Clone the repository:
Install dependencies:
Run code generation (for Hive & Models):
Run the application:

--------------------------------------------------------------------------------
Note: This project is intended for personal educational use. Please respect copyright laws when downloading content from external sources.

################

VipSound - Chương trình nhạc với bộ xử lý âm thanh siêu việt
VipSound là một ứng dụng nghe nhạc và học tập đa năng, được thiết kế đặc biệt để tối ưu hóa trải nghiệm nghe Pháp thoại, luyện nghe tiếng Anh và thưởng thức âm nhạc chất lượng cao
. Ứng dụng tích hợp bộ xử lý âm thanh UltraTimeStretch V2 cho phép thay đổi tốc độ cực hạn mà không làm biến dạng giọng nói
.
🚀 Tính năng nổi bật
1. Bộ xử lý âm thanh UltraTimeStretch V2 (Core Engine)
Tốc độ cực hạn: Hỗ trợ thay đổi tốc độ từ 0.05x đến 10.0x
.
Công nghệ xử lý tín hiệu: Sử dụng Phase Vocoder đa phân giải, tách thành phần Harmonic-Percussive và bảo toàn định dạng (Formant Preservation) để giữ giọng nói tự nhiên ngay cả ở tốc độ rất chậm
.
Hiệu suất cao: Tối ưu hóa bằng SIMD (NEON/AVX) thông qua Dart FFI
.
2. Hệ sinh thái học tập thông minh
Chế độ NGHE (Listen Mode): Giao diện Waveform rolling hiện đại, hỗ trợ lặp đoạn A-B với khoảng lặng (Gap duration) tùy chỉnh để thấm nhuần nội dung
.
Chế độ HIỂU (Understand Mode): Đồng bộ văn bản (LRC/SRT) với âm thanh. Tích hợp tính năng Shadowing giúp luyện phát âm và chấm điểm dựa trên phân tích âm vị (Phoneme Analysis)
.
Chế độ ĐỌC (Read Mode): Hỗ trợ highlight văn bản theo cấp độ từ vựng CEFR (A1-C2) hoặc loại từ (Danh từ, Động từ...), tích hợp tra từ nhanh và dịch thuật đa nguồn (Google, DeepLX, Zalo AI)
.
Vườn Trí Nhớ (Memory Garden): Hệ thống ôn tập từ vựng dựa trên thuật toán lặp lại ngắt quãng SM-2 (chuẩn Anki). Từ vựng được hình tượng hóa qua 6 giai đoạn phát triển từ Hạt giống đến Hoa nở
.
3. Nguồn nội dung đa dạng
YouTube Explorer: Tìm kiếm, tải Audio và Captions trực tiếp từ YouTube để chuyển thành tài liệu học tập
.
Trình đọc PDF & Web: Trích xuất văn bản từ tệp PDF hoặc trang web bất kỳ để đọc với tính năng highlight thông minh
.
Cloud Storage: Kết nối trực tiếp với Google Drive để stream hoặc tải file âm thanh cá nhân
.
🛠 Công nghệ sử dụng
Framework: Flutter (Dart)
.
Native Engine: C++ (UltraTimeStretch)
.
Backend & Sync: Firebase Auth (Google Sign-in), Cloud Firestore (Đồng bộ từ vựng), Hive (Cơ sở dữ liệu Local)
.
Platform: Android, iOS, Windows
.
📦 Cấu trúc thư mục chính (lib/)
audio/: Quản lý dịch vụ phát nhạc và xử lý âm thanh
.
features/: Các tính năng mở rộng (PDF Reader, Web Reader, YouTube Downloader, TTS, Dịch thuật)
.
models/: Định nghĩa cấu trúc dữ liệu cho dự án (WordEntry, PlaybackState, Segment...)
.
providers/: Quản lý trạng thái ứng dụng bằng Provider (PlayerProvider, VocabularyProvider...)
.
screens/: Giao diện các chế độ học tập và công cụ
.
ffi/: Ràng buộc (Bindings) giữa Dart và mã nguồn C++ native
.
🔨 Cài đặt
Clone dự án: git clone https://github.com/Pabhassaracitto/vipsound.git
Cài đặt dependencies: flutter pub get
Cấu hình Firebase: Cần thiết lập google-services.json (Android) và GoogleService-Info.plist (iOS) từ Firebase Console
.
Chạy ứng dụng: flutter run (Lưu ý: Đối với Windows, đảm bảo các thư viện native đã được build bằng CMake)
.

--------------------------------------------------------------------------------
Ghi chú: Thông tin này được tổng hợp dựa trên phân tích mã nguồn hiện tại của dự án vipsound
. Bạn có thể tùy chỉnh thêm phần License hoặc Contact tùy theo nhu cầu cá nhân.