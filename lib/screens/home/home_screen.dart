import 'dart:math' as math;

import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter/services.dart';
import 'package:in4up/l10n/app_localizations.dart';

import '../../core/responsive/app_responsive.dart';
import '../settings/stt_model_settings_screen.dart';
import '../../services/auth_service.dart';
import 'quick_capture/quick_capture_sheet.dart';
import 'quick_capture/quick_suggestion_sheet.dart';
import 'widgets/continue_learning_card.dart';
import 'widgets/focus_streak_card.dart';
import 'widgets/knowledge_graph_preview.dart';
import 'widgets/memory_garden_card.dart';

class HomeScreen extends StatefulWidget {
  /// Phòng Studio: 7 mode riêng — mỗi card mở đúng một sub-mode của shell.
  /// NGHE/NÓI/XEM = listen sub-mode 0/1/2; ĐỌC/VIẾT = read sub-mode 0/1.
  final VoidCallback onNavigateToListen;
  final VoidCallback onNavigateToSpeak;
  final VoidCallback onNavigateToWatch;
  final VoidCallback onNavigateToRead;
  final VoidCallback onNavigateToWrite;
  final VoidCallback onNavigateToUnderstand;
  final VoidCallback onNavigateToMemory;
  final VoidCallback onOpenAiChat;
  final VoidCallback? onOpenTextLibrary;

  const HomeScreen({
    super.key,
    required this.onNavigateToListen,
    required this.onNavigateToSpeak,
    required this.onNavigateToWatch,
    required this.onNavigateToRead,
    required this.onNavigateToWrite,
    required this.onNavigateToUnderstand,
    required this.onNavigateToMemory,
    required this.onOpenAiChat,
    this.onOpenTextLibrary,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF080B1A),
      child: Stack(
        children: [
          const _AnimatedBackground(),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {},
              backgroundColor: const Color(0xFF1A1A2E),
              color: const Color(0xFF6C63FF),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final horizontalPadding =
                      AppResponsive.pageHorizontalPadding(constraints.maxWidth);

                  return ResponsiveContentFrame(
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(child: _buildGlassHeader(context)),
                        // 1. HERO: "Tiếp tục học" đứng đầu dashboard — đưa người
                        // học quay lại đúng hoạt động đang dở từ dữ liệu thật.
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            horizontalPadding,
                            8,
                            horizontalPadding,
                            8,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: ContinueLearningCard(
                              onResumeListening: widget.onNavigateToListen,
                              onResumeReading: widget.onNavigateToRead,
                              onReviewDue: widget.onNavigateToMemory,
                            ),
                          ),
                        ),
                        // 2. BENTO AI + Gợi ý nhanh (gộp I4U AI Chat & Gợi ý từ vựng,
                        // bỏ HebbianInputCard lặp lại nút Mic với FAB).
                        SliverPadding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                            vertical: 8,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: _buildAiAndQuickSuggestionRow(context),
                          ),
                        ),
                        // 3. Lối tắt Studio chuyên biệt (chỉ giữ các sub-mode
                        // phụ Viết · Nói · Xem không nằm trực tiếp trên BottomNav).
                        SliverPadding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                            vertical: 8,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: _buildStudioSubmodesStrip(context),
                          ),
                        ),
                        // 4. BENTO Tiến độ (2 cột trên tablet/desktop, dọc gọn trên phone).
                        SliverPadding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                            vertical: 8,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: _buildProgressBento(context),
                          ),
                        ),
                        SliverPadding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                            vertical: 8,
                          ),
                          sliver: const SliverToBoxAdapter(
                            child: KnowledgeGraphPreview(),
                          ),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 96)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: _buildOmniMicrophone(),
          ),
        ],
      ),
    );
  }

  Widget _buildAiAndQuickSuggestionRow(BuildContext context) {
    final aiCard = InkWell(
      onTap: widget.onOpenAiChat,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF312E81), Color(0xFF172554)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Color(0xFFE9D5FF), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.uiText('I4U AI Chat'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.uiText('Hỏi đáp về từ vựng và ngữ pháp'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: Colors.white70),
          ],
        ),
      ),
    );

    final suggestionBtn = InkWell(
      onTap: _openSuggestion,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF00D1FF).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFF00D1FF).withValues(alpha: 0.28),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.tips_and_updates_outlined,
              color: Color(0xFF00D1FF),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              context.uiText('Gợi ý'),
              style: const TextStyle(
                color: Color(0xFF00D1FF),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 360) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              aiCard,
              const SizedBox(height: 8),
              suggestionBtn,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: aiCard),
            const SizedBox(width: 10),
            suggestionBtn,
          ],
        );
      },
    );
  }

  Widget _buildGlassHeader(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // PSRC-247 (owner 2026-11-15) — HOÁN ĐỔI hai biểu tượng:
    //   * ô góc trái trên của AppBar shell = **Thư viện Đọc** ở MỌI tab
    //     (trước đây ở Home ô này là robot ⇒ cùng một ô đổi nghĩa theo tab,
    //     còn thư viện lại nằm thêm ở header này ⇒ trùng chỗ);
    //   * header Home = **robot «Quản lý Model AI»** đặt cạnh nút Đăng nhập.
    final headerActions = <Widget>[
      IconButton(
        key: const Key('home-model-ai'),
        icon: const Icon(
          Icons.smart_toy_outlined,
          color: Color(0xFFFF9800),
          size: 24,
        ),
        tooltip: context.uiText('Quản lý Model AI'),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SttModelSettingsScreen()),
        ),
      ),
      _FirebaseAuthButton(),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = AppResponsive.isCompact(constraints.maxWidth);
        final horizontal = isCompact ? 16.0 : 24.0;

        return Padding(
          padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 4),
          child: Row(
            children: [
              Expanded(child: _buildHeaderTextBlock(context, l10n)),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: headerActions,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderTextBlock(BuildContext context, AppLocalizations l10n) {
    return Text(
      l10n.knowledgeOS,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: Colors.white,
        letterSpacing: -0.5,
      ),
    );
  }

  Widget _buildStudioSubmodesStrip(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = [
      (
        icon: Icons.edit_note_rounded,
        title: context.uiText('Viết'),
        color: const Color(0xFF26C6DA),
        onTap: widget.onNavigateToWrite,
      ),
      (
        icon: Icons.mic_rounded,
        title: context.uiText('Nói'),
        color: const Color(0xFFB388FF),
        onTap: widget.onNavigateToSpeak,
      ),
      (
        icon: Icons.smart_display_rounded,
        title: context.uiText('Xem'),
        color: const Color(0xFFFFB300),
        onTap: widget.onNavigateToWatch,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.studioRoom,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Colors.grey,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _StudioPillTile(
                  icon: items[i].icon,
                  title: items[i].title,
                  color: items[i].color,
                  onTap: items[i].onTap,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildProgressBento(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoCols = constraints.maxWidth >= 720;
        if (twoCols) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(child: FocusStreakCard()),
              const SizedBox(width: 12),
              Expanded(
                child: MemoryGardenCard(
                  onStartReview: widget.onNavigateToMemory,
                ),
              ),
            ],
          );
        }
        return Column(
          children: [
            const FocusStreakCard(),
            const SizedBox(height: 12),
            MemoryGardenCard(
              onStartReview: widget.onNavigateToMemory,
            ),
          ],
        );
      },
    );
  }

  /// HOME-QUICK-001 — MỘT flow STT thật dùng chung cho FAB microphone và
  /// nút "Ghi chú nói" của card: ưu tiên Sherpa offline khi đã có model,
  /// fallback speech service hệ thống; transcript realtime; dừng sạch khi
  /// đóng sheet; lưu vào WordList hoặc ghi chú nói.
  void _openQuickCapture() {
    HapticFeedback.mediumImpact();
    QuickCaptureSheet.show(context);
  }

  /// Nút "Gợi ý": hiện MỘT entry thật từ WordList (ưu tiên thẻ đến kỳ ôn).
  void _openSuggestion() {
    HapticFeedback.lightImpact();
    QuickSuggestionSheet.show(context);
  }

  Widget _buildOmniMicrophone() {
    return FloatingActionButton(
      heroTag: 'home_omni_microphone',
      onPressed: _openQuickCapture,
      backgroundColor: const Color(0xFF6C63FF),
      tooltip: context.uiText('Nạp tri thức nhanh'),
      child: const Icon(Icons.mic, color: Colors.white, size: 30),
    );
  }
}

