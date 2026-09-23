// Mục lục PDF là cây; panel là danh sách phẳng. Hai suy luận dễ sai nhất ở đây
// là (1) thứ tự DFS + cấp thụt lề và (2) lệch mốc trang: PdfDest.pageNumber là
// 1-based còn PdfReaderController.currentPage là 0-based. Test khóa cả hai.
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/pdf_reader/services/pdf_outline_index.dart';
import 'package:pdfrx/pdfrx.dart' hide PdfAnnotation;

PdfOutlineNode _node(String title, int? page, List<PdfOutlineNode> children) {
  return PdfOutlineNode(
    title: title,
    dest: page == null
        ? null
        : PdfDest(page, PdfDestCommand.xyz, const <double?>[null, null, null]),
    children: children,
  );
}

void main() {
  group('flattenPdfOutline', () {
    test('DFS: cha trước con, level tăng dần, index là vị trí thật', () {
      final tree = [
        _node('Chương 1', 3, [
          _node('1.1', 3, const []),
          _node('1.2', 7, const []),
        ]),
        _node('Chương 2', 12, const []),
      ];
      final flat = flattenPdfOutline(tree);

      expect(flat.map((e) => e.title).toList(),
          ['Chương 1', '1.1', '1.2', 'Chương 2']);
      expect(flat.map((e) => e.level).toList(), [0, 1, 1, 0]);
      expect(flat.map((e) => e.index).toList(), [0, 1, 2, 3]);
      expect(flat.map((e) => e.pageNumber).toList(), [3, 3, 7, 12]);
      expect(flat[0].hasChildren, isTrue);
      expect(flat[1].hasChildren, isFalse);
    });

    test('mục không có destination vẫn hiển thị nhưng không nhảy được', () {
      final flat = flattenPdfOutline([
        _node('Phần mở đầu', null, [_node('Giới thiệu', 2, const [])]),
      ]);
      expect(flat, hasLength(2));
      expect(flat[0].pageNumber, isNull);
      expect(flat[0].isJumpable, isFalse);
      expect(flat[1].isJumpable, isTrue);
      // dest phải được mang xuống widget để goToDest dùng, không tự tính lại.
      expect(flat[1].dest?.pageNumber, 2);
    });

    test('title rỗng/trailing space được làm sạch; null cây an toàn', () {
      expect(flattenPdfOutline(null), isEmpty);
      expect(flattenPdfOutline(const []), isEmpty);
      final flat = flattenPdfOutline([_node('  ', 1, const [])]);
      expect(flat.single.title, '—');
      expect(flattenPdfOutline([_node(' A  ', 1, const [])]).single.title, 'A');
    });

    test('phanh maxNodes: cây khổng lồ không làm dựng UI vô hạn', () {
      final tree = List.generate(500, (i) => _node('Mục $i', i + 1, const []));
      final flat = flattenPdfOutline(tree, maxNodes: 100);
      expect(flat, hasLength(100));
    });
  });

  group('findActiveOutlineIndex', () {
    final flat = flattenPdfOutline([
      _node('Chương 1', 3, [
        _node('1.1', 3, const []),
        _node('1.2', 7, const []),
      ]),
      _node('Chương 2', 12, const []),
    ]);

    test('trang 0-based 0..2 (chưa tới chương đầu) -> -1', () {
      expect(findActiveOutlineIndex(flat, 0), -1);
      // trang 1-based 3 = chương đầu => currentPage phải là 2, không phải 3
      expect(findActiveOutlineIndex(flat, 1), -1);
      // currentPage=2 (trang 3): cả 'Chương 1' lẫn '1.1' đều khớp; lấy mục
      // CUỐI cùng khớp = nhánh sâu nhất => đang đọc 1.1, không phải Chương 1.
      expect(findActiveOutlineIndex(flat, 2), 1);
    });

    test('chọn mục CUỐI cùng có trang <= trang hiện tại (0-based + 1)', () {
      expect(findActiveOutlineIndex(flat, 5), 1); // trang 6 -> vẫn ở 1.1
      expect(findActiveOutlineIndex(flat, 6), 2); // trang 7 -> vào 1.2
      expect(findActiveOutlineIndex(flat, 20), 3); // Chương 2 (trang 12)
    });

    test('bỏ qua mục không có trang, kể cả khi nó chen giữa', () {
      final withHeader = flattenPdfOutline([
        _node('Dẫn nhập', null, const []),
        _node('Chương 1', 5, const []),
      ]);
      expect(findActiveOutlineIndex(withHeader, 3), -1);
      expect(findActiveOutlineIndex(withHeader, 4), 1);
      expect(withHeader[0].pageNumber, isNull);
    });

    test('nhánh lộn xộn thứ tự trang vẫn đúng (không break sớm)', () {
      // Sách hai ngôn ngữ: mục lục Latinh rồi phần Phụ lục trỏ về trang nhỏ hơn.
      final odd = flattenPdfOutline([
        _node('Chương cuối', 90, const []),
        _node('Phụ lục A', 4, const []),
      ]);
      expect(findActiveOutlineIndex(odd, 10), 1);
      expect(findActiveOutlineIndex(odd, 2), -1);
    });

    test('describeActiveOutline trả null khi chưa có mục nào khớp', () {
      expect(describeActiveOutline(const [], 5), isNull);
      expect(describeActiveOutline(flat, 0), isNull);
      expect(describeActiveOutline(flat, 8), '1.2');
    });
  });
}
