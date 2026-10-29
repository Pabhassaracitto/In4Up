import unittest

from tool.generate_legacy_ui_fallbacks import scan_strings


class ScanStringsTest(unittest.TestCase):
    def scan_all(self, source: str) -> list[str]:
        return scan_strings(source, include_unaccented=True)

    def test_reconstructs_adjacent_fragments_and_renumbers_placeholders(self):
        source = """
final label = 'Xin $name, '
    /* adjacency may cross comments and whitespace */
    'bạn có ${items.length} mục';
"""

        self.assertEqual(
            self.scan_all(source),
            ['Xin {value0}, bạn có {value1} mục'],
        )

    def test_supports_line_comments_between_adjacent_fragments(self):
        source = """
final label = 'Một ' // explanation
    'chuỗi hoàn chỉnh';
"""

        self.assertEqual(self.scan_all(source), ['Một chuỗi hoàn chỉnh'])

    def test_raw_fragment_keeps_dollar_literal_and_offsets_later_interpolation(self):
        source = r"""
final label = r'Giá $khôngNoiSuy: ' '${amount} đồng';
"""

        self.assertEqual(
            self.scan_all(source),
            [r'Giá $khôngNoiSuy: {value0} đồng'],
        )

    def test_does_not_join_literals_separated_by_syntax(self):
        source = """
final first = 'Một';
final second = 'Hai';
final combined = 'Ba' + 'Bốn';
final spaced = 'Năm' ?? 'Sáu';
"""

        self.assertEqual(
            self.scan_all(source),
            ['Một', 'Hai', 'Ba', 'Bốn', 'Năm', 'Sáu'],
        )

    def test_adjacent_fragments_preserve_escaped_and_literal_whitespace(self):
        source = r"""
final label = 'Dòng 1\n'
    '  Dòng ${line}';
"""

        self.assertEqual(self.scan_all(source), ['Dòng 1\n  Dòng {value0}'])


if __name__ == '__main__':
    unittest.main()
