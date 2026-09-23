import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:in4up/l10n/app_localizations.dart';

import '../../core/responsive/app_responsive.dart';
import '../../providers/player_provider.dart';
import '../../services/auth_service.dart';
import '../settings/stt_model_settings_screen.dart';
import 'quick_capture/quick_capture_sheet.dart';
import 'quick_capture/quick_suggestion_sheet.dart';
import 'widgets/focus_streak_card.dart';
import 'widgets/hebbian_input_card.dart';
import 'widgets/knowledge_graph_preview.dart';
import 'widgets/memory_garden_card.dart';

/// Chiều cao card Phòng Studio.
///
/// Cố định theo `mainAxisExtent` (thay vì `childAspectRatio`) để card không
/// tràn khi 7 thẻ bị ép xuống 2 cột: icon 26 + tiêu đề 1 dòng + phụ đề 2 dòng
/// ở cỡ chữ tối đa app cho phép (text scale bị kẹp ≤ 1.15 trong `main.dart`).
const double _studioCardExtent = 108;

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
                        SliverPadding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                            vertical: 12,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: _buildAiChatCard(context),
                          ),
                        ),
                        SliverPadding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                            vertical: 12,
                          ),
                          sliver: const SliverToBoxAdapter(
                            child: FocusStreakCard(),
                          ),
                        ),
                        SliverPadding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                            vertical: 12,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: MemoryGardenCard(
                              onStartReview: widget.onNavigateToMemory,
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                            vertical: 12,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: HebbianInputCard(
                              onStartVoiceCapture: _openQuickCapture,
                              onShowSuggestion: _openSuggestion,
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                            vertical: 12,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: _buildBentoModesGrid(context),
                          ),
                        ),
                        SliverPadding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                            vertical: 12,
                          ),
                          sliver: const SliverToBoxAdapter(
                            child: KnowledgeGraphPreview(),
                          ),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 120)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _GlobalMiniPlayer(),
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

  Widget _buildAiChatCard(BuildContext context) {
    return InkWell(
      onTap: widget.onOpenAiChat,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF312E81), Color(0xFF172554)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Color(0xFFE9D5FF), size: 30),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.uiText('I4U AI Chat'),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.uiText('Hỏi đáp về từ vựng và ngữ pháp'),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassHeader(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = AppResponsive.isCompact(constraints.maxWidth);
        final horizontal = isCompact ? 16.0 : 24.0;

        return Padding(
          padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 8),
          child: isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderTextBlock(context, l10n),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.smart_toy_outlined,
                            color: Colors.blueAccent,
                            size: 24,
                          ),
                          tooltip: l10n.manageAIModels,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SttModelSettingsScreen(),
                              ),
                            );
                          },
                        ),
                        _FirebaseAuthButton(),
                      ],
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildHeaderTextBlock(context, l10n)),
                    const SizedBox(width: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.smart_toy_outlined,
                            color: Colors.blueAccent,
                            size: 24,
                          ),
                          tooltip: l10n.manageAIModels,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SttModelSettingsScreen(),
                              ),
                            );
                          },
                        ),
                        _FirebaseAuthButton(),
                      ],
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildHeaderTextBlock(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.commandCenter,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: Colors.blue[400],
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.knowledgeOS,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.uiText(
            'Home là trung tâm điều phối: tiếp tục học, theo dõi tiến độ và truy cập nhanh hệ thống.',
          ),
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildBentoModesGrid(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // 7 card (NGHE · NÓI · XEM · ĐỌC · VIẾT · HIỂU · NHỚ): 2 cột trên phone
        // (2+2+2+1), 3–5 cột khi rộng (4+3 …). Chiều cao card cố định theo
        // `mainAxisExtent` để không phụ thuộc tỉ lệ chữ → không overflow.
        final crossAxisCount = AppResponsive.adaptiveGridColumns(
          width,
          compact: width < 380 ? 1 : 2,
          medium: 3,
          expanded: 4,
          large: 5,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.studioRoom,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.grey,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: _studioCardExtent,
              ),
              children: [
                _BentoCard(
                  icon: Icons.headphones,
                  title: l10n.listen,
                  subtitle: l10n.listenLibrary,
                  color: const Color(0xFF6C63FF),
                  onTap: widget.onNavigateToListen,
                ),
                _BentoCard(
                  icon: Icons.mic,
                  title: context.uiText('NÓI'),
                  subtitle: l10n.shadowingSubtitle,
                  color: const Color(0xFFB388FF),
                  onTap: widget.onNavigateToSpeak,
                ),
                _BentoCard(
                  icon: Icons.smart_display,
                  title: context.uiText('XEM'),
                  subtitle: context.uiText('Thư viện video'),
                  color: const Color(0xFFFFB300),
                  onTap: widget.onNavigateToWatch,
                ),
                _BentoCard(
                  icon: Icons.menu_book,
                  title: l10n.read,
                  subtitle: l10n.readLibrary,
                  color: const Color(0xFF2196F3),
                  onTap: widget.onNavigateToRead,
                ),
                _BentoCard(
                  icon: Icons.edit_note,
                  title: context.uiText('VIẾT'),
                  subtitle: l10n.readTextStudio,
                  color: const Color(0xFF26C6DA),
                  onTap: widget.onNavigateToWrite,
                ),
                _BentoCard(
                  icon: Icons.lightbulb,
                  title: l10n.understand,
                  subtitle: context.uiText('Đồng bộ · Hiểu sâu'),
                  color: const Color(0xFFFFB300),
                  onTap: widget.onNavigateToUnderstand,
                ),
                _BentoCard(
                  icon: Icons.psychology,
                  title: l10n.remember,
                  subtitle: context.uiText('Ôn tập · SRS'),
                  color: const Color(0xFF4CAF50),
                  onTap: widget.onNavigateToMemory,
                ),
              ],
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

class _BentoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _BentoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -10,
              top: -10,
              child: Icon(
                icon,
                size: 60,
                color: color.withValues(alpha: 0.05),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: color, size: 26),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color.withValues(alpha: 0.82),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlobalMiniPlayer extends StatelessWidget {
  const _GlobalMiniPlayer();

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, _) {
        if (player.currentSongTitle == null) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.music_note,
                  color: Color(0xFF6C63FF),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player.currentSongTitle ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      AppLocalizations.of(context).nowPlaying,
                      style: const TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  player.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                ),
                onPressed: player.togglePlayPause,
              ),
            ],
          ),
        );
      },
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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 2),
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
