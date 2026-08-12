// lib/features/learn_by_heart/screens/assessment_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../controllers/learn_by_heart_provider.dart';
import '../models/fsrs_models.dart';
import '../models/learn_by_heart_item.dart';
import '../widgets/assessment_rating_bar.dart';

class AssessmentScreen extends StatefulWidget {
  final LearnByHeartItem item;

  const AssessmentScreen({super.key, required this.item});

  @override
  State<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen> {
  bool _isRecitationFinished = false;

  void _onFinishReadingInMind() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isRecitationFinished = true;
    });
  }

  Future<void> _handleAssessmentRating(AssessmentRating rating) async {
    final provider = context.read<LearnByHeartProvider>();
    await provider.submitAssessment(item: widget.item, rating: rating);

    if (!mounted) return;

    final String message;
    final Color snackColor;

    switch (rating) {
      case AssessmentRating.heavyMistake:
        message = 'Đã ghi nhận củng cố lại. FSRS sẽ đưa vào lịch ôn tập sớm.';
        snackColor = const Color(0xFFE53935);
        break;
      case AssessmentRating.nearCorrect:
        message = 'Rất tốt! Giữ vững tiến độ để đạt chuẩn thuộc lòng 100%.';
        snackColor = const Color(0xFFFB8C00);
        break;
      case AssessmentRating.perfect:
        message = 'Xuất sắc! Trí nhớ bền vững được tăng gấp đôi (2x FSRS Weight).';
        snackColor = const Color(0xFF43A047);
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: snackColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Scaffold(
      backgroundColor: const Color(0xFF080B1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: const Text(
          'Kiểm tra thực chất (Assessment)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Item Header Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF4CAF50).withValues(alpha: 0.15),
                            const Color(0xFF1E293B),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50).withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'CHẾ ĐỘ KHÔNG GỢI Ý',
                              style: TextStyle(
                                color: Color(0xFF81C784),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            item.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (item.subtitle.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              item.subtitle,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey[300],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Stage 1: Blank Recitation Prompt
                    if (!_isRecitationFinished) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.psychology_alt_rounded,
                              size: 64,
                              color: Color(0xFF81C784),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Hãy tự đọc toàn bài trong đầu',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Cố gắng nhẩm lại từng câu một cách trọn vẹn nhất trước khi mở văn bản đối chiếu.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 36),
                            ElevatedButton.icon(
                              onPressed: _onFinishReadingInMind,
                              icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                              label: const Text(
                                'Tôi đã đọc xong trong đầu',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4CAF50),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Stage 2: Full Text Comparison Reveal
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.compare_arrows_rounded, color: Color(0xFF4CAF50), size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'ĐỐI CHIẾU TOÀN VĂN',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Pali Section
                            if (item.paliText.isNotEmpty) ...[
                              Text(
                                'Nguyên văn Pali:',
                                style: TextStyle(
                                  color: const Color(0xFFFFD54F),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  item.paliText,
                                  style: const TextStyle(
                                    color: Color(0xFFFFE082),
                                    fontSize: 15,
                                    fontStyle: FontStyle.italic,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Vietnamese Section
                            Text(
                              'Bản dịch Tiếng Việt:',
                              style: TextStyle(
                                color: const Color(0xFF81C784),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                item.vietnameseText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Bottom Rating Bar (Only when finished)
            if (_isRecitationFinished)
              AssessmentRatingBar(
                onRated: _handleAssessmentRating,
              ),
          ],
        ),
      ),
    );
  }
}
