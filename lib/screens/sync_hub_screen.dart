// lib/screens/sync_hub_screen.dart
// VipSound - Sync Hub Screen
// Version 3.0 - Enhanced for Buddhism & English Learning
// Author: Claude AI - Optimized based on Neuroscience & Learning Psychology

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:async';

import '../providers/player_provider.dart';
import '../providers/text_provider.dart';
import '../models/text_item.dart';
import '../widgets/mini_player_controls.dart';
import '../widgets/synced_lyrics_view.dart';

// ============================================================================
// MAIN SCREEN
// ============================================================================

class SyncHubScreen extends StatefulWidget {
  const SyncHubScreen({super.key});

  @override
  State<SyncHubScreen> createState() => _SyncHubScreenState();
}

class _SyncHubScreenState extends State<SyncHubScreen>
    with TickerProviderStateMixin {
  // === LAYOUT STATE ===
  double _splitRatio = 0.38;
  bool _autoScroll = true;

  // === ANIMATION ===
  late AnimationController _breathingController;
  late Animation<double> _breathingAnimation;

  // === GESTURE ===
  double _dragStartX = 0;
  double _initialSpeed = 1.0;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    // Breathing animation cho Buddhism mode
    _breathingController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);

    _breathingAnimation = Tween<double>(
      begin: 0.3,
      end: 0.6,
    ).animate(CurvedAnimation(
      parent: _breathingController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _breathingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: Consumer<PlayerProvider>(
          builder: (context, player, _) {
            final theme = _getModeTheme(player.currentMode);

            return Column(
              children: [
                _buildAppBar(context, player, theme),
                Expanded(
                  child: _buildSplitView(context, player, theme),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ============================================================================
  // THEME SYSTEM - Tối ưu theo Khoa học Thần kinh
  // ============================================================================

  _ModeTheme _getModeTheme(VipMode mode) {
    switch (mode) {
      case VipMode.buddhism:
      // Warm Earth Tones - Kích hoạt sóng Alpha, giảm stress
        return const _ModeTheme(
          primary: Color(0xFFD4A574),      // Warm Sand
          secondary: Color(0xFF8B7355),    // Earth Brown
          accent: Color(0xFFF5E6D3),       // Cream
          background: Color(0xFF1A1612),   // Dark Warm
          surface: Color(0xFF2D2520),      // Surface Warm
          icon: Icons.spa,
          name: 'Tịnh Tâm',
          speedPresets: [0.8, 0.85, 0.9, 0.95, 1.0],
          defaultGap: 3.0,
        );

      case VipMode.english:
      // Cool Blue Tones - Tăng tập trung, hỗ trợ học tập
        return const _ModeTheme(
          primary: Color(0xFF64B5F6),      // Light Blue
          secondary: Color(0xFF1976D2),    // Blue
          accent: Color(0xFFBBDEFB),       // Pale Blue
          background: Color(0xFF0D1117),   // Dark Cool
          surface: Color(0xFF161B22),      // Surface Cool
          icon: Icons.school,
          name: 'Học Tập',
          speedPresets: [0.5, 0.6, 0.7, 0.75, 0.85, 1.0],
          defaultGap: 2.0,
        );

      case VipMode.music:
      // Purple Gradient - Thưởng thức âm nhạc
        return const _ModeTheme(
          primary: Color(0xFF9C7CF4),      // Soft Purple
          secondary: Color(0xFF6C63FF),    // Vivid Purple
          accent: Color(0xFFD1C4E9),       // Lavender
          background: Color(0xFF0F0F1A),   // Dark Purple
          surface: Color(0xFF1A1A2E),      // Surface Purple
          icon: Icons.music_note,
          name: 'Âm Nhạc',
          speedPresets: [0.75, 1.0, 1.25, 1.5, 2.0],
          defaultGap: 0.0,
        );
    }
  }

  // ============================================================================
  // APP BAR
  // ============================================================================

  Widget _buildAppBar(
      BuildContext context,
      PlayerProvider player,
      _ModeTheme theme,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.primary.withOpacity(0.15),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          // Back button
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: Colors.white70,
          ),

          // Logo & Title
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.primary, theme.secondary],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: theme.primary.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(theme.icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Sync Hub',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Chế độ: ${theme.name}',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Mode Switcher
          _buildModeSwitcher(context, player, theme),

          // Auto-scroll toggle
          _buildAutoScrollButton(theme),

          // Import button
          IconButton(
            onPressed: () => _showImportOptions(context, theme),
            icon: const Icon(Icons.add_circle_outline, size: 22),
            color: theme.primary,
            tooltip: 'Thêm nội dung',
          ),

          // Settings
          IconButton(
            onPressed: () => _showSyncSettings(context, theme),
            icon: const Icon(Icons.tune, size: 22),
            color: theme.primary,
            tooltip: 'Cài đặt',
          ),
        ],
      ),
    );
  }

  Widget _buildModeSwitcher(
      BuildContext context,
      PlayerProvider player,
      _ModeTheme theme,
      ) {
    return PopupMenuButton<VipMode>(
      offset: const Offset(0, 40),
      color: theme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: theme.primary.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.primary.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(theme.icon, size: 14, color: theme.primary),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 16, color: theme.primary),
          ],
        ),
      ),
      onSelected: (mode) => player.setMode(mode),
      itemBuilder: (context) => [
        _buildModeMenuItem(
          VipMode.buddhism,
          Icons.spa,
          'Phật Pháp',
          'Chậm rãi, có khoảng lặng suy ngẫm',
          const Color(0xFFD4A574),
          player.currentMode == VipMode.buddhism,
        ),
        _buildModeMenuItem(
          VipMode.english,
          Icons.school,
          'Tiếng Anh',
          'Tốc độ chậm, loop nhiều lần',
          const Color(0xFF64B5F6),
          player.currentMode == VipMode.english,
        ),
        _buildModeMenuItem(
          VipMode.music,
          Icons.music_note,
          'Âm Nhạc',
          'Nghe tự nhiên, không lặp',
          const Color(0xFF9C7CF4),
          player.currentMode == VipMode.music,
        ),
      ],
    );
  }

  PopupMenuItem<VipMode> _buildModeMenuItem(
      VipMode mode,
      IconData icon,
      String title,
      String subtitle,
      Color color,
      bool isSelected,
      ) {
    return PopupMenuItem(
      value: mode,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(isSelected ? 0.3 : 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, size: 18, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoScrollButton(_ModeTheme theme) {
    return IconButton(
      onPressed: () {
        setState(() => _autoScroll = !_autoScroll);
        HapticFeedback.lightImpact();
      },
      icon: Icon(
        _autoScroll ? Icons.swap_vert : Icons.vertical_align_top,
        size: 22,
      ),
      color: _autoScroll ? theme.primary : Colors.grey,
      tooltip: _autoScroll ? 'Tự cuộn: BẬT' : 'Tự cuộn: TẮT',
    );
  }

  // ============================================================================
  // SPLIT VIEW - Layout chính
  // ============================================================================

  Widget _buildSplitView(
      BuildContext context,
      PlayerProvider player,
      _ModeTheme theme,
      ) {
    return Consumer<TextProvider>(
      builder: (context, textProvider, child) {
        // Empty state
        if (player.currentSongPath == null && textProvider.lines.isEmpty) {
          return _buildEmptyState(context, player, theme);
        }

        return Column(
          children: [
            // === MUSIC SECTION ===
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: MediaQuery.of(context).size.height * _splitRatio,
              decoration: BoxDecoration(
                color: theme.surface.withOpacity(0.5),
                border: Border(
                  bottom: BorderSide(
                    color: theme.primary.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
              child: _buildMusicSection(context, player, theme),
            ),

            // === RESIZE DIVIDER ===
            _buildResizeDivider(theme),

            // === TEXT SECTION (with Gesture Controls) ===
            Expanded(
              child: GestureDetector(
                // Swipe ngang để điều chỉnh speed
                onHorizontalDragStart: (details) {
                  _dragStartX = details.globalPosition.dx;
                  _initialSpeed = player.state.speed;
                },
                onHorizontalDragUpdate: (details) {
                  final delta = details.globalPosition.dx - _dragStartX;
                  final speedChange = delta / 200; // 200px = 1.0 speed
                  final newSpeed = (_initialSpeed + speedChange).clamp(0.25, 2.0);
                  player.setSpeed(newSpeed);
                },
                onHorizontalDragEnd: (details) {
                  _showSpeedToast(context, player.state.speed, theme);
                },
                // Double tap để pause/play
                onDoubleTap: () {
                  player.togglePlayPause();
                  HapticFeedback.mediumImpact();
                },
                child: _buildTextSection(context, player, textProvider, theme),
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================================
  // MUSIC SECTION - Phần điều khiển nhạc
  // ============================================================================

  Widget _buildMusicSection(
      BuildContext context,
      PlayerProvider player,
      _ModeTheme theme,
      ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // === SONG INFO ROW ===
          _buildSongInfo(context, player, theme),

          const SizedBox(height: 12),

          // === SMART SPEED ZONE - Tận dụng Engine 0.05x-10x ===
          _buildSmartSpeedZone(context, player, theme),

          const SizedBox(height: 12),

          // === CONTEMPLATION ZONE (Buddhism mode) ===
          if (player.isBuddhismMode)
            _buildContemplationZone(context, player, theme),

          // === SHADOWING HINT (English mode) ===
          if (player.isEnglishMode)
            _buildShadowingHint(context, player, theme),

          const SizedBox(height: 8),

          // === PROGRESS BAR ===
          _buildProgressBar(context, player, theme),

          const SizedBox(height: 8),

          // === MINI CONTROLS ===
          const MiniPlayerControls(),

          // === LOOP INFO (nếu đang loop) ===
          if (player.isLooping) ...[
            const SizedBox(height: 8),
            _buildLoopInfo(player, theme),
          ],
        ],
      ),
    );
  }

  Widget _buildSongInfo(
      BuildContext context,
      PlayerProvider player,
      _ModeTheme theme,
      ) {
    return Row(
      children: [
        // Album art / Mode icon
        AnimatedBuilder(
          animation: _breathingAnimation,
          builder: (context, child) {
            final opacity = player.isBuddhismMode && player.isPlaying
                ? _breathingAnimation.value
                : 0.3;
            return Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: player.isLooping
                      ? [const Color(0xFF4CAF50), const Color(0xFF2E7D32)]
                      : [theme.primary, theme.secondary],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (player.isLooping
                        ? const Color(0xFF4CAF50)
                        : theme.primary)
                        .withOpacity(opacity),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                player.isLooping
                    ? Icons.loop
                    : player.isPlaying
                    ? Icons.equalizer
                    : theme.icon,
                color: Colors.white,
                size: 28,
              ),
            );
          },
        ),
        const SizedBox(width: 12),

        // Song info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                player.currentSongTitle ?? 'Chưa chọn audio',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                player.currentSongArtist ?? 'Bấm + để thêm audio',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // Status chips
              Row(
                children: [
                  // Speed chip
                  _StatusChip(
                    icon: Icons.speed,
                    label: '${player.state.speed.toStringAsFixed(2)}x',
                    color: theme.primary,
                  ),
                  const SizedBox(width: 6),
                  // Loop chip
                  if (player.isLooping)
                    _StatusChip(
                      icon: Icons.loop,
                      label: '${player.loopCount}/${player.maxLoopCount > 0 ? player.maxLoopCount : "∞"}',
                      color: const Color(0xFF4CAF50),
                    ),
                  // Gap chip
                  if (player.isWaitingGap)
                    _StatusChip(
                      icon: Icons.pause_circle,
                      label: 'Gap ${player.gapDuration.toInt()}s',
                      color: Colors.orange,
                    ),
                ],
              ),
            ],
          ),
        ),

        // Add audio button
        if (player.currentSongPath == null)
          IconButton(
            onPressed: () => _pickAudioFile(context),
            icon: Icon(Icons.add_circle, color: theme.primary, size: 32),
          ),
      ],
    );
  }

  // ============================================================================
  // SMART SPEED ZONE - Khai thác Engine 0.05x-10x
  // ============================================================================

  Widget _buildSmartSpeedZone(
      BuildContext context,
      PlayerProvider player,
      _ModeTheme theme,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.primary.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.speed, size: 14, color: theme.primary),
              const SizedBox(width: 6),
              Text(
                'Tốc độ phát',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              // Ultra slow button
              GestureDetector(
                onTap: () => _showUltraSpeedPicker(context, player, theme),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.secondary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.slow_motion_video, size: 12, color: theme.accent),
                      const SizedBox(width: 4),
                      Text(
                        '0.05x-10x',
                        style: TextStyle(fontSize: 10, color: theme.accent),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Speed preset buttons
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Mode-specific presets
                ...theme.speedPresets.map((speed) {
                  final isActive = (player.state.speed - speed).abs() < 0.01;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _SpeedPresetButton(
                      speed: speed,
                      isActive: isActive,
                      theme: theme,
                      onTap: () {
                        player.setSpeed(speed);
                        HapticFeedback.selectionClick();
                      },
                    ),
                  );
                }),

                // Divider
                Container(
                  width: 1,
                  height: 24,
                  color: theme.primary.withOpacity(0.2),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                ),

                // Fine tune buttons
                _FineTuneButton(
                  icon: Icons.remove,
                  onTap: () {
                    player.decreaseSpeed(0.05);
                    HapticFeedback.lightImpact();
                  },
                  theme: theme,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${player.state.speed.toStringAsFixed(2)}x',
                    style: TextStyle(
                      color: theme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                _FineTuneButton(
                  icon: Icons.add,
                  onTap: () {
                    player.increaseSpeed(0.05);
                    HapticFeedback.lightImpact();
                  },
                  theme: theme,
                ),
              ],
            ),
          ),

          // Speed description
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _getSpeedDescription(player.state.speed, player.currentMode),
              style: TextStyle(
                fontSize: 10,
                color: theme.primary.withOpacity(0.7),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getSpeedDescription(double speed, VipMode mode) {
    if (speed <= 0.1) return '🔬 Siêu chậm - Phân tích từng âm tiết';
    if (speed <= 0.3) return '🐢 Rất chậm - Nghe rõ âm vị (phoneme)';
    if (speed <= 0.5) return '🎯 Chậm - Luyện phát âm chuẩn xác';
    if (speed <= 0.7) return '📖 Học tập - Dễ nghe, dễ hiểu';
    if (speed <= 0.85) return '🧘 Thư giãn - Chậm rãi, tĩnh tâm';
    if (speed <= 1.0) return '✨ Tự nhiên - Tốc độ gốc';
    if (speed <= 1.25) return '⚡ Nhanh - Luyện phản xạ nghe';
    if (speed <= 1.5) return '🚀 Rất nhanh - Thử thách bản thân';
    return '💨 Cực nhanh - Dành cho chuyên gia';
  }

  // ============================================================================
  // CONTEMPLATION ZONE - Dành cho Phật Pháp
  // ============================================================================

  Widget _buildContemplationZone(
      BuildContext context,
      PlayerProvider player,
      _ModeTheme theme,
      ) {
    return AnimatedBuilder(
      animation: _breathingAnimation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.primary.withOpacity(_breathingAnimation.value * 0.15),
                theme.secondary.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.primary.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              // Icon breathing
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.primary.withOpacity(_breathingAnimation.value),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.spa, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Khoảng lặng suy ngẫm',
                      style: TextStyle(
                        color: theme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'Nghỉ ${player.gapDuration.toInt()}s sau mỗi đoạn để chiêm nghiệm',
                      style: TextStyle(
                        color: theme.primary.withOpacity(0.7),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),

              // Gap adjuster
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _GapAdjustButton(
                    icon: Icons.remove,
                    onTap: () => player.setGapDuration(player.gapDuration - 1),
                    theme: theme,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: theme.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${player.gapDuration.toInt()}s',
                      style: TextStyle(
                        color: theme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  _GapAdjustButton(
                    icon: Icons.add,
                    onTap: () => player.setGapDuration(player.gapDuration + 1),
                    theme: theme,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================================
  // SHADOWING HINT - Dành cho học Tiếng Anh
  // ============================================================================

  Widget _buildShadowingHint(
      BuildContext context,
      PlayerProvider player,
      _ModeTheme theme,
      ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.primary.withOpacity(0.1),
            Colors.purple.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.purple, Colors.deepPurple],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.mic, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Luyện Shadowing',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Nhấn giữ dòng text để bắt đầu ghi âm so sánh',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _showShadowingGuide(context, theme),
            style: TextButton.styleFrom(
              foregroundColor: Colors.purple,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            child: const Text('Hướng dẫn', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // PROGRESS BAR
  // ============================================================================

  Widget _buildProgressBar(
      BuildContext context,
      PlayerProvider player,
      _ModeTheme theme,
      ) {
    final position = player.state.position;
    final duration = player.state.duration;
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return Column(
      children: [
        // Slider
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: player.isLooping
                ? const Color(0xFF4CAF50)
                : theme.primary,
            inactiveTrackColor: Colors.white12,
            thumbColor: player.isLooping
                ? const Color(0xFF4CAF50)
                : theme.primary,
            overlayColor: (player.isLooping
                ? const Color(0xFF4CAF50)
                : theme.primary)
                .withOpacity(0.2),
          ),
          child: Slider(
            value: progress.clamp(0.0, 1.0),
            onChanged: (value) => player.seekToPercent(value),
          ),
        ),

        // Time labels
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(position),
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              if (player.isLooping && player.loopDuration != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Loop: ${_formatDuration(player.loopDuration!)}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF4CAF50),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              Text(
                _formatDuration(duration),
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoopInfo(PlayerProvider player, _ModeTheme theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50).withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.loop, size: 16, color: Color(0xFF4CAF50)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đang lặp: ${player.loopCount}/${player.maxLoopCount > 0 ? player.maxLoopCount : "∞"}',
                  style: const TextStyle(
                    color: Color(0xFF4CAF50),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (player.isWaitingGap)
                  const Text(
                    'Đang nghỉ... suy ngẫm',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          // Loop progress
          if (player.maxLoopCount > 0)
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                value: player.loopProgress,
                strokeWidth: 3,
                backgroundColor: Colors.white12,
                color: const Color(0xFF4CAF50),
              ),
            ),
          const SizedBox(width: 8),
          // Clear loop button
          IconButton(
            onPressed: () => player.clearLoop(),
            icon: const Icon(Icons.close, size: 18),
            color: Colors.red[300],
            tooltip: 'Dừng loop',
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // TEXT SECTION
  // ============================================================================

  Widget _buildTextSection(
      BuildContext context,
      PlayerProvider player,
      TextProvider textProvider,
      _ModeTheme theme,
      ) {
    if (textProvider.lines.isEmpty) {
      return _buildNoTextState(context, theme);
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Gesture hint
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.swipe, size: 12, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Vuốt ngang để đổi tốc độ • Chạm 2 lần để phát/dừng',
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          // Lyrics view
          Expanded(
            child: SyncedLyricsView(
              autoScroll: _autoScroll,
              onLineTap: (index, line) {
                textProvider.setCurrentLine(index);
                if (line.startTime != null) {
                  player.seek(line.startTime!);
                }
                HapticFeedback.selectionClick();
              },
              onLineDoubleTap: (index, line) {
                textProvider.setCurrentLine(index);
                textProvider.speakCurrentLine();
              },
              onLineLongPress: (index, line) {
                _showLineOptions(context, player, textProvider, index, line, theme);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoTextState(BuildContext context, _ModeTheme theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  theme.primary.withOpacity(0.2),
                  theme.secondary.withOpacity(0.1),
                ],
              ),
            ),
            child: Icon(
              Icons.text_snippet_outlined,
              size: 48,
              color: theme.primary.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Chưa có text/lyrics',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Thêm text để đồng bộ với audio',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _showImportOptions(context, theme),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Thêm Text'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // EMPTY STATE
  // ============================================================================

  Widget _buildEmptyState(
      BuildContext context,
      PlayerProvider player,
      _ModeTheme theme,
      ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),

          // Animated logo
          AnimatedBuilder(
            animation: _breathingAnimation,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      theme.primary.withOpacity(_breathingAnimation.value * 0.5),
                      theme.secondary.withOpacity(0.2),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.primary.withOpacity(_breathingAnimation.value * 0.3),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.sync_alt,
                  size: 56,
                  color: theme.primary,
                ),
              );
            },
          ),

          const SizedBox(height: 32),
          const Text(
            'Sync Hub',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Kết nối Audio & Text để học hiệu quả hơn',
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 40),

          // Action cards
          Row(
            children: [
              Expanded(
                child: _EmptyActionCard(
                  icon: Icons.music_note,
                  title: 'Chọn Audio',
                  subtitle: 'MP3, WAV, M4A...',
                  color: theme.primary,
                  onTap: () => _pickAudioFile(context),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _EmptyActionCard(
                  icon: Icons.text_snippet,
                  title: 'Thêm Text',
                  subtitle: 'TXT, SRT, LRC...',
                  color: const Color(0xFF4CAF50),
                  onTap: () => _showImportOptions(context, theme),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Features list
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                _FeatureItem(
                  icon: Icons.sync_alt,
                  text: 'Audio và Text đồng bộ theo thời gian',
                  color: theme.primary,
                ),
                _FeatureItem(
                  icon: Icons.speed,
                  text: 'Tốc độ siêu linh hoạt: 0.05x → 10x',
                  color: Colors.orange,
                ),
                _FeatureItem(
                  icon: Icons.loop,
                  text: 'A-B Loop với khoảng nghỉ suy ngẫm',
                  color: const Color(0xFF4CAF50),
                ),
                _FeatureItem(
                  icon: Icons.mic,
                  text: 'Shadowing: Ghi âm và so sánh giọng nói',
                  color: Colors.purple,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // RESIZE DIVIDER
  // ============================================================================

  Widget _buildResizeDivider(_ModeTheme theme) {
    return GestureDetector(
      onVerticalDragUpdate: (details) {
        setState(() {
          _splitRatio += details.delta.dy / MediaQuery.of(context).size.height;
          _splitRatio = _splitRatio.clamp(0.25, 0.55);
        });
      },
      child: Container(
        height: 24,
        color: Colors.transparent,
        child: Center(
          child: Container(
            width: 48,
            height: 4,
            decoration: BoxDecoration(
              color: theme.primary.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // DIALOGS & BOTTOM SHEETS
  // ============================================================================

  void _showImportOptions(BuildContext context, _ModeTheme theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Thêm Text/Lyrics',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.primary,
              ),
            ),
            const SizedBox(height: 20),
            _ImportOption(
              icon: Icons.file_open,
              title: 'Mở file',
              subtitle: 'TXT, SRT, LRC',
              color: theme.primary,
              onTap: () {
                Navigator.pop(context);
                _importTextFile(context);
              },
            ),
            _ImportOption(
              icon: Icons.paste,
              title: 'Dán văn bản',
              subtitle: 'Từ clipboard',
              color: const Color(0xFF4CAF50),
              onTap: () {
                Navigator.pop(context);
                _showPasteDialog(context, theme);
              },
            ),
            _ImportOption(
              icon: Icons.edit,
              title: 'Nhập thủ công',
              subtitle: 'Gõ từng dòng',
              color: Colors.orange,
              onTap: () {
                Navigator.pop(context);
                _showPasteDialog(context, theme);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _showUltraSpeedPicker(
      BuildContext context,
      PlayerProvider player,
      _ModeTheme theme,
      ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Icon(Icons.slow_motion_video, color: theme.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'Tốc độ Siêu Chậm',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Dùng để phân tích từng âm tiết, phoneme',
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                ),
                const SizedBox(height: 24),

                // Speed display
                Text(
                  '${player.state.speed.toStringAsFixed(2)}x',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: theme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _getSpeedDescription(player.state.speed, player.currentMode),
                  style: TextStyle(
                    color: theme.primary.withOpacity(0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 24),

                // Ultra slow range: 0.05 - 0.5
                const Text(
                  'Siêu chậm (0.05x - 0.5x)',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                Slider(
                  value: player.state.speed.clamp(0.05, 0.5),
                  min: 0.05,
                  max: 0.5,
                  divisions: 9,
                  activeColor: theme.primary,
                  onChanged: (value) {
                    player.setSpeed(value);
                    setModalState(() {});
                  },
                ),

                const SizedBox(height: 16),

                // Normal range: 0.5 - 2.0
                const Text(
                  'Bình thường (0.5x - 2.0x)',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                Slider(
                  value: player.state.speed.clamp(0.5, 2.0),
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
                  activeColor: theme.secondary,
                  onChanged: (value) {
                    player.setSpeed(value);
                    setModalState(() {});
                  },
                ),

                const SizedBox(height: 16),

                // Ultra fast range: 2.0 - 10.0
                const Text(
                  'Siêu nhanh (2.0x - 10.0x)',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                Slider(
                  value: player.state.speed.clamp(2.0, 10.0),
                  min: 2.0,
                  max: 10.0,
                  divisions: 16,
                  activeColor: Colors.orange,
                  onChanged: (value) {
                    player.setSpeed(value);
                    setModalState(() {});
                  },
                ),

                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showLineOptions(
      BuildContext context,
      PlayerProvider player,
      TextProvider textProvider,
      int index,
      TextItem line,
      _ModeTheme theme,
      ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Dòng ${index + 1}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                line.content,
                style: const TextStyle(color: Colors.white70),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),

            // Options
            _LineOptionTile(
              icon: Icons.volume_up,
              title: 'Đọc bằng TTS',
              subtitle: 'Nghe phát âm chuẩn',
              color: Colors.blue,
              onTap: () {
                Navigator.pop(context);
                textProvider.setCurrentLine(index);
                textProvider.speakCurrentLine();
              },
            ),
            _LineOptionTile(
              icon: Icons.loop,
              title: 'Tạo A-B Loop',
              subtitle: 'Lặp đoạn này ${player.modeSettings.defaultLoopCount} lần',
              color: const Color(0xFF4CAF50),
              onTap: () {
                Navigator.pop(context);
                if (line.startTime != null && line.endTime != null) {
                  player.setLoop(
                    line.startTime!,
                    line.endTime!,
                    repeatCount: player.modeSettings.defaultLoopCount,
                    gapSeconds: player.modeSettings.defaultGapDuration,
                  );
                } else {
                  final current = player.state.position;
                  player.setLoop(
                    current,
                    current + const Duration(seconds: 10),
                    repeatCount: player.modeSettings.defaultLoopCount,
                  );
                }
                player.play();
              },
            ),
            _LineOptionTile(
              icon: Icons.slow_motion_video,
              title: 'Nghe chậm ${player.modeSettings.defaultSpeed}x',
              subtitle: 'Nghe rõ từng từ',
              color: Colors.orange,
              onTap: () {
                Navigator.pop(context);
                player.setSpeed(player.modeSettings.defaultSpeed);
                if (line.startTime != null) {
                  player.seek(line.startTime!);
                }
                player.play();
              },
            ),

            // Shadowing (English mode only)
            if (player.isEnglishMode)
              _LineOptionTile(
                icon: Icons.mic,
                title: 'Shadowing',
                subtitle: 'Nghe → Ghi âm → So sánh',
                color: Colors.purple,
                onTap: () {
                  Navigator.pop(context);
                  _startShadowingSession(context, player, textProvider, line, theme);
                },
              ),

            _LineOptionTile(
              icon: Icons.flag,
              title: 'Đánh dấu KHÓ',
              subtitle: 'Thêm vào danh sách ôn tập',
              color: Colors.red,
              onTap: () {
                Navigator.pop(context);
                textProvider.markLineDifficulty(index, DifficultyMark.hard);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Đã đánh dấu là đoạn khó!'),
                    backgroundColor: Colors.red[700],
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            _LineOptionTile(
              icon: Icons.bookmark_add,
              title: 'Lưu Bookmark',
              subtitle: 'Lưu để nghe lại sau',
              color: Colors.amber,
              onTap: () {
                Navigator.pop(context);
                final segment = player.saveLoopAsSegment(
                  title: line.content.length > 30
                      ? '${line.content.substring(0, 30)}...'
                      : line.content,
                );
                if (segment != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã lưu bookmark!'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _startShadowingSession(
      BuildContext context,
      PlayerProvider player,
      TextProvider textProvider,
      TextItem line,
      _ModeTheme theme,
      ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ShadowingSheet(
        line: line,
        player: player,
        textProvider: textProvider,
        theme: theme,
      ),
    );
  }

  void _showShadowingGuide(BuildContext context, _ModeTheme theme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.mic, color: Colors.purple),
            const SizedBox(width: 8),
            const Text('Shadowing là gì?',
                style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _GuideStep(number: '1', text: 'Nghe đoạn audio mẫu'),
            _GuideStep(number: '2', text: 'Khi có tín hiệu, bạn nói theo'),
            _GuideStep(number: '3', text: 'App ghi âm giọng bạn'),
            _GuideStep(number: '4', text: 'So sánh 2 waveform để cải thiện'),
            const SizedBox(height: 12),
            Text(
              '💡 Mẹo: Bắt đầu với tốc độ 0.7x để dễ bắt kịp',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Đã hiểu', style: TextStyle(color: theme.primary)),
          ),
        ],
      ),
    );
  }

  void _showSyncSettings(BuildContext context, _ModeTheme theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final textProvider = context.watch<TextProvider>();
          final player = context.watch<PlayerProvider>();

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Cài đặt Sync Hub',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.primary,
                  ),
                ),
                const SizedBox(height: 16),

                // Auto scroll
                SwitchListTile(
                  secondary: Icon(Icons.swap_vert, color: theme.primary),
                  title: const Text('Tự động cuộn',
                      style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Cuộn theo vị trí audio',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  value: _autoScroll,
                  activeColor: theme.primary,
                  onChanged: (value) {
                    setModalState(() => _autoScroll = value);
                    setState(() {});
                  },
                ),

                // Font size
                ListTile(
                  leading: Icon(Icons.format_size, color: theme.primary),
                  title: const Text('Cỡ chữ',
                      style: TextStyle(color: Colors.white)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () {
                          textProvider.setFontSize(textProvider.fontSize - 2);
                          setModalState(() {});
                        },
                        icon: Icon(Icons.remove, color: theme.primary),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${textProvider.fontSize.toInt()}',
                          style: TextStyle(
                            color: theme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          textProvider.setFontSize(textProvider.fontSize + 2);
                          setModalState(() {});
                        },
                        icon: Icon(Icons.add, color: theme.primary),
                      ),
                    ],
                  ),
                ),

                // Show translation
                SwitchListTile(
                  secondary: Icon(Icons.translate, color: theme.primary),
                  title: const Text('Hiện bản dịch',
                      style: TextStyle(color: Colors.white)),
                  value: textProvider.showTranslation,
                  activeColor: theme.primary,
                  onChanged: (_) {
                    textProvider.toggleTranslation();
                    setModalState(() {});
                  },
                ),

                // TTS Speed
                ListTile(
                  leading: Icon(Icons.record_voice_over, color: theme.primary),
                  title: const Text('Tốc độ TTS',
                      style: TextStyle(color: Colors.white)),
                  subtitle: Text(
                    'Tốc độ đọc văn bản',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                  trailing: Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${textProvider.ttsSpeed.toStringAsFixed(1)}x',
                      style: TextStyle(
                        color: theme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  onTap: () => _showTtsSpeedPicker(context, textProvider, theme),
                ),

                // Default gap (for Buddhism mode)
                if (player.isBuddhismMode)
                  ListTile(
                    leading: Icon(Icons.timer, color: theme.primary),
                    title: const Text('Khoảng nghỉ mặc định',
                        style: TextStyle(color: Colors.white)),
                    trailing: Text(
                      '${player.gapDuration.toInt()}s',
                      style: TextStyle(color: theme.primary),
                    ),
                  ),

                const SizedBox(height: 10),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showTtsSpeedPicker(
      BuildContext context,
      TextProvider textProvider,
      _ModeTheme theme,
      ) {
    final speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Tốc độ TTS', style: TextStyle(color: theme.primary)),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: speeds.map((speed) {
            final isSelected = textProvider.ttsSpeed == speed;
            return ChoiceChip(
              label: Text('${speed}x'),
              selected: isSelected,
              selectedColor: theme.primary,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.grey,
              ),
              onSelected: (_) {
                textProvider.setTtsSpeed(speed);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showPasteDialog(BuildContext context, _ModeTheme theme) {
    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Dán văn bản',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.primary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 8,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Dán hoặc nhập text ở đây...\n\nMỗi dòng sẽ được hiển thị riêng.',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.primary),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Hủy'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      if (controller.text.trim().isNotEmpty) {
                        context.read<TextProvider>().loadText(controller.text);
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Thêm'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // FILE PICKERS
  // ============================================================================

  Future<void> _importTextFile(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'srt', 'lrc'],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = File(result.files.first.path!);
        final content = await file.readAsString();
        final title = result.files.first.name;

        if (context.mounted) {
          context.read<TextProvider>().loadText(content, title: title);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã tải: $title'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _pickAudioFile(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null && context.mounted) {
          await context.read<PlayerProvider>().loadSong(
            path: file.path!,
            title: file.name,
            autoPlay: true,
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ============================================================================
  // UTILITIES
  // ============================================================================

  void _showSpeedToast(
      BuildContext context,
      double speed,
      _ModeTheme theme,
      ) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.speed, color: theme.primary, size: 16),
            const SizedBox(width: 8),
            Text(
              '${speed.toStringAsFixed(2)}x',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 600),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 100, left: 100, right: 100),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: theme.surface,
      ),
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}

// ============================================================================
// HELPER CLASSES
// ============================================================================

class _ModeTheme {
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color background;
  final Color surface;
  final IconData icon;
  final String name;
  final List<double> speedPresets;
  final double defaultGap;

  const _ModeTheme({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.background,
    required this.surface,
    required this.icon,
    required this.name,
    required this.speedPresets,
    required this.defaultGap,
  });
}

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeedPresetButton extends StatelessWidget {
  final double speed;
  final bool isActive;
  final _ModeTheme theme;
  final VoidCallback onTap;

  const _SpeedPresetButton({
    required this.speed,
    required this.isActive,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? theme.primary : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? theme.primary : Colors.white12,
          ),
        ),
        child: Text(
          '${speed}x',
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _FineTuneButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final _ModeTheme theme;

  const _FineTuneButton({
    required this.icon,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: theme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 16, color: theme.primary),
      ),
    );
  }
}

class _GapAdjustButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final _ModeTheme theme;

  const _GapAdjustButton({
    required this.icon,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: theme.primary.withOpacity(0.2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 14, color: theme.primary),
      ),
    );
  }
}

class _EmptyActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _EmptyActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 36),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: color.withOpacity(0.7),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _FeatureItem({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ImportOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(subtitle,
          style: const TextStyle(color: Colors.grey, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}

class _LineOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _LineOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: Colors.grey, fontSize: 11),
      ),
      onTap: onTap,
    );
  }
}

class _GuideStep extends StatelessWidget {
  final String number;
  final String text;

  const _GuideStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Colors.purple,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SHADOWING SHEET
// ============================================================================

class _ShadowingSheet extends StatefulWidget {
  final TextItem line;
  final PlayerProvider player;
  final TextProvider textProvider;
  final _ModeTheme theme;

  const _ShadowingSheet({
    required this.line,
    required this.player,
    required this.textProvider,
    required this.theme,
  });

  @override
  State<_ShadowingSheet> createState() => _ShadowingSheetState();
}

class _ShadowingSheetState extends State<_ShadowingSheet> {
  _ShadowingPhase _phase = _ShadowingPhase.ready;
  int _currentRound = 1;
  final int _totalRounds = 3;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.purple, Colors.deepPurple],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.mic, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Shadowing Practice',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Nghe → Nói theo → So sánh',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.grey),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Progress dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_totalRounds, (i) {
              final isCompleted = i < _currentRound - 1;
              final isCurrent = i == _currentRound - 1;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 50,
                height: 4,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? Colors.green
                      : isCurrent
                      ? Colors.purple
                      : Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
          Text(
            'Lượt $_currentRound / $_totalRounds',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),

          const SizedBox(height: 24),

          // Text to shadow
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: widget.theme.primary.withOpacity(0.3)),
            ),
            child: Text(
              widget.line.content,
              style: const TextStyle(
                fontSize: 18,
                height: 1.5,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const Spacer(),

          // Phase indicator
          _buildPhaseIndicator(),

          const Spacer(),

          // Action button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _handleAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: _getButtonColor(),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                _getButtonText(),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildPhaseIndicator() {
    IconData icon;
    String text;
    Color color;

    switch (_phase) {
      case _ShadowingPhase.ready:
        icon = Icons.play_circle_outline;
        text = 'Bấm để bắt đầu nghe';
        color = Colors.blue;
        break;
      case _ShadowingPhase.listening:
        icon = Icons.hearing;
        text = 'Đang phát... Lắng nghe kỹ!';
        color = Colors.orange;
        break;
      case _ShadowingPhase.recording:
        icon = Icons.mic;
        text = 'Đến lượt bạn! Hãy nói theo';
        color = Colors.red;
        break;
      case _ShadowingPhase.comparing:
        icon = Icons.compare;
        text = 'Đang phân tích...';
        color = Colors.purple;
        break;
      case _ShadowingPhase.result:
        icon = Icons.check_circle;
        text = 'Hoàn thành!';
        color = Colors.green;
        break;
    }

    return Column(
      children: [
        Icon(icon, size: 64, color: color),
        const SizedBox(height: 12),
        Text(
          text,
          style: TextStyle(
            fontSize: 16,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _getButtonText() {
    switch (_phase) {
      case _ShadowingPhase.ready:
        return '▶️ Bắt đầu';
      case _ShadowingPhase.listening:
        return '🎧 Đang nghe...';
      case _ShadowingPhase.recording:
        return '🎤 Đang ghi âm...';
      case _ShadowingPhase.comparing:
        return '⏳ Đang xử lý...';
      case _ShadowingPhase.result:
        return _currentRound < _totalRounds ? '➡️ Lượt tiếp' : '✅ Hoàn thành';
    }
  }

  Color _getButtonColor() {
    switch (_phase) {
      case _ShadowingPhase.ready:
        return Colors.blue;
      case _ShadowingPhase.listening:
        return Colors.orange;
      case _ShadowingPhase.recording:
        return Colors.red;
      case _ShadowingPhase.comparing:
        return Colors.purple;
      case _ShadowingPhase.result:
        return Colors.green;
    }
  }

  void _handleAction() {
    switch (_phase) {
      case _ShadowingPhase.ready:
        _startListening();
        break;
      case _ShadowingPhase.listening:
      // Do nothing, waiting
        break;
      case _ShadowingPhase.recording:
      // Do nothing, recording
        break;
      case _ShadowingPhase.comparing:
      // Do nothing, processing
        break;
      case _ShadowingPhase.result:
        if (_currentRound < _totalRounds) {
          _currentRound++;
          _phase = _ShadowingPhase.ready;
          setState(() {});
        } else {
          Navigator.pop(context);
        }
        break;
    }
  }

  void _startListening() {
    setState(() => _phase = _ShadowingPhase.listening);

    // Play the audio segment
    if (widget.line.startTime != null) {
      widget.player.seek(widget.line.startTime!);
    }
    widget.player.play();

    // Simulate listening duration (in real app, listen for segment duration)
    _timer = Timer(const Duration(seconds: 3), () {
      widget.player.pause();
      _startRecording();
    });
  }

  void _startRecording() {
    setState(() => _phase = _ShadowingPhase.recording);

    // TODO: Start actual recording
    // In real implementation, use flutter_sound or record package

    // Simulate recording duration
    _timer = Timer(const Duration(seconds: 3), () {
      _compareResults();
    });
  }

  void _compareResults() {
    setState(() => _phase = _ShadowingPhase.comparing);

    // TODO: Compare waveforms or use speech recognition
    // In real implementation, analyze audio similarity

    // Simulate processing
    _timer = Timer(const Duration(seconds: 1), () {
      setState(() => _phase = _ShadowingPhase.result);
    });
  }
}

enum _ShadowingPhase {
  ready,
  listening,
  recording,
  comparing,
  result,
}