// lib/features/learn_by_heart/controllers/chain_recitation_controller.dart

import 'package:flutter/foundation.dart';
import '../models/learn_by_heart_item.dart';

class ChainStep {
  final int stepIndex;
  final String primePrompt; // Câu mồi (Line N)
  final String targetLine; // Câu mục tiêu cần nhớ (Line N+1)
  final String? primePaliPrompt;
  final String? targetPaliLine;
  bool isCompleted;

  ChainStep({
    required this.stepIndex,
    required this.primePrompt,
    required this.targetLine,
    this.primePaliPrompt,
    this.targetPaliLine,
    this.isCompleted = false,
  });
}

/// Controller điều phối chế độ Nối Xích Kệ Ngôn (Chain Priming Recitation)
class ChainRecitationController extends ChangeNotifier {
  final LearnByHeartItem item;
  final List<ChainStep> _steps = [];

  int _currentStepIndex = 0;
  bool _isCurrentRevealed = false;

  int get currentStepIndex => _currentStepIndex;
  int get totalSteps => _steps.length;
  List<ChainStep> get steps => List.unmodifiable(_steps);
  ChainStep? get currentStep => _steps.isNotEmpty && _currentStepIndex < _steps.length ? _steps[_currentStepIndex] : null;
  bool get isCurrentRevealed => _isCurrentRevealed;
  bool get isAllCompleted => _steps.isNotEmpty && _steps.every((s) => s.isCompleted);

  ChainRecitationController(this.item) {
    _buildChainSteps();
  }

  void _buildChainSteps() {
    final primary = item.memorizeLines;
    final support = item.supportLines;

    if (primary.length <= 1) {
      _steps.add(ChainStep(
        stepIndex: 0,
        primePrompt: item.title,
        targetLine: primary.isNotEmpty ? primary[0] : item.memorizeText,
        targetPaliLine: support.isNotEmpty ? support[0] : item.supportText,
      ));
      return;
    }

    for (int i = 0; i < primary.length - 1; i++) {
      _steps.add(ChainStep(
        stepIndex: i,
        primePrompt: primary[i],
        targetLine: primary[i + 1],
        primePaliPrompt: i < support.length ? support[i] : null,
        targetPaliLine: i + 1 < support.length ? support[i + 1] : null,
      ));
    }
  }

  void revealCurrentTarget() {
    _isCurrentRevealed = true;
    notifyListeners();
  }

  void markStepCompleted() {
    if (currentStep != null) {
      currentStep!.isCompleted = true;
      _isCurrentRevealed = true;
      notifyListeners();
    }
  }

  bool nextStep() {
    if (_currentStepIndex < _steps.length - 1) {
      _currentStepIndex++;
      _isCurrentRevealed = false;
      notifyListeners();
      return true;
    }
    return false;
  }

  bool previousStep() {
    if (_currentStepIndex > 0) {
      _currentStepIndex--;
      _isCurrentRevealed = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  void resetChain() {
    _currentStepIndex = 0;
    _isCurrentRevealed = false;
    for (final s in _steps) {
      s.isCompleted = false;
    }
    notifyListeners();
  }
}
