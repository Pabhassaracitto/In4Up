// lib/services/g2p_rules_service.dart
// NEW - Dịch vụ quy tắc G2P (Grapheme-to-Phoneme) để chuyển đổi văn bản thành phiên âm IPA

class G2PRulesService {
  /// Convert word to IPA using rules
  static List<String> predict(String word) {
    final phonemes = <String>[];
    final chars = word.toLowerCase().split('');

    int i = 0;
    while (i < chars.length) {
      final result = _matchRule(chars, i);
      if (result != null) {
        phonemes.addAll(result.phonemes);
        i += result.consumed;
      } else {
        i++;
      }
    }

    return phonemes.isEmpty ? _fallback(word) : phonemes;
  }

  static _RuleResult? _matchRule(List<String> chars, int pos) {
    final remaining = chars.sublist(pos).join();

    for (final rule in _rules) {
      if (remaining.startsWith(rule.pattern)) {
        return _RuleResult(
          phonemes: rule.phonemes,
          consumed: rule.pattern.length,
        );
      }
    }

    return null;
  }

  static List<String> _fallback(String word) {
    // Letter-by-letter fallback
    return word.toLowerCase().split('').map((c) {
      if ('aeiou'.contains(c)) return c;
      return c;
    }).toList();
  }

  static final List<_G2PRule> _rules = [
    // 4+ character patterns
    _G2PRule('tion', ['ʃ', 'ə', 'n']),
    _G2PRule('sion', ['ʒ', 'ə', 'n']),
    _G2PRule('ough', ['ʌ', 'f']),
    _G2PRule('ight', ['aɪ', 't']),

    // 3 character patterns
    _G2PRule('tch', ['tʃ']),
    _G2PRule('dge', ['dʒ']),
    _G2PRule('ing', ['ɪ', 'ŋ']),
    _G2PRule('ous', ['ə', 's']),
    _G2PRule('ure', ['ʊ', 'r']),
    _G2PRule('are', ['ɛ', 'r']),
    _G2PRule('ore', ['ɔ', 'r']),
    _G2PRule('ire', ['aɪ', 'r']),
    _G2PRule('ear', ['ɪ', 'r']),
    _G2PRule('all', ['ɔ', 'l']),

    // 2 character patterns
    _G2PRule('ch', ['tʃ']),
    _G2PRule('sh', ['ʃ']),
    _G2PRule('th', ['θ']),
    _G2PRule('ph', ['f']),
    _G2PRule('wh', ['w']),
    _G2PRule('ck', ['k']),
    _G2PRule('ng', ['ŋ']),
    _G2PRule('qu', ['k', 'w']),

    // Vowel digraphs
    _G2PRule('ee', ['i']),
    _G2PRule('ea', ['i']),
    _G2PRule('oo', ['u']),
    _G2PRule('ou', ['aʊ']),
    _G2PRule('ow', ['oʊ']),
    _G2PRule('oi', ['ɔɪ']),
    _G2PRule('oy', ['ɔɪ']),
    _G2PRule('ai', ['eɪ']),
    _G2PRule('ay', ['eɪ']),
    _G2PRule('au', ['ɔ']),
    _G2PRule('aw', ['ɔ']),
    _G2PRule('ew', ['u']),
    _G2PRule('ie', ['i']),

    // Single consonants
    _G2PRule('b', ['b']),
    _G2PRule('c', ['k']),
    _G2PRule('d', ['d']),
    _G2PRule('f', ['f']),
    _G2PRule('g', ['g']),
    _G2PRule('h', ['h']),
    _G2PRule('j', ['dʒ']),
    _G2PRule('k', ['k']),
    _G2PRule('l', ['l']),
    _G2PRule('m', ['m']),
    _G2PRule('n', ['n']),
    _G2PRule('p', ['p']),
    _G2PRule('r', ['r']),
    _G2PRule('s', ['s']),
    _G2PRule('t', ['t']),
    _G2PRule('v', ['v']),
    _G2PRule('w', ['w']),
    _G2PRule('x', ['k', 's']),
    _G2PRule('y', ['j']),
    _G2PRule('z', ['z']),

    // Single vowels
    _G2PRule('a', ['æ']),
    _G2PRule('e', ['ɛ']),
    _G2PRule('i', ['ɪ']),
    _G2PRule('o', ['ɑ']),
    _G2PRule('u', ['ʌ']),
  ];
}

class _G2PRule {
  final String pattern;
  final List<String> phonemes;

  const _G2PRule(this.pattern, this.phonemes);
}

class _RuleResult {
  final List<String> phonemes;
  final int consumed;

  _RuleResult({required this.phonemes, required this.consumed});
}
