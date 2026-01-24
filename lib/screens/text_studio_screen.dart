import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

import '../providers/text_provider.dart';
import '../providers/player_provider.dart';
import '../models/text_item.dart';

class TextStudioScreen extends StatefulWidget {
  const TextStudioScreen({super.key});

  @override
  State<TextStudioScreen> createState() => _TextStudioScreenState();
}

class _TextStudioScreenState extends State<TextStudioScreen> {
  final TextEditingController _textController = TextEditingController();
  bool _isEditing = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  _ModeTheme _getModeTheme(VipMode mode) {
    switch (mode) {
      case VipMode.buddhism:
        return const _ModeTheme(
          primary: Color(0xFFFFB300),
          secondary: Color(0xFFFF8F00),
          icon: Icons.self_improvement,
          name: 'Phat Phap',
        );
      case VipMode.english:
        return const _ModeTheme(
          primary: Color(0xFF2196F3),
          secondary: Color(0xFF1976D2),
          icon: Icons.school,
          name: 'Tieng Anh',
        );
      case VipMode.music:
        return const _ModeTheme(
          primary: Color(0xFF6C63FF),
          secondary: Color(0xFF5B52CC),
          icon: Icons.music_note,
          name: 'Am Nhac',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F23),
      body: SafeArea(
        child: Consumer2<PlayerProvider, TextProvider>(
          builder: (context, player, textProvider, child) {
            final theme = _getModeTheme(player.currentMode);

            return Column(
              children: [
                _buildAppBar(context, textProvider, theme),
                _buildTtsControls(context, textProvider, theme),
                Expanded(
                  child: textProvider.lines.isEmpty
                      ? _buildEmptyState(context, theme)
                      : _buildTextContent(context, textProvider, theme),
                ),
                if (textProvider.lines.isNotEmpty)
                  _buildBottomControls(context, textProvider, theme),
              ],
            );
          },
        ),
      ),
    );
  }

  // ==================== APP BAR ====================

