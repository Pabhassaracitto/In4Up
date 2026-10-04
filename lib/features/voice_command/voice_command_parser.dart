/// Pure, dependency-free voice command grammar.
enum VoiceCommandType { play, pause, next, previous, faster, slower, toggleLyrics, translate }

class VoiceCommand {
  final VoiceCommandType type;
  final String phrase;
  const VoiceCommand(this.type, this.phrase);
}

String _normalize(String value) {
  const from = 'áàảãạăắằẳẵặâấầẩẫậéèẻẽẹêếềểễệíìỉĩịóòỏõọôốồổỗộơớờởỡợúùủũụưứừửữựýỳỷỹỵđ';
  const to =   'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiioooooooooooooouuuuuuuuuuuuyyyyyd';
  var result = value.toLowerCase();
  for (var i = 0; i < from.length; i++) {
    result = result.replaceAll(from[i], to[i]);
  }
  return result.replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}

VoiceCommand? parseVoiceCommand(String phrase) {
  final text = _normalize(phrase);
  if (text.isEmpty) return null;
  const grammar = <VoiceCommandType, List<String>>{
    VoiceCommandType.play: ['phat', 'choi', 'play', 'tiep tuc', 'bat dau'],
    VoiceCommandType.pause: ['tam dung', 'dung', 'pause', 'ngung'],
    VoiceCommandType.next: ['tiep theo', 'tai tiep', 'bai tiep', 'next', 'tiep'],
    VoiceCommandType.previous: ['bai truoc', 'truoc', 'previous', 'quay lai', 'lui'],
    VoiceCommandType.faster: ['nhanh hon', 'tang toc', 'faster'],
    VoiceCommandType.slower: ['cham hon', 'giam toc', 'slower'],
    VoiceCommandType.toggleLyrics: ['hien loi', 'an loi', 'lyrics'],
    VoiceCommandType.translate: ['dich', 'translate'],
  };
  for (final entry in grammar.entries) {
    for (final candidate in entry.value) {
      if (text == candidate || text.contains(candidate)) {
        return VoiceCommand(entry.key, phrase);
      }
    }
  }
  return null;
}
