/// Audit v1.29.0 §6. Centralized labels keep the translation lane independent
/// of the hub-owned ARBs/native pack. Registered in priority_ui_overrides.dart;
/// consumers still go through uiText (locale → English, never Vietnamese).
abstract final class TranslationUiLabels {
  static const preferred = 'Engine ưu tiên';
  static const actual = 'Engine trả kết quả';
  static const fallback = 'Đã dùng engine dự phòng';
  static const order = 'Thứ tự engine dịch';
  static const orderHint = 'Kéo tay nắm để sắp xếp. Thay đổi được lưu tự động.';
  static const policyHint =
      'Engine không sẵn sàng sẽ được bỏ qua. Chỉ offline và cấu hình Server & API vẫn có hiệu lực. Từ điển luôn ở cuối.';
  static const onlineHint = 'Chọn engine online để tắt Chỉ offline.';
  static const offline = 'Offline';
  static const online = 'Online';
  static const translating = 'Đang dịch…';
  static const succeeded = 'Dịch thành công';
  static const partial = 'Dịch xong một phần';
  static const failed = 'Dịch thất bại';
  static const cancelled = 'Đã dừng dịch';
  static const counts = 'Thành công / lỗi';
  static const cache = 'Bộ nhớ đệm — không chạy engine';
  static const up = 'Tăng ưu tiên';
  static const down = 'Giảm ưu tiên';
  static const automatic = 'Khôi phục thứ tự tự động';
  static const retry = 'Thử dịch lại';
}

