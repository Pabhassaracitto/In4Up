// Model đơn giản đại diện cho 1 dòng text + bản dịch
class TextLine {
  final String content;      // Tiếng Anh gốc
  final String? translation; // Bản dịch tiếng Việt (nullable)

  const TextLine({
    required this.content,
    this.translation,
  });
}
