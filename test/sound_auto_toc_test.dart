// ignore_for_file: avoid_empty_else, avoid_equals_hash_default, avoid_function_literals_in_foreach_calls, avoid_init_to_null, avoid_null_checks_in_equality_operators, avoid_print, avoid_redundant_argument_values, avoid_renaming_method_parameters, avoid_return_types_on_setters, avoid_returning_null_for_void, avoid_setters_without_getters, avoid_shadowing_type_parameters, avoid_single_cascade_in_expression_statements, avoid_slow_async_io, avoid_types_as_parameter_names, avoid_unnecessary_containers, avoid_unused_constructor_parameters, avoid_void_async, avoid_web_libraries_in_flutter, await_only_futures, camel_case_extensions, camel_case_types, constant_identifier_names, control_flow_in_finally, curly_braces_in_flow_control_structures, dead_code, depend_on_referenced_packages, deprecated_member_use, discarded_futures, empty_catches, empty_constructor_bodies, empty_statements, exhaustive_cases, file_names, hash_and_equals, implicit_call_tearoffs, invariant_booleans, join_return_with_assignment, library_annotations, library_names, library_prefixes, library_private_types_in_public_api, no_duplicate_case_values, no_leading_underscores_for_library_prefixes, no_leading_underscores_for_local_identifiers, no_logic_in_create_state, no_wildcard_variable_uses, non_constant_identifier_names, null_check_on_nullable_type_parameter, null_closures, overridden_fields, package_names, package_prefixed_library_names, prefer_adjacent_string_concatenation, prefer_asserts_in_initializer_lists, prefer_collection_literals, prefer_conditional_assignment, prefer_const_constructors, prefer_const_constructors_in_immutables, prefer_const_declarations, prefer_const_literals_to_create_immutables, prefer_contains, prefer_final_fields, prefer_final_locals, prefer_for_elements_to_map_fromIterable, prefer_function_declarations_over_variables, prefer_generic_function_type_aliases, prefer_if_null_operators, prefer_initializing_formals, prefer_inlined_adds, prefer_interpolation_to_compose_strings, prefer_is_empty, prefer_is_not_empty, prefer_is_not_operator, prefer_iterable_where, prefer_null_aware_operators, prefer_spread_collections, prefer_typing_uninitialized_variables, prefer_void_to_null, provide_deprecation_message, recursive_getters, sized_box_for_whitespace, slash_for_doc_comments, sort_child_properties_last, type_init_formals, unnecessary_brace_in_string_interps, unnecessary_const, unnecessary_constructor_name, unnecessary_getters_setters, unnecessary_late, unnecessary_new, unnecessary_null_aware_assignments, unnecessary_nullable_for_final_variable_declarations, unnecessary_overrides, unnecessary_parenthesis, unnecessary_statements, unnecessary_string_escapes, unnecessary_string_interpolations, unnecessary_this, unused_field, unused_import, unused_local_variable, use_build_context_synchronously, use_full_hex_values_for_flutter_colors, use_function_type_syntax_for_parameters, use_key_in_widget_constructors, use_rethrow_when_possible, use_setters_to_change_properties, use_string_buffers, valid_regexps
// test/sound_auto_toc_test.dart
// Test logic thuần của bộ máy tự tạo mục lục (không cần thiết bị/audio).

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/models/vad_settings.dart';
import 'package:in4up/providers/soundlist_provider.dart';
import 'package:in4up/services/sound_auto_toc_service.dart';
import 'package:in4up_stt/in4up_stt.dart';

SttSegment _seg(int id, double startSec, double endSec, String text) {
  return SttSegment(
    id: id,
    uid: 'u$id',
    startSeconds: startSec,
    endSeconds: endSec,
    text: text,
    words: const [],
    avgConfidence: 0.9,
  );
}

