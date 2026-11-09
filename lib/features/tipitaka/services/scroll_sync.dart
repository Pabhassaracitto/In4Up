import 'package:flutter/foundation.dart';

/// Order-index based bridge shared by two related edition readers.
class TipitakaScrollSyncController extends ChangeNotifier {
  bool _enabled = false;
  int? sourceBookId;
  int orderIndex = 0;

  bool get enabled => _enabled;

  set enabled(bool value) {
    if (value == _enabled) return;
    _enabled = value;
    notifyListeners();
  }

  void publish({required int bookId, required int order}) {
    if (!_enabled || (sourceBookId == bookId && (orderIndex - order).abs() < 2)) {
      return;
    }
    sourceBookId = bookId;
    orderIndex = order;
    notifyListeners();
  }
}
