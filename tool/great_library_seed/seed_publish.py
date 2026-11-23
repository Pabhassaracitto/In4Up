#!/usr/bin/env python3
"""GLIB-008 — publish nội bộ (thay màn admin ở P0).

Upload 22 pack `.i4upack` trong dist/ lên Firebase Storage và ghi doc catalog
`gl_packs/<id>` từ catalog_seed.json. YÊU CẦU quyền owner (không chạy trong
sandbox CI — script này chạy 1 lần trên máy chủ khi owner rảnh).

Dùng Firebase Admin SDK / REST với service account của owner:

  pip install firebase-admin   # hoặc dùng REST + access token

  python3 tool/great_library_seed/seed_publish.py \
      --service-account ~/in4up-firebase-admin.json \
      --bucket in4up-seed --dist tool/great_library_seed/dist

Nếu chưa cài firebase-admin, script in ra checklist thủ công tương đương.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--service-account', help='đường dẫn JSON service account')
    ap.add_argument('--bucket', default='in4up-seed',
                    help='Firebase Storage bucket')
    ap.add_argument('--dist', default='tool/great_library_seed/dist')
    args = ap.parse_args()

    dist = Path(args.dist)
    catalog_path = dist / 'catalog_seed.json'
    if not catalog_path.exists():
        print('Chưa có catalog_seed.json — chạy build_seed_packs.py trước.')
        return 1
    catalog = json.loads(catalog_path.read_text(encoding='utf-8'))
    print(f'{len(catalog)} pack trong catalog_seed.json')

    try:
        import firebase_admin  # type: ignore
        from firebase_admin import credentials, storage, firestore  # noqa
    except ImportError:
        print('\nfirebase-admin chưa cài → checklist thủ công:')
        print('  1. Deploy rules: docs/great_library_firestore_schema.md §4')
        print('  2. Upload từng dist/*.i4upack lên Storage path trong doc.')
        print('  3. Tạo doc gl_packs/<id> từ catalog_seed.json (Firestore).')
        print('  Hoặc: pip install firebase-admin rồi chạy lại script này.')
        return 0

    if not args.service_account:
        print('Thiếu --service-account khi firebase-admin đã cài.')
        return 1

    cred = credentials.Certificate(args.service_account)
    firebase_admin.initialize_app(cred, {'storageBucket': args.bucket})
    bucket = storage.bucket()
    db = firestore.client()
    for doc in catalog:
        pack_path = dist / f"{doc['id']}.i4upack"
        blob = bucket.blob(doc['storagePath'].split('/', 3)[-1]
                           if doc['storagePath'].startswith('gs://')
                           else doc['storagePath'])
        blob.upload_from_filename(str(pack_path))
        db.collection('gl_packs').document(doc['id']).set(doc)
        print(f"  ✓ {doc['id']}")
    print('Publish xong.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
