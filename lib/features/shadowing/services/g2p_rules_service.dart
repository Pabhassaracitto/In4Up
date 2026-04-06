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
    const _G2PRule('tion', ['ʃ', 'ə', 'n']),
    const _G2PRule('sion', ['ʒ', 'ə', 'n']),
    const _G2PRule('ough', ['ʌ', 'f']),
    const _G2PRule('ight', ['aɪ', 't']),

    // 3 character patterns
    const _G2PRule('tch', ['tʃ']),
    const _G2PRule('dge', ['dʒ']),
    const _G2PRule('ing', ['ɪ', 'ŋ']),
    const _G2PRule('ous', ['ə', 's']),
    const _G2PRule('ure', ['ʊ', 'r']),
    const _G2PRule('are', ['ɛ', 'r']),
    const _G2PRule('ore', ['ɔ', 'r']),
    const _G2PRule('ire', ['aɪ', 'r']),
    const _G2PRule('ear', ['ɪ', 'r']),
    const _G2PRule('all', ['ɔ', 'l']),

    // 2 character patterns
    const _G2PRule('ch', ['tʃ']),
    const _G2PRule('sh', ['ʃ']),
    const _G2PRule('th', ['θ']),
    const _G2PRule('ph', ['f']),
    const _G2PRule('wh', ['w']),
    const _G2PRule('ck', ['k']),
    const _G2PRule('ng', ['ŋ']),
    const _G2PRule('qu', ['k', 'w']),

    // Vowel digraphs
    const _G2PRule('ee', ['i']),
    const _G2PRule('ea', ['i']),
    const _G2PRule('oo', ['u']),
    const _G2PRule('ou', ['aʊ']),
    const _G2PRule('ow', ['oʊ']),
    const _G2PRule('oi', ['ɔɪ']),
    const _G2PRule('oy', ['ɔɪ']),
    const _G2PRule('ai', ['eɪ']),
    const _G2PRule('ay', ['eɪ']),
    const _G2PRule('au', ['ɔ']),
    const _G2PRule('aw', ['ɔ']),
    const _G2PRule('ew', ['u']),
    const _G2PRule('ie', ['i']),

    // Single consonants
    const _G2PRule('b', ['b']),
    const _G2PRule('c', ['k']),
    const _G2PRule('d', ['d']),
    const _G2PRule('f', ['f']),
    const _G2PRule('g', ['g']),
    const _G2PRule('h', ['h']),
    const _G2PRule('j', ['dʒ']),
    const _G2PRule('k', ['k']),
    const _G2PRule('l', ['l']),
    const _G2PRule('m', ['m']),
    const _G2PRule('n', ['n']),
    const _G2PRule('p', ['p']),
    const _G2PRule('r', ['r']),
    const _G2PRule('s', ['s']),
    const _G2PRule('t', ['t']),
    const _G2PRule('v', ['v']),
    const _G2PRule('w', ['w']),
    const _G2PRule('x', ['k', 's']),
    const _G2PRule('y', ['j']),
    const _G2PRule('z', ['z']),

    // Single vowels
    const _G2PRule('a', ['æ']),
    const _G2PRule('e', ['ɛ']),
    const _G2PRule('i', ['ɪ']),
    const _G2PRule('o', ['ɑ']),
    const _G2PRule('u', ['ʌ']),
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
