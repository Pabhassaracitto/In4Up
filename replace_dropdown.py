import re

with open('lib/screens/settings/stt_model_settings_screen.dart', 'r') as f:
    content = f.read()

new_items = """              items: const [
                DropdownMenuItem(value: 'system', child: Text('Hệ thống')),
                DropdownMenuItem(value: 'ar', child: Text('العربية (Arabic)')),
                DropdownMenuItem(value: 'bn', child: Text('বাংলা (Bengali)')),
                DropdownMenuItem(value: 'bo', child: Text('བོད་ཡིག (Tibetan)')),
                DropdownMenuItem(value: 'de', child: Text('Deutsch (German)')),
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'es', child: Text('Español (Spanish)')),
                DropdownMenuItem(value: 'fr', child: Text('Français (French)')),
                DropdownMenuItem(value: 'hi', child: Text('हिन्दी (Hindi)')),
                DropdownMenuItem(value: 'id', child: Text('Bahasa Indonesia')),
                DropdownMenuItem(value: 'it', child: Text('Italiano (Italian)')),
                DropdownMenuItem(value: 'ja', child: Text('日本語 (Japanese)')),
                DropdownMenuItem(value: 'km', child: Text('ភាសាខ្មែរ (Khmer)')),
                DropdownMenuItem(value: 'ko', child: Text('한국어 (Korean)')),
                DropdownMenuItem(value: 'lo', child: Text('ລາວ (Lao)')),
                DropdownMenuItem(value: 'mn', child: Text('Монгол (Mongolian)')),
                DropdownMenuItem(value: 'mr', child: Text('मराठी (Marathi)')),
                DropdownMenuItem(value: 'my', child: Text('မြန်မာ (Burmese)')),
                DropdownMenuItem(value: 'pt', child: Text('Português (Portuguese)')),
                DropdownMenuItem(value: 'ru', child: Text('Русский (Russian)')),
                DropdownMenuItem(value: 'si', child: Text('සිංහල (Sinhala)')),
                DropdownMenuItem(value: 'ta', child: Text('தமிழ் (Tamil)')),
                DropdownMenuItem(value: 'te', child: Text('తెలుగు (Telugu)')),
                DropdownMenuItem(value: 'th', child: Text('ไทย (Thai)')),
                DropdownMenuItem(value: 'vi', child: Text('Tiếng Việt')),
                DropdownMenuItem(value: 'zh', child: Text('中文 (Giản thể)')),
                DropdownMenuItem(value: 'zh_TW', child: Text('中文 (Phồn thể)')),
              ],"""

pattern = re.compile(r"items:\s*const\s*\[\s*DropdownMenuItem.*?\]\s*,", re.DOTALL)
content = pattern.sub(new_items, content)

with open('lib/screens/settings/stt_model_settings_screen.dart', 'w') as f:
    f.write(content)

print("Replaced dropdown successfully.")
