import importlib.util
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    'catalog_generator', Path(__file__).parents[1] / 'scripts/generate_cscd_catalog.py')
generator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(generator)


class CatalogGeneratorTest(unittest.TestCase):
    def test_common_parent_and_split_file_identifiers(self):
        def leaf(href):
            return {'text': 'section', 'a_attr': {'href': href}}
        tree = [{'text': 'root', 'children': [{'text': 'Mula', 'children': [
            {'text': 'Sutta', 'children': [
                {'text': 'Nikaya', 'children': [
                    {'text': 'Volume', 'children': [
                        leaf('cscd/s0402m1.mul0.xml'),
                        leaf('cscd/s0402m1.mul1.xml'),
                    ]},
                    {'text': 'Another volume', 'children': [
                        leaf('cscd/s0402m1.mul2.xml'),
                    ]},
                ]},
            ]},
        ]}]}]
        _, entries = generator.build(tree)
        self.assertEqual(entries['S0402M1_MUL'], [0, 0, 0, ['Nikaya']])

    def test_conflicting_divisions_are_rejected(self):
        leaf = {'text': 'book', 'a_attr': {'href': 'cscd/vin01m.mul0.xml'}}
        tree = [{'text': 'root', 'children': [{'text': 'Mula', 'children': [
            {'text': 'one', 'children': [leaf]},
            {'text': 'two', 'children': [leaf]},
        ]}]}]
        with self.assertRaises(ValueError):
            generator.build(tree)


if __name__ == '__main__':
    unittest.main()
