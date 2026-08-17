import 'package:flutter_test/flutter_test.dart';
import 'package:in2up/features/writing/models/writing_assignment.dart';
import 'package:in2up/features/writing/models/writing_source_request.dart';
import 'package:in2up/features/writing/services/document_summary_signal_service.dart';
import 'package:in2up/features/writing/services/writing_draft_store.dart';
import 'package:in2up/features/writing/services/writing_sentence_segmenter.dart';

void main() {
  const excerptRequest = WritingSourceRequest(
    task: WritingTaskType.rewrite,
    kind: WritingSourceKind.web,
    sourceLabel: 'Example article',
    isExcerpt: true,
  );

  WritingAssignmentContext contextFor({
    required String fullText,
    WritingSourceRequest? request,
    List<String>? lines,
    int lineIndex = 0,
  }) {
    return WritingAssignmentContext(
      sourceKey: 'source-key',
      sourceTitle: 'Source title',
      fullText: fullText,
      lines: lines ?? [fullText],
      lineIndex: lineIndex,
      request: request,
    );
  }

  group('WritingAssignment.fromContext', () {
    test('keeps a one-sentence excerpt as sentence-level rewrite', () {
      final assignment = WritingAssignment.fromContext(
        context: contextFor(
          fullText: 'Learning takes deliberate practice.',
          request: excerptRequest,
        ),
        task: WritingTaskType.rewrite,
      );

      expect(assignment.origin, AssignmentOrigin.excerpt);
      expect(assignment.scoringProfile, ScoringProfile.sentenceLevel);
      expect(assignment.showLineNavigator, isFalse);
      expect(assignment.needsContextPreview, isFalse);
      expect(assignment.sourceText, assignment.contextText);
    });

    test('multi-sentence excerpt rewrite scores only the first sentence', () {
      const excerpt =
          'Learning takes deliberate practice. Feedback makes practice useful. Reflection makes it stick.';
      final assignment = WritingAssignment.fromContext(
        context: contextFor(fullText: excerpt, request: excerptRequest),
        task: WritingTaskType.rewrite,
      );

      expect(assignment.origin, AssignmentOrigin.excerpt);
      expect(assignment.scoringProfile, ScoringProfile.sentenceLevel);
      expect(assignment.sourceText, 'Learning takes deliberate practice.');
      expect(assignment.contextText, excerpt);
      expect(assignment.needsContextPreview, isTrue);
      expect(assignment.showLineNavigator, isFalse);
    });

    test('excerpt summary uses document signals without line navigation', () {
      final assignment = WritingAssignment.fromContext(
        context: contextFor(
          fullText: 'First idea. Second idea.',
          request: excerptRequest,
        ),
        task: WritingTaskType.summary,
      );

      expect(assignment.origin, AssignmentOrigin.excerpt);
      expect(assignment.scoringProfile, ScoringProfile.documentSignals);
      expect(assignment.showLineNavigator, isFalse);
      expect(assignment.sourceText, assignment.contextText);
    });

    test('full-document handoff uses document signals only for summary', () {
      const request = WritingSourceRequest(
        task: WritingTaskType.summary,
        kind: WritingSourceKind.pdf,
        sourceLabel: 'Paper.pdf',
        isExcerpt: false,
      );
      final context = contextFor(
        fullText: 'First line. Second line.',
        request: request,
        lines: const ['First line.', 'Second line.'],
        lineIndex: 1,
      );

      final summary = WritingAssignment.fromContext(
        context: context,
        task: WritingTaskType.summary,
      );
      final rewrite = WritingAssignment.fromContext(
        context: context,
        task: WritingTaskType.rewrite,
      );

      expect(summary.origin, AssignmentOrigin.fullDocument);
      expect(summary.scoringProfile, ScoringProfile.documentSignals);
      expect(summary.showLineNavigator, isFalse);
      expect(rewrite.origin, AssignmentOrigin.perLine);
      expect(rewrite.scoringProfile, ScoringProfile.sentenceLevel);
      expect(rewrite.sourceText, 'Second line.');
      expect(rewrite.showLineNavigator, isTrue);
    });

    test('assignment id is deterministic for the same input', () {
      final context = contextFor(fullText: 'Stable source.');
      final first = WritingAssignment.fromContext(
        context: context,
        task: WritingTaskType.dictation,
      );
      final second = WritingAssignment.fromContext(
        context: context,
        task: WritingTaskType.dictation,
      );

      expect(first.id, second.id);
    });
  });

  group('WritingDraftKey', () {
    test('separates drafts by source, task and assignment', () {
      const base = WritingDraftKey(
        sourceKey: 'source-a',
        task: WritingTaskType.rewrite,
        assignmentId: 'assignment-a',
      );
      const otherTask = WritingDraftKey(
        sourceKey: 'source-a',
        task: WritingTaskType.summary,
        assignmentId: 'assignment-a',
      );
      const otherAssignment = WritingDraftKey(
        sourceKey: 'source-a',
        task: WritingTaskType.rewrite,
        assignmentId: 'assignment-b',
      );

      expect(base.storageId, isNot(otherTask.storageId));
      expect(base.storageId, isNot(otherAssignment.storageId));
    });
  });

  group('WritingSentenceSegmenter', () {
    test('does not split common abbreviations', () {
      const text =
          'Mr. Smith moved to the U.S. last year. He now teaches there.';
      final sentences = WritingSentenceSegmenter.split(text);

      expect(sentences, hasLength(2));
      expect(sentences.first, 'Mr. Smith moved to the U.S. last year.');
    });

    test('keeps decimal periods inside a sentence', () {
      final sentences = WritingSentenceSegmenter.split(
        'The score was 3.5 points. It later improved.',
      );

      expect(sentences, hasLength(2));
      expect(sentences.first, 'The score was 3.5 points.');
    });
  });

  group('DocumentSummarySignalService', () {
    test('returns observations rather than a synthetic overall score', () {
      final signals = DocumentSummarySignalService.analyze(
        sourceText:
            'Deliberate practice needs focused repetition and useful feedback.',
        draftText: 'Focused practice improves through useful feedback.',
      );

      expect(signals.sourceWordCount, 8);
      expect(signals.draftWordCount, 6);
      expect(signals.compressionRatio, closeTo(0.75, 0.001));
      expect(signals.keywordPresenceRatio, inInclusiveRange(0.0, 1.0));
      expect(signals.copiedPhraseRatio, inInclusiveRange(0.0, 1.0));
    });
  });
}
