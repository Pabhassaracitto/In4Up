// lib/screens/memory_mode/memory_mode.dart

/// Memory Mode - Tab NHỚ
/// Hệ thống ôn tập từ vựng dựa trên khoa học thần kinh
///
/// Features:
/// - 6 giai đoạn trưởng thành trí nhớ (Seed → Bloom)
/// - Spaced Repetition System (SM-2 algorithm)
/// - Adaptive card sizing (Von Restorff Effect)
/// - Color-coded urgency (Salience Network)
/// - Flashcard with flip animation (Active Recall)
/// - Garden visualization (Gamification)

export 'memory_mode_screen.dart';
export 'controllers/memory_controller.dart';
export 'models/memory_item.dart';
export 'models/memory_stage.dart';
export 'models/memory_stats.dart';
export 'models/review_session.dart';
export 'services/memory_storage_service.dart';
export 'memory_tab_connector.dart';

// Widgets (export nếu cần dùng ngoài)
export 'widgets/memory_card_widget.dart';
export 'widgets/flashcard_presenter.dart';
export 'widgets/stage_progress_bar.dart';

// Painters
export 'painters/garden_painter.dart';
export 'painters/bloom_particle_painter.dart';

// Sheets
export 'sheets/word_detail_sheet.dart';
export 'sheets/review_settings_sheet.dart';
export 'sheets/memory_stats_sheet.dart';
