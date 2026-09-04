import 'package:flutter/material.dart';

class TipsLanguagePackScreen extends StatelessWidget {
  const TipsLanguagePackScreen({super.key});

  static const List<Map<String, dynamic>> packs = [
    {"code":"pali_roman","name":"Pāli (Roman)","vi":"Pāli La-tinh","url":"https://dhamma.paauksociety.org/Root/Tipitaka/SqlLite%20Database/pali%20text/tipitaka-roman-pali.db.zip","source":"reference"},
    {"code":"vietnamese","name":"Vietnamese","vi":"Tiếng Việt","url":"https://dhamma.paauksociety.org/Root/Tipitaka/SqlLite%20Database/vietnamese_tipitaka_translation_data-2026-04-29.db.zip","source":"reference"},
    {"code":"english","name":"English","vi":"Tiếng Anh","url":"https://dhamma.paauksociety.org/Root/Tipitaka/SqlLite%20Database/english_tipitaka_translation_data-2026-04-28.db.zip","source":"reference"},
    {"code":"bengali","name":"Bengali","vi":"Bengal","url":"https://dhamma.paauksociety.org/Root/Tipitaka/SqlLite%20Database/bengali_tipitaka_translation_data-2026-07-11.db.zip","source":"link"},
    {"code":"chinese","name":"Chinese","vi":"Trung Quốc","url":"https://dhamma.paauksociety.org/Root/Tipitaka/SqlLite%20Database/chinese_tipitaka_translation_data-2026-06-20.db.zip","source":"link"},
    {"code":"french","name":"French","vi":"Pháp","url":"https://dhamma.paauksociety.org/Root/Tipitaka/SqlLite%20Database/french_tipitaka_translation_data-2026-04-27.db.zip","source":"link"},
    {"code":"german","name":"German","vi":"Đức","url":"https://dhamma.paauksociety.org/Root/Tipitaka/SqlLite%20Database/german_tipitaka_translation_data-2026-06-03.db.zip","source":"link"},
    {"code":"hindi","name":"Hindi","vi":"Hindi","url":"https://dhamma.paauksociety.org/Root/Tipitaka/SqlLite%20Database/hindi_tipitaka_translation_data-2026-04-30.db.zip","source":"link"},
    {"code":"indonesian","name":"Indonesian","vi":"Indonesia","url":"https://dhamma.paauksociety.org/Root/Tipitaka/SqlLite%20Database/indonesian_tipitaka_translation_data-2026-04-30.db.zip","source":"link"},
    {"code":"japanese","name":"Japanese","vi":"Nhật","url":"https://dhamma.paauksociety.org/Root/Tipitaka/SqlLite%20Database/japanese_tipitaka_translation_data-2026-04-27.db.zip","source":"link"},
    {"code":"khmer","name":"Khmer","vi":"Khmer","url":"https://dhamma.paauksociety.org/Root/Tipitaka/SqlLite%20Database/khmer_tipitaka_translation_data-2026-07-01.db.zip","source":"link"},
    {"code":"korean","name":"Korean","vi":"Hàn","url":"https://dhamma.paauksociety.org/Root/Tipitaka/SqlLite%20Database/korean_tipitaka_translation_data-2026-04-25.db.zip","source":"link"},
    {"code":"lao","name":"Lao","vi":"Lào","url":"https://dhamma.paauksociety.org/Root/Tipitaka/SqlLite%20Database/lao_tipitaka_translation_data-2026-07-16.db.zip","source":"link"},
    {"code":"marathi","name":"Marathi","vi":"Marathi","url":"https://dhamma.paauksociety.org/Root/Tipitaka/SqlLite%20Database/marathi_tipitaka_translation_data-2026-06-16.db.zip","source":"link"},
    {"code":"myanmar","name":"Myanmar (Burmese)","vi":"Miến Điện","url":"https://dhamma.paauksociety.org/Root/Tipitaka/SqlLite%20Database/myanmar_tipitaka_translation_data-2026-06-24.db.zip","source":"link"},
    {"code":"portuguese","name":"Portuguese","vi":"Bồ Đào Nha","url":"https://dhamma.paauksociety.org/Root/Tipitaka/SqlLite%20Database/portuguese_tipitaka_translation_data-2026-07-22.db.zip","source":"link"},
    {"code":"sinhala","name":"Sinhala","vi":"Sinhala","url":"https://dhamma.paauksociety.org/Root/Tipitaka/SqlLite%20Database/sinhala_tipitaka_translation_data-2026-05-23.db.zip","source":"link"},
    {"code":"spanish","name":"Spanish","vi":"Tây Ban Nha","url":"https://dhamma.paauksociety.org/Root/Tipitaka/SqlLite%20Database/spanish_tipitaka_translation_data-2026-05-15.db.zip","source":"link"},
    {"code":"thai","name":"Thai","vi":"Thái","url":"https://dhamma.paauksociety.org/Root/Tipitaka/SqlLite%20Database/thai_tipitaka_translation_data-2026-04-29.db.zip","source":"link"},
    {"code":"tibetan","name":"Tibetan","vi":"Tây Tạng","url":"https://dhamma.paauksociety.org/Root/Tipitaka/SqlLite%20Database/tibetan_tipitaka_translation_data-2026-06-22.db.zip","source":"link"},
    {"code":"pali_thai","name":"Pāli (Thai)","vi":"Pāli Thái","url":"https://dhamma.paauksociety.org/Root/Tipitaka/SqlLite%20Database/pali%20text/tipitaka-thai-pali.db.zip","source":"link"},
    {"code":"pali_sinhala","name":"Pāli (Sinhala)","vi":"Pāli Sinhala","url":"https://dhamma.paauksociety.org/Root/Tipitaka/SqlLite%20Database/pali%20text/tipitaka-sinhala-pali.db.zip","source":"link"},
    {"code":"pali_myanmar","name":"Pāli (Myanmar)","vi":"Pāli Myanmar","url":"https://dhamma.paauksociety.org/Root/Tipitaka/SqlLite%20Database/pali%20text/tipitaka-myanmar-pali.db.zip","source":"link"},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(Localizations.localeOf(context).languageCode == 'vi' ? 'Gói ngôn ngữ Tipiṭaka' : 'Tipiṭaka Language Packs'),
        backgroundColor: const Color(0xFF1A1A2E),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Tải từ nguồn paauksociety',
            onPressed: () {
              // Open root source page
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: packs.length,
        itemBuilder: (ctx, i) {
          final p = packs[i];
          final isLocal = p["source"] == "reference" || p["source"] == "local";
          return Card(
            margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            color: const Color(0xFF1A1A2E),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isLocal ? Colors.orangeAccent : Colors.blueGrey,
                child: Icon(isLocal ? Icons.check_circle : Icons.cloud_download, size: 18, color: Colors.white),
              ),
              title: Text(p["name"], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              subtitle: Text(
                (Localizations.localeOf(context).languageCode == 'vi') ? (p["vi"] ?? p["name"]) : p["name"],
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
              trailing: IconButton(
                icon: Icon(isLocal ? Icons.open_in_new : Icons.link, color: const Color(0xFFFF9800)),
                tooltip: isLocal ? 'Mở từ reference/' : 'Tải từ nguồn',
                onPressed: () async {
                  if (isLocal) {
                    // Try to open local DB if present in reference/
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('DB đã có trong reference/ — hãy import bằng script hoặc mở trực tiếp')),
                    );
                  } else {
                    // Open browser/download link
                    // In production: use url_launcher
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Link tải: ${p["url"]}')),
                    );
                  }
                },
              ),
            ),
          );
        },
      ),
    );
  }
}