class PlaybackRunToken {
  final int id;
  const PlaybackRunToken(this.id);

  @override
  bool operator ==(Object other) =>
      other is PlaybackRunToken && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