  Widget _buildAppBar(
      BuildContext context, TextProvider textProvider, _ModeTheme theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.primary.withOpacity(0.15),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.text_fields,
              color: theme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Text Studio • ${theme.name}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  textProvider.currentDocument?.title ?? 'Chua co van ban',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Import file button
          IconButton(
            onPressed: () => _importTextFile(context),
            icon: Icon(Icons.file_open, color: theme.primary),
            tooltip: 'Mo file text',
          ),
          // Paste text button
          IconButton(
            onPressed: () => _showPasteDialog(context),
            icon: Icon(Icons.paste, color: theme.primary),
            tooltip: 'Dan van ban',
          ),
          // Settings button
          IconButton(
            onPressed: () => _showSettingsSheet(context, textProvider, theme),
            icon: Icon(Icons.settings, color: theme.primary),
            tooltip: 'Cai dat',
          ),
        ],
      ),
    );
  }

  // ==================== TTS CONTROLS ====================

  Widget _buildTtsControls(
      BuildContext context, TextProvider textProvider, _ModeTheme theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Speed control
          Row(
            children: [
              const Icon(Icons.speed, size: 20, color: Colors.grey),
              const SizedBox(width: 8),
              const Text('Toc do:', style: TextStyle(color: Colors.grey)),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: theme.primary,
                    inactiveTrackColor: theme.primary.withOpacity(0.2),
                    thumbColor: theme.primary,
                  ),
                  child: Slider(
                    value: textProvider.ttsSpeed,
                    min: 0.25,
                    max: 2.0,
                    divisions: 7,
                    label: '${textProvider.ttsSpeed.toStringAsFixed(2)}x',
                    onChanged: (value) => textProvider.setTtsSpeed(value),
                  ),
                ),
              ),
              Text(
                '${textProvider.ttsSpeed.toStringAsFixed(2)}x',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // TTS Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _TtsButton(
                icon: Icons.play_arrow,
                label: 'Doc tat ca',
                color: Colors.green,
                onPressed: textProvider.lines.isEmpty
                    ? null
                    : () => textProvider.speakAllLines(),
              ),
              _TtsButton(
                icon: Icons.record_voice_over,
                label: 'Doc dong',
                color: Colors.blue,
                onPressed: textProvider.currentLineIndex < 0
                    ? null
                    : () => textProvider.speakCurrentLine(),
              ),
              _TtsButton(
                icon: Icons.select_all,
                label: 'Doc chon',
                color: Colors.orange,
                onPressed: textProvider.selectedText == null
                    ? null
                    : () => textProvider.speakSelected(),
              ),
              _TtsButton(
                icon: Icons.stop,
                label: 'Dung',
                color: Colors.red,
                isActive: textProvider.isSpeaking,
                onPressed: textProvider.isSpeaking
                    ? () => textProvider.stopSpeaking()
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== EMPTY STATE ====================

  Widget _buildEmptyState(BuildContext context, _ModeTheme theme) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: theme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.text_snippet,
                size: 64,
                color: theme.primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Chua co van ban',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Nhap hoac mo file text de bat dau',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _importTextFile(context),
                  icon: const Icon(Icons.file_open),
                  label: const Text('Mo file'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: () => _showPasteDialog(context),
                  icon: Icon(Icons.paste, color: theme.primary),
                  label: Text(
                    'Dan text',
                    style: TextStyle(color: theme.primary),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: theme.primary),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==================== TEXT CONTENT ====================

  Widget _buildTextContent(
      BuildContext context, TextProvider textProvider, _ModeTheme theme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: textProvider.lines.length,
      itemBuilder: (context, index) {
        final line = textProvider.lines[index];
        final isCurrentLine = index == textProvider.currentLineIndex;

        return GestureDetector(
          onTap: () {
            textProvider.setCurrentLine(index);
          },
          onDoubleTap: () {
            textProvider.setCurrentLine(index);
            textProvider.speakCurrentLine();
          },
          onLongPress: () {
            _showLineOptionsSheet(context, textProvider, index, line, theme);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isCurrentLine
                  ? theme.primary.withOpacity(0.2)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isCurrentLine ? theme.primary : Colors.transparent,
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Line number
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (isCurrentLine && textProvider.isSpeaking)
                      Icon(
                        Icons.volume_up,
                        size: 16,
                        color: theme.primary,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                // Content
                SelectableText(
                  line.content,
                  style: TextStyle(
                    fontSize: textProvider.fontSize,
                    color: Colors.white,
                    height: 1.5,
                  ),
                  onSelectionChanged: (selection, cause) {
                    if (selection.baseOffset != selection.extentOffset) {
                      final selected = line.content.substring(
                        selection.baseOffset,
                        selection.extentOffset,
                      );
                      textProvider.selectText(selected);
                    }
                  },
                ),
                // Translation (if available)
                if (textProvider.showTranslation && line.translation != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    line.translation!,
                    style: TextStyle(
                      fontSize: textProvider.fontSize - 2,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ==================== BOTTOM CONTROLS ====================

  Widget _buildBottomControls(
      BuildContext context, TextProvider textProvider, _ModeTheme theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _BottomButton(
            icon: Icons.text_decrease,
            label: 'A-',
            onPressed: () =>
                textProvider.setFontSize(textProvider.fontSize - 2),
          ),
          _BottomButton(
            icon: Icons.text_increase,
            label: 'A+',
            onPressed: () =>
                textProvider.setFontSize(textProvider.fontSize + 2),
          ),
          _BottomButton(
            icon: Icons.flag,
            label: 'Kho',
            color: Colors.red,
            onPressed: textProvider.selectedText != null
                ? () =>
                textProvider.markSelectedDifficulty(DifficultyMark.hard)
                : null,
          ),
          Consumer<PlayerProvider>(
            builder: (context, player, child) {
              return _BottomButton(
                icon: Icons.sync,
                label: 'Sync',
                color: player.currentSongPath != null
                    ? Colors.green
                    : Colors.grey,
                onPressed: player.currentSongPath != null
                    ? () => _syncWithAudio(context)
                    : null,
              );
            },
          ),
          _BottomButton(
            icon: Icons.clear_all,
            label: 'Xoa',
            onPressed: () => textProvider.clearText(),
          ),
        ],
      ),
    );
  }

  // ==================== DIALOGS & SHEETS ====================

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
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Loi doc file: $e')),
        );
      }
    }
  }

  void _showPasteDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nhap van ban',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _textController,
              maxLines: 8,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Dan hoac nhap van ban o day...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Huy'),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_textController.text.trim().isNotEmpty) {
                        context.read<TextProvider>().loadText(
                          _textController.text,
                          title: 'Van ban moi',
                        );
                        _textController.clear();
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text('Them van ban'),
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

  void _showSettingsSheet(
      BuildContext context, TextProvider textProvider, _ModeTheme theme) {
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
            const Text(
              'Cai dat Text Studio',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            // Font size
            Row(
              children: [
                const Icon(Icons.format_size, color: Colors.grey),
                const SizedBox(width: 12),
                const Text('Co chu:', style: TextStyle(color: Colors.white)),
                Expanded(
                  child: Slider(
                    value: textProvider.fontSize,
                    min: 12,
                    max: 32,
                    divisions: 10,
                    label: '${textProvider.fontSize.toInt()}',
                    onChanged: (value) => textProvider.setFontSize(value),
                  ),
                ),
                Text(
                  '${textProvider.fontSize.toInt()}',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
            // TTS Language
            ListTile(
              leading: const Icon(Icons.language, color: Colors.grey),
              title:
              const Text('Ngon ngu TTS', style: TextStyle(color: Colors.white)),
              trailing: DropdownButton<String>(
                value: textProvider.ttsLanguage,
                dropdownColor: const Color(0xFF1A1A2E),
                items: const [
                  DropdownMenuItem(value: 'en-US', child: Text('English (US)')),
                  DropdownMenuItem(value: 'en-GB', child: Text('English (UK)')),
                  DropdownMenuItem(value: 'vi-VN', child: Text('Tieng Viet')),
                ],
                onChanged: (value) {
                  if (value != null) textProvider.setTtsLanguage(value);
                },
              ),
            ),
            // Show translation toggle
            SwitchListTile(
              secondary: const Icon(Icons.translate, color: Colors.grey),
              title: const Text('Hien ban dich',
                  style: TextStyle(color: Colors.white)),
              value: textProvider.showTranslation,
              onChanged: (_) => textProvider.toggleTranslation(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showLineOptionsSheet(
      BuildContext context,
      TextProvider textProvider,
      int index,
      TextItem line,
      _ModeTheme theme,
      ) {
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
          children: [
            Text(
              'Dong ${index + 1}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.volume_up, color: theme.primary),
              title: const Text('Doc dong nay',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                textProvider.setCurrentLine(index);
                textProvider.speakCurrentLine();
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag, color: Colors.red),
              title: const Text('Danh dau KHO (5x)',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                textProvider.markLineDifficulty(index, DifficultyMark.hard);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag, color: Colors.orange),
              title: const Text('Danh dau VUA (3x)',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                textProvider.markLineDifficulty(index, DifficultyMark.medium);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag, color: Colors.green),
              title: const Text('Danh dau DE (1x)',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                textProvider.markLineDifficulty(index, DifficultyMark.easy);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _syncWithAudio(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Da ket noi voi Audio Player'),
        backgroundColor: Colors.green,
      ),
    );
  }
}

// ==================== HELPER WIDGETS ====================

class _TtsButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isActive;
  final VoidCallback? onPressed;

  const _TtsButton({
    required this.icon,
    required this.label,
    required this.color,
    this.isActive = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;

    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? color.withOpacity(0.3)
              : isEnabled
              ? color.withOpacity(0.1)
              : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isEnabled ? color : Colors.grey,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isEnabled ? color : Colors.grey,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  const _BottomButton({
    required this.icon,
    required this.label,
    this.color = Colors.white,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;

    return GestureDetector(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isEnabled ? color : Colors.grey,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isEnabled ? color : Colors.grey,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== HELPER CLASSES ====================

class _ModeTheme {
  final Color primary;
  final Color secondary;
  final IconData icon;
  final String name;

  const _ModeTheme({
    required this.primary,
    required this.secondary,
    required this.icon,
    required this.name,
  });
}