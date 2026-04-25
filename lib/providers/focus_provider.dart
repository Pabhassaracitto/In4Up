import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FocusProvider extends ChangeNotifier {
  static const String _streakKey = 'focus_streak';
  static const String _lastEffortKey = 'last_effort_score';
  static const String _lastAssessDateKey = 'last_assessment_date';

  int _streak = 0;
  double _lastEffortScore = 5.0;
  DateTime? _lastAssessmentDate;

  int get streak => _streak;
  double get lastEffortScore => _lastEffortScore;
  bool get hasAssessedToday {
    if (_lastAssessmentDate == null) return false;
    final now = DateTime.now();
    return _lastAssessmentDate!.year == now.year &&
        _lastAssessmentDate!.month == now.month &&
        _lastAssessmentDate!.day == now.day;
  }

  FocusProvider() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _streak = prefs.getInt(_streakKey) ?? 0;
    _lastEffortScore = prefs.getDouble(_lastEffortKey) ?? 5.0;
    final dateStr = prefs.getString(_lastAssessDateKey);
    if (dateStr != null) {
      _lastAssessmentDate = DateTime.parse(dateStr);
    }
    notifyListeners();
  }

  Future<void> saveEffort(double score) async {
    final prefs = await SharedPreferences.getInstance();
    _lastEffortScore = score;
    
    final now = DateTime.now();
    
    // Update streak if it's a new day and score is decent (e.g. > 3)
    if (!hasAssessedToday && score >= 4.0) {
      if (_lastAssessmentDate != null) {
        final diff = now.difference(_lastAssessmentDate!).inDays;
        if (diff == 1) {
          _streak++;
        } else if (diff > 1) {
          _streak = 1;
        }
      } else {
        _streak = 1;
      }
    }

    _lastAssessmentDate = now;
    await prefs.setInt(_streakKey, _streak);
    await prefs.setDouble(_lastEffortKey, _lastEffortScore);
    await prefs.setString(_lastAssessDateKey, now.toIso8601String());
    
    notifyListeners();
  }
}
