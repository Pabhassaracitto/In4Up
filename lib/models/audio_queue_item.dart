import 'audio_library_entry.dart';
import 'audio_playlist.dart';

/// One occurrence in the current playback queue, not a saved playlist.
///
/// [source] is the original file path or content URI. A temporary path used by
/// the audio engine must never be saved as the identity of a MediaStore item.
class AudioQueueItem {
  final String source;
  final String title;
  final String? artist;
  final String? libraryId;

  const AudioQueueItem({
    required this.source,
    required this.title,
    this.artist,
    this.libraryId,
  });

  factory AudioQueueItem.fromLibrary(AudioLibraryEntry entry) => AudioQueueItem(
        source: entry.uri,
        title: entry.title,
        artist: entry.artist,
        libraryId: entry.libraryId,
      );

  /// Snapshot the saved order, including unavailable IDs as placeholders.
  static List<AudioQueueItem> fromPlaylist(
    AudioPlaylist playlist,
    Iterable<AudioLibraryEntry> entries,
  ) {
    final byId = {for (final entry in entries) entry.libraryId: entry};
    return List<AudioQueueItem>.unmodifiable([
      for (final id in playlist.trackIds)
        if (byId[id] != null)
          AudioQueueItem.fromLibrary(byId[id]!)
        else
          AudioQueueItem.missing(id),
    ]);
  }

  /// Preserve the position of an unavailable ID in a saved playlist without
  /// deleting or guessing its original source.
  const AudioQueueItem.missing(String id)
      : source = '',
        title = '',
        artist = null,
        libraryId = id;

  bool get isMissing => source.isEmpty;
}
