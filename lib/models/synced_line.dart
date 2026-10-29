class SyncedLine {
  final String id;
  final String text;
  final String? translation;
  final Duration startTime;
  final Duration? endTime;
  final bool isHighlighted;

  SyncedLine({
    required this.id,
    required this.text,
    this.translation,
    required this.startTime,
    this.endTime,
    this.isHighlighted = false,
  });

  SyncedLine copyWith({
    String? id,
    String? text,
    String? translation,
    Duration? startTime,
    Duration? endTime,
    bool? isHighlighted,
  }) {
    return SyncedLine(
      id: id ?? this.id,
      text: text ?? this.text,
      translation: translation ?? this.translation,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isHighlighted: isHighlighted ?? this.isHighlighted,
    );
  }

  // Parse từ định dạng LRC: [00:30.50]Text here
  static SyncedLine? fromLrc(String line, int index) {
    final regex = RegExp(r'\[(\d{2}):(\d{2})\.?(\d{0,2})\](.*)');
    final match = regex.firstMatch(line);

    if (match != null) {
      final minutes = int.parse(match.group(1)!);
      final seconds = int.parse(match.group(2)!);
      final millisStr = match.group(3) ?? '0';
      final millis = millisStr.isNotEmpty ? int.parse(millisStr.padRight(3, '0')) : 0;
      // Bỏ inline word timestamps `<mm:ss.cs>` để không lộ ra text hiển thị.
      var text = (match.group(4) ?? '').trim();
      text = text.replaceAll(RegExp(r'<\d{2}:\d{2}\.\d{2,3}>'), '').trim();

      if (text.isEmpty) return null;

      return SyncedLine(
        id: 'line_$index',
        text: text,
        startTime: Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: millis,
        ),
      );
    }
    return null;
  }

  // Parse từ định dạng SRT
  static List<SyncedLine> fromSrt(String content) {
    final lines = <SyncedLine>[];
    final blocks = content.split(RegExp(r'\n\n+'));

    for (int i = 0; i < blocks.length; i++) {
      final block = blocks[i].trim();
      if (block.isEmpty) continue;

      final parts = block.split('\n');
      if (parts.length < 3) continue;

      // Parse timestamp: 00:00:30,500 --> 00:00:35,000
      final timeRegex = RegExp(
          r'(\d{2}):(\d{2}):(\d{2})[,.](\d{3})\s*-->\s*(\d{2}):(\d{2}):(\d{2})[,.](\d{3})'
      );
      final timeMatch = timeRegex.firstMatch(parts[1]);

      if (timeMatch != null) {
        final startTime = Duration(
          hours: int.parse(timeMatch.group(1)!),
          minutes: int.parse(timeMatch.group(2)!),
          seconds: int.parse(timeMatch.group(3)!),
          milliseconds: int.parse(timeMatch.group(4)!),
        );

        final endTime = Duration(
          hours: int.parse(timeMatch.group(5)!),
          minutes: int.parse(timeMatch.group(6)!),
          seconds: int.parse(timeMatch.group(7)!),
          milliseconds: int.parse(timeMatch.group(8)!),
        );

        final text = parts.sublist(2).join(' ').trim();

        if (text.isNotEmpty) {
          lines.add(SyncedLine(
            id: 'srt_$i',
            text: text,
            startTime: startTime,
            endTime: endTime,
          ));
        }
      }
    }

    return lines;
  }

  // Chuyển thành LRC format
  String toLrc() {
    final minutes = startTime.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = startTime.inSeconds.remainder(60).toString().padLeft(2, '0');
    final millis = (startTime.inMilliseconds.remainder(1000) ~/ 10).toString().padLeft(2, '0');
    return '[$minutes:$seconds.$millis]$text';
  }
}

class SyncedDocument {
  final String id;
  final String title;
  final String? audioPath;
  final List<SyncedLine> lines;
  final DateTime createdAt;

  SyncedDocument({
    required this.id,
    required this.title,
    this.audioPath,
    required this.lines,
    required this.createdAt,
  });

  // Parse từ file LRC
  static SyncedDocument fromLrcContent(String content, {String? title, String? audioPath}) {
    final lines = <SyncedLine>[];
    final rawLines = content.split('\n');

    int index = 0;
    for (final rawLine in rawLines) {
      final line = SyncedLine.fromLrc(rawLine.trim(), index);
      if (line != null) {
        lines.add(line);
        index++;
      }
    }

    // Sort by start time
    lines.sort((a, b) => a.startTime.compareTo(b.startTime));

    return SyncedDocument(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title ?? 'Untitled',
      audioPath: audioPath,
      lines: lines,
      createdAt: DateTime.now(),
    );
  }

  // Parse từ file SRT
  static SyncedDocument fromSrtContent(String content, {String? title, String? audioPath}) {
    final lines = SyncedLine.fromSrt(content);

    return SyncedDocument(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title ?? 'Untitled',
      audioPath: audioPath,
      lines: lines,
      createdAt: DateTime.now(),
    );
  }
}