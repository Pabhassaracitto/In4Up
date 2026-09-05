import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/pic_models.dart';

class PicAnkiStore extends ChangeNotifier {
  PicAnkiStore._();
  static final PicAnkiStore instance = PicAnkiStore._();

  static const String boxName = 'pic_anki_decks';
  static const _uuid = Uuid();

  Box<Map>? _box;
  final List<PicDeck> _decks = <PicDeck>[];

  List<PicDeck> get decks => List<PicDeck>.unmodifiable(_decks);

  int dueCount(DateTime now) =>
      _decks.fold(0, (n, d) => n + d.dueCount(now));

  Future<void> ensureInit() async {
    if (_box != null) return;
    try {
      final box = await Hive.openBox<Map>(boxName);
      _box = box;
      _reload();
    } catch (e) {
      debugPrint('PicAnkiStore init: $e');
    }
  }

  void _reload() {
    final box = _box;
    if (box == null) return;
    _decks
      ..clear()
      ..addAll(
        box.values.map((v) => PicDeck.fromJson(Map<String, dynamic>.from(v))),
      );
    _decks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    notifyListeners();
  }

  PicDeck? byId(String id) {
    for (final d in _decks) {
      if (d.id == id) return d;
    }
    return null;
  }

  Future<PicDeck> importImage(String sourcePath, {String? title}) async {
    await ensureInit();
    final id = _uuid.v4();
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'pic_anki'));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    final ext = p.extension(sourcePath).isEmpty ? '.jpg' : p.extension(sourcePath);
    final dest = p.join(dir.path, '$id$ext');
    await File(sourcePath).copy(dest);
    final name = title?.trim().isNotEmpty == true
        ? title!.trim()
        : p.basenameWithoutExtension(sourcePath);
    final deck = PicDeck(
      id: id,
      title: name,
      imagePath: dest,
      createdAt: DateTime.now(),
    );
    await save(deck);
    return deck;
  }

  Future<void> save(PicDeck deck) async {
    await ensureInit();
    final box = _box;
    if (box == null) return;
    await box.put(deck.id, deck.toJson());
    final i = _decks.indexWhere((d) => d.id == deck.id);
    if (i >= 0) {
      _decks[i] = deck;
    } else {
      _decks.insert(0, deck);
    }
    notifyListeners();
  }

  Future<void> delete(String id) async {
    await ensureInit();
    final existing = byId(id);
    final box = _box;
    if (box == null) return;
    await box.delete(id);
    if (existing != null && existing.imagePath.isNotEmpty) {
      try {
        final f = File(existing.imagePath);
        if (f.existsSync()) await f.delete();
      } catch (_) {}
    }
    _decks.removeWhere((d) => d.id == id);
    notifyListeners();
  }
}
