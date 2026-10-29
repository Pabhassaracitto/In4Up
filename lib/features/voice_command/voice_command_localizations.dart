/// Voice-command copy is kept here so the feature never hard-codes UI text.
/// English is the required fallback; the other launch locales are included
/// from day one and can be moved into ARB without changing command code.
const voiceCommandLabels = <String, Map<String, String>>{
  'en': {
    'listening': 'Listening',
    'noModel': 'No speech recognition service available (check Google Speech Services or mic permission)',
    'received': 'Received',
    'permissionDenied': 'Microphone permission denied',
  },
  'vi': {
    'listening': 'Đang nghe',
    'noModel': 'Không có dịch vụ nhận diện giọng nói (kiểm tra quyền micro hoặc Google Speech)',
    'received': 'Đã nhận',
    'permissionDenied': 'Chưa cấp quyền microphone',
  },
  'hi': {
    'listening': 'सुन रहा है',
    'noModel': 'भाषण मॉडल उपलब्ध नहीं है',
    'received': 'प्राप्त',
    'permissionDenied': 'माइक्रोफ़ोन अनुमति अस्वीकृत',
  },
  'zh-Hans': {
    'listening': '正在聆听',
    'noModel': '没有可用的语音识别服务',
    'received': '已识别',
    'permissionDenied': '麦克风权限被拒绝',
  },
  'zh-Hant': {
    'listening': '正在聆聽',
    'noModel': '沒有可用的語音辨識服務',
    'received': '已辨識',
    'permissionDenied': '麥克風權限被拒絕',
  },
  'si': {
    'listening': 'සවන් දෙමින්',
    'noModel': 'STT ආකෘතියක් නොමැත',
    'received': 'ලැබුණි',
    'permissionDenied': 'මයික්‍රෆෝන අවසරය ප්‍රතික්ෂේප විය',
  },
};

String voiceCommandLabel(String locale, String key) =>
    voiceCommandLabels[locale]?[key] ?? voiceCommandLabels['en']![key]!;
