// lib/services/shadowing/cmu_dictionary_service.dart
// Service load và query CMU Pronouncing Dictionary (134,000+ từ)

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/phoneme_models.dart';

class CMUDictionaryService {
  static Map<String, List<List<String>>>? _dictionary;
  static bool _initialized = false;
  static bool _isLoading = false;

  /// Bảng chuyển đổi ARPAbet → IPA
  static const Map<String, String> _arpaToIPA = {
    // Vowels
    'AA': 'ɑ', 'AA0': 'ɑ', 'AA1': 'ˈɑ', 'AA2': 'ˌɑ',
    'AE': 'æ', 'AE0': 'æ', 'AE1': 'ˈæ', 'AE2': 'ˌæ',
    'AH': 'ʌ', 'AH0': 'ə', 'AH1': 'ˈʌ', 'AH2': 'ˌʌ',
    'AO': 'ɔ', 'AO0': 'ɔ', 'AO1': 'ˈɔ', 'AO2': 'ˌɔ',
    'AW': 'aʊ', 'AW0': 'aʊ', 'AW1': 'ˈaʊ', 'AW2': 'ˌaʊ',
    'AY': 'aɪ', 'AY0': 'aɪ', 'AY1': 'ˈaɪ', 'AY2': 'ˌaɪ',
    'EH': 'ɛ', 'EH0': 'ɛ', 'EH1': 'ˈɛ', 'EH2': 'ˌɛ',
    'ER': 'ɝ', 'ER0': 'ɚ', 'ER1': 'ˈɝ', 'ER2': 'ˌɝ',
    'EY': 'eɪ', 'EY0': 'eɪ', 'EY1': 'ˈeɪ', 'EY2': 'ˌeɪ',
    'IH': 'ɪ', 'IH0': 'ɪ', 'IH1': 'ˈɪ', 'IH2': 'ˌɪ',
    'IY': 'i', 'IY0': 'i', 'IY1': 'ˈi', 'IY2': 'ˌi',
    'OW': 'oʊ', 'OW0': 'oʊ', 'OW1': 'ˈoʊ', 'OW2': 'ˌoʊ',
    'OY': 'ɔɪ', 'OY0': 'ɔɪ', 'OY1': 'ˈɔɪ', 'OY2': 'ˌɔɪ',
    'UH': 'ʊ', 'UH0': 'ʊ', 'UH1': 'ˈʊ', 'UH2': 'ˌʊ',
    'UW': 'u', 'UW0': 'u', 'UW1': 'ˈu', 'UW2': 'ˌu',
    // Consonants
    'B': 'b', 'CH': 'tʃ', 'D': 'd', 'DH': 'ð',
    'F': 'f', 'G': 'g', 'HH': 'h', 'JH': 'dʒ',
    'K': 'k', 'L': 'l', 'M': 'm', 'N': 'n',
    'NG': 'ŋ', 'P': 'p', 'R': 'r', 'S': 's',
    'SH': 'ʃ', 'T': 't', 'TH': 'θ', 'V': 'v',
    'W': 'w', 'Y': 'j', 'Z': 'z', 'ZH': 'ʒ',
  };

  /// Khởi tạo dictionary từ assets
  static Future<void> initialize() async {
    if (_initialized || _isLoading) return;
    _isLoading = true;

    try {
      debugPrint('📚 Loading CMU Dictionary...');

      // Thử load từ assets
      String? dictString;
      try {
        dictString =
            await rootBundle.loadString('assets/dictionary/cmudict.dict');
      } catch (e) {
        debugPrint('⚠️ CMU Dictionary not found, using built-in mini dict');
        _dictionary = _getBuiltInDictionary();
        _initialized = true;
        _isLoading = false;
        return;
      }

      _dictionary = {};
      int count = 0;

      for (final line in dictString.split('\n')) {
        if (line.startsWith(';;;') || line.trim().isEmpty) continue;

        // Sử dụng double quotes cho RegExp với special characters
        final match =
            RegExp(r"^([A-Za-z'\-\.]+)(?:\((\d+)\))?\s+(.+)$").firstMatch(line);
        if (match == null) continue;

        final word = match.group(1)!.toLowerCase();
        final phonemesStr = match.group(3)!;
        final phonemes =
            phonemesStr.split(' ').where((p) => p.isNotEmpty).toList();

        final ipaPhonemes = phonemes.map((p) {
          return _arpaToIPA[p] ?? p.toLowerCase();
        }).toList();

        _dictionary![word] ??= [];
        _dictionary![word]!.add(ipaPhonemes);
        count++;
      }

      _initialized = true;
      debugPrint('✅ CMU Dictionary loaded: $count entries');
    } catch (e) {
      debugPrint('❌ Failed to load CMU Dictionary: $e');
      _dictionary = _getBuiltInDictionary();
    } finally {
      _isLoading = false;
    }
  }

  /// Built-in dictionary cho các từ thông dụng
  static Map<String, List<List<String>>> _getBuiltInDictionary() {
    return {
      'hello': [
        ['h', 'ə', 'l', 'oʊ']
      ],
      'world': [
        ['w', 'ɝ', 'l', 'd']
      ],
      'the': [
        ['ð', 'ə']
      ],
      'a': [
        ['ə']
      ],
      'is': [
        ['ɪ', 'z']
      ],
      'are': [
        ['ɑ', 'r']
      ],
      'you': [
        ['j', 'u']
      ],
      'i': [
        ['aɪ']
      ],
      'we': [
        ['w', 'i']
      ],
      'they': [
        ['ð', 'eɪ']
      ],
      'this': [
        ['ð', 'ɪ', 's']
      ],
      'that': [
        ['ð', 'æ', 't']
      ],
      'good': [
        ['g', 'ʊ', 'd']
      ],
      'thank': [
        ['θ', 'æ', 'ŋ', 'k']
      ],
      'please': [
        ['p', 'l', 'i', 'z']
      ],
      'yes': [
        ['j', 'ɛ', 's']
      ],
      'no': [
        ['n', 'oʊ']
      ],
      'love': [
        ['l', 'ʌ', 'v']
      ],
      'like': [
        ['l', 'aɪ', 'k']
      ],
      'have': [
        ['h', 'æ', 'v']
      ],
      'do': [
        ['d', 'u']
      ],
      'go': [
        ['g', 'oʊ']
      ],
      'see': [
        ['s', 'i']
      ],
      'think': [
        ['θ', 'ɪ', 'ŋ', 'k']
      ],
      'know': [
        ['n', 'oʊ']
      ],
      'say': [
        ['s', 'eɪ']
      ],
      'speak': [
        ['s', 'p', 'i', 'k']
      ],
      'english': [
        ['ɪ', 'ŋ', 'g', 'l', 'ɪ', 'ʃ']
      ],
      'practice': [
        ['p', 'r', 'æ', 'k', 't', 'ɪ', 's']
      ],
    };
  }

  static bool get isInitialized => _initialized;
  static int get wordCount => _dictionary?.length ?? 0;

  static List<String>? getIPA(String word) {
    if (!_initialized) return null;
    // Sử dụng double quotes cho RegExp
    final clean = word.toLowerCase().replaceAll(RegExp(r"[^\w\-']"), '');
    final variants = _dictionary?[clean];
    return variants?.isNotEmpty == true ? variants!.first : null;
  }

  static bool hasWord(String word) {
    if (!_initialized) return false;
    final clean = word.toLowerCase().replaceAll(RegExp(r"[^\w\-']"), '');
    return _dictionary?.containsKey(clean) ?? false;
  }

  static PhonemeType getPhonemeType(String phoneme) {
    final clean = phoneme.replaceAll(RegExp(r'[ˈˌ]'), '');

    const vowels = {'ɑ', 'æ', 'ʌ', 'ə', 'ɔ', 'ɛ', 'ɝ', 'ɚ', 'ɪ', 'i', 'ʊ', 'u'};
    const diphthongs = {'aʊ', 'aɪ', 'eɪ', 'oʊ', 'ɔɪ'};

    if (diphthongs.contains(clean)) return PhonemeType.diphthong;
    if (vowels.contains(clean)) return PhonemeType.vowel;
    return PhonemeType.consonant;
  }

  static String getPhonemeDescription(String phoneme) {
    final clean = phoneme.replaceAll(RegExp(r'[ˈˌ]'), '');

    const descriptions = {
      'ɑ': 'như "a" trong "father"',
      'æ': 'như "a" trong "cat"',
      'ʌ': 'như "u" trong "cup"',
      'ə': 'âm schwa, như "a" trong "about"',
      'ɔ': 'như "o" trong "thought"',
      'ɛ': 'như "e" trong "bed"',
      'ɝ': 'như "ir" trong "bird"',
      'ɪ': 'như "i" trong "bit"',
      'i': 'như "ee" trong "bee"',
      'ʊ': 'như "oo" trong "book"',
      'u': 'như "oo" trong "boot"',
      'aʊ': 'như "ow" trong "how"',
      'aɪ': 'như "i" trong "my"',
      'eɪ': 'như "ay" trong "say"',
      'oʊ': 'như "o" trong "go"',
      'ɔɪ': 'như "oy" trong "boy"',
      'b': 'âm "b"',
      'd': 'âm "d"',
      'f': 'âm "f"',
      'g': 'âm "g"',
      'h': 'âm "h"',
      'k': 'âm "k"',
      'l': 'âm "l"',
      'm': 'âm "m"',
      'n': 'âm "n"',
      'ŋ': 'như "ng" trong "sing"',
      'p': 'âm "p"',
      'r': 'âm "r"',
      's': 'âm "s"',
      't': 'âm "t"',
      'v': 'âm "v"',
      'w': 'âm "w"',
      'j': 'âm "y"',
      'z': 'âm "z"',
      'ʃ': 'như "sh" trong "ship"',
      'ʒ': 'như "s" trong "measure"',
      'tʃ': 'như "ch" trong "church"',
      'dʒ': 'như "j" trong "judge"',
      'θ': 'như "th" trong "think"',
      'ð': 'như "th" trong "this"',
    };

    return descriptions[clean] ?? 'Phoneme: $clean';
  }

  static List<String> getPhonemeExamples(String phoneme) {
    final clean = phoneme.replaceAll(RegExp(r'[ˈˌ]'), '');

    const examples = {
      'ɑ': ['father', 'hot', 'spa'],
      'æ': ['cat', 'bad', 'man'],
      'ʌ': ['cup', 'love', 'blood'],
      'ə': ['about', 'banana', 'sofa'],
      'i': ['bee', 'see', 'key'],
      'ɪ': ['bit', 'sit', 'gym'],
      'u': ['boot', 'food', 'blue'],
      'ʊ': ['book', 'put', 'good'],
      'eɪ': ['say', 'make', 'rain'],
      'aɪ': ['my', 'time', 'fly'],
      'oʊ': ['go', 'home', 'show'],
      'aʊ': ['how', 'out', 'house'],
      'ɔɪ': ['boy', 'coin', 'joy'],
      'ʃ': ['ship', 'she', 'nation'],
      'tʃ': ['church', 'check', 'watch'],
      'dʒ': ['judge', 'job', 'edge'],
      'θ': ['think', 'bath', 'tooth'],
      'ð': ['this', 'mother', 'breathe'],
      'ŋ': ['sing', 'ring', 'thing'],
    };

    return examples[clean] ?? [];
  }
}
