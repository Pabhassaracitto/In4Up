import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/knowledge/engine/adapters/use_form_engine.dart';

void main() {
  group('UseFormEngine — inflection rules', () {
    group('plural', () {
      test('regular: +s', () {
        expect(UseFormEngine.generateForm('cat', InflectionForm.plural), 'cats');
        expect(UseFormEngine.generateForm('dog', InflectionForm.plural), 'dogs');
      });

      test('s/x/ch/sh: +es', () {
        expect(UseFormEngine.generateForm('box', InflectionForm.plural), 'boxes');
        expect(UseFormEngine.generateForm('bus', InflectionForm.plural), 'buses');
        expect(UseFormEngine.generateForm('church', InflectionForm.plural), 'churches');
        expect(UseFormEngine.generateForm('dish', InflectionForm.plural), 'dishes');
      });

      test('consonant + y: ies', () {
        expect(UseFormEngine.generateForm('city', InflectionForm.plural), 'cities');
        expect(UseFormEngine.generateForm('baby', InflectionForm.plural), 'babies');
      });

      test('vowel + y: +s', () {
        expect(UseFormEngine.generateForm('day', InflectionForm.plural), 'days');
        expect(UseFormEngine.generateForm('boy', InflectionForm.plural), 'boys');
      });
    });

    group('gerund', () {
      test('regular: +ing', () {
        expect(UseFormEngine.generateForm('run', InflectionForm.gerund), 'running');
        expect(UseFormEngine.generateForm('walk', InflectionForm.gerund), 'walking');
      });

      test('silent e: drop e + ing', () {
        expect(UseFormEngine.generateForm('use', InflectionForm.gerund), 'using');
        expect(UseFormEngine.generateForm('make', InflectionForm.gerund), 'making');
      });
    });

    group('past', () {
      test('regular: +ed', () {
        expect(UseFormEngine.generateForm('walk', InflectionForm.past), 'walked');
        expect(UseFormEngine.generateForm('play', InflectionForm.past), 'played');
      });

      test('silent e: +d', () {
        expect(UseFormEngine.generateForm('use', InflectionForm.past), 'used');
        expect(UseFormEngine.generateForm('like', InflectionForm.past), 'liked');
      });

      test('consonant + y: ied', () {
        expect(UseFormEngine.generateForm('study', InflectionForm.past), 'studied');
      });
    });

    group('comparative', () {
      test('regular: +er', () {
        expect(UseFormEngine.generateForm('big', InflectionForm.comparative), 'bigger');
        expect(UseFormEngine.generateForm('tall', InflectionForm.comparative), 'taller');
      });

      test('silent e: +r', () {
        expect(UseFormEngine.generateForm('nice', InflectionForm.comparative), 'nicer');
      });
    });

    group('check', () {
      test('đúng dạng → isCorrect', () {
        final r = UseFormEngine.check(
          baseWord: 'cat',
          form: InflectionForm.plural,
          userAnswer: 'cats',
        );
        expect(r.isCorrect, isTrue);
        expect(r.hasRule, isTrue);
        expect(r.correctForm, 'cats');
      });

      test('sai dạng → isCorrect false', () {
        final r = UseFormEngine.check(
          baseWord: 'cat',
          form: InflectionForm.plural,
          userAnswer: 'cat',
        );
        expect(r.isCorrect, isFalse);
      });

      test('normalize: case + dấu không ảnh hưởng', () {
        final r = UseFormEngine.check(
          baseWord: 'city',
          form: InflectionForm.plural,
          userAnswer: 'Cities',
        );
        expect(r.isCorrect, isTrue);
      });

      test('thirdPerson = plural rules', () {
        final r = UseFormEngine.check(
          baseWord: 'run',
          form: InflectionForm.thirdPerson,
          userAnswer: 'runs',
        );
        expect(r.isCorrect, isTrue);
      });
    });
  });
}
