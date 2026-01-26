import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../providers/text_provider.dart';
import '../providers/waveform_provider.dart';
import '../providers/shadowing_provider.dart';
import '../widgets/waveform_editor.dart';
import '../widgets/shadowing_widget.dart';

/// Chế độ HIỂU - Sync Mode (Text + Audio + Shadowing)
/// Focus: Split view, đồng bộ text-audio, shadowing, dictionary
class UnderstandModeScreen extends StatefulWidget {
  const UnderstandModeScreen({super.key});

  @override
  State<UnderstandModeScreen> createState() => _UnderstandModeScreenState();
}

class _UnderstandModeScreenState extends State<UnderstandModeScreen>
    with SingleTickerProviderStateMixin {
  // View mode
  bool _showShadowing = false;
  double _splitRatio = 0.4; // 40% waveform, 60% text

  // Tab controller for sub-features
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer4<PlayerProvider, TextProvider, WaveformProvider, ShadowingProvider>(
      builder: (context, player, textProvider, waveform, shadowing, child) {
        // Check requirements
        final hasAudio = player.currentSongPath != null;
        final hasText = textProvider.hasLyrics;

        // Empty state if nothing loaded
        if (!hasAudio && !hasText) {
          return _buildEmptyState(context);
        }

        // Partial state (only audio or only text)
        if (!hasAudio || !hasText) {
          return _buildPartialState(context, hasAudio, hasText);
        }

        // Full mode: both audio and text
        return _buildSyncMode(context, player, textProvider, waveform, shadowing);
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFFB300).withOpacity(0.2),
                    const Color(0xFFFF8F00).withOpacity(0.1),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.psychology,
                size: 64,
                color: Color(0xFFFFB300),
              ),
            ),
            const SizedBox(height: 24),

            // Title
            const Text(
              'Chế độ Hiểu',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),

            Text(
              'Kết hợp Nghe + Đọc để hiểu sâu',
              style: TextStyle(color: Colors.grey[500]),
            ),
            const SizedBox(height: 32),

            // Instructions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFB300).withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  _StepItem(number: 1, text: 'Vào Tab "Nghe" để chọn audio'),
                  const SizedBox(height: 12),
                  _StepItem(number: 2, text: 'Vào Tab "Đọc" để thêm văn bản'),
                  const SizedBox(height: 12),
                  _StepItem(number: 3, text: 'Quay lại đây để đồng bộ & học'),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Features preview
            _buildFeaturesList(),
          ],
        ),
      ),
    );
  }

  Widget _buildPartialState(BuildContext context, bool hasAudio, bool hasText) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Status icons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StatusIcon(
                  icon: Icons.headphones,
                  label: 'Audio',
                  isReady: hasAudio,
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.add,
                  color: Colors.grey[600],
                  size: 24,
                ),
                const SizedBox(width: 16),
                _StatusIcon(
                  icon: Icons.menu_book,
                  label: 'Text',
                  isReady: hasText,
                ),
              ],
            ),

            const SizedBox(height: 32),

            Text(
              hasAudio ? 'Cần thêm văn bản' : 'Cần thêm audio',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),

            Text(
              hasAudio
                  ? 'Vuốt từ cạnh trái hoặc vào Tab "Đọc"'
                  : 'Vuốt từ cạnh phải hoặc vào Tab "Nghe"',
              style: TextStyle(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            // Quick action
            ElevatedButton.icon(
              onPressed: () {
                // Navigate to appropriate tab
                HapticFeedback.mediumImpact();
              },
              icon: Icon(hasAudio ? Icons.menu_book : Icons.headphones),
              label: Text(hasAudio ? 'Thêm Text' : 'Thêm Audio'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB300),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncMode(
      BuildContext context,
      PlayerProvider player,
      TextProvider textProvider,
      WaveformProvider waveform,
      ShadowingProvider shadowing,
      ) {
    return Column(
      children: [
        // Mode tabs
        _buildModeTabs(),

        // Content based on tab
        Expanded(
          child: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              // Tab 1: Sync View (Split)
              _buildSplitView(player, textProvider, waveform),

              // Tab 2: Shadowing
              _buildShadowingView(player, shadowing),

              // Tab 3: Dictionary/SRS
              _buildDictionaryView(textProvider),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModeTabs() {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: TabBar(
        controller: _tabController,
        indicatorColor: const Color(0xFFFFB300),
        labelColor: const Color(0xFFFFB300),
        unselectedLabelColor: Colors.grey,
        tabs: const [
          Tab(
            icon: Icon(Icons.sync, size: 20),
            text: 'Đồng bộ',
          ),
          Tab(
            icon: Icon(Icons.mic, size: 20),
            text: 'Shadowing',
          ),
          Tab(
            icon: Icon(Icons.book, size: 20),
            text: 'Từ điển',
          ),
        ],
      ),
    );
  }

  Widget _buildSplitView(
      PlayerProvider player,
      TextProvider textProvider,
      WaveformProvider waveform,
      ) {
    return Column(
      children: [
        // Waveform section (adjustable)
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: MediaQuery.of(context).size.height * _splitRatio * 0.5,
          child: const WaveformEditor(
            height: 180,
            showControls: false,
            showMarkersList: false,
          ),
        ),

        // Divider with drag handle
        GestureDetector(
          onVerticalDragUpdate: (details) {
            setState(() {
              _splitRatio = (_splitRatio + details.primaryDelta! / MediaQuery.of(context).size.height)
                  .clamp(0.2, 0.6);
            });
          },
          child: Container(
            height: 24,
            color: const Color(0xFF1A1A2E),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),

        // Text section
        Expanded(
          child: Container(
            color: const Color(0xFF0D1520),
            child: _buildSyncedTextList(player, textProvider),
          ),
        ),

        // Mini controls
        _buildMiniControls(player),
      ],
    );
  }

  Widget _buildSyncedTextList(PlayerProvider player, TextProvider textProvider) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: textProvider.lines.length,
      itemBuilder: (context, index) {
        final line = textProvider.lines[index];

        // Check if line is currently playing - SỬA LỖI
        final isSynced = line.startTime != null;
        bool isActive = false;
        if (isSynced && line.startTime != null) {
          isActive = player.state.position >= line.startTime! &&
              (line.endTime == null || player.state.position <= line.endTime!);
        }

        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            if (isSynced && line.startTime != null) { // SỬA LỖI
              player.seek(line.startTime!);
            }
          },
          onLongPress: () {
            // Set A-B loop for this line - SỬA LỖI
            if (isSynced && line.startTime != null && line.endTime != null) {
              player.setLoop(line.startTime!, line.endTime!);
              HapticFeedback.mediumImpact();
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFFFFB300).withOpacity(0.15)
                  : Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
              border: isActive
                  ? Border.all(color: const Color(0xFFFFB300).withOpacity(0.5))
                  : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time badge
                if (isSynced && line.startTime != null) // SỬA LỖI
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFFFFB300).withOpacity(0.3)
                          : Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _formatDuration(line.startTime!), // SỬA LỖI
                      style: TextStyle(
                        fontSize: 10,
                        color: isActive ? const Color(0xFFFFB300) : Colors.grey,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),

                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.content, // SỬA LỖI: từ line.text thành line.content
                        style: TextStyle(
                          color: isActive ? Colors.white : Colors.white70,
                          fontSize: 16,
                          height: 1.5,
                          fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
                      if (line.translation != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          line.translation!,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Active indicator
                if (isActive)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    child: const Icon(
                      Icons.volume_up,
                      color: Color(0xFFFFB300),
                      size: 18,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMiniControls(PlayerProvider player) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: const Color(0xFF1A1A2E),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.replay_10),
            color: Colors.white70,
            onPressed: () => player.replay10(),
          ),
          const SizedBox(width: 16),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFB300).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(player.isPlaying ? Icons.pause : Icons.play_arrow),
              color: const Color(0xFFFFB300),
              iconSize: 32,
              onPressed: () => player.togglePlayPause(),
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.forward_10),
            color: Colors.white70,
            onPressed: () => player.forward10(),
          ),
        ],
      ),
    );
  }

  Widget _buildShadowingView(PlayerProvider player, ShadowingProvider shadowing) {
    // Check if loop is set
    if (player.loopStart == null || player.loopEnd == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, size: 48, color: Colors.grey[600]),
              const SizedBox(height: 16),
              const Text(
                'Chọn đoạn để luyện Shadowing',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Long press vào một câu trong tab "Đồng bộ"\nhoặc dùng A-B Loop trong Waveform',
                style: TextStyle(color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Auto-setup shadowing if not done
    if (shadowing.state == ShadowingState.idle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        shadowing.setSegment(
          start: player.loopStart!,
          end: player.loopEnd!,
          audioPath: player.currentSongPath ?? '',
          waveform: [],
        );
      });
    }

    return const SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: ShadowingWidget(),
    );
  }

  Widget _buildDictionaryView(TextProvider textProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.book,
                size: 48,
                color: Color(0xFF4CAF50),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Từ điển & SRS',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap vào từ trong text để tra cứu\nvà thêm vào danh sách ôn tập',
              style: TextStyle(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                children: [
                  _FeatureRow(icon: Icons.search, text: 'Tra cứu từ điển'),
                  SizedBox(height: 12),
                  _FeatureRow(icon: Icons.refresh, text: 'Spaced Repetition (SRS)'),
                  SizedBox(height: 12),
                  _FeatureRow(icon: Icons.collections_bookmark, text: 'Flashcards'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Coming Soon',
                style: TextStyle(
                  color: Color(0xFF4CAF50),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesList() {
    final features = [
      (Icons.sync, 'Đồng bộ text với audio'),
      (Icons.mic, 'Luyện Shadowing'),
      (Icons.book, 'Tra từ điển tích hợp'),
      (Icons.refresh, 'Ôn tập với SRS'),
      (Icons.touch_app, 'Tap câu để nhảy tới'),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: features.map((f) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(f.$1, color: const Color(0xFFFFB300), size: 20),
                const SizedBox(width: 12),
                Text(
                  f.$2,
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }
}

// Helper widgets
class _StepItem extends StatelessWidget {
  final int number;
  final String text;

  const _StepItem({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFFFFB300).withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$number',
              style: const TextStyle(
                color: Color(0xFFFFB300),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      ],
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isReady;

  const _StatusIcon({
    required this.icon,
    required this.label,
    required this.isReady,
  });

  @override
  Widget build(BuildContext context) {
    final color = isReady ? const Color(0xFF4CAF50) : Colors.grey;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Icon(icon, color: color, size: 32),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isReady ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color)),
          ],
        ),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF4CAF50), size: 18),
        const SizedBox(width: 12),
        Text(text, style: TextStyle(color: Colors.grey[400])),
      ],
    );
  }
}