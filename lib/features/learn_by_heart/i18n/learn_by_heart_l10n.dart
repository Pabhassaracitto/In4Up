// lib/features/learn_by_heart/i18n/learn_by_heart_l10n.dart

import 'package:flutter/material.dart';

/// Hỗ trợ bản địa hóa chuẩn quốc tế cho module Thuộc Lòng (Learn by Heart)
/// Ngôn ngữ đầy đủ: Tiếng Việt (vi), English (en), Hindi (hi),
/// Trung giản thể (zh), Trung phồn thể (zh_TW), Sinhala (si).
/// Fallback mặc định: English (en).
class LearnByHeartL10n {
  final String locale;

  const LearnByHeartL10n(this.locale);

  static LearnByHeartL10n of(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final tag = locale.toLanguageTag().replaceAll('-', '_');
    return LearnByHeartL10n(_resolveLocale(tag));
  }

  static String _resolveLocale(String tag) {
    final lower = tag.toLowerCase();
    if (lower.startsWith('vi')) return 'vi';
    if (lower.contains('tw') || lower.contains('hant') || lower.contains('hk')) return 'zh_TW';
    if (lower.startsWith('zh')) return 'zh';
    if (lower.startsWith('hi')) return 'hi';
    if (lower.startsWith('si')) return 'si';
    return 'en';
  }

  String _get(Map<String, String> map) {
    return map[locale] ?? map['en'] ?? '';
  }

  // ===== TIÊU ĐỀ & CHUNG =====
  String get moduleTitle => _get({
        'vi': 'Thuộc Lòng · Learn by Heart',
        'en': 'Memorization · Learn by Heart',
        'hi': 'कंठस्थ · Learn by Heart',
        'zh': '背诵记忆 · Learn by Heart',
        'zh_TW': '背誦記憶 · Learn by Heart',
        'si': 'පාඩම් මතක තබා ගැනීම · Learn by Heart',
      });

  String get moduleSubtitle => _get({
        'vi': 'Kinh Pháp Cú, kinh tụng & đoạn kinh ý nghĩa',
        'en': 'Dhammapada verses, chanting & meaningful suttas',
        'hi': 'धम्मपद गाथाएं, पाठ और अर्थपूर्ण सूत्र',
        'zh': '法句经、唱诵与义理经文',
        'zh_TW': '法句經、唱誦與義理經文',
        'si': 'ධම්මපදය, සජ්ඣායනා සහ අර්ථවත් සූත්‍ර',
      });

  String get dueToday => _get({
        'vi': 'bài cần ôn hôm nay',
        'en': 'verses due today',
        'hi': 'आज दोहराने के लिए गाथाएं',
        'zh': '今日待复习篇目',
        'zh_TW': '今日待複習篇目',
        'si': 'අද සමාලෝචනය කළ යුතු ගාථා',
      });

  String get allDoneToday => _get({
        'vi': 'Đã hoàn thành hôm nay',
        'en': 'All caught up for today',
        'hi': 'आज का अभ्यास पूर्ण हुआ',
        'zh': '今日复习已全部完成',
        'zh_TW': '今日複習已全部完成',
        'si': 'අද සියල්ල සම්පූර්ණයි',
      });

  String streakText(int count) => _get({
        'vi': '$count ngày liên tiếp',
        'en': '$count day streak',
        'hi': '$count दिनों की निरंतरता',
        'zh': '连续 $count 天',
        'zh_TW': '連續 $count 天',
        'si': 'දින $count ක අඛණ්ඩතාව',
      });

  String get mastered => _get({
        'vi': 'Thuộc vững',
        'en': 'Mastered',
        'hi': 'कंठस्थ',
        'zh': '熟练掌握',
        'zh_TW': '熟練掌握',
        'si': 'ප්‍රගුණ කළ',
      });

  String get totalCount => _get({
        'vi': 'Tổng số',
        'en': 'Total',
        'hi': 'कुल',
        'zh': '总数',
        'zh_TW': '總數',
        'si': 'මුළු එකතුව',
      });

  String get reviewNow => _get({
        'vi': 'Ôn ngay',
        'en': 'Review Now',
        'hi': 'अभी दोहराएं',
        'zh': '立即复习',
        'zh_TW': '立即複習',
        'si': 'දැන් සමාලෝචනය කරන්න',
      });

  String get practice => _get({
        'vi': 'Ôn luyện',
        'en': 'Practice',
        'hi': 'अभ्यास करें',
        'zh': '自由练习',
        'zh_TW': '自由練習',
        'si': 'පුහුණු වන්න',
      });

  String get searchHint => _get({
        'vi': 'Tìm theo số kệ, từ khóa, tiêu đề, Pali...',
        'en': 'Search by verse, keywords, title, Pali...',
        'hi': 'गाथा संख्या, मुख्य शब्द, शीर्षक, पाली खोजें...',
        'zh': '按偈颂编号、关键词、标题、巴利文搜索...',
        'zh_TW': '按偈頌編號、關鍵詞、標題、巴利文搜尋...',
        'si': 'ගාථා අංකය, මූල පද, මාතෘකාව, පාලි අනුව සොයන්න...',
      });

  // ===== 4 CẤP ĐỘ BỐC HƠI CHỮ (VANISHING CLOZE) =====
  String get vanishingScaffolding => _get({
        'vi': 'Tầng Bốc Hơi Chữ (Vanishing Scaffolding)',
        'en': 'Vanishing Memory Scaffolding',
        'hi': 'स्मृति लुप्तप्राय स्तर',
        'zh': '渐隐记忆阶梯 (Vanishing Cloze)',
        'zh_TW': '漸隱記憶階梯 (Vanishing Cloze)',
        'si': 'වියැකෙන මතක මට්ටම්',
      });

  String get level1Full => _get({
        'vi': '1. Toàn văn',
        'en': '1. Full Text',
        'hi': '1. संपूर्ण पाठ',
        'zh': '1. 全文对照',
        'zh_TW': '1. 全文對照',
        'si': '1. සම්පූර්ණ පෙළ',
      });

  String get level1Desc => _get({
        'vi': 'Đọc và nghe trọn vẹn văn bản',
        'en': 'Read and listen to the full text',
        'hi': 'पूरा पाठ पढ़ें और सुनें',
        'zh': '阅读并聆听全文',
        'zh_TW': '閱讀並聆聽全文',
        'si': 'සම්පූර්ණ පෙළ කියවා සවන් දෙන්න',
      });

  String get level2Keywords => _get({
        'vi': '2. Ẩn từ khóa',
        'en': '2. Keywords',
        'hi': '2. मुख्य शब्द',
        'zh': '2. 关键词填空',
        'zh_TW': '2. 關鍵詞填空',
        'si': '2. මූල පද',
      });

  String get level2Desc => _get({
        'vi': 'Chạm vào ô [ ___ ] để lật mở từ khóa',
        'en': 'Tap on [ ___ ] to reveal keywords',
        'hi': 'मुख्य शब्द देखने के लिए [ ___ ] पर टैप करें',
        'zh': '点击空白 [ ___ ] 以揭晓核心词',
        'zh_TW': '點擊空白 [ ___ ] 以揭曉核心詞',
        'si': 'මූල පද බැලීමට [ ___ ] තට්ටු කරන්න',
      });

  String get level3FirstLetter => _get({
        'vi': '3. Mồi chữ đầu',
        'en': '3. First Letters',
        'hi': '3. आद्याक्षर संकेत',
        'zh': '3. 首字助记',
        'zh_TW': '3. 首字助記',
        'si': '3. මුල් අකුරු',
      });

  String get level3Desc => _get({
        'vi': 'Chạm vào chữ mồi [ d___ ] để xem trọn từ',
        'en': 'Tap on first-letter cue [ d___ ] to reveal word',
        'hi': 'पूरा शब्द देखने के लिए [ d___ ] पर टैप करें',
        'zh': '点击首字提示 [ d___ ] 以查看完整词汇',
        'zh_TW': '點擊首字提示 [ d___ ] 以查看完整詞彙',
        'si': 'සම්පූර්ණ වචනය බැලීමට [ d___ ] තට්ටු කරන්න',
      });

  String get level4Ghost => _get({
        'vi': '4. Ẩn toàn bộ',
        'en': '4. Blind Recall',
        'hi': '4. पूर्ण अंध स्मरण',
        'zh': '4. 盲背重现',
        'zh_TW': '4. 盲背重現',
        'si': '4. සම්පූර්ණ මතකය',
      });

  String get level4Desc => _get({
        'vi': 'Toàn bộ bài đã ẩn, tự đọc nhẩm rồi chạm để kiểm tra',
        'en': '100% blind recall, recite in mind and tap to verify',
        'hi': 'संपूर्ण पाठ अदृश्य, मन में याद करें और टैप कर जांचें',
        'zh': '全文已隐去，请在大脑中默背后点击核对',
        'zh_TW': '全文已隱去，請在大腦中默背後點擊核對',
        'si': 'සම්පූර්ණ පෙළ සඟවා ඇත, සිතින් මතක් කර පරීක්ෂා කිරීමට තට්ටු කරන්න',
      });

  String get revealAll => _get({
        'vi': 'Mở hết',
        'en': 'Reveal All',
        'hi': 'सब दिखाएं',
        'zh': '全部揭晓',
        'zh_TW': '全部揭曉',
        'si': 'සියල්ල පෙන්වන්න',
      });

  String get hideAll => _get({
        'vi': 'Ẩn lại',
        'en': 'Hide All',
        'hi': 'सब छिपाएं',
        'zh': '重新隐藏',
        'zh_TW': '重新隱藏',
        'si': 'නැවත සඟවන්න',
      });

  String get keywordsCountLabel => _get({
        'vi': 'từ khóa',
        'en': 'keywords',
        'hi': 'मुख्य शब्द',
        'zh': '关键词',
        'zh_TW': '關鍵詞',
        'si': 'මූල පද',
      });

  String get wordsCountLabel => _get({
        'vi': 'từ',
        'en': 'words',
        'hi': 'शब्द',
        'zh': '词',
        'zh_TW': '詞',
        'si': 'වචන',
      });

  // ===== ACTIVE RECALL 3 DẠNG =====
  String get modeCloze => _get({
        'vi': 'Điền khuyết',
        'en': 'Cloze Test',
        'hi': 'रिक्त स्थान',
        'zh': '填空回想',
        'zh_TW': '填空回想',
        'si': 'හිස්තැන් පිරවීම',
      });

  String get modeMeaning => _get({
        'vi': 'Ý nghĩa → Kinh',
        'en': 'Meaning → Verse',
        'hi': 'अर्थ → गाथा',
        'zh': '义理回想',
        'zh_TW': '義理回想',
        'si': 'අර්ථය → ගාථාව',
      });

  String get modeAudio => _get({
        'vi': 'Nghe & Đọc tiếp',
        'en': 'Audio → Continue',
        'hi': 'श्रवण → आगे पढ़ें',
        'zh': '听引读后',
        'zh_TW': '聽引讀後',
        'si': 'සවන් දී ඉදිරියට',
      });

  // ===== ELABORATIVE CARD =====
  String get elaborativeAnchor => _get({
        'vi': 'Móc treo ghi nhớ (Elaborative Anchor)',
        'en': 'Elaborative Memory Anchor',
        'hi': 'विस्तृत स्मृति लंगर',
        'zh': '精细加工记忆锚点',
        'zh_TW': '精細加工記憶錨點',
        'si': 'විස්තීරණ මතක නැංගුරම',
      });

  String get coreMeaning => _get({
        'vi': 'Ý NGHĨA CỐT LÕI',
        'en': 'CORE MEANING',
        'hi': 'मूल अर्थ',
        'zh': '核心义理',
        'zh_TW': '核心義理',
        'si': 'මූලික අර්ථය',
      });

  String get lifeConnection => _get({
        'vi': 'Liên hệ thực tế',
        'en': 'Life Application',
        'hi': 'जीवन अनुप्रयोग',
        'zh': '生活观照',
        'zh_TW': '生活觀照',
        'si': 'ජීවිත යෙදුම',
      });

  // ===== ĐÁNH GIÁ FSRS (4 NÚT) =====
  String get ratingHint => _get({
        'vi': 'Đánh giá độ nhớ để FSRS tối ưu lịch ôn tập:',
        'en': 'Rate your recall to optimize FSRS scheduling:',
        'hi': 'पुनरावृत्ति अनुसूची अनुकूलित करने के लिए मूल्यांकन करें:',
        'zh': '评估记忆熟练度以优化 FSRS 复习周期:',
        'zh_TW': '評估記憶熟練度以優化 FSRS 複習週期:',
        'si': 'FSRS කාලසටහන සකස් කිරීමට ඔබගේ මතකය ශ්‍රේණිගත කරන්න:',
      });

  String get again => _get({'vi': 'Quên', 'en': 'Again', 'hi': 'पुनः', 'zh': '忘记', 'zh_TW': '忘記', 'si': 'නැවත'});
  String get hard => _get({'vi': 'Khó', 'en': 'Hard', 'hi': 'कठिन', 'zh': '吃力', 'zh_TW': '吃力', 'si': 'අමාරුයි'});
  String get good => _get({'vi': 'Được', 'en': 'Good', 'hi': 'उत्तम', 'zh': '掌握', 'zh_TW': '掌握', 'si': 'හොඳයි'});
  String get easy => _get({'vi': 'Dễ', 'en': 'Easy', 'hi': 'सहज', 'zh': '熟练', 'zh_TW': '熟練', 'si': 'පහසුයි'});

  // ===== ASSESSMENT LAYER =====
  String get assessmentTitle => _get({
        'vi': 'Kiểm tra thực chất (Assessment)',
        'en': 'Genuine Recall Assessment',
        'hi': 'वास्तविक स्मरण परीक्षा',
        'zh': '实质记忆考核 (Assessment)',
        'zh_TW': '實質記憶考核 (Assessment)',
        'si': 'නියම මතක පරීක්ෂණය',
      });

  String get noHintMode => _get({
        'vi': 'CHẾ ĐỘ KHÔNG GỢI Ý',
        'en': 'ZERO-CUE BLIND MODE',
        'hi': 'बिना संकेत अंध विधा',
        'zh': '无提示盲背模式',
        'zh_TW': '無提示盲背模式',
        'si': 'ඉඟි රහිත අන්ධ මාදිලිය',
      });

  String get reciteInHeadPrompt => _get({
        'vi': 'Hãy tự đọc toàn bài trong đầu',
        'en': 'Recite the full verse in your mind',
        'hi': 'अपने मन में पूरी गाथा का पाठ करें',
        'zh': '请在大脑中默背全篇经文',
        'zh_TW': '請在大腦中默背全篇經文',
        'si': 'ඔබගේ සිතින් සම්පූර්ණ ගාථාව සජ්ඣායනා කරන්න',
      });

  String get reciteInHeadDesc => _get({
        'vi': 'Cố gắng nhẩm lại từng câu một cách trọn vẹn nhất trước khi mở văn bản đối chiếu.',
        'en': 'Try reciting every single line completely before revealing the full text for comparison.',
        'hi': 'तुलना के लिए पाठ खोलने से पहले प्रत्येक पंक्ति को पूरी तरह से याद करने का प्रयास करें।',
        'zh': '在点击对照前，请尽力完整回想每一个字句。',
        'zh_TW': '在點擊對照前，請盡力完整回想每一個字句。',
        'si': 'සංසන්දනය සඳහා පෙළ විවෘත කිරීමට පෙර එක් එක් පේළිය සම්පූර්ණයෙන්ම මතක් කිරීමට උත්සාහ කරන්න.',
      });

  String get doneReciting => _get({
        'vi': 'Tôi đã đọc xong trong đầu',
        'en': 'I Have Finished Reciting',
        'hi': 'मैंने मन में पाठ पूरा कर लिया',
        'zh': '我已在大脑中默背完毕',
        'zh_TW': '我已在大腦中默背完畢',
        'si': 'මම සිතින් සජ්ඣායනා කර අවසන් කළෙමි',
      });