const Map<String, Map<String, String>> translationUiOverrides = {
  TranslationUiLabels.preferred: {
    'en': 'Preferred engine',
    'hi': 'पसंदीदा इंजन',
    'zh': '首选引擎',
    'zh_TW': '偏好引擎',
    'si': 'ප්‍රමුඛ එන්ජිම',
  },
  TranslationUiLabels.actual: {
    'en': 'Result engine',
    'hi': 'परिणाम देने वाला इंजन',
    'zh': '实际处理引擎',
    'zh_TW': '實際處理引擎',
    'si': 'ප්‍රතිඵලය සැපයූ එන්ජිම',
  },
  TranslationUiLabels.fallback: {
    'en': 'Fallback engine used',
    'hi': 'वैकल्पिक इंजन इस्तेमाल हुआ',
    'zh': '已使用备用引擎',
    'zh_TW': '已使用備用引擎',
    'si': 'විකල්ප එන්ජිම භාවිත විය',
  },
  TranslationUiLabels.order: {
    'en': 'Translation engine order',
    'hi': 'अनुवाद इंजन का क्रम',
    'zh': '翻译引擎顺序',
    'zh_TW': '翻譯引擎順序',
    'si': 'පරිවර්තන එන්ජින් අනුපිළිවෙළ',
  },
  TranslationUiLabels.orderHint: {
    'en': 'Drag a handle to reorder. Changes are saved automatically.',
    'hi': 'क्रम बदलने के लिए हैंडल खींचें। बदलाव अपने आप सहेजे जाते हैं।',
    'zh': '拖动手柄排序。更改会自动保存。',
    'zh_TW': '拖曳把手排序。變更會自動儲存。',
    'si':
        'අනුපිළිවෙළ වෙනස් කිරීමට හසුරුව අදින්න. වෙනස්කම් ස්වයංක්‍රීයව සුරැකේ.',
  },
  TranslationUiLabels.policyHint: {
    'en':
        'Unavailable engines are skipped. Offline-only and Server & API settings still apply. The dictionary always runs last.',
    'hi':
        'अनुपलब्ध इंजन छोड़ दिए जाते हैं। केवल ऑफ़लाइन और Server & API सेटिंग लागू रहती हैं। शब्दकोश हमेशा अंत में चलता है।',
    'zh': '跳过不可用的引擎。仅离线及 Server & API 设置仍然有效。词典始终最后运行。',
    'zh_TW': '略過無法使用的引擎。僅離線及 Server & API 設定仍然有效。詞典一律最後執行。',
    'si':
        'නොමැති එන්ජින් මඟ හැරේ. නොබැඳි පමණක් සහ Server & API සැකසුම් තවමත් අදාළ වේ. ශබ්දකෝෂය සැමවිටම අවසානයේ ක්‍රියාත්මක වේ.',
  },
  TranslationUiLabels.onlineHint: {
    'en': 'Choose an online engine to turn off Offline-only.',
    'hi': 'केवल ऑफ़लाइन बंद करने के लिए ऑनलाइन इंजन चुनें।',
    'zh': '选择在线引擎以关闭“仅离线”。',
    'zh_TW': '選擇線上引擎以關閉「僅離線」。',
    'si': 'නොබැඳි පමණක් අක්‍රිය කිරීමට මාර්ගගත එන්ජිමක් තෝරන්න.',
  },
  TranslationUiLabels.offline: {
    'en': 'Offline',
    'hi': 'ऑफ़लाइन',
    'zh': '离线',
    'zh_TW': '離線',
    'si': 'නොබැඳි',
  },
  TranslationUiLabels.translating: {
    'en': 'Translating…',
    'hi': 'अनुवाद हो रहा है…',
    'zh': '正在翻译…',
    'zh_TW': '正在翻譯…',
    'si': 'පරිවර්තනය වෙමින්…',
  },
  TranslationUiLabels.succeeded: {
    'en': 'Translation succeeded',
    'hi': 'अनुवाद सफल हुआ',
    'zh': '翻译成功',
    'zh_TW': '翻譯成功',
    'si': 'පරිවර්තනය සාර්ථකයි',
  },
  TranslationUiLabels.partial: {
    'en': 'Partially translated',
    'hi': 'आंशिक अनुवाद हुआ',
    'zh': '部分翻译完成',
    'zh_TW': '部分翻譯完成',
    'si': 'අර්ධ වශයෙන් පරිවර්තනය විය',
  },
  TranslationUiLabels.failed: {
    'en': 'Translation failed',
    'hi': 'अनुवाद विफल हुआ',
    'zh': '翻译失败',
    'zh_TW': '翻譯失敗',
    'si': 'පරිවර්තනය අසාර්ථකයි',
  },
  TranslationUiLabels.counts: {
    'en': 'Succeeded / failed',
    'hi': 'सफल / विफल',
    'zh': '成功 / 失败',
    'zh_TW': '成功 / 失敗',
    'si': 'සාර්ථක / අසාර්ථක',
  },
  TranslationUiLabels.cache: {
    'en': 'Cache — no engine run',
    'hi': 'कैश — कोई इंजन नहीं चला',
    'zh': '缓存 — 未运行引擎',
    'zh_TW': '快取 — 未執行引擎',
    'si': 'හැඹිලිය — එන්ජිමක් ක්‍රියාත්මක නොවීය',
  },
  TranslationUiLabels.up: {
    'en': 'Move up',
    'hi': 'ऊपर ले जाएँ',
    'zh': '上移',
    'zh_TW': '上移',
    'si': 'ඉහළට ගෙන යන්න',
  },
  TranslationUiLabels.down: {
    'en': 'Move down',
    'hi': 'नीचे ले जाएँ',
    'zh': '下移',
    'zh_TW': '下移',
    'si': 'පහළට ගෙන යන්න',
  },
  TranslationUiLabels.automatic: {
    'en': 'Restore automatic order',
    'hi': 'स्वचालित क्रम बहाल करें',
    'zh': '恢复自动顺序',
    'zh_TW': '還原自動順序',
    'si': 'ස්වයංක්‍රීය අනුපිළිවෙළ යළි පිහිටුවන්න',
  },
  TranslationUiLabels.retry: {
    'en': 'Retry translation',
    'hi': 'अनुवाद फिर से करें',
    'zh': '重试翻译',
    'zh_TW': '重試翻譯',
    'si': 'පරිවර්තනය නැවත උත්සාහ කරන්න',
  },
};
