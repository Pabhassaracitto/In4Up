/// Voice-command copy is kept here so the feature never hard-codes UI text.
/// English is the required fallback; the other launch locales are included
/// from day one and can be moved into ARB without changing command code.
const voiceCommandLabels = <String, Map<String, String>>{
  'en': {'listening': 'Listening', 'noModel': 'No speech model available', 'received': 'Received'},
  'vi': {'listening': 'Đang nghe', 'noModel': 'Chưa có model STT', 'received': 'Đã nhận'},
  'hi': {'listening': 'सुन रहा है', 'noModel': 'भाषण मॉडल उपलब्ध नहीं है', 'received': 'प्राप्त'},
  'zh-Hans': {'listening': '正在聆听', 'noModel': '没有可用的语音模型', 'received': '已识别'},
  'zh-Hant': {'listening': '正在聆聽', 'noModel': '沒有可用的語音模型', 'received': '已辨識'},
  'si': {'listening': 'සවන් දෙමින්', 'noModel': 'STT ආකෘතියක් නොමැත', 'received': 'ලැබුණි'},
};

String voiceCommandLabel(String locale, String key) =>
    voiceCommandLabels[locale]?[key] ?? voiceCommandLabels['en']![key]!;