class _StudioPillTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _StudioPillTile({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.24)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedBackground extends StatelessWidget {
  const _AnimatedBackground();

  @override
  Widget build(BuildContext context) {
    return const RepaintBoundary(
      child: CustomPaint(
        painter: _BackgroundPainter(0.5),
        child: SizedBox.expand(),
      ),
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  final double t;

  const _BackgroundPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);

    paint.color = const Color(0xFF6C63FF).withValues(alpha: 0.1);
    canvas.drawCircle(
      Offset(
        size.width * (0.3 + 0.1 * math.sin(t * 2 * math.pi)),
        size.height * (0.2 + 0.1 * math.cos(t * 2 * math.pi)),
      ),
      size.width * 0.4,
      paint,
    );

    paint.color = const Color(0xFF2196F3).withValues(alpha: 0.08);
    canvas.drawCircle(
      Offset(
        size.width * (0.8 + 0.1 * math.cos(t * 2 * math.pi)),
        size.height * (0.7 + 0.1 * math.sin(t * 2 * math.pi)),
      ),
      size.width * 0.5,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FirebaseAuthButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Stream thống nhất: Firebase plugin (Android/Win/macOS) hoặc REST fallback
    // (Linux — firebase_auth không có plugin native).
    final auth = AuthService();
    return StreamBuilder<AppUser?>(
      stream: auth.authStateChanges,
      builder: (context, snapshot) {
        // Không để trạng thái Firebase treo vô hạn che nút tài khoản. REST
        // fallback/Linux có thể không phát event đầu tiên; vẫn cho phép mở
        // đăng nhập thay vì hiển thị spinner vĩnh viễn.
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return IconButton(
            tooltip: 'Đăng nhập',
            icon: const Icon(Icons.account_circle_outlined,
                color: Colors.white, size: 28),
            onPressed: () => _handleSignIn(context),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return IconButton(
            icon: const Icon(
              Icons.account_circle_outlined,
              color: Colors.white,
              size: 28,
            ),
            onPressed: () => _handleSignIn(context),
          );
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundImage:
                  user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
              child: user.photoUrl == null
                  ? Text(user.displayName?[0] ?? 'U')
                  : null,
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white, size: 20),
              onPressed: () => AuthService().signOut(),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleSignIn(BuildContext context) async {
    try {
      await AuthService().signInWithGoogle();
    } catch (e) {
      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.loginFailed(e.toString()))),
      );
    }
  }
}
