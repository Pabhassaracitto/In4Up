import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/utils/audio_source_identity.dart';

void main() {
  group('AudioSourceIdentity', () {
    test('normalizes picker representations of the same audio', () {
      expect(
        AudioSourceIdentity.matches(
          r'C:\Lessons\My%20Audio.MP3',
          'c:/lessons/My Audio.mp3',
        ),
        isTrue,
      );
    });

    test('never treats two different audio files as one source', () {
      expect(
        AudioSourceIdentity.matches(
          '/audio/lesson-one.mp3',
          '/audio/lesson-two.mp3',
        ),
        isFalse,
      );
    });

    test('survives malformed percent characters from a local filename', () {
      expect(
        AudioSourceIdentity.normalize('/Audio/100% lesson.M4A'),
        '/audio/100% lesson.m4a',
      );
    });
  });
}
