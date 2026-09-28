// lib/features/vocab_image/vocab_image_quick_add.dart
//
// IMG-WEB-001 (nối tiếp) — "Thêm hình" cho luồng LƯU TỪ NHANH.
//
// Chủ dự án yêu cầu tìm ảnh trên mạng không chỉ có lúc MỞ từ để sửa, mà phải
// có ngay ở chỗ thêm từ 1 chạm (PDF tap sheet, float action khi bôi đen chữ).
// Lưu nhanh vốn cố ý KHÔNG hỏi gì thêm → nên ở đây chỉ là một nút nhỏ hiện ra
// SAU KHI đã lưu: bấm là mở sheet tìm ảnh (web trước, máy thứ hai), chọn xong
// là gắn vào từ, không bắt người dùng quay lại Wordlist tìm từ.

import 'package:provider/provider.dart';

import '../../core/language/localized_material.dart';
import '../../models/word_entry.dart';
import '../../providers/vocabulary_provider.dart';
import 'vocab_image_api_config.dart';
import 'vocab_image_picker_sheet.dart';
import 'vocab_image_service.dart';
import 'vocab_image_web_service.dart';
import 'vocab_image_thumbnail.dart';

/// IMG-WEB-001 — "Tự gán ảnh đầu tiên" (toggle trong dialog Cài đặt ảnh).
///
/// Không mở sheet: tìm trên mạng theo `từ + nghĩa`, tải ảnh ĐẦU TIÊN về storage
/// app rồi gắn vào [wordId]. Mặc định TẮT — chủ dự án chốt "mặc định là tự
/// tìm, chạm chọn", bật toggle mới dùng đường này.
///
/// Im lặng khi không gán được (chưa có key, hết mạng, không ra ảnh): việc lưu
/// từ không bị cắt, người dùng vẫn gán tay được. Trả về đường dẫn ảnh nếu gán
/// thành công, null nếu bỏ qua. Không cần BuildContext ⇒ gọi được cả khi sheet
/// đã đóng.
Future<String?> autoAssignVocabImage({
  required VocabularyProvider provider,
  required String wordId,
  required String word,
  String? meaning,
  String? currentImageUrl,
}) async {
  if (wordId.isEmpty) return null;
  if ((currentImageUrl ?? '').isNotEmpty) return null; // đã có ảnh → không đè
  final client = VocabImageWebService();
  try {
    final cfg = await VocabImageApiConfig.instance.load();
    if (!cfg.autoAssignFirst) return null;
    final query =
        VocabImageWebService.buildQuery(word: word, meaning: meaning);
    if (query.trim().isEmpty) return null;
    final results = await client.search(query, limit: 4, settings: cfg);
    if (results.isEmpty) return null;
    final path = await VocabImageService.instance
        .saveFromUrl(results.first.imageUrl, client: client);
    if (path == null || path.isEmpty) return null;
    provider.updateImageUrl(wordId, path);
    return path;
  } catch (e) {
    debugPrint('autoAssignVocabImage: bỏ qua — $e');
    return null;
  } finally {
    client.dispose();
  }
}

/// Gán/bỏ ảnh cho một từ vừa lưu, qua [VocabImagePickerSheet].
///
/// `context` PHẢI còn sống khi gọi (đừng gọi từ callback của một sheet đã
/// `Navigator.pop` — context đó đã chết; đó là lý do luồng "lưu nhanh rồi
/// pop sheet" không gắn action hình, mà gắn ở trạng thái "đã lưu" của sheet).
///
/// Provider được lấy TRƯỚC khi mở sheet để phần ghi dữ liệu sau khi đóng sheet
/// không cần đụng context nữa. Trả về true khi có thay đổi (gán hoặc bỏ ảnh).
Future<bool> attachVocabImage(
  BuildContext context, {
  required String wordId,
  required String word,
  String? meaning,
  String? currentImageUrl,
}) async {
  final provider = context.read<VocabularyProvider>();

  // Toggle "tự gán ảnh đầu tiên" → 1 chạm là xong, không mở sheet. Không gán
  // được gì (mạng/key) thì rơi tiếp vào sheet để người dùng tự chọn.
  final path = await autoAssignVocabImage(
    provider: provider,
    wordId: wordId,
    word: word,
    meaning: meaning,
    currentImageUrl: currentImageUrl,
  );
  if (path != null) return true;

  final result = await VocabImagePickerSheet.show(
    context,
    word: word,
    meaning: meaning,
    hasExistingImage: (currentImageUrl ?? '').isNotEmpty,
  );
  if (result == null) return false;

  if (result.removed) {
    provider.updateImageUrl(wordId, null);
    return true;
  }
  final path = result.imagePath;
  if (path == null || path.isEmpty) return false;
  provider.updateImageUrl(wordId, path);
  return true;
}

/// Nút nhỏ "Thêm hình / Đổi hình" dùng trong state "đã lưu" của các luồng
/// lưu nhanh. Tự đọc lại từ trong Wordlist để biết đã có ảnh chưa.
class VocabImageQuickAddButton extends StatelessWidget {
  final String word;

  /// Nhãn phụ (vd nghĩa của từ) → mồi từ khóa tìm ảnh.
  final String? meaning;

  /// true = hiển thị như một action của snackbar/bar (chỉ icon + chữ nhỏ).
  final bool compact;

  const VocabImageQuickAddButton({
    super.key,
    required this.word,
    this.meaning,
    this.compact = false,
  });

  /// Nghĩa dùng làm từ khóa tìm ảnh: nghĩa caller đưa trước, nếu trống thì
  /// lấy nghĩa đã lưu của từ (Pali/Hindi thường có nghĩa tiếng Anh ở đây).
  String? _effectiveMeaning(WordEntry entry) {
    final own = (meaning ?? '').trim();
    if (own.isNotEmpty) return own;
    final stored = entry.meaning.trim();
    return stored.isEmpty ? null : stored;
  }

  @override
  Widget build(BuildContext context) {
    // Selector: chỉ rebuild khi imageUrl của từ này đổi (không vẽ lại cả sheet
    // mỗi lần provider notify).
    return Selector<VocabularyProvider, WordEntry?>(
      selector: (_, provider) => provider.findByWord(word.trim()),
      builder: (context, entry, _) {
        final imageUrl = entry?.imageUrl;
        final hasImage = (imageUrl ?? '').isNotEmpty;
        if (entry == null) return const SizedBox.shrink();

        return TextButton.icon(
          onPressed: () => attachVocabImage(
            context,
            wordId: entry.id,
            word: entry.word,
            meaning: _effectiveMeaning(entry),
            currentImageUrl: imageUrl,
          ),
          icon: hasImage
              ? (imageUrl != null
                  ? VocabImageThumbnail(imageUrl: imageUrl, size: 16)
                  : const Icon(Icons.image, size: 16))
              : const Icon(Icons.add_photo_alternate_outlined, size: 16),
          label: Text(hasImage
              ? context.uiText('Đổi hình')
              : context.uiText('Thêm hình')),
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 10),
            foregroundColor: const Color(0xFF4CAF50),
          ),
        );
      },
    );
  }
}
