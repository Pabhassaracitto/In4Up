// lib/screens/understand_mode/understand_mode_screen.dart
// VipSound - Chế độ HIỂU (Fixed version)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../models/shadowing_result.dart';
import '../../../models/waveform_data.dart';
import '../../../providers/player_provider.dart';
import '../../../providers/shadowing_provider.dart';
import '../../../providers/text_provider.dart';
import '../../../providers/waveform_provider.dart';
import '../listen_mode/controllers/rolling_waveform_controller.dart';
import '../listen_mode/widgets/rolling_waveform_view.dart';
import '../../../widgets/shadowing/pronunciation_result.dart';

// Import các components mới tách
import 'widgets/status_circle.dart';
import 'widgets/quick_button.dart';
import 'widgets/auto_scroll_button.dart';
import 'widgets/speed_chip.dart';
import 'widgets/progress_item.dart';
import 'widgets/shadowing_button.dart';
import 'widgets/guide_step.dart';
import 'sheets/loop_control_sheet.dart';
import 'sheets/speed_control_sheet.dart';

class UnderstandModeScreen extends StatefulWidget {
  const UnderstandModeScreen({super.key});

  @override
  State<UnderstandModeScreen> createState() => _UnderstandModeScreenState();
}

class _UnderstandModeScreenState extends State<UnderstandModeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late RollingWaveformController _waveformController;
  final ScrollController _textScrollController = ScrollController();

  // Auto-scroll to current line
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _waveformController = RollingWaveformController();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _waveformController.dispose();
    _textScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer4<PlayerProvider, TextProvider, WaveformProvider,
        ShadowingProvider>(
      builder: (context, player, textProvider, waveform, shadowing, child) {
        // Sync waveform data
        if (player.currentSongPath != null &&
            (waveform.waveformData.isEmpty ||
                waveform.currentFilePath != player.currentSongPath) &&
            !waveform.isLoading) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            waveform.loadWaveform(
                player.currentSongPath!, player.state.duration);
          });
        }

        if (waveform.waveformData.isNotEmpty) {
          final currentData = _waveformController.waveformData;
          if (currentData == null ||
              (player.state.duration > Duration.zero &&
                  currentData.duration != player.state.duration) ||
              currentData.samples.length != waveform.waveformData.length) {
            _waveformController.setWaveformData(WaveformData(
              samples: waveform.waveformData,
              duration: player.state.duration,
            ));
          }
        }

        if (_waveformController.position != player.state.position) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _waveformController.updatePosition(player.state.position);
            }
          });
        }

        if (player.loopStart != null && player.loopEnd != null) {
          if (_waveformController.loopRegions.isEmpty) {
            _waveformController.addLoopRegion(LoopRegion(
              start: player.loopStart!,
              end: player.loopEnd!,
            ));
          }
        } else {
          _waveformController.clearLoopRegions();
        }

        final hasAudio = player.currentSongPath != null;
        final hasText = textProvider.hasLyrics;

        if (!hasAudio || !hasText) {
          return _buildGuideState(context, hasAudio, hasText);
        }

        return Column(
          children: [
            _buildCompactTabs(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildSyncTab(player, textProvider),
                  _buildShadowingTab(player, textProvider, shadowing),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGuideState(BuildContext context, bool hasAudio, bool hasText) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                StatusCircle(
                  icon: Icons.headphones,
                  label: 'Audio',
                  isReady: hasAudio,
                  color: const Color(0xFF6C63FF),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  width: 40,
                  height: 2,
                  color: hasAudio && hasText
                      ? const Color(0xFFFFB300)
                      : Colors.grey[700],
                ),
                StatusCircle(
                  icon: Icons.menu_book,
                  label: 'Text',
                  isReady: hasText,
                  color: const Color(0xFF2196F3),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              hasAudio && hasText
                  ? 'Sẵn sàng!'
                  : hasAudio
                      ? 'Cần thêm văn bản'
                      : hasText
                          ? 'Cần thêm audio'
                          : 'Cần cả audio và text',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Chế độ Hiểu kết hợp audio với text để học hiệu quả',
              style: TextStyle(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (!hasAudio)
              QuickButton(
                icon: Icons.headphones,
                label: 'Thêm Audio',
                color: const Color(0xFF6C63FF),
                onTap: () {
                  HapticFeedback.mediumImpact();
                },
              ),
            if (!hasText) ...[
              if (!hasAudio) const SizedBox(height: 12),
              QuickButton(
                icon: Icons.menu_book,
                label: 'Thêm Text',
                color: const Color(0xFF2196F3),
                onTap: () {
                  HapticFeedback.mediumImpact();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompactTabs() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: const Color(0xFFFFB300),
        indicatorWeight: 3,
        labelColor: const Color(0xFFFFB300),
        unselectedLabelColor: Colors.grey,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'Đồng bộ'),
          Tab(text: 'Shadowing'),
        ],
      ),
    );
  }

  Widget _buildSyncTab(PlayerProvider player, TextProvider textProvider) {
    return Column(
      children: [
        Container(
          height: 120,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1520),
            border: Border(
              bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: RollingWaveformView(
                  controller: _waveformController,
                  onSeek: (position) => player.seek(position),
                  onTap: () => player.togglePlayPause(),
                  showControls: false,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Text(
                      _formatDuration(player.state.position),
                      style:
                          const TextStyle(fontSize: 10, color: Colors.white70),
                    ),
                    Expanded(
                      child: Slider(
                        value: player.state.duration.inMilliseconds > 0
                            ? player.state.position.inMilliseconds /
                                player.state.duration.inMilliseconds
                            : 0.0,
                        onChanged: (value) => player.seekToPercent(value),
                        activeColor: const Color(0xFFFFB300),
                        inactiveColor: Colors.white12,
                      ),
                    ),
                    Text(
                      _formatDuration(player.state.duration),
                      style:
                          const TextStyle(fontSize: 10, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              _buildSyncedTextList(player, textProvider),
              Positioned(
                top: 8,
                right: 8,
                child: AutoScrollButton(
                  isActive: _autoScroll,
                  onToggle: () {
                    setState(() => _autoScroll = !_autoScroll);
                    if (_autoScroll) {
                      _scrollToCurrentLine(textProvider);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        _buildQuickControls(player, textProvider),
      ],
    );
  }

  Widget _buildSyncedTextList(
      PlayerProvider player, TextProvider textProvider) {
    if (_autoScroll && player.isPlaying) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToCurrentLine(textProvider);
      });
    }

    return ListView.builder(
      controller: _textScrollController,
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
      itemCount: textProvider.lines.length,
      itemBuilder: (context, index) {
        final line = textProvider.lines[index];
        final isSynced = line.startTime != null;

        bool isActive = false;
        if (isSynced && line.startTime != null) {
          isActive = player.state.position >= line.startTime! &&
              (line.endTime == null || player.state.position <= line.endTime!);
        }

        if (isActive) {
          textProvider.setCurrentLine(index);
        }

        return GestureDetector(
          onTap: () {
            if (isSynced && line.startTime != null) {
              HapticFeedback.selectionClick();
              player.seek(line.startTime!);
              if (!player.isPlaying) player.play();
            }
          },
          onLongPress: () {
            if (isSynced && line.startTime != null && line.endTime != null) {
              HapticFeedback.mediumImpact();
              player.setLoop(line.startTime!, line.endTime!);
              _showLoopSetSnackbar(context, index);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 8),
            padding: EdgeInsets.fromLTRB(
              isActive ? 16 : 12,
              12,
              12,
              12,
            ),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFFFFB300).withOpacity(0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border(
                left: BorderSide(
                  color: isActive
                      ? const Color(0xFFFFB300)
                      : isSynced
                          ? Colors.white24
                          : Colors.transparent,
                  width: isActive ? 4 : 2,
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  margin: const EdgeInsets.only(right: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isActive
                              ? const Color(0xFFFFB300)
                              : Colors.grey[600],
                          fontWeight:
                              isActive ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      if (isSynced && line.startTime != null)
                        Text(
                          _formatDuration(line.startTime!),
                          style: TextStyle(
                            fontSize: 9,
                            color: isActive
                                ? const Color(0xFFFFB300).withOpacity(0.8)
                                : Colors.grey[700],
                            fontFamily: 'monospace',
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.content,
                        style: TextStyle(
                          color: isActive ? Colors.white : Colors.white70,
                          fontSize: 15,
                          height: 1.5,
                          fontWeight:
                              isActive ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
                      if (line.translation != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          line.translation!,
                          style: TextStyle(
                            color:
                                isActive ? Colors.grey[400] : Colors.grey[600],
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isActive)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB300).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.graphic_eq,
                      color: Color(0xFFFFB300),
                      size: 16,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickControls(PlayerProvider player, TextProvider textProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.replay_10),
            color: Colors.white70,
            onPressed: () => player.replay10(),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB300).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(player.isPlaying ? Icons.pause : Icons.play_arrow),
              color: const Color(0xFFFFB300),
              iconSize: 28,
              onPressed: () => player.togglePlayPause(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.forward_10),
            color: Colors.white70,
            onPressed: () => player.forward10(),
          ),
          const SizedBox(width: 16),
          if (player.isLooping)
            GestureDetector(
              onTap: () => showLoopControlSheet(context, player),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF4CAF50).withOpacity(0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.loop, size: 16, color: Color(0xFF4CAF50)),
                    const SizedBox(width: 4),
                    Text(
                      '${player.loopCount}x',
                      style: const TextStyle(
                        color: Color(0xFF4CAF50),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => player.clearLoop(),
                      child: const Icon(
                        Icons.close,
                        size: 14,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: () => _showSetLoopGuide(context),
              icon: const Icon(Icons.loop, size: 18),
              label: const Text('Set Loop'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey,
                side: BorderSide(color: Colors.grey[700]!),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          const Spacer(),
          SpeedChip(
            speed: player.state.speed,
            onTap: () => showSpeedControlSheet(context, player),
          ),
        ],
      ),
    );
  }

  Widget _buildShadowingTab(
    PlayerProvider player,
    TextProvider textProvider,
    ShadowingProvider shadowing,
  ) {
    if (player.loopStart == null || player.loopEnd == null) {
      return _buildShadowingGuide(player);
    }

    String loopText = '';
    final loopStart = player.loopStart!;
    final loopEnd = player.loopEnd!;

    final linesInLoop = <String>[];
    for (final line in textProvider.lines) {
      if (line.startTime == null) continue;

      final lineStart = line.startTime!;
      final lineEnd = line.endTime ?? (lineStart + const Duration(seconds: 5));

      if (lineStart <= loopEnd + const Duration(milliseconds: 500) &&
          lineEnd >= loopStart - const Duration(milliseconds: 500)) {
        linesInLoop.add(line.content);
      }
    }

    if (linesInLoop.isNotEmpty) {
      loopText = linesInLoop.join(' ');
    }

    if (loopText.isEmpty && textProvider.currentLineIndex >= 0) {
      final currentLine = textProvider.lines[textProvider.currentLineIndex];
      loopText = currentLine.content;
    }

    if (loopText.isEmpty) {
      Duration? closestDistance;
      String? closestText;

      for (final line in textProvider.lines) {
        if (line.startTime == null || line.content.trim().isEmpty) continue;

        final distance = (line.startTime! - loopStart).abs();
        if (closestDistance == null || distance < closestDistance) {
          closestDistance = distance;
          closestText = line.content;
        }
      }

      if (closestText != null) {
        loopText = closestText;
      }
    }

    debugPrint('📝 Loop text found: "$loopText"');

    if (loopText.isNotEmpty) {
      shadowing.setPracticeText(loopText);
    }
    if (player.currentSongPath != null) {
      shadowing.setOriginalAudioPath(player.currentSongPath!);
    }
    shadowing.setLoopRegion(loopStart, loopEnd);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildLoopInfoCard(player, shadowing, loopText),
          const SizedBox(height: 24),
          _buildControlButtons(player, shadowing, loopText),
          if (shadowing.userRecordingPath != null &&
              (shadowing.state == ShadowingState.idle ||
                  shadowing.state == ShadowingState.showingResults)) ...[
            const SizedBox(height: 12),
            ShadowingButton(
              icon: Icons.play_circle_outline,
              label: 'Nghe lại bản ghi',
              color: Colors.green,
              enabled: true,
              onTap: () => shadowing.playUserRecording(),
              fullWidth: true,
            ),
          ],
          if (shadowing.state == ShadowingState.analyzing) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                children: [
                  CircularProgressIndicator(color: Color(0xFF9C27B0)),
                  SizedBox(height: 16),
                  Text(
                    'Đang phân tích phát âm...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
          if (shadowing.state == ShadowingState.showingResults &&
              shadowing.currentResult != null) ...[
            const SizedBox(height: 24),
            PronunciationResultView(
              result: shadowing.currentResult!,
              onTryAgain: () => shadowing.reset(),
              onPlayRecording: shadowing.userRecordingPath != null
                  ? () => shadowing.playUserRecording()
                  : null,
            ),
          ],
          if (loopText.isEmpty) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Không tìm thấy text cho đoạn loop này.\n'
                      'Hãy đồng bộ text với audio trong tab Đồng bộ.',
                      style: TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          _buildShadowingSettings(shadowing),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildLoopInfoCard(
    PlayerProvider player,
    ShadowingProvider shadowing,
    String loopText,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF9C27B0).withOpacity(0.2),
            const Color(0xFF9C27B0).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF9C27B0).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.repeat, color: Color(0xFF9C27B0), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Đoạn luyện tập',
                style: TextStyle(
                  color: Color(0xFF9C27B0),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStateColor(shadowing.state).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getStateLabel(shadowing.state),
                  style: TextStyle(
                    color: _getStateColor(shadowing.state),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (loopText.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                loopText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ProgressItem(
                  label: 'Lần lặp',
                  current: shadowing.completedRepetitions,
                  target: shadowing.repeatCount,
                  color: const Color(0xFF9C27B0),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ProgressItem(
                  label: 'Tốc độ',
                  value: '${shadowing.playbackSpeed.toStringAsFixed(1)}x',
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ProgressItem(
                  label: 'Điểm',
                  value: '${(shadowing.similarityScore * 100).toInt()}%',
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlButtons(
    PlayerProvider player,
    ShadowingProvider shadowing,
    String loopText,
  ) {
    return Row(
      children: [
        Expanded(
          child: ShadowingButton(
            icon: shadowing.isPlaying ? Icons.stop : Icons.headphones,
            label: shadowing.isPlaying ? 'Dừng phát' : 'Nghe mẫu',
            color: Colors.blue,
            enabled: shadowing.state == ShadowingState.idle ||
                shadowing.state == ShadowingState.showingResults ||
                shadowing.state == ShadowingState.playingOriginal,
            onTap: () {
              if (shadowing.isPlaying) {
                shadowing.stopPlayback();
              } else {
                shadowing.playOriginal();
              }
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ShadowingButton(
            icon: shadowing.isRecording ? Icons.stop : Icons.mic,
            label: shadowing.isRecording
                ? 'Dừng (${_formatDuration(shadowing.recordingDuration)})'
                : shadowing.state == ShadowingState.countdown
                    ? 'Đếm: ${shadowing.countdown}'
                    : 'Ghi âm',
            color: shadowing.isRecording ? Colors.red : const Color(0xFF9C27B0),
            enabled: shadowing.state == ShadowingState.idle ||
                shadowing.state == ShadowingState.showingResults ||
                shadowing.isRecording,
            onTap: () {
              if (shadowing.isRecording) {
                shadowing.stopRecording();
              } else {
                shadowing.startShadowing();
              }
            },
          ),
        ),
      ],
    );
  }

  Color _getStateColor(ShadowingState state) {
    switch (state) {
      case ShadowingState.idle:
        return Colors.grey;
      case ShadowingState.playingOriginal:
        return Colors.blue;
      case ShadowingState.countdown:
        return Colors.orange;
      case ShadowingState.recording:
        return Colors.red;
      case ShadowingState.analyzing:
        return const Color(0xFF9C27B0);
      case ShadowingState.showingResults:
        return Colors.green;
    }
  }

  String _getStateLabel(ShadowingState state) {
    switch (state) {
      case ShadowingState.idle:
        return 'Sẵn sàng';
      case ShadowingState.playingOriginal:
        return '▶ Đang phát';
      case ShadowingState.countdown:
        return '⏱ Đếm ngược';
      case ShadowingState.recording:
        return '● Ghi âm';
      case ShadowingState.analyzing:
        return '🔍 Phân tích';
      case ShadowingState.showingResults:
        return '✅ Kết quả';
    }
  }

  Widget _buildShadowingGuide(PlayerProvider player) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF9C27B0).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.repeat,
                size: 48,
                color: Color(0xFF9C27B0),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Chọn đoạn để luyện Shadowing',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Long press vào câu trong tab "Đồng bộ"\nhoặc dùng nút Set Loop',
              style: TextStyle(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                _tabController.animateTo(0);
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('Về tab Đồng bộ'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9C27B0),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShadowingSettings(ShadowingProvider shadowing) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cài đặt luyện tập',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.repeat, size: 18, color: Color(0xFF9C27B0)),
              const SizedBox(width: 8),
              const Text('Số lần lặp:', style: TextStyle(color: Colors.grey)),
              const Spacer(),
              ...List.generate(5, (i) {
                final count = i + 1;
                return GestureDetector(
                  onTap: () => shadowing.setRepeatCount(count),
                  child: Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: shadowing.repeatCount == count
                          ? const Color(0xFF9C27B0)
                          : Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        color: shadowing.repeatCount == count
                            ? Colors.white
                            : Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.speed, size: 18, color: Colors.orange),
              const SizedBox(width: 8),
              const Text('Tốc độ:', style: TextStyle(color: Colors.grey)),
              Expanded(
                child: Slider(
                  value: shadowing.playbackSpeed,
                  min: 0.5,
                  max: 1.5,
                  divisions: 10,
                  activeColor: Colors.orange,
                  onChanged: (value) => shadowing.setPlaybackSpeed(value),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${shadowing.playbackSpeed.toStringAsFixed(1)}x',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _scrollToCurrentLine(TextProvider textProvider) {
    if (textProvider.currentLineIndex < 0) return;

    final itemHeight = 80.0;
    final targetOffset = textProvider.currentLineIndex * itemHeight;
    final viewportHeight = _textScrollController.position.viewportDimension;
    final centerOffset = targetOffset - (viewportHeight / 2) + (itemHeight / 2);

    _textScrollController.animateTo(
      centerOffset.clamp(0.0, _textScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _showLoopSetSnackbar(BuildContext context, int lineIndex) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã set loop cho dòng ${lineIndex + 1}'),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Xóa',
          textColor: Colors.white,
          onPressed: () => context.read<PlayerProvider>().clearLoop(),
        ),
      ),
    );
  }

  void _showSetLoopGuide(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.loop, color: Color(0xFF4CAF50)),
                SizedBox(width: 8),
                Text(
                  'Cách set A-B Loop',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GuideStep(
              number: '1',
              text: 'Long press vào câu muốn lặp',
              icon: Icons.touch_app,
            ),
            const SizedBox(height: 12),
            GuideStep(
              number: '2',
              text: 'Hoặc dùng nút A-B trong player',
              icon: Icons.repeat,
            ),
            const SizedBox(height: 12),
            GuideStep(
              number: '3',
              text: 'Điều chỉnh vùng loop trên waveform',
              icon: Icons.tune,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                minimumSize: const Size(double.infinity, 44),
              ),
              child: const Text('Đã hiểu'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }
}
