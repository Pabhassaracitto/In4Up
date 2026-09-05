/// Video module — xem video local + phụ đề + học từ vựng
///
/// Approach A+B:
/// - A: Sub-tab "Xem" trong tab Nghe (Nghe | Nói | Xem)
/// - B: Quick-action "Video" trong ⚡ menu
///
/// Tính năng:
/// - Phát video local (MP4, MKV, WebM…)
/// - Phụ đề SRT/ASS overlay đồng bộ
/// - Tap từ trong phụ đề → tra từ điển + lưu vào WordList
/// - Tốc độ phát thay đổi (reuse UltraTimeStretch cho audio track)
/// - A-B loop theo câu phụ đề
library;

export 'models/video_info.dart';
export 'services/video_library_service.dart';
export 'widgets/video_player_screen.dart';
export 'widgets/video_library_screen.dart';