  String get heavyMistakes => _get({
        'vi': 'Sai nhiều',
        'en': 'Heavy Mistakes',
        'hi': 'अत्यधिक त्रुटियां',
        'zh': '多处错误',
        'zh_TW': '多處錯誤',
        'si': 'බොහෝ වැරදි',
      });

  String get almostCorrect => _get({
        'vi': 'Gần đúng',
        'en': 'Almost Correct',
        'hi': 'लगभग सही',
        'zh': '基本正确',
        'zh_TW': '基本正確',
        'si': 'පාහේ නිවැරදියි',
      });

  String get perfectRecite => _get({
        'vi': 'Đúng hoàn toàn',
        'en': '100% Perfect',
        'hi': 'पूर्णतः शुद्ध',
        'zh': '完美无瑕',
        'zh_TW': '完美無瑕',
        'si': 'සම්පූර්ණයෙන්ම නිවැරදියි',
      });

  String get allCategories => _get({
        'vi': 'Tất cả thể loại',
        'en': 'All Categories',
        'hi': 'सभी श्रेणियां',
        'zh': '所有分类',
        'zh_TW': '所有分類',
        'si': 'සියලු කාණ්ඩ',
      });

  String get allStates => _get({
        'vi': 'Tất cả trạng thái',
        'en': 'All States',
        'hi': 'सभी स्थितियां',
        'zh': '所有状态',
        'zh_TW': '所有狀態',
        'si': 'සියලු තත්වයන්',
      });

  String get sourceLanguage => _get({
        'vi': 'Ngôn ngữ nguyên văn',
        'en': 'Source language',
        'hi': 'मूल भाषा',
        'zh': '原文语言',
        'zh_TW': '原文語言',
        'si': 'මූල භාෂාව',
      });

  String get translationLanguage => _get({
        'vi': 'Ngôn ngữ bản dịch / nghĩa',
        'en': 'Translation language',
        'hi': 'अनुवाद भाषा',
        'zh': '译文语言',
        'zh_TW': '譯文語言',
        'si': 'පරිවර්තන භාෂාව',
      });

  String get memorizeWhichSide => _get({
        'vi': 'Học thuộc mặt nào?',
        'en': 'Which side to memorize?',
        'hi': 'कौन-सा पक्ष कंठस्थ करें?',
        'zh': '背诵哪一面？',
        'zh_TW': '背誦哪一面？',
        'si': 'කුමන පැත්ත මතක තබා ගන්නද?',
      });

  String get memorizeSource => _get({
        'vi': 'Nguyên văn',
        'en': 'Source',
        'hi': 'मूल पाठ',
        'zh': '原文',
        'zh_TW': '原文',
        'si': 'මූල පෙළ',
      });

  String get memorizeTranslation => _get({
        'vi': 'Bản dịch',
        'en': 'Translation',
        'hi': 'अनुवाद',
        'zh': '译文',
        'zh_TW': '譯文',
        'si': 'පරිවර්තනය',
      });

  String get repeatItem => _get({
        'vi': 'Bài',
        'en': 'Piece',
        'hi': 'पूरा पाठ',
        'zh': '整篇',
        'zh_TW': '整篇',
        'si': 'සම්පූර්ණය',
      });

  String get repeatLine => _get({
        'vi': 'Câu',
        'en': 'Line',
        'hi': 'पंक्ति',
        'zh': '一句',
        'zh_TW': '一句',
        'si': 'පේළිය',
      });

  String get repeatLineCountTitle => _get({
        'vi': 'Số lần phát câu này',
        'en': 'Repeats for this line',
        'hi': 'इस पंक्ति के लिए पुनरावृत्ति',
        'zh': '这句话的播放次数',
        'zh_TW': '這句話的播放次數',
        'si': 'මෙම පේළිය සඳහා පුනරාවර්තන',
      });

  String get repeatLinePlus => _get({
        'vi': 'Tăng số lần lặp câu này',
        'en': 'Repeat this line more times',
        'hi': 'इस पंक्ति को और बार पढ़ाएँ',
        'zh': '这句话多播几次',
        'zh_TW': '這句話多播幾次',
        'si': 'මෙම පේළිය වැඩි වේලාවක්',
      });

