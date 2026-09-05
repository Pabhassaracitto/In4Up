/// Dictionary module — từ điển MDX/MDD đa ngữ
///
/// Tính năng:
/// - Import file .mdx (+ .mdd tùy chọn) từ thiết bị
/// - Tra từ tức thì khi đọc PDF, TXT, Web, YouTube
/// - Quản lý đa từ điển: bật/tắt, xóa
/// - Đa ngôn ngữ: EN↔VI, EN↔ZH, JA↔EN, Pali↔VI…
library;

export 'models/dict_entry.dart';
export 'models/dict_info.dart';
export 'services/dict_db_service.dart';
export 'services/dictionary_service.dart';
export 'services/mdx_parser.dart';
