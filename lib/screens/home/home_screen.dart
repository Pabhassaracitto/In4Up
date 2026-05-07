import 'dart:math' as math;

import 'package:animations/animations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:vipsound_ai/vipsound_ai.dart';

import '../../providers/player_provider.dart';
import '../../services/auth_service.dart';
import 'widgets/focus_streak_card.dart';
import 'widgets/hebbian_input_card.dart';
import 'widgets/knowledge_graph_preview.dart';
import 'widgets/memory_garden_card.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onNavigateToListen;
  final VoidCallback onNavigateToRead;
  final VoidCallback onNavigateToUnderstand;
  final VoidCallback onNavigateToMemory;

  const HomeScreen({
    super.key,
    required this.onNavigateToListen,
    required this.onNavigateToRead,
    required this.onNavigateToUnderstand,
    required this.onNavigateToMemory,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B1A),
      body: Stack(
        children: [
          // Static Abstract Background
          const _AnimatedBackground(),

          // Main Content
          SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                // Refresh data logic
              },
              backgroundColor: const Color(0xFF1A1A2E),
              color: const Color(0xFF6C63FF),
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildGlassHeader()),

                  // FOCUS & MOMENTUM SECTION
                  const SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    sliver: SliverToBoxAdapter(
                      child: FocusStreakCard(),
                    ),
                  ),

                  // MEMORY GARDEN (LIVESTATUS)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    sliver: SliverToBoxAdapter(
                      child: MemoryGardenCard(
                        onStartReview: widget.onNavigateToMemory,
                      ),
                    ),
                  ),

                  // QUICK INPUT & HEBBIAN SUGGESTION
                  const SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    sliver: SliverToBoxAdapter(
                      child: HebbianInputCard(),
                    ),
                  ),

                  // MODES SECTION (BENTO GRID)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    sliver: SliverToBoxAdapter(
                      child: _buildBentoModesGrid(),
                    ),
                  ),

                  // KNOWLEDGE GRAPH PREVIEW
                  const SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    sliver: SliverToBoxAdapter(
                      child: KnowledgeGraphPreview(),
                    ),
                  ),

                  // BOTTOM SPACING
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
          ),

          // MINI PLAYER OVERLAY
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _GlobalMiniPlayer(),
          ),
        ],
      ),
      floatingActionButton: _buildOmniMicrophone(),
    );
  }

  Widget _buildGlassHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'COMMAND CENTER',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Colors.blue[400],
                  letterSpacing: 2,
                ),
              ),
              const Text(
                'Hệ điều hành Tri thức',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Nút cấu hình AI Model
          _buildAiStatusButton(context),
          const SizedBox(width: 8),
          _FirebaseAuthButton(),
        ],
      ),
    );
  }

  Widget _buildAiStatusButton(BuildContext context) {
    return Consumer<AiServiceFacade>(
      builder: (context, aiFacade, child) {
        Color statusColor;
        IconData icon;

        if (aiFacade.facadeState == AiFacadeState.idle) {
          statusColor = Colors.green;
          icon = Icons.psychology;
        } else if (aiFacade.facadeState == AiFacadeState.noModel) {
          statusColor = Colors.orange;
          icon = Icons.psychology_alt;
        } else if (aiFacade.facadeState == AiFacadeState.loading) {
          return const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        } else {
          statusColor = Colors.red;
          icon = Icons.error_outline;
        }

        return IconButton(
          icon: Icon(icon, color: statusColor, size: 28),
          onPressed: () => _showAiManagementDialog(context, aiFacade),
          tooltip: 'Quản lý AI Model',
        );
      },
    );
  }

  void _showAiManagementDialog(BuildContext context, AiServiceFacade aiFacade) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Cấu hình AI Engine',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Trạng thái: ${aiFacade.facadeState.name}',
                style: const TextStyle(color: Colors.grey)),
            Text('Nguồn: ${aiFacade.modelSourceLabel}',
                style: const TextStyle(color: Colors.grey)),
            if (aiFacade.lastError != null)
              Text('Lỗi: ${aiFacade.lastError}',
                  style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await aiFacade.importModelFromUser();
            },
            child: const Text('IMPORT .GGUF'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ĐÓNG'),
          ),
        ],
      ),
    );
  }

  Widget _buildBentoModesGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PHÒNG STUDIO',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Colors.grey,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: [
            _BentoCard(
              icon: Icons.headphones,
              title: 'NGHE',
              color: const Color(0xFF6C63FF),
              onTap: widget.onNavigateToListen,
            ),
            _BentoCard(
              icon: Icons.menu_book,
              title: 'ĐỌC',
              color: const Color(0xFF2196F3),
              onTap: widget.onNavigateToRead,
            ),
            _BentoCard(
              icon: Icons.lightbulb,
              title: 'HIỂU',
              color: const Color(0xFFFFB300),
              onTap: widget.onNavigateToUnderstand,
            ),
            _BentoCard(
              icon: Icons.psychology,
              title: 'NHỚ',
              color: const Color(0xFF4CAF50),
              onTap: widget.onNavigateToMemory,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOmniMicrophone() {
    return OpenContainer(
      transitionType: ContainerTransitionType.fade,
      openBuilder: (context, _) => const _SttDialog(),
      closedElevation: 6.0,
      closedShape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(56 / 2)),
      ),
      closedColor: const Color(0xFF6C63FF),
      closedBuilder: (context, openContainer) => FloatingActionButton(
        onPressed: openContainer,
        backgroundColor: const Color(0xFF6C63FF),
        child: const Icon(Icons.mic, color: Colors.white, size: 30),
      ),
    );
  }
}

class _BentoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _BentoCard({
    required this.icon,
    required this.title,
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
              child: Icon(icon, size: 60, color: color.withValues(alpha: 0.05)),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 28),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
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
                color: const Color(0xFF6C63FF).withValues(alpha: 0.3)),
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
                child: const Icon(Icons.music_note, color: Color(0xFF6C63FF)),
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
                          fontWeight: FontWeight.bold),
                    ),
                    const Text(
                      'Đang phát',
                      style: TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.play_arrow, color: Colors.white),
                onPressed: () {},
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SttDialog extends StatelessWidget {
  const _SttDialog();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B1A),
      appBar: AppBar(
        title: const Text('Ghi chú nhanh'),
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.mic, size: 80, color: Color(0xFF6C63FF)),
            const SizedBox(height: 24),
            const Text(
              'Đang lắng nghe...',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hoàn tất'),
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
        size: Size.infinite,
        painter: _BackgroundPainter(
            0.5), // Fixed value instead of animated controller
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

    // Deep Indigo Orb
    paint.color = const Color(0xFF6C63FF).withValues(alpha: 0.1);
    canvas.drawCircle(
      Offset(
        size.width * (0.3 + 0.1 * math.sin(t * 2 * math.pi)),
        size.height * (0.2 + 0.1 * math.cos(t * 2 * math.pi)),
      ),
      size.width * 0.4,
      paint,
    );

    // Deep Ocean Orb
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
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 2));
        }
        final user = snapshot.data;
        if (user == null) {
          return IconButton(
            icon: const Icon(Icons.account_circle_outlined,
                color: Colors.white, size: 28),
            onPressed: () => _handleSignIn(context),
          );
        }
        return Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundImage:
                  user.photoURL != null ? NetworkImage(user.photoURL!) : null,
              child: user.photoURL == null
                  ? Text(user.displayName?[0] ?? 'U')
                  : null,
            ),
            const SizedBox(width: 8),
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
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Đăng nhập thất bại: $e')));
      }
    }
  }
}
