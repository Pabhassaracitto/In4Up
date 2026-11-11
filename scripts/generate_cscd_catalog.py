#!/usr/bin/env python3
"""Generate the CSCD book-to-division index from a local tree.json.

Input: VipassanaTech/tipitaka-xml, tipitaka.org/romn/tree.json, git blob
3c12ab26e00845892bc6a42f7f46c93bc64d57a1. GitHub serves this blob as
UTF-16; it need not be copied into the app. The generated index contains no
scripture text. Unknown source tables remain in their imported collection.
"""
import json
import re
import sys
from pathlib import Path


def build(tree):
    root = tree[0]
    entries = {}
    for section, branch in enumerate(root['children']):
        for division, node in enumerate(branch['children']):
            def walk(item, ancestors):
                href = item.get('a_attr', {}).get('href', '')
                match = re.search(r'/([^/]+)\.(mul|att|tik|nrf)\d*\.xml', href, re.I)
                if match:
                    code = (match[1] + '_' + match[2]).upper()
                    parents = ancestors[:-1]  # last node is this source book
                    if code not in entries:
                        entries[code] = [section, division, len(entries), parents]
                    else:
                        record = entries[code]
                        if record[:2] != [section, division]:
                            raise ValueError(f'{code} occurs in two source divisions')
                        # Never guess a parent when a book spans source branches.
                        old = record[3]
                        record[3] = [v for i, v in enumerate(old)
                                     if old[:i + 1] == parents[:i + 1]]
                for child in item.get('children', []):
                    walk(child, ancestors + [item['text']])
            for child in node.get('children', []):
                walk(child, [])
    return root, entries


def render(root, entries):
    out = ['''// Catalogue positions derived from the CSCD tree used by the Pāli source.
// Source: VipassanaTech/tipitaka-xml, tipitaka.org/romn/tree.json,
// blob 3c12ab26e00845892bc6a42f7f46c93bc64d57a1.
// Only identifiers, source ordering, and structural labels are retained.
// Unknown/non-CSCD books deliberately fall back to their imported metadata.

typedef CscdCatalogLocation = ({int section, int division, int order, List<String> parents});

const cscdDivisionTitles = <List<String>>[
''']
    for branch in root['children']:
        out.append('  [' + ', '.join(json.dumps(x['text'], ensure_ascii=False)
                                      for x in branch['children']) + '],\n')
    out.append('];\n\nconst cscdCatalog = <String, CscdCatalogLocation>{\n')
    for code, (section, division, order, parents) in entries.items():
        out.append(f"  '{code}': (section: {section}, division: {division}, order: {order}, "
                   f"parents: {json.dumps(parents, ensure_ascii=False)}),\n")
    out.append('};\n')
    return ''.join(out)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit('Usage: generate_cscd_catalog.py /path/to/tree.json')
    source = json.loads(Path(sys.argv[1]).read_text(encoding='utf-16'))
    root, entries = build(source)
    target = Path(__file__).resolve().parents[1] / 'lib/features/tipitaka/models/cscd_catalog.dart'
    target.write_text(render(root, entries), encoding='utf-8')
    print(f'Wrote {len(entries)} source books to {target}')
