import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PositionService {
  static const String _key = 'saved_positions';

  SharedPreferences? _prefs;
  Map<String, int> _positions = {};

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadPositions();
  }

  void _loadPositions() {
    final String? data = _prefs?.getString(_key);
    if (data != null) {
      _positions = Map<String, int>.from(json.decode(data));
    }
  }

  Future<void> _savePositions() async {
    await _prefs?.setString(_key, json.encode(_positions));
  }

  Future<void> savePosition(String audioPath, Duration position) async {
    _positions[audioPath] = position.inMilliseconds;
    await _savePositions();
  }

  Duration? getPosition(String audioPath) {
    final ms = _positions[audioPath];
    if (ms == null) return null;
    return Duration(milliseconds: ms);
  }

  Future<void> clearPosition(String audioPath) async {
    _positions.remove(audioPath);
    await _savePositions();
  }

  Future<void> clearAll() async {
    _positions.clear();
    await _savePositions();
  }
}