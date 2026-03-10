import 'dart:io';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/player_provider.dart';
import '../../screens/memory_mode/controllers/memory_controller.dart';
import '../../services/auth_service.dart';

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

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _bgController;
  late AnimationController _cardController;
  late List<Animation<double>> _cardAnims;

  @override
  void initState() {
    super.initState();

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // Staggered card animations
    _cardAnims = List.generate(4, (i) {
      final start = i * 0.15;
      final end = (start + 0.55).clamp(0.0, 1.0);
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _cardController,
          curve: Interval(start, end, curve: Curves.easeOutBack),
        ),
      );
    });

    _cardController.forward();
  }

  @override
  void dispose() {
    _bgController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B1A),
      body: Stack(
        children: [
          // Animated background
          _AnimatedBackground(controller: _bgController),

          // Content
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                SliverToBoxAdapter(child: _buildQuickStats()),
                SliverToBoxAdapter(child: _buildModesSection()),
                SliverToBoxAdapter(child: _buildImportSection()),
                SliverToBoxAdapter(child: _buildBottomActions()),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── HEADER ───────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        children: [
          // Logo + Title
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFF2196F3)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.graphic_eq,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'VipSound',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _getGreeting(),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),

          const Spacer(),

          // Firebase auth button
          _FirebaseAuthButton(),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Buổi sáng tốt lành ☀️';
    if (hour < 18) return 'Buổi chiều vui vẻ 🌤️';
    return 'Buổi tối an lành 🌙';
  }

  // ─── QUICK STATS ──────────────────────────────────────────
  Widget _buildQuickStats() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Consumer<PlayerProvider>( 
        builder: (context, player, _) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF6C63FF).withOpacity(0.15),
                  const Color(0xFF2196F3).withOpacity(0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF6C63FF).withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                _StatItem(
                  icon: Icons.headphones,
                  label: 'Đang phát',
                  value: player.currentSongTitle != null ? '1 bài' : 'Chưa có',
                  color: const Color(0xFF6C63FF),
                ),
                _Divider(),
                _MemoryStatItem(),
                _Divider(),
                _StatItem(
                  icon: Icons.local_fire_department,
                  label: 'Streak',
                  value: '— ngày',
                  color: const Color(0xFFFF6B35),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── MODES SECTION ────────────────────────────────────────
  Widget _buildModesSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel(text: 'CHẾ ĐỘ HỌC'),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ModeCard(
                  index: 0,
                  anim: _cardAnims[0],
                  icon: Icons.headphones,
                  label: 'Nghe',
                  sublabel: 'Luyện tai',
                  color: const Color(0xFF6C63FF),
                  gradientColors: [
                    const Color(0xFF6C63FF),
                    const Color(0xFF9C56FF),
                  ],
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    widget.onNavigateToListen();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ModeCard(
                  index: 1,
                  anim: _cardAnims[1],
                  icon: Icons.menu_book,
                  label: 'Đọc',
                  sublabel: 'Hiểu văn bản',
                  color: const Color(0xFF2196F3),
                  gradientColors: [
                    const Color(0xFF2196F3),
                    const Color(0xFF00BCD4),
                  ],
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    widget.onNavigateToRead();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ModeCard(
                  index: 2,
                  anim: _cardAnims[2],
                  icon: Icons.lightbulb,
                  label: 'Hiểu',
                  sublabel: 'Phân tích sâu',
                  color: const Color(0xFFFFB300),
                  gradientColors: [
                    const Color(0xFFFF8F00),
                    const Color(0xFFFFB300),
                  ],
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    widget.onNavigateToUnderstand();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ModeCard(
                  index: 3,
                  anim: _cardAnims[3],
                  icon: Icons.psychology,
                  label: 'Nhớ',
                  sublabel: 'Vườn trí nhớ',
                  color: const Color(0xFF4CAF50),
                  gradientColors: [
                    const Color(0xFF2E7D32),
                    const Color(0xFF4CAF50),
                  ],
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    widget.onNavigateToMemory();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── IMPORT SECTION ───────────────────────────────────────
  Widget _buildImportSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel(text: 'THÊM NỘI DUNG'),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ImportCard(
                  icon: Icons.audio_file,
                  label: 'Audio',
                  sublabel: 'MP3, WAV, FLAC...',
                  color: const Color(0xFF6C63FF),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onNavigateToListen();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ImportCard(
                  icon: Icons.text_snippet,
                  label: 'Text',
                  sublabel: 'TXT, SRT, LRC...',
                  color: const Color(0xFF2196F3),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onNavigateToRead();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── BOTTOM ACTIONS ───────────────────────────────────────
  Widget _buildBottomActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel(text: 'CÀI ĐẶT'),
          const SizedBox(height: 14),
          _SettingsRow(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SUB WIDGETS
// ─────────────────────────────────────────────────────────────

class _AnimatedBackground extends StatelessWidget {
  final AnimationController controller;
  const _AnimatedBackground({required this.controller});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: controller,
        builder: (_, __) {
          return CustomPaint(
            painter: _BgPainter(controller.value),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _BgPainter extends CustomPainter {
  final double t;
  _BgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    // Orb 1 - Purple
    final p1 = Paint()
      ..color = const Color(0xFF6C63FF).withOpacity(0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);
    canvas.drawCircle(
      Offset(
        size.width * (0.2 + 0.1 * math.sin(t * math.pi * 2)),
        size.height * (0.15 + 0.05 * math.cos(t * math.pi * 2)),
      ),
      160,
      p1,
    );

    // Orb 2 - Blue
    final p2 = Paint()
      ..color = const Color(0xFF2196F3).withOpacity(0.06)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);
    canvas.drawCircle(
      Offset(
        size.width * (0.8 + 0.08 * math.cos(t * math.pi * 2)),
        size.height * (0.4 + 0.1 * math.sin(t * math.pi * 1.3)),
      ),
      180,
      p2,
    );

    // Orb 3 - Green
    final p3 = Paint()
      ..color = const Color(0xFF4CAF50).withOpacity(0.05)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 100);
    canvas.drawCircle(
      Offset(
        size.width * (0.3 + 0.12 * math.sin(t * math.pi * 1.7)),
        size.height * (0.75 + 0.06 * math.cos(t * math.pi * 1.7)),
      ),
      140,
      p3,
    );
  }

  @override
  bool shouldRepaint(_BgPainter old) => old.t != t;
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.grey[600],
        letterSpacing: 1.5,
      ),
    );
  }
}

class _ModeCard extends StatefulWidget {
  final int index;
  final Animation<double> anim;
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _ModeCard({
    required this.index,
    required this.anim,
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  State<_ModeCard> createState() => _ModeCardState();
}

class _ModeCardState extends State<_ModeCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.anim,
      builder: (_, child) {
        return Transform.scale(
          scale: widget.anim.value,
          child: Opacity(
            opacity: widget.anim.value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.93 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.gradientColors
                    .map((c) => c.withOpacity(0.18))
                    .toList(),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: widget.color.withOpacity(0.3),
              ),
            ),
            child: Stack(
              children: [
                // Background icon (decorative)
                Positioned(
                  right: -8,
                  bottom: -8,
                  child: Icon(
                    widget.icon,
                    size: 64,
                    color: widget.color.withOpacity(0.08),
                  ),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: widget.color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          widget.icon,
                          color: widget.color,
                          size: 20,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        widget.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.sublabel,
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ImportCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback onTap;

  const _ImportCard({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ImportCard> createState() => _ImportCardState();
}

class _ImportCardState extends State<_ImportCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.color.withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.icon, color: widget.color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      widget.sublabel,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.add_circle_outline,
                  color: widget.color.withOpacity(0.6), size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoryStatItem extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Try to get memory controller if available
    try {
      final ctrl = context.read<MemoryController>();
      return Expanded(
        child: Column(
          children: [
            const Icon(Icons.psychology, color: Color(0xFF4CAF50), size: 20),
            const SizedBox(height: 6),
            Text(
              '${ctrl.dueItems.length} từ',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Cần ôn',
              style: TextStyle(color: Colors.grey[600], fontSize: 10),
            ),
          ],
        ),
      );
    } catch (_) {
      return const _StatItem(
        icon: Icons.psychology,
        label: 'Cần ôn',
        value: '— từ',
        color: Color(0xFF4CAF50),
      );
    }
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      color: Colors.white.withOpacity(0.08),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SettingsChip(
            icon: Icons.tune,
            label: 'Cài đặt',
            onTap: () {
              // TODO: mở settings sheet
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SettingsChip(
            icon: Icons.info_outline,
            label: 'Giới thiệu',
            onTap: () {
              // TODO: mở about
            },
          ),
        ),
      ],
    );
  }
}

class _SettingsChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SettingsChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.grey[400], size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Firebase Auth Button ─────────────────────────────────────
class _FirebaseAuthButton extends StatefulWidget {
  @override
  State<_FirebaseAuthButton> createState() => _FirebaseAuthButtonState();
}

class _FirebaseAuthButtonState extends State<_FirebaseAuthButton> {
  // Lắng nghe auth state thay đổi để tự rebuild
  late final Stream<User?> _authStream;

  @override
  void initState() {
    super.initState();
    _authStream = AuthService().authStateChanges;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authStream,
      builder: (context, snapshot) {
        final user = snapshot.data ?? AuthService().currentUser;
        final isAnonymous = user == null || (user.isAnonymous);
        final displayName = user?.displayName;
        final photoUrl = user?.photoURL;

        return GestureDetector(
          onTap: () => _showAuthSheet(context, isAnonymous),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Avatar
                CircleAvatar(
                  radius: 12,
                  backgroundColor: isAnonymous
                      ? const Color(0xFF6C63FF).withOpacity(0.3)
                      : const Color(0xFF4CAF50).withOpacity(0.3),
                  backgroundImage:
                      photoUrl != null ? NetworkImage(photoUrl) : null,
                  child: photoUrl == null
                      ? Icon(
                          isAnonymous ? Icons.person_outline : Icons.person,
                          color: isAnonymous
                              ? const Color(0xFF6C63FF)
                              : const Color(0xFF4CAF50),
                          size: 14,
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                // Label
                Text(
                  isAnonymous
                      ? 'Ẩn danh'
                      : (displayName?.split(' ').first ?? 'Tôi'),
                  style: TextStyle(
                    color: isAnonymous ? Colors.white70 : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down,
                    color: Colors.grey[600], size: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAuthSheet(BuildContext context, bool isAnonymous) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (_) => _AuthSheet(isAnonymous: isAnonymous),
    );
  }
}

class _AuthSheet extends StatefulWidget {
  final bool isAnonymous;
  const _AuthSheet({required this.isAnonymous});

  @override
  State<_AuthSheet> createState() => _AuthSheetState();
}

class _AuthSheetState extends State<_AuthSheet> {
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await AuthService().signInWithGoogle();

      if (!mounted) return;

      if (user != null) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Đã đăng nhập: ${user.displayName ?? user.email ?? "Thành công"}',
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      } else {
        // User chủ động cancel → không hiện lỗi
        setState(() => _isLoading = false);
      }
    } on AuthException catch (e) {
      // Lỗi rõ ràng từ AuthService (chưa config, hết giờ, v.v.)
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Lỗi không xác định: $e';
      });
    }
  }

  Future<void> _handleSignOut() async {
    setState(() => _isLoading = true);
    await AuthService().signOut();
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 28,
        right: 28,
        top: 28,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Title
          const Text(
            'Tài khoản',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.isAnonymous
                ? 'Đăng nhập để đồng bộ vườn nhớ trên tất cả thiết bị'
                : 'Đang đăng nhập với tài khoản Google',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),

          // Status card
          _buildStatusCard(),
          const SizedBox(height: 14),

          // Error message
          if (_errorMessage != null) ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: Colors.redAccent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                          color: Colors.redAccent, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Action button
          SizedBox(
            width: double.infinity,
            child: widget.isAnonymous
                ? _buildGoogleSignInButton()
                : _buildSignOutButton(),
          ),

          const SizedBox(height: 12),
          Text(
            widget.isAnonymous
                ? 'Đăng nhập Google giúp đồng bộ vườn nhớ\nkhi chuyển thiết bị hoặc cài lại ứng dụng.'
                : 'Đăng xuất sẽ chuyển về chế độ ẩn danh.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 11,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final isAnonymous = widget.isAnonymous;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isAnonymous
                      ? const Color(0xFF6C63FF)
                      : const Color(0xFF4CAF50))
                  .withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isAnonymous ? Icons.shield_outlined : Icons.verified_user,
              color: isAnonymous
                  ? const Color(0xFF6C63FF)
                  : const Color(0xFF4CAF50),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAnonymous ? 'Chế độ ẩn danh' : 'Google Account',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isAnonymous
                      ? 'Đang hoạt động · Dữ liệu lưu trên thiết bị này'
                      : (AuthService().email ?? AuthService().displayName ?? 'Đã đăng nhập'),
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
              ],
            ),
          ),
          Icon(
            Icons.check_circle,
            color: isAnonymous
                ? const Color(0xFF6C63FF)
                : const Color(0xFF4CAF50),
            size: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleSignInButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _handleGoogleSignIn,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A2E),
        disabledBackgroundColor: Colors.white.withOpacity(0.5),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        elevation: 0,
      ),
      child: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFF1A1A2E),
              ),
            )
          : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.g_mobiledata, size: 22),
                SizedBox(width: 8),
                Text(
                  'Đăng nhập với Google',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSignOutButton() {
    return OutlinedButton(
      onPressed: _isLoading ? null : _handleSignOut,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.redAccent,
        side: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      child: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.redAccent,
              ),
            )
          : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout, size: 18),
                SizedBox(width: 8),
                Text(
                  'Đăng xuất',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
    );
  }
}
