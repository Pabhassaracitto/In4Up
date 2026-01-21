enum AudioCategory {
  dharma('Pháp thoại', '☸️', Color(0xFFFFD700)),
  english('Tiếng Anh', '🇬🇧', Color(0xFF4CAF50)),
  meditation('Thiền', '🧘', Color(0xFF9C27B0)),
  music('Nhạc', '🎵', Color(0xFF2196F3)),
  podcast('Podcast', '🎙️', Color(0xFFFF5722)),
  other('Khác', '📁', Colors.grey);

  const AudioCategory(this.label, this.emoji, this.color);
  
  final String label;
  final String emoji;
  final Color color;
}