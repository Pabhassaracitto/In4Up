import 'package:hive/hive.dart';

class PositionService {
  static const String _boxName = 'positions';
  late Box<int> _box;

  Future<void> init() async {
    _box = await Hive.openBox<int>(_boxName);
  }

  // Lưu vị trí (milliseconds)
  Future<void> savePosition(String audioPath, Duration position) async {
    await _box.put(audioPath, position.inMilliseconds);
  }

  // Lấy vị trí đã lưu
  Duration? getPosition(String audioPath) {
    final ms = _box.get(audioPath);
    if (ms == null) return null;
    return Duration(milliseconds: ms);
  }

  // Xóa vị trí
  Future<void> clearPosition(String audioPath) async {
    await _box.delete(audioPath);
  }