import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/models/audio_queue_item.dart';
import 'package:in4up/models/audio_library_entry.dart';
import 'package:in4up/models/audio_playlist.dart';
import 'package:in4up/providers/player/playback_queue_controller.dart';

AudioQueueItem track(String name) => AudioQueueItem(source: name, title: name);

void main() {
  test('saved playlist snapshot retains order and missing IDs', () {
    final playlist = AudioPlaylist.create('ordered')
      ..trackIds.addAll(['b', 'missing', 'a']);
    AudioLibraryEntry entry(String id) => AudioLibraryEntry(
      libraryId: id,
      uri: 'content://media/$id',
      title: id,
      addedAt: DateTime(2026),
    );
    final snapshot = AudioQueueItem.fromPlaylist(playlist, [entry('a'), entry('b')]);
    playlist.reorder(0, 3);
    expect(snapshot.map((item) => item.libraryId), ['b', 'missing', 'a']);
    expect(snapshot[1].isMissing, isTrue);
    expect(snapshot[0].source, 'content://media/b');
    expect(playlist.trackIds, ['missing', 'a', 'b']);
  });

  group('PlaybackQueueController', () {
    late List<String> loads;
    late List<String> starts;
    late List<bool> resumes;
    late PlaybackQueueController queue;

    setUp(() {
      loads = [];
      starts = [];
      resumes = [];
      queue = PlaybackQueueController(
        loadTrack: (item, resume, initial, isCurrent) async {
          loads.add(item.source);
          resumes.add(resume);
          return isCurrent();
        },
        onLoaded: (item) => starts.add(item.source),
        onChanged: () {},
      );
    });

    tearDown(() => queue.dispose());

    test('empty and single-track queues have no neighbours', () async {
      expect(await queue.replace([]), isFalse);
      expect(queue.items, isEmpty);
      expect(queue.canGoPrevious, isFalse);
      expect(queue.canGoNext, isFalse);

      expect(await queue.replace([track('a')]), isTrue);
      expect(queue.activeIndex, 0);
      expect(queue.canGoPrevious, isFalse);
      expect(queue.canGoNext, isFalse);
      expect(await queue.advanceAfterCompletion(), isFalse);
      expect(starts, ['a']);
    });

    test('snapshot, next, previous and direct selection have clear policies',
        () async {
      final selected = [track('a'), track('b'), track('c')];
      expect(await queue.replace(selected, startIndex: 1), isTrue);
      selected.clear();
      expect(queue.items.length, 3);
      expect(queue.activeIndex, 1);
      expect(queue.canGoPrevious, isTrue);
      expect(queue.canGoNext, isTrue);

      expect(await queue.next(), isTrue);
      expect(queue.activeIndex, 2);
      expect(queue.canGoNext, isFalse);
      expect(await queue.previous(), isTrue);
      expect(queue.activeIndex, 1);
      expect(await queue.select(0), isTrue);
      expect(queue.canGoPrevious, isFalse);
      expect(loads, ['b', 'c', 'b', 'a']);
      expect(resumes, [true, false, false, true]);
    });

    test('the same source may occupy different queue positions', () async {
      expect(await queue.replace([track('a'), track('a')]), isTrue);
      expect(await queue.next(), isTrue);
      expect(queue.activeIndex, 1);
      expect(starts, ['a', 'a']);
    });

    test('automatic completion skips unavailable tracks without wrapping',
        () async {
      queue.dispose();
      queue = PlaybackQueueController(
        loadTrack: (item, resume, initial, isCurrent) async {
          loads.add(item.source);
          return !item.isMissing && item.source != 'broken';
        },
        onLoaded: (item) => starts.add(item.source),
        onChanged: () {},
      );
      final items = [
        track('a'),
        const AudioQueueItem.missing('removed-id'),
        track('broken'),
        track('d'),
      ];
      expect(await queue.replace(items), isTrue);
      expect(await queue.advanceAfterCompletion(), isTrue);
      expect(queue.activeIndex, 3);
      expect(queue.failedIndices, {1, 2});
      expect(loads, ['a', '', 'broken', 'd']);
      expect(starts, ['a', 'd']);
      expect(await queue.advanceAfterCompletion(), isFalse);
    });

    test('all remaining files failing terminates and leaves errors visible',
        () async {
      queue.dispose();
      queue = PlaybackQueueController(
        loadTrack: (item, resume, initial, isCurrent) async {
          loads.add(item.source);
          return item.source == 'a';
        },
        onLoaded: (item) => starts.add(item.source),
        onChanged: () {},
      );
      await queue.replace([track('a'), track('b'), track('c')]);
      expect(await queue.advanceAfterCompletion(), isFalse);
      expect(loads, ['a', 'b', 'c']);
      expect(queue.failedIndices, {1, 2});
      expect(queue.activeIndex, -1);
      expect(queue.cursor, 2);
      expect(queue.isLoading, isFalse);
      expect(queue.canGoNext, isFalse);
    });

    test('a manual failure does not silently select another item', () async {
      queue.dispose();
      queue = PlaybackQueueController(
        loadTrack: (item, resume, initial, isCurrent) async => item.source != 'b',
        onLoaded: (item) => starts.add(item.source),
        onChanged: () {},
      );
      await queue.replace([track('a'), track('b'), track('c')]);
      expect(await queue.next(), isFalse);
      expect(queue.cursor, 1);
      expect(queue.activeIndex, -1);
      expect(queue.failedIndices, {1});
      expect(starts, ['a']);
      expect(await queue.next(), isTrue);
      expect(starts, ['a', 'c']);
    });

    test('rapid requests serialize loading and only the latest can start',
        () async {
      queue.dispose();
      final waiting = Completer<bool>();
      final entered = Completer<void>();
      var activeLoads = 0;
      var maxActiveLoads = 0;
      queue = PlaybackQueueController(
        loadTrack: (item, resume, initial, isCurrent) async {
          activeLoads++;
          if (activeLoads > maxActiveLoads) maxActiveLoads = activeLoads;
          loads.add(item.source);
          if (item.source == 'b') {
            entered.complete();
            await waiting.future;
          }
          activeLoads--;
          return isCurrent();
        },
        onLoaded: (item) => starts.add(item.source),
        onChanged: () {},
      );
      await queue.replace([track('a'), track('b'), track('c')]);
      final first = queue.next();
      await entered.future;
      final second = queue.next();
      expect(queue.cursor, 2);
      waiting.complete(true);
      expect(await first, isFalse);
      expect(await second, isTrue);
      expect(loads, ['a', 'b', 'c']);
      expect(starts, ['a', 'c']);
      expect(maxActiveLoads, 1);
      expect(queue.activeIndex, 2);
    });

    test('clear invalidates an in-flight load and preserves no queue', () async {
      queue.dispose();
      final waiting = Completer<bool>();
      final entered = Completer<void>();
      queue = PlaybackQueueController(
        loadTrack: (item, resume, initial, isCurrent) async {
          entered.complete();
          await waiting.future;
          return isCurrent();
        },
        onLoaded: (item) => starts.add(item.source),
        onChanged: () {},
      );
      final pending = queue.replace([track('a')]);
      await entered.future;
      queue.clear();
      waiting.complete(true);
      expect(await pending, isFalse);
      await queue.whenIdle;
      expect(queue.items, isEmpty);
      expect(queue.activeIndex, -1);
      expect(starts, isEmpty);
    });
  });
}
