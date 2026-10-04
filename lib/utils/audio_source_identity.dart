/// Canonical identity used when binding transcripts and cache results to audio.
///
/// File pickers may return the same path with Windows separators, URI-encoded
/// characters, or different casing. Those representations must compare equal,
/// while two genuinely different files must never share an in-memory LRC.
class AudioSourceIdentity {
  const AudioSourceIdentity._();

  static bool matches(String first, String second) =>
      normalize(first) == normalize(second);

  static String normalize(String path) {
    final normalized = path.replaceAll('\\', '/').trim().toLowerCase();
    try {
      return Uri.decodeFull(normalized);
    } catch (_) {
      return normalized;
    }
  }
}
