// lib/screens/understand_mode/models/lrc_line.dart
//
// Re-export LrcLine/LrcWord từ in2up_stt (nguồn duy nhất).
// Trước đây class LrcLine được định nghĩa ở đây, nhưng sau khi thêm
// word-timestamps (karaoke) vào STT package, class này đã được dời về
// packages/in2up_stt/lib/stt_lrc_converter.dart để tránh 2 định nghĩa
// trùng tên. File này giữ đường dẫn import cũ cho các consumer.
export 'package:in2up_stt/stt_lrc_converter.dart' show LrcLine, LrcWord;
