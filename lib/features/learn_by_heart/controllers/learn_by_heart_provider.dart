// lib/features/learn_by_heart/controllers/learn_by_heart_provider.dart

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../models/learning_activity.dart';
import '../../../services/learning_activity_service.dart';
import '../models/fsrs_models.dart';
import '../models/learn_by_heart_item.dart';
import '../models/recitation_category.dart';
import '../models/review_state.dart';
import '../services/fsrs_engine.dart';
import '../services/learn_by_heart_storage.dart';
import '../services/learn_by_heart_sync_service.dart';

class LearnByHeartProvider extends ChangeNotifier {
  final LearnByHeartStorage _storage = LearnByHeartStorage.instance;

  /// LHB-006 — đồng bộ lưu trữ đa thiết bị (offline-first, giống WordList).
  final LearnByHeartSyncService _sync = LearnByHeartSyncService.instance;

  List<LearnByHeartItem> _items = [];
  bool _isLoading = false;
  int _streak = 0;

  bool _isSyncEnabled = false;
  bool _isEnablingSync = false;
  String? _syncUid;

  RecitationCategory? _selectedCategory;
  ReviewState? _selectedStateFilter;
  String _searchQuery = '';

  // Getters
  bool get isLoading => _isLoading;
  int get streak => _streak;
  RecitationCategory? get selectedCategory => _selectedCategory;
  ReviewState? get selectedStateFilter => _selectedStateFilter;
  String get searchQuery => _searchQuery;
  List<LearnByHeartItem> get allItems => List.unmodifiable(_items);

  /// Danh sách các bài cần ôn tập hôm nay (SRS Due)
  List<LearnByHeartItem> get dueItems {
    return _items.where((item) => item.isDue).toList()
      ..sort((a, b) {
        // Ưu tiên bài lapse trước, rồi đến ngày đến hạn cũ hơn
        if (a.reviewState == ReviewState.lapse && b.reviewState != ReviewState.lapse) return -1;
        if (b.reviewState == ReviewState.lapse && a.reviewState != ReviewState.lapse) return 1;
        final aDate = a.nextReviewDate ?? DateTime(2000);
        final bDate = b.nextReviewDate ?? DateTime(2000);
        return aDate.compareTo(bDate);
      });
  }

  /// Danh sách các bài sẵn sàng cho bài kiểm tra thực chất (consecutiveSuccesses >= 5)
  List<LearnByHeartItem> get assessmentReadyItems {
    return _items.where((item) => item.isReadyForAssessment).toList();
  }

  int get dueCount => dueItems.length;
  int get totalCount => _items.length;
  int get learningCount => _items.where((i) => i.reviewState == ReviewState.learning || i.reviewState == ReviewState.relearning).length;
  int get masteredCount => _items.where((i) => i.isMastered).length;