  String get repeatLineMinus => _get({
        'vi': 'Giảm số lần lặp câu này',
        'en': 'Repeat this line fewer times',
        'hi': 'इस पंक्ति को कम बार पढ़ाएँ',
        'zh': '这句话少播几次',
        'zh_TW': '這句話少播幾次',
        'si': 'මෙම පේළිය අඩු වේලාවක්',
      });

  String get resetLineRepeat => _get({
        'vi': 'Quay về mặc định (nhấn giữ)',
        'en': 'Reset to default (long-press)',
        'hi': 'डिफ़ॉल्ट पर लौटाएँ (लंबे दबाएँ)',
        'zh': '恢复默认（长按）',
        'zh_TW': '恢復預設（長按）',
        'si': 'පෙරනිමි අගයට (දිගු ඔබීම)',
      });

  // ===== ĐỒNG BỘ ĐA THIẾT BỊ (LHB-006) =====

  String get syncTitle => _get({
        'vi': 'Đồng bộ đa thiết bị',
        'en': 'Multi-device sync',
        'hi': 'बहु-उपकरण समकालन',
        'zh': '多设备同步',
        'zh_TW': '多裝置同步',
        'si': 'උපාංග කිහිපය අතර සමමුහුර්තකරණය',
      });

  String get syncBadgeTooltip => _get({
        'vi': 'Đồng bộ bài thuộc lòng',
        'en': 'Sync memorization items',
        'hi': 'कंठस्थ पाठ समकालित करें',
        'zh': '同步背诵篇目',
        'zh_TW': '同步背誦篇目',
        'si': 'පාඩම් සමමුහුර්ත කරන්න',
      });

  String get syncIdle => _get({
        'vi': 'Sẵn sàng đồng bộ',
        'en': 'Ready to sync',
        'hi': 'समकालन के लिए तैयार',
        'zh': '可以同步',
        'zh_TW': '可以同步',
        'si': 'සමමුහුර්ත කිරීමට සූදානම්',
      });

  String get syncSyncing => _get({
        'vi': 'Đang đồng bộ…',
        'en': 'Syncing…',
        'hi': 'समकालन हो रहा है…',
        'zh': '正在同步…',
        'zh_TW': '正在同步…',
        'si': 'සමමුහුර්ත වෙමින්…',
      });

  String get syncSuccess => _get({
        'vi': 'Đã đồng bộ',
        'en': 'Synced',
        'hi': 'समकालन पूर्ण',
        'zh': '已同步',
        'zh_TW': '已同步',
        'si': 'සමමුහුර්ත කළා',
      });

  String get syncError => _get({
        'vi': 'Lỗi đồng bộ',
        'en': 'Sync error',
        'hi': 'समकालन त्रुटि',
        'zh': '同步出错',
        'zh_TW': '同步錯誤',
        'si': 'සමමුහුර්ත දෝෂයක්',
      });

  String get syncErrorHint => _get({
        'vi': 'Đồng bộ thất bại — kiểm tra mạng rồi thử lại.',
        'en': 'Sync failed — check your connection and try again.',
        'hi': 'समकालन विफल — कनेक्शन जाँचें और पुनः प्रयास करें।',
        'zh': '同步失败 — 请检查网络后重试。',
        'zh_TW': '同步失敗 — 請檢查網路後重試。',
        'si': 'සමමුහුර්ත කිරීම අසාර්ථකයි — සම්බන්ධතාවය පරීක්ෂා කර නැවත උත්සාහ කරන්න.',
      });

  String get syncSignedOut => _get({
        'vi': 'Đăng nhập để đồng bộ bài thuộc lòng giữa các thiết bị.',
        'en': 'Sign in to sync memorization items across devices.',
        'hi': 'उपकरणों के बीच कंठस्थ पाठ समकालित करने के लिए साइन इन करें।',
        'zh': '登录后可在设备之间同步背诵篇目。',
        'zh_TW': '登入後可在裝置之間同步背誦篇目。',
        'si': 'උපාංග අතර පාඩම් සමමුහුර්ත කිරීමට පිවිසෙන්න.',
      });