void main() {
  group('SoundAutoTocService.buildChapters', () {
    test('slices + whisper → chapter per slice, title = first sentence', () {
      final slices = [
        const AudioSlice(
          start: Duration(seconds: 0),
          end: Duration(seconds: 30),
        ),
        const AudioSlice(
          start: Duration(seconds: 30),
          end: Duration(seconds: 60),
        ),
      ];
      final segments = [
        _seg(0, 0.5, 8.0, 'Xin chào, hôm nay chúng ta học về Tứ Niệm Xứ.'),
        _seg(1, 8.0, 20.0, 'Thân là vô thường.'),
        _seg(2, 35.0, 45.0, 'Cảm thọ cũng vô thường.'),
      ];

      final chapters = SoundAutoTocService.buildChapters(
        audioPath: '/audio/1.mp3',
        slices: slices,
        sttSegments: segments,
        useWhisper: true,
      );

      expect(chapters, hasLength(2));
      expect(chapters[0].title, 'Xin chào, hôm nay chúng ta học về Tứ Niệm Xứ.');
      expect(chapters[0].position, const Duration(seconds: 0));
      expect(chapters[1].title, 'Cảm thọ cũng vô thường.');
      expect(chapters[1].position, const Duration(seconds: 30));
    });

    test('slices only (no whisper) → fallback "Đoạn N · mm:ss"', () {
      final slices = [
        const AudioSlice(
          start: Duration(seconds: 0),
          end: Duration(seconds: 40),
        ),
        const AudioSlice(
          start: Duration(seconds: 40),
          end: Duration(seconds: 90),
        ),
      ];

      final chapters = SoundAutoTocService.buildChapters(
        audioPath: '/audio/2.mp3',
        slices: slices,
        useWhisper: false,
      );

      expect(chapters, hasLength(2));
      expect(chapters[0].title, 'Đoạn 1 · 00:00');
      expect(chapters[1].title, 'Đoạn 2 · 00:40');
      expect(chapters[0].position, const Duration(seconds: 0));
      expect(chapters[1].position, const Duration(seconds: 40));
    });

    test('no slices, many whisper segments → grouped ≤ 80 chapters', () {
      final segments = List.generate(120, (i) {
        return _seg(
          i,
          i * 2.0,
          i * 2.0 + 1.5,
          'Câu số $i nội dung khá dài để kiểm tra việc gom nhóm chapter.',
        );
      });

      final chapters = SoundAutoTocService.buildChapters(
        audioPath: '/audio/3.mp3',
        slices: const [],
        sttSegments: segments,
        useWhisper: true,
      );

      expect(chapters.length, lessThanOrEqualTo(80));
      expect(chapters.first.position, const Duration(seconds: 0));
      expect(chapters.first.title, contains('Câu số'));
    });

    test('title is truncated to 64 chars and cleaned', () {
      final long = '  --  '
          'Từ bi là một phẩm chất vô cùng quan trọng trong đời sống tâm linh '
          'và chúng ta nên thực tập mỗi ngày để tâm được an lạc hơn.';
      final segments = [_seg(0, 1, 5, long)];

      final chapters = SoundAutoTocService.buildChapters(
        audioPath: '/audio/4.mp3',
        slices: const [
          AudioSlice(start: Duration.zero, end: Duration(seconds: 30)),
        ],
        sttSegments: segments,
        useWhisper: true,
      );

      expect(chapters.single.title.length, lessThanOrEqualTo(65));
      expect(chapters.single.title, isNot(startsWith('--')));
    });
  });

  group('SoundlistProvider.transcriptFromLrcLines', () {
    test('builds lines with end = next line timestamp (fallback +3s)', () {
      final provider = SoundlistProvider();
      final lines = [
        LrcLine(timestamp: const Duration(seconds: 1), text: 'Hello world'),
        LrcLine(timestamp: const Duration(seconds: 5), text: 'Second line'),
        LrcLine(timestamp: const Duration(seconds: 5), text: '   '), // bỏ dòng trống
      ];

      final t = provider.transcriptFromLrcLines('/a.mp3', lines);

      expect(t, isNotNull);
      expect(t!.lineCount, 2);
      expect(t.lines[0].text, 'Hello world');
      expect(t.lines[0].start, const Duration(seconds: 1));
      expect(t.lines[0].end, const Duration(seconds: 5));
      expect(t.lines[1].end, const Duration(seconds: 8)); // dòng cuối + 3s
      expect(t.fullText, contains('Second line'));
    });

    test('returns null for empty lines', () {
      final provider = SoundlistProvider();
      expect(provider.transcriptFromLrcLines('/a.mp3', const []), isNull);
    });
  });

  group('SoundAutoTocService.computeBoundaryMs', () {
    test('phát hiện ranh giới ở giữa khoảng lặng dài', () {
      // 600 mẫu = 60s (1 mẫu = 100ms): nói 20s, lặng 8s (200..280), nói tiếp.
      final peaks = List<double>.generate(600, (i) {
        if (i >= 200 && i < 280) return 0.01; // im lặng
        return 0.7; // có tiếng
      });

      final boundaries = SoundAutoTocService.computeBoundaryMs(
        peaks,
        60000,
        settings: VadSettings.normal, // minSilence 0.9s
      );

      expect(boundaries, isNotEmpty);
      // Ranh giới ~ giữa khoảng lặng: (200+280)/2 = 240 → 24000ms.
      expect(boundaries.first, closeTo(24000, 2000));
    });

    test('không có im lặng → không có ranh giới (UI sẽ dùng fallback chia đều)', () {
      final peaks = List<double>.filled(600, 0.8);
      final boundaries = SoundAutoTocService.computeBoundaryMs(
        peaks,
        60000,
        settings: VadSettings.normal,
      );
      expect(boundaries, isEmpty);
    });
  });
}