  /// Danh sách sau khi áp dụng bộ lọc thể loại, trạng thái và tìm kiếm
  List<LearnByHeartItem> get filteredItems {
    return _items.where((item) {
      if (_selectedCategory != null && item.category != _selectedCategory) {
        return false;
      }
      if (_selectedStateFilter != null && item.reviewState != _selectedStateFilter) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final matchTitle = item.title.toLowerCase().contains(q);
        final matchSubtitle = item.subtitle.toLowerCase().contains(q);
        final matchPali = item.paliText.toLowerCase().contains(q);
        final matchVi = item.vietnameseText.toLowerCase().contains(q);
        final matchKw = item.keywords.any((k) => k.toLowerCase().contains(q));
        if (!matchTitle && !matchSubtitle && !matchPali && !matchVi && !matchKw) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  // ==================== ĐỒNG BỘ ĐA THIẾT BỊ (LHB-006) ====================

  bool get isSyncEnabled => _isSyncEnabled;
  LhbSyncStatus get syncStatus => _sync.status.value;
  DateTime? get lastSyncedAt => _sync.lastSyncedAt.value;
  ValueNotifier<LhbSyncStatus> get syncStatusNotifier => _sync.status;
  ValueNotifier<DateTime?> get lastSyncedNotifier => _sync.lastSyncedAt;

  /// Bật đồng bộ cho tài khoản [uid]: kéo cloud về trước, rồi đẩy hàng đợi.
  Future<void> enableSync(String uid) async {
    if (_isEnablingSync) return;
    if (_isSyncEnabled && _syncUid == uid) return;

    _isEnablingSync = true;
    try {
      _sync.localRevision.removeListener(_onSyncRevision);
      _sync.localRevision.addListener(_onSyncRevision);
      await _sync.initialize(uid);

      _isSyncEnabled = true;
      _syncUid = uid;

      // Pull trong initialize() đã báo qua localRevision nếu có thay đổi;
      // nạp lại thêm 1 lần cho chắc (rẻ) rồi mới đẩy hàng đợi lên.
      await _reloadFromStorage();
      await _sync.flushPending();
    } catch (e, stack) {
      _isSyncEnabled = false;
      _syncUid = null;
      debugPrint('❌ LHB enableSync error: $e\n$stack');
    } finally {
      _isEnablingSync = false;
      notifyListeners();
    }
  }

  void disableSync() {
    _sync.localRevision.removeListener(_onSyncRevision);
    _isSyncEnabled = false;
    _syncUid = null;
    _isEnablingSync = false;
    _sync.dispose();
    notifyListeners();
  }

  /// Đồng bộ ngay: kéo cloud → hòa giải → đẩy thay đổi cục bộ.
  /// [forceAll] = kéo TOÀN BỘ collection (bỏ qua checkpoint).
  Future<void> syncNow({bool forceAll = false}) async {
    if (!_isSyncEnabled) return;
    try {
      await _sync.pullFromFirestore(forceAll: forceAll);
      await _sync.flushPending();
    } catch (e, stack) {
      debugPrint('❌ LHB syncNow error: $e\n$stack');
    }
  }

  /// Đẩy toàn bộ bài cục bộ lên cloud (dùng khi máy này là nguồn dữ liệu).
  Future<void> pushAllToCloud() async {
    if (!_isSyncEnabled) return;
    try {
      await _sync.pushAll();
    } catch (e) {
      debugPrint('❌ LHB pushAllToCloud error: $e');
    }
  }

  void _onSyncRevision() {
    unawaited(_reloadFromStorage());
  }

  // ==================== LIFECYCLE & LOADING ====================

  Future<void> loadData() => _reloadFromStorage(showLoading: true);

  Future<void> _reloadFromStorage({bool showLoading = false}) async {
    if (showLoading) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      _items = await _storage.loadItems();
      _streak = await _storage.getStreak();
    } catch (e) {
      debugPrint('⚠️ LearnByHeartProvider loadData error: $e');
    } finally {
      if (showLoading) _isLoading = false;
      notifyListeners();
    }
  }

  // ==================== ACTIONS & REVIEWS ====================

  /// Đóng dấu mốc thay đổi — mọi ghi cục bộ đều phải đi qua đây để lớp đồng
  /// bộ biết bản nào mới hơn khi hòa giải với cloud.
  LearnByHeartItem _stamp(LearnByHeartItem item) =>
      item.copyWith(updatedAt: DateTime.now());

  /// Gửi kết quả đánh giá Active Recall (FSRS 4 nút)
  Future<void> submitReview({
    required LearnByHeartItem item,
    required FSRSRating rating,
  }) async {
    final updated = _stamp(FSRSEngine.processReview(item: item, rating: rating));
    final index = _items.indexWhere((i) => i.id == item.id);

    if (index >= 0) {
      _items[index] = updated;
    } else {
      _items.add(updated);
    }

    _streak = await _storage.recordStudySession();
    _sync.markStatsDirty();
    await _storage.saveItems(_items);
    _sync.markDirty(updated.id);
    _recordLearningSession(item.id);
    notifyListeners();
  }

  /// Gửi kết quả đánh giá Assessment Layer (3 nút - trọng số x2)
  Future<void> submitAssessment({
    required LearnByHeartItem item,
    required AssessmentRating rating,
  }) async {
    final updated =
        _stamp(FSRSEngine.processAssessment(item: item, rating: rating));
    final index = _items.indexWhere((i) => i.id == item.id);

    if (index >= 0) {
      _items[index] = updated;
    } else {
      _items.add(updated);
    }

    _streak = await _storage.recordStudySession();
    _sync.markStatsDirty();
    await _storage.saveItems(_items);
    _sync.markDirty(updated.id);
    _recordLearningSession(item.id);
    notifyListeners();
  }

  // ==================== HOME-STREAK-001 ====================

  /// Ôn/đánh giá một bài LHB là hoạt động học thật cho "Nhịp điệu học tập".
  /// Khoá theo id bài ⇒ đánh giá lại cùng bài trong ngày không đếm lặp.
  void _recordLearningSession(String itemId) {
    if (itemId.trim().isEmpty) return;
    unawaited(LearningActivityService.instance.record(
      LearningActivityKind.learnByHeart,
      sourceKey: itemId.trim(),
    ));
  }

  /// Bắt đầu học mới 1 bài (chuyển sang trạng thái learning)
  Future<void> startLearning(LearnByHeartItem item) async {
    if (item.reviewState == ReviewState.newItem) {
      final updated = _stamp(item.copyWith(reviewState: ReviewState.learning));
      final index = _items.indexWhere((i) => i.id == item.id);
      if (index >= 0) {
        _items[index] = updated;
        await _storage.saveItems(_items);
        _sync.markDirty(updated.id);
        notifyListeners();
      }
    }
  }

  /// Thêm hoặc cập nhật bài học thuộc lòng
  Future<void> saveItem(LearnByHeartItem item) async {
    final stamped = _stamp(item);
    final index = _items.indexWhere((i) => i.id == item.id);
    if (index >= 0) {
      _items[index] = stamped;
    } else {
      _items.insert(0, stamped);
    }
    await _storage.saveItems(_items);
    _sync.markDirty(stamped.id);
    notifyListeners();
  }

  /// Xóa bài học thuộc lòng (đồng bộ bằng bia mộ — xoá lan sang thiết bị khác)
  Future<void> deleteItem(String id) async {
    _items.removeWhere((i) => i.id == id);
    await _storage.saveItems(_items);
    _sync.markDeleted(id);
    notifyListeners();
  }

  /// Đổi trạng thái yêu thích
  Future<void> toggleFavorite(String id) async {
    final index = _items.indexWhere((i) => i.id == id);
    if (index >= 0) {
      _items[index] = _stamp(_items[index].copyWith(
        isFavorite: !_items[index].isFavorite,
      ));
      await _storage.saveItems(_items);
      _sync.markDirty(id);
      notifyListeners();
    }
  }

  /// Reset toàn bộ về dữ liệu mặc định ban đầu (hành động CỤC BỘ — xem
  /// [LearnByHeartStorage.resetToDefaults]).
  Future<void> resetToDefaults() async {
    _isLoading = true;
    notifyListeners();
    _items = await _storage.resetToDefaults();
    _streak = 0;
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _sync.localRevision.removeListener(_onSyncRevision);
    super.dispose();
  }

  // ==================== FILTERS ====================

  void setCategory(RecitationCategory? cat) {
    _selectedCategory = cat;
    notifyListeners();
  }

  void setStateFilter(ReviewState? state) {
    _selectedStateFilter = state;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }
}
