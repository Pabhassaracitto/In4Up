import 'dart:async';
import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter/services.dart';

import '../models/cabin_caption.dart';
import '../services/stts_cabin_service.dart';

class LiveCabinScreen extends StatefulWidget {
  const LiveCabinScreen({super.key});

  @override
  State<LiveCabinScreen> createState() => _LiveCabinScreenState();
}

class _LiveCabinScreenState extends State<LiveCabinScreen>
    with SingleTickerProviderStateMixin {
  final SttsCabinService _service = SttsCabinService();
  final ScrollController _scrollController = ScrollController();

  late AnimationController _pulseController;
  bool _showHeadphoneBanner = false;
  Timer? _bannerTimer;

  static const _supportedLanguages = <String, String>{
    'en': 'English',
    'vi': 'Tiếng Việt',
    'zh': '中文 (Chinese)',
    'fr': 'Français (French)',
    'de': 'Deutsch (German)',
    'ja': '日本語 (Japanese)',
    'ko': '한국어 (Korean)',
    'th': 'ไทย (Thai)',
    'hi': 'हिन्दी (Hindi)',
    'si': 'සිංහල (Sinhala)',
    'my': 'မြန်မာ (Burmese)',
    'pi': 'Pāli',
  };

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceUpdate);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _service.removeListener(_onServiceUpdate);
    _pulseController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onServiceUpdate() {
    if (!mounted) return;
    setState(() {});
    // Auto-scroll to bottom on new finalized caption
    if (_service.displayMode == CabinDisplayMode.fullTranscript &&
        _scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _toggleDubbing() {
    final next = !_service.isDubbingEnabled;
    _service.setDubbing(next);

    if (next) {
      // Show headphone reminder banner
      _bannerTimer?.cancel();
      setState(() => _showHeadphoneBanner = true);
      _bannerTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _showHeadphoneBanner = false);
      });
    } else {
      setState(() => _showHeadphoneBanner = false);
    }
  }

  void _showLanguagePicker({required bool isSource}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  context.uiText(isSource ? 'Chọn ngôn ngữ nói (Gốc)' : 'Chọn ngôn ngữ dịch (Đích)'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  children: _supportedLanguages.entries.map((entry) {
                    final selected = isSource
                        ? _service.sourceLanguage == entry.key
                        : _service.targetLanguage == entry.key;
                    return ListTile(
                      leading: Icon(
                        selected ? Icons.check_circle : Icons.circle_outlined,
                        color: selected ? const Color(0xFF00E676) : Colors.grey,
                      ),
                      title: Text(
                        entry.value,
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.white70,
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: Text(
                        entry.key.toUpperCase(),
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        if (isSource) {
                          _service.setSourceLanguage(entry.key);
                        } else {
                          _service.setTargetLanguage(entry.key);
                        }
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _copyAllTranscript() {
    if (_service.history.isEmpty) return;
    final buffer = StringBuffer();
    for (final c in _service.history) {
      buffer.writeln('[${c.sourceLang.toUpperCase()}] ${c.sourceText}');
      buffer.writeln('[${c.targetLang.toUpperCase()}] ${c.translatedText}');
      buffer.writeln('');
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.uiText('Đã sao chép toàn bộ nội dung dịch cabin vào bộ nhớ tạm!')),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141A32),
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.interpreter_mode_rounded, color: Color(0xFF00E676), size: 22),
            const SizedBox(width: 8),
            Text(
              context.uiText('Dịch Live Cabin'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: context.uiText('Sao chép văn bản'),
            icon: const Icon(Icons.copy_rounded, size: 20),
            onPressed: _service.history.isNotEmpty ? _copyAllTranscript : null,
          ),
          IconButton(
            tooltip: context.uiText('Xóa lịch sử'),
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            onPressed: _service.history.isNotEmpty
                ? () {
                    _service.clearHistory();
                    HapticFeedback.lightImpact();
                  }
                : null,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Language Pair Selector & Mode Chips
            _buildLanguageAndModeBar(),

            // Headphone Warning Banner
            if (_showHeadphoneBanner) _buildHeadphoneReminder(),

            // Error banner if any
            if (_service.lastError != null) _buildErrorBanner(),

            // Main Visualizer & Transcript Area
            Expanded(
              child: _buildMainContent(),
            ),

            // Bottom Control Toolbar
            _buildBottomControlBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageAndModeBar() {
    final srcName = _supportedLanguages[_service.sourceLanguage] ?? _service.sourceLanguage.toUpperCase();
    final tgtName = _supportedLanguages[_service.targetLanguage] ?? _service.targetLanguage.toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF141A32),
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Source Lang Button
              Expanded(
                child: InkWell(
                  onTap: () => _showLanguagePicker(isSource: true),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F2847),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            srcName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, color: Colors.white54, size: 18),
                      ],
                    ),
                  ),
                ),
              ),

              // Swap Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: IconButton(
                  icon: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF00E676)),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    _service.swapLanguages();
                  },
                ),
              ),

              // Target Lang Button
              Expanded(
                child: InkWell(
                  onTap: () => _showLanguagePicker(isSource: false),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F2847),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            tgtName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, color: Colors.white54, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Display Mode Segmented Control
          Row(
            children: [
              _buildModeChip('1 Chữ', CabinDisplayMode.oneWord),
              const SizedBox(width: 8),
              _buildModeChip('1 Dòng', CabinDisplayMode.oneLine),
              const SizedBox(width: 8),
              _buildModeChip('Toàn bộ', CabinDisplayMode.fullTranscript),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeChip(String label, CabinDisplayMode mode) {
    final isSelected = _service.displayMode == mode;
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          _service.setDisplayMode(mode);
        },
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF00E676).withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFF00E676).withValues(alpha: 0.6) : Colors.white10,
            ),
          ),
          child: Text(
            context.uiText(label),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? const Color(0xFF00E676) : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeadphoneReminder() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2E1C0C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.headphones_rounded, color: Color(0xFFFF9800), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.uiText('Khuyên dùng tai nghe khi bật phát âm để tránh tiếng dịch lọt ngược vào micro!'),
              style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 11, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _service.lastError!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    if (_service.displayMode == CabinDisplayMode.oneWord) {
      return _buildOneWordView();
    }
    if (_service.displayMode == CabinDisplayMode.oneLine) {
      return _buildOneLineView();
    }
    return _buildFullTranscriptView();
  }

  Widget _buildOneWordView() {
    final active = _service.activeCaption;
    final lastWord = active?.sourceText.split(RegExp(r'\s+')).lastWhere((w) => w.isNotEmpty, orElse: () => '') ?? '...';
    final translated = active?.translatedText ?? '';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_service.isListening)
              FadeTransition(
                opacity: Tween(begin: 0.4, end: 1.0).animate(_pulseController),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E676).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.mic, color: Color(0xFF00E676), size: 16),
                      const SizedBox(width: 6),
                      Text(context.uiText('Đang nghe trực tiếp...'), style: const TextStyle(color: Color(0xFF00E676), fontSize: 12)),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 30),
            Text(
              lastWord.isNotEmpty ? lastWord : '...',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 42,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 16),
            if (translated.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF141A32),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.3)),
                ),
                child: Text(
                  translated,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF00E676),
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOneLineView() {
    final active = _service.activeCaption;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Original Speech Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF141A32),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _service.isListening
                    ? const Color(0xFF6C63FF).withValues(alpha: 0.6)
                    : Colors.white12,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.record_voice_over_rounded, color: Color(0xFF6C63FF), size: 18),
                        const SizedBox(width: 6),
                      Text(
                        '${context.uiText('GỐC')} (${_service.sourceLanguage.toUpperCase()})',
                        style: const TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ],
                  ),
                  if (_service.isListening)
                    FadeTransition(
                      opacity: Tween(begin: 0.3, end: 1.0).animate(_pulseController),
                      child: const Row(
                        children: [
                          Icon(Icons.circle, color: Color(0xFF00E676), size: 8),
                          SizedBox(width: 4),
                          Text('Live', style: TextStyle(color: Color(0xFF00E676), fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                active?.sourceText.isNotEmpty == true
                    ? active!.sourceText
                    : context.uiText('Nói vào microphone để bắt đầu dịch cabin...'),
                style: TextStyle(
                  color: active?.sourceText.isNotEmpty == true ? Colors.white : Colors.white38,
                  fontSize: 18,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Translated Output Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF13222E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF00E676).withValues(alpha: 0.4),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.translate_rounded, color: Color(0xFF00E676), size: 18),
                      const SizedBox(width: 6),
                      Text(
                        '${context.uiText('BẢN DỊCH')} (${_service.targetLanguage.toUpperCase()})',
                        style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ],
                  ),
                  if (active?.translatedText.isNotEmpty == true)
                    IconButton(
                      icon: const Icon(Icons.volume_up_rounded, color: Color(0xFF00E676), size: 20),
                      onPressed: () => _service.replayCaption(active!),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                active?.translatedText.isNotEmpty == true
                    ? active!.translatedText
                    : context.uiText('Bản dịch thời gian thực sẽ hiển thị tại đây...'),
                style: TextStyle(
                  color: active?.translatedText.isNotEmpty == true
                      ? const Color(0xFFE8F5E9)
                      : Colors.white30,
                  fontSize: 19,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullTranscriptView() {
    if (_service.history.isEmpty && _service.activeCaption == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mic_none_rounded, size: 64, color: Colors.white.withValues(alpha: 0.15)),
            const SizedBox(height: 16),
            Text(
              context.uiText('Chưa có dữ liệu hội thoại.\nBấm nút Micro để bắt đầu phiên dịch cabin.'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 14, height: 1.5),
            ),
          ],
        ),
      );
    }

    final items = [..._service.history];
    if (_service.activeCaption != null && !_service.activeCaption!.isFinal) {
      items.add(_service.activeCaption!);
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final caption = items[index];
        return _buildTranscriptCard(caption, index);
      },
    );
  }

  Widget _buildTranscriptCard(CabinCaption caption, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141A32),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: caption.isFinal ? Colors.white10 : const Color(0xFF00E676).withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '#${index + 1} · ${_fmtTime(caption.timestamp)}',
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (caption.translatedText.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.volume_up_rounded, size: 16, color: Color(0xFF00E676)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _service.replayCaption(caption),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 15, color: Colors.grey),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: '${caption.sourceText}\n${caption.translatedText}'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.uiText('Đã chép câu dịch!')), duration: const Duration(seconds: 1)),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            caption.sourceText,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          if (caption.translatedText.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              caption.translatedText,
              style: const TextStyle(
                color: Color(0xFF00E676),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomControlBar() {
    final isListening = _service.isListening;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        color: Color(0xFF141A32),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Dubbing Switch (Phát âm bản dịch)
          InkWell(
            onTap: _toggleDubbing,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _service.isDubbingEnabled
                    ? const Color(0xFF00E676).withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _service.isDubbingEnabled ? const Color(0xFF00E676) : Colors.white12,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _service.isDubbingEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                    color: _service.isDubbingEnabled ? const Color(0xFF00E676) : Colors.grey,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    context.uiText('Đọc dịch'),
                    style: TextStyle(
                      color: _service.isDubbingEnabled ? const Color(0xFF00E676) : Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Main Mic Toggle Button
          GestureDetector(
            onTap: () async {
              HapticFeedback.heavyImpact();
              if (isListening) {
                await _service.stopCabin();
              } else {
                await _service.startCabin();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isListening ? const Color(0xFFFF5252) : const Color(0xFF00E676),
                boxShadow: [
                  BoxShadow(
                    color: (isListening ? const Color(0xFFFF5252) : const Color(0xFF00E676)).withValues(alpha: 0.4),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                isListening ? Icons.stop_rounded : Icons.mic_rounded,
                color: Colors.black,
                size: 32,
              ),
            ),
          ),

          // Pause / Resume Button
          IconButton(
            icon: Icon(
              _service.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              color: isListening || _service.isPaused ? Colors.white : Colors.white30,
              size: 28,
            ),
            onPressed: isListening || _service.isPaused
                ? () {
                    HapticFeedback.mediumImpact();
                    _service.togglePause();
                  }
                : null,
          ),
        ],
      ),
    );
  }

  String _fmtTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
