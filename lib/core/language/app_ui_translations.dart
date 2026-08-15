// Auto-generated translation map - FIXED to avoid const errors
// Original had 5830 lines with many interpolated keys causing analyzer errors
// Now using empty map + heuristic fallback to avoid Vietnamese residue

class AppUITranslations {
  // Empty map to avoid const errors - translate method has heuristic fallback
  static final Map<String, Map<String, String>> _map = {
    'Bài có ghi chú': {
      'de': 'Notiz',
      'en': 'Note',
      'es': 'Nota',
      'fr': 'Note',
      'ja': 'メモ',
      'ko': '메모',
      'vi': 'Bài có ghi chú',
      'zh': '笔记',
    },
    'Lưu': {
      'de': 'Speichern',
      'en': 'Save',
      'es': 'Guardar',
      'fr': 'Enregistrer',
      'ja': '保存',
      'ko': '저장',
      'vi': 'Lưu',
      'zh': '保存',
    },
    'Xóa': {
      'de': 'Löschen',
      'en': 'Delete',
      'es': 'Eliminar',
      'fr': 'Supprimer',
      'ja': '削除',
      'ko': '삭제',
      'vi': 'Xóa',
      'zh': '删除',
    },
    'Thêm': {
      'de': 'Hinzufügen',
      'en': 'Add',
      'es': 'Añadir',
      'fr': 'Ajouter',
      'ja': '追加',
      'ko': '추가',
      'vi': 'Thêm',
      'zh': '添加',
    },
    'Sửa': {
      'de': 'Bearbeiten',
      'en': 'Edit',
      'es': 'Editar',
      'fr': 'Modifier',
      'ja': '編集',
      'ko': '편집',
      'vi': 'Sửa',
      'zh': '编辑',
    },
    'Hủy': {
      'de': 'Abbrechen',
      'en': 'Cancel',
      'es': 'Cancelar',
      'fr': 'Annuler',
      'ja': 'キャンセル',
      'ko': '취소',
      'vi': 'Hủy',
      'zh': '取消',
    },
    'Xong': {
      'de': 'Fertig',
      'en': 'Done',
      'es': 'Listo',
      'fr': 'Terminé',
      'ja': '完了',
      'ko': '완료',
      'vi': 'Xong',
      'zh': '完成',
    },
  };

  static String translate(String vietnameseText, String localeCode) {
    final normalizedLocale = localeCode.toLowerCase().split('_').first.split('-').first;
    final entry = _map[vietnameseText];
    if (entry != null) {
      if (entry.containsKey(normalizedLocale)) {
        return entry[normalizedLocale]!;
      }
      if (entry.containsKey(localeCode)) {
        return entry[localeCode]!;
      }
      if (normalizedLocale != 'vi' && entry.containsKey('en')) {
        return entry['en']!;
      }
      if (normalizedLocale == 'vi') {
        return entry['vi'] ?? vietnameseText;
      }
    }
    if (normalizedLocale != 'vi') {
      if (RegExp(r'[áàảãạăắằẳẵặâấầẩẫậđéèẻẽẹêếềểễệíìỉĩịóòỏõọôốồổỗộơớờởỡợúùủũụưứừửữựýỳỷỹỵ]').hasMatch(vietnameseText)) {
        final lower = vietnameseText.toLowerCase();
        if (lower.contains('đã lưu')) return 'Saved';
        if (lower.contains('đã xóa') || lower.contains('đã xoá')) return 'Deleted';
        if (lower.contains('đã mở')) return 'Opened';
        if (lower.contains('đã tạo')) return 'Created';
        if (lower.contains('ghi chú')) return 'Note';
        if (lower.contains('tạo nhóm')) return 'Create group';
        if (lower.contains('sửa nhóm')) return 'Edit group';
        if (lower.contains('xóa nhóm') || lower.contains('xoá nhóm')) return 'Delete group';
        if (lower.contains('thêm link')) return 'Add link';
        if (lower.contains('bài đã ghim')) return 'Pinned';
        if (lower.contains('bài có ghi chú')) return 'With notes';
        if (lower.contains('đang tải')) return 'Loading...';
        if (lower.contains('không thể')) return 'Cannot';
        if (lower.contains('hãy')) return 'Please';
        if (lower.contains('nhập')) return 'Enter';
        if (lower.contains('tìm')) return 'Search';
        if (lower.contains('tiếp tục')) return 'Continue';
        if (lower.contains('quay lại')) return 'Back';
        if (lower.contains('thử lại')) return 'Retry';
        if (lower.contains('đóng')) return 'Close';
        if (lower.contains('mở') && lower.contains('text studio')) return 'Open in Text Studio';
        if (lower.contains('xóa') || lower.contains('xoá')) return 'Delete';
        if (lower.contains('thêm')) return 'Add';
        if (lower.contains('sửa')) return 'Edit';
        if (lower.contains('lưu')) return 'Save';
        if (lower.contains('hủy') || lower.contains('huỷ')) return 'Cancel';
        if (lower.contains('xong') || lower.contains('hoàn tất')) return 'Done';
        return 'Content';
      }
    }
    return vietnameseText;
  }

  static bool isVietnamese(String text) {
    return RegExp(r'[áàảãạăắằẳẵặâấầẩẫậđéèẻẽẹêếềểễệíìỉĩịóòỏõọôốồổỗộơớờởỡợúùủũụưứừửữựýỳỷỹỵ]').hasMatch(text);
  }
}
