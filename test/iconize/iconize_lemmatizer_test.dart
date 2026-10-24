// test/iconize/iconize_lemmatizer_test.dart
//
// ICONIZE-001b — lemmatizer: bảng bất quy tắc thật (assets/iconize/) +
// luật đuôi. Gồm các case bộ vàng blueprint Khối F: saw/ran/mice.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/iconize/engine/iconize_lemmatizer.dart';

void main() {
  final lemmatizer = IconizeLemmatizer.fromJsonString(
      File('assets/iconize/irregular_lemmas.json').readAsStringSync());
  // Từ điển tham chiếu giả lập cho luật -ing/-ed/-s.
  const dict = {
    'cat', 'dog', 'mouse', 'run', 'make', 'save', 'stop', 'jump',
    'glass', 'bus', 'catch', 'box', 'baby', 'study', 'house', 'horse',
  };
  bool known(String w) => dict.contains(w);

  group('bất quy tắc (bảng thật)', () {
    test('danh từ: mice/men/children/feet', () {
      expect(lemmatizer.lemma('mice'), 'mouse');
      expect(lemmatizer.lemma('men'), 'man');
      expect(lemmatizer.lemma('children'), 'child');
      expect(lemmatizer.lemma('feet'), 'foot');
    });

    test('động từ: saw/ran/caught/went/ate', () {
      expect(lemmatizer.lemma('saw'), 'see');
      expect(lemmatizer.lemma('ran'), 'run');
      expect(lemmatizer.lemma('caught'), 'catch');
      expect(lemmatizer.lemma('went'), 'go');
      expect(lemmatizer.lemma('ate'), 'eat');
    });

    test('bảng nạp đủ (>= 150 dạng)', () {
      expect(lemmatizer.irregularCount, greaterThanOrEqualTo(150));
    });
  });

  group('luật đuôi', () {
    test('-s thường: cats → cat; horses → horse', () {
      expect(lemmatizer.lemma('cats', isKnown: known), 'cat');
      expect(lemmatizer.lemma('horses', isKnown: known), 'horse');
    });

    test('-es sau ch/x: catches → catch, boxes → box', () {
      expect(lemmatizer.lemma('catches', isKnown: known), 'catch');
      expect(lemmatizer.lemma('boxes', isKnown: known), 'box');
    });

    test('-ies: babies → baby, studies → study', () {
      expect(lemmatizer.lemma('babies', isKnown: known), 'baby');
      expect(lemmatizer.lemma('studies', isKnown: known), 'study');
    });

    test('KHÔNG cắt -ss/-us/-is: glass/bus giữ nguyên', () {
      expect(lemmatizer.lemma('glass', isKnown: known), 'glass');
      expect(lemmatizer.lemma('bus', isKnown: known), 'bus');
    });

    test('-ing: running → run (phụ âm đôi), making → make (+e)', () {
      expect(lemmatizer.lemma('running', isKnown: known), 'run');
      expect(lemmatizer.lemma('making', isKnown: known), 'make');
      expect(lemmatizer.lemma('jumping', isKnown: known), 'jump');
    });

    test('-ed: stopped → stop, saved → save, jumped → jump', () {
      expect(lemmatizer.lemma('stopped', isKnown: known), 'stop');
      expect(lemmatizer.lemma('saved', isKnown: known), 'save');
      expect(lemmatizer.lemma('jumped', isKnown: known), 'jump');
    });

    test('từ đã là lemma trong từ điển → giữ nguyên', () {
      expect(lemmatizer.lemma('cat', isKnown: known), 'cat');
      expect(lemmatizer.lemma('house', isKnown: known), 'house');
    });
  });
}
