// lib/features/learn_by_heart/controllers/learn_by_heart_provider.dart

import 'package:flutter/foundation.dart';
import '../models/fsrs_models.dart';
import '../models/learn_by_heart_item.dart';
import '../models/recitation_category.dart';
import '../models/review_state.dart';
import '../services/fsrs_engine.dart';
import '../services/learn_by_heart_storage.dart';

class LearnByHeartProvider extends ChangeNotifier {
  final LearnByHeartStorage _storage = LearnByHeartStorage.instance;

  List<LearnByHeartItem> _items = [];
  bool _isLoading = false;
  int _streak = 0;

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

  // ==================== LIFECYCLE & LOADING ====================

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();

    try {
      _items = await _storage.loadItems();
      _streak = await _storage.getStreak();
    } catch (e) {
      debugPrint('⚠️ LearnByHeartProvider loadData error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==================== ACTIONS & REVIEWS ====================

  /// Gửi kết quả đánh giá Active Recall (FSRS 4 nút)
  Future<void> submitReview({
    required LearnByHeartItem item,
    required FSRSRating rating,
  }) async {
    final updated = FSRSEngine.processReview(item: item, rating: rating);
    final index = _items.indexWhere((i) => i.id == item.id);

    if (index >= 0) {
      _items[index] = updated;
    } else {
      _items.add(updated);
    }

    _streak = await _storage.recordStudySession();
    await _storage.saveItems(_items);
    notifyListeners();
  }

  /// Gửi kết quả đánh giá Assessment Layer (3 nút - trọng số x2)
  Future<void> submitAssessment({
    required LearnByHeartItem item,
    required AssessmentRating rating,
  }) async {
    final updated = FSRSEngine.processAssessment(item: item, rating: rating);
    final index = _items.indexWhere((i) => i.id == item.id);

    if (index >= 0) {
      _items[index] = updated;
    } else {
      _items.add(updated);
    }

    _streak = await _storage.recordStudySession();
    await _storage.saveItems(_items);
    notifyListeners();
  }

  /// Bắt đầu học mới 1 bài (chuyển sang trạng thái learning)
  Future<void> startLearning(LearnByHeartItem item) async {
    if (item.reviewState == ReviewState.newItem) {
      final updated = item.copyWith(reviewState: ReviewState.learning);
      final index = _items.indexWhere((i) => i.id == item.id);
      if (index >= 0) {
        _items[index] = updated;
        await _storage.saveItems(_items);
        notifyListeners();
      }
    }
  }

  /// Thêm hoặc cập nhật bài học thuộc lòng
  Future<void> saveItem(LearnByHeartItem item) async {
    final index = _items.indexWhere((i) => i.id == item.id);
    if (index >= 0) {
      _items[index] = item;
    } else {
      _items.insert(0, item);
    }
    await _storage.saveItems(_items);
    notifyListeners();
  }

  /// Xóa bài học thuộc lòng
  Future<void> deleteItem(String id) async {
    _items.removeWhere((i) => i.id == id);
    await _storage.saveItems(_items);
    notifyListeners();
  }

  /// Đổi trạng thái yêu thích
  Future<void> toggleFavorite(String id) async {
    final index = _items.indexWhere((i) => i.id == id);
    if (index >= 0) {
      _items[index] = _items[index].copyWith(
        isFavorite: !_items[index].isFavorite,
      );
      await _storage.saveItems(_items);
      notifyListeners();
    }
  }

  /// Reset toàn bộ về dữ liệu mặc định ban đầu
  Future<void> resetToDefaults() async {
    _isLoading = true;
    notifyListeners();
    _items = await _storage.resetToDefaults();
    _streak = 0;
    _isLoading = false;
    notifyListeners();
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
