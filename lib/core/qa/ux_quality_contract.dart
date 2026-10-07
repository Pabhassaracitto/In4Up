import 'package:flutter/foundation.dart';

enum I4uQualityCheck { responsive, accessibility, keyboard, safeArea, statePreservation, offlineRecovery }

enum I4uQualityStatus { notRun, pass, fail, blocked }

@immutable
class I4uQualityFinding {
  const I4uQualityFinding({required this.check, required this.status, this.details});
  final I4uQualityCheck check;
  final I4uQualityStatus status;
  final String? details;
}

@immutable
class I4uQualityRun {
  const I4uQualityRun({this.findings = const []});
  final List<I4uQualityFinding> findings;

  bool get isReadyForFreeze => findings.isNotEmpty && findings.every(
        (finding) => finding.status == I4uQualityStatus.pass,
      );

  bool get hasBlocker => findings.any(
        (finding) => finding.status == I4uQualityStatus.fail,
      );
}