  String get syncDescription => _get({
        'vi': 'Bài thuộc lòng, tiến độ SRS và chuỗi ngày học được lưu trên cloud và tự đồng bộ giữa các thiết bị.',
        'en': 'Your memorization items, SRS progress and study streak are stored in the cloud and synced across devices.',
        'hi': 'आपके कंठस्थ पाठ, SRS प्रगति और अध्ययन श्रृंखला क्लाउड में सहेजी जाती है और उपकरणों के बीच समकालित होती है।',
        'zh': '背诵篇目、SRS 进度与连续学习天数保存在云端，并在设备之间自动同步。',
        'zh_TW': '背誦篇目、SRS 進度與連續學習天數保存在雲端，並在裝置之間自動同步。',
        'si': 'ඔබේ පාඩම්, SRS ප්‍රගතිය සහ දින අඛණ්ඩතාව ක්ලවුඩ් හි සුරැකී උපාංග අතර සමමුහුර්ත වේ.',
      });

  String get syncNow => _get({
        'vi': 'Đồng bộ ngay',
        'en': 'Sync now',
        'hi': 'अभी समकालन करें',
        'zh': '立即同步',
        'zh_TW': '立即同步',
        'si': 'දැන් සමමුහුර්ත කරන්න',
      });

  String get syncPullAll => _get({
        'vi': 'Kéo toàn bộ từ cloud',
        'en': 'Pull everything from cloud',
        'hi': 'क्लाउड से सब कुछ लाएँ',
        'zh': '从云端拉取全部',
        'zh_TW': '從雲端拉取全部',
        'si': 'ක්ලවුඩ් එකෙන් සියල්ල ලබාගන්න',
      });

  String get syncPushAll => _get({
        'vi': 'Đẩy tất cả lên cloud',
        'en': 'Push all to cloud',
        'hi': 'सब कुछ क्लाउड पर भेजें',
        'zh': '全部推送到云端',
        'zh_TW': '全部推送到雲端',
        'si': 'සියල්ල ක්ලවුඩ් එකට යවන්න',
      });

  String get syncNever => _get({
        'vi': 'Chưa đồng bộ lần nào',
        'en': 'Never synced yet',
        'hi': 'अभी तक कोई समकालन नहीं',
        'zh': '尚未同步',
        'zh_TW': '尚未同步',
        'si': 'තවම සමමුහුර්ත කර නැත',
      });

  String syncLastSynced(String time) => _get({
        'vi': 'Lần cuối: $time',
        'en': 'Last synced: $time',
        'hi': 'अंतिम समकालन: $time',
        'zh': '上次同步：$time',
        'zh_TW': '上次同步：$time',
        'si': 'අවසන් සමමුහුර්ත: $time',
      });

  String get syncJustNow => _get({
        'vi': 'vừa xong',
        'en': 'just now',
        'hi': 'अभी-अभी',
        'zh': '刚刚',
        'zh_TW': '剛剛',
        'si': 'දැන්',
      });

  String syncMinutesAgo(int minutes) => _get({
        'vi': '$minutes phút trước',
        'en': '$minutes min ago',
        'hi': '$minutes मिनट पहले',
        'zh': '$minutes 分钟前',
        'zh_TW': '$minutes 分鐘前',
        'si': 'මිනිත්තු $minutes කට පෙර',
      });

  String syncHoursAgo(int hours) => _get({
        'vi': '$hours giờ trước',
        'en': '$hours h ago',
        'hi': '$hours घंटे पहले',
        'zh': '$hours 小时前',
        'zh_TW': '$hours 小時前',
        'si': 'පැය $hours කට පෙර',
      });

  String syncDaysAgo(int days) => _get({
        'vi': '$days ngày trước',
        'en': '$days d ago',
        'hi': '$days दिन पहले',
        'zh': '$days 天前',
        'zh_TW': '$days 天前',
        'si': 'දින $days කට පෙර',
      });

  String get syncClose => _get({
        'vi': 'Đóng',
        'en': 'Close',
        'hi': 'बंद करें',
        'zh': '关闭',
        'zh_TW': '關閉',
        'si': 'වසන්න',
      });
}
