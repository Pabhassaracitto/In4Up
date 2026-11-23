from __future__ import annotations

import argparse
import hashlib
import io
import json
import sys
import time
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from seed_spec import PackSpec, slugify

import math
import struct
import wave
import io as _io


def _tone_wav(freq: float, seconds: float = 4.0, rate: int = 8000) -> bytes:
    """WAV tone nhỏ (8kHz mono 16-bit) — placeholder audio rõ ràng cho
    seed v1; TTS bulk / LibriVox thật thay lúc soạn trên máy chủ."""
    n = int(seconds * rate)
    buf = _io.BytesIO()
    with wave.open(buf, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        frames = bytearray()
        for i in range(n):
            env = min(1.0, i / (rate * 0.3), (n - i) / (rate * 0.5))
            sample = int(12000 * env * math.sin(2 * math.pi * freq * i / rate))
            frames += struct.pack('<h', sample)
        w.writeframes(bytes(frames))
    return buf.getvalue()



SCHEMA_NOTE = (
    'data/ schema khớp GLIB-005 pack_content.dart v1 — đừng đổi mà không '
    'bump PackContent.currentDataSchemaVersion.'
)


def build_manifest(spec: PackSpec, item_count: int, byte_size: int) -> dict:
    """Manifest JSON khớp PackManifest.toJson (pack_manifest.dart GLIB-001).

    Key: schemaVersion/id/type/title/description/srcLang/dstLang/tags/level/
    author{uid,displayName,verified}/license(enum wire)/version/sizeBytes/
    entryCount/stats/status/storage{backend,path}/createdAt/updatedAt.
    """
    return {
        'schemaVersion': 1,
        'id': spec.pack_id,
        'type': spec.pack_type,
        'title': spec.title,
        'description': spec.description,
        'srcLang': spec.language,
        'dstLang': spec.target_language,
        'tags': spec.tags,
        'level': spec.level,
        'author': {
            'uid': 'seed-in4up',
            'displayName': 'In4Up Seed',
            'verified': True,
        },
        'license': spec.license_name,   # enum PackLicense wire: 'cc0' | 'self-made' | 'permission-granted' | ...
        'version': spec.version,
        'sizeBytes': byte_size,
        'entryCount': item_count,
        'stats': {'downloads': 0, 'rating': 0, 'ratings': 0},
        'status': 'published',
        'storage': {'backend': 'firebase', 'path': spec.storage_path},
        'createdAt': '2026-11-23T00:00:00Z',
        'updatedAt': '2026-11-23T00:00:00Z',
    }


def svg_placeholder(word: str, caption: str, hue: int) -> bytes:
    """Ảnh SVG tối giản có nhãn — placeholder CC0 tự sinh.

    Image.memory hiển thị SVG? KHÔNG — Flutter Image.memory cần raster.
    Vậy ImageSet seed dùng PNG? Không có lib ảnh trong sandbox → sinh PNG
    tối giản bằng zlib thủ công (ảnh màu phẳng + không chữ; caption nằm
    trong data/items.json và hiển thị dưới ảnh)."""
    # Trả về PNG màu phẳng 256x256 (tạo bởi _solid_png bên dưới).
    return _solid_png(256, 256, hue)


def _crc32(data: bytes) -> int:
    import zlib

    return zlib.crc32(data) & 0xFFFFFFFF


def _solid_png(w: int, h: int, hue: int) -> bytes:
    """PNG RGB màu phẳng sinh thuần (không Pillow)."""
    import struct
    import zlib

    # Màu từ hue (HSL gần đúng, s=0.5, l=0.6).
    c = (1 - abs(2 * 0.6 - 1)) * 0.5
    x = c * (1 - abs(((hue / 60) % 2) - 1))
    m = 0.6 - c / 2
    if hue < 60:
        r, g, b = c, x, 0
    elif hue < 120:
        r, g, b = x, c, 0
    elif hue < 180:
        r, g, b = 0, c, x
    elif hue < 240:
        r, g, b = 0, x, c
    elif hue < 300:
        r, g, b = x, 0, c
    else:
        r, g, b = c, 0, x
    rgb = bytes([int((r + m) * 255), int((g + m) * 255), int((b + m) * 255)])

    def chunk(tag: bytes, data: bytes) -> bytes:
        return (
            struct.pack('>I', len(data))
            + tag
            + data
            + struct.pack('>I', _crc32(tag + data))
        )

    sig = b'\x89PNG\r\n\x1a\n'
    ihdr = chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0))
    raw = b''.join(b'\x00' + rgb * w for _ in range(h))
    idat = chunk(b'IDAT', zlib.compress(raw, 6))
    iend = chunk(b'IEND', b'')
    return sig + ihdr + idat + iend


def build_vocab_pack(spec: PackSpec, entries: list[dict]) -> dict[str, bytes]:
    """files: manifest.json + data/entries.json + media/<word>.mp3.

    GLIB-005 parser bắt buộc mọi media ref tồn tại trong zip → v1 ship tone
    WAV placeholder cho mỗi từ (TTS bulk thật chạy lúc soạn trên máy chủ, ghi
    đè cùng tên file)."""
    files: dict[str, bytes] = {}
    data = {'schema': 'vocab-v1', 'entries': entries}
    files['data/entries.json'] = json.dumps(
        data, ensure_ascii=False, indent=1
    ).encode()
    payload_size = len(files['data/entries.json'])
    for i, e in enumerate(entries):
        ref = e.get('audio')
        if ref:
            blob = _tone_wav(330.0 + (i % 24) * 12.0, seconds=1.2)
            files[f'media/{ref}'] = blob
            payload_size += len(blob)
    files['manifest.json'] = json.dumps(
        build_manifest(spec, len(entries), payload_size), ensure_ascii=False,
        indent=1,
    ).encode()
    return files


def build_audio_pack(spec: PackSpec, tracks: list[dict],
                     media: dict[str, bytes],
                     lrc: dict[str, str]) -> dict[str, bytes]:
    """tracks.json + media/<audio> + data/<lrc>."""
    files: dict[str, bytes] = {'data/tracks.json': json.dumps(
        {'schema': 'audio-v1', 'tracks': tracks}, ensure_ascii=False,
        indent=1,
    ).encode()}
    payload_size = len(files['data/tracks.json'])
    for name, blob in media.items():
        files[f'media/{name}'] = blob
        payload_size += len(blob)
    for name, text in lrc.items():
        files[f'data/{name}'] = text.encode()
        payload_size += len(files[f'data/{name}'])
    files['manifest.json'] = json.dumps(
        build_manifest(spec, len(tracks), payload_size), ensure_ascii=False,
        indent=1,
    ).encode()
    return files


def build_image_pack(spec: PackSpec, items: list[dict]) -> dict[str, bytes]:
    """items.json + media/<ảnh PNG tự sinh>."""
    files: dict[str, bytes] = {'data/items.json': json.dumps(
        {'schema': 'image-v1', 'items': items}, ensure_ascii=False, indent=1,
    ).encode()}
    payload_size = len(files['data/items.json'])
    for i, item in enumerate(items):
        hue = (i * 47) % 360
        png = _solid_png(256, 256, hue)
        files[f'media/{item["image"]}'] = png
        payload_size += len(png)
    files['manifest.json'] = json.dumps(
        build_manifest(spec, len(items), payload_size), ensure_ascii=False,
        indent=1,
    ).encode()
    return files


def write_pack(out_dir: Path, spec: PackSpec, files: dict[str, bytes]) -> Path:
    """Ghi .i4upack = zip(store): manifest.json + data/* + media/*."""
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, 'w', zipfile.ZIP_DEFLATED) as zf:
        # manifest đầu tiên cho dễ đọc.
        for name in sorted(files, key=lambda n: n != 'manifest.json'):
            zf.writestr(name, files[name])
    out_dir.mkdir(parents=True, exist_ok=True)
    path = out_dir / f'{spec.pack_id}.i4upack'
    path.write_bytes(buf.getvalue())
    return path


# ---------------------------------------------------------------------------
# Validator — khắc PackFile.build (GLIB-001) + PackContent.parse (GLIB-005).
# ---------------------------------------------------------------------------

MANIFEST_REQUIRED = {
    'schemaVersion': int, 'id': str, 'type': str, 'title': str,
    'description': str, 'srcLang': str, 'dstLang': str, 'tags': list,
    'level': str, 'author': dict, 'license': str, 'version': int,
    'sizeBytes': int, 'entryCount': int, 'stats': dict, 'status': str,
    'storage': dict,
}
PACK_LICENSES = {'cc0', 'cc-by', 'cc-by-nc', 'self-made',
                 'permission-granted'}
PACK_LEVELS = {'A1', 'A2', 'B1', 'B2', 'C1', 'C2', 'mixed'}

DATA_FILES = {'vocab': 'data/entries.json', 'audio': 'data/tracks.json',
              'image': 'data/items.json'}
DATA_REQUIRED = {'vocab': {'word', 'meaning'}, 'audio': {'file'},
                 'image': {'image'}}
DATA_LIST_KEY = {'vocab': 'entries', 'audio': 'tracks', 'image': 'items'}


def validate_pack(path: Path) -> list[str]:
    """Trả list lỗi (rỗng = pass). Bắt chước chặt PackManifest/PackContent."""
    errors: list[str] = []
    try:
        with zipfile.ZipFile(path) as zf:
            names = set(zf.namelist())
            if 'manifest.json' not in names:
                return ['manifest.json missing']
            m = json.loads(zf.read('manifest.json'))
            for k, t in MANIFEST_REQUIRED.items():
                if k not in m:
                    errors.append(f'manifest: thiếu {k}')
                elif not isinstance(m[k], t):
                    errors.append(f'manifest: {k} sai kiểu {t.__name__}')
            if errors:
                return errors
            author = m['author']
            if not str(author.get('displayName', '')).strip():
                errors.append('manifest invalid: author-name-empty')
            ptype = m['type']
            if ptype not in DATA_FILES:
                errors.append(f'manifest: type lạ {ptype}')
                return errors
            if not m['title'].strip():
                errors.append('manifest: title-empty')
            if m['license'] not in PACK_LICENSES:
                errors.append(f"manifest: license lạ '{m['license']}'")
            if m['level'] not in PACK_LEVELS:
                errors.append(f"manifest: level lạ '{m['level']}'")
            if not str(m.get('srcLang', '')).strip():
                errors.append('manifest: srcLang-empty')
            if not str(m.get('dstLang', '')).strip():
                errors.append('manifest: dstLang-empty')
            st = m['storage']
            if not st.get('backend') or not st.get('path'):
                errors.append('manifest: storage-invalid')
            df = DATA_FILES[ptype]
            if df not in names:
                errors.append(f'{df} missing')
                return errors
            data = json.loads(zf.read(df))
            items = data[DATA_LIST_KEY[ptype]]
            if len(items) != m['entryCount']:
                errors.append(f"entryCount {m['entryCount']} != {len(items)}")
            for i, it in enumerate(items):
                for req in DATA_REQUIRED[ptype]:
                    if not str(it.get(req, '')).strip():
                        errors.append(f'{df}[{i}]: {req} trống')
                # Mọi media ref PHẢI tồn tại trong zip — khớp chặt
                # PackContent.parse (_requireMedia ném FormatException).
                # VocabPack v1 buộc ship media/<word>.mp3 placeholder (tone
                # WAV) vì seed pipeline chưa chạy TTS bulk; thay thật lúc soạn.
                for ref_key in ('audio', 'image', 'file'):
                    ref = it.get(ref_key)
                    if ref and f'media/{ref}' not in names:
                        errors.append(f'{df}[{i}]: media/{ref} missing')
            # entry vocab không nên bắt đầu bằng cụm thừa "CỘT V1 — " nếu
            # dùng lại bảng bất quy tắc (regex guard).
            if ptype == 'vocab':
                for it in items:
                    if str(it.get('word', '')).startswith('CỘT V1'):
                        errors.append('word bắt đầu bằng marker bảng bất quy tắc')
                lrc = it.get('lrc')
                if lrc and f'data/{lrc}' not in names:
                    errors.append(f'{df}[{i}]: data/{lrc} missing')
            if m['sizeBytes'] <= 0:
                errors.append('manifest: sizeBytes <= 0')
    except zipfile.BadZipFile:
        return ['không phải zip']
    return errors


def catalog_entry(spec: PackSpec, path: Path) -> dict:
    """Doc gợi ý cho gl_packs/<id> (owner/seed-publish upload)."""
    return {
        'id': spec.pack_id,
        'type': spec.pack_type,
        'title': spec.title,
        'subtitle': spec.subtitle,
        'description': spec.description,
        'srcLang': spec.language,
        'dstLang': spec.target_language,
        'level': spec.level,
        'tags': spec.tags,
        'version': spec.version,
        'license': spec.license_name,
        'downloads': 0,
        'rating': 0.0,
        'status': 'published',
        'attribution': spec.attribution,
        'storagePath': spec.storage_path,
        'zipBytes': path.stat().st_size,
        'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
        'updatedAt': '2026-11-23T00:00:00Z',
    }


def main() -> int:
    from vocab_content import VOCAB_PACKS
    from audio_content import AUDIO_PACKS, PHAP_THOAI_NOTES
    from image_content import IMAGE_PACKS

    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default='tool/great_library_seed/dist',
                    help='thư mục ghi .i4upack + catalog_seed.json')
    args = ap.parse_args()
    out = Path(args.out)

    t0 = time.time()
    catalog: list[dict] = []
    failures = 0

    for spec, entries in VOCAB_PACKS:
        files = build_vocab_pack(spec, entries)
        p = write_pack(out, spec, files)
        errs = validate_pack(p)
        status = 'OK ' if not errs else 'FAIL'
        print(f'[{status}] {p.name:42s} {len(entries):4d} entries')
        for e in errs:
            print('    ✗', e)
            failures += 1
        if not errs:
            catalog.append(catalog_entry(spec, p))

    for spec, tracks, media, lrc in AUDIO_PACKS:
        files = build_audio_pack(spec, tracks, media, lrc)
        p = write_pack(out, spec, files)
        errs = validate_pack(p)
        status = 'OK ' if not errs else 'FAIL'
        print(f'[{status}] {p.name:42s} {len(tracks):4d} tracks')
        for e in errs:
            print('    ✗', e)
            failures += 1
        if not errs:
            catalog.append(catalog_entry(spec, p))

    for spec, items in IMAGE_PACKS:
        files = build_image_pack(spec, items)
        p = write_pack(out, spec, files)
        errs = validate_pack(p)
        status = 'OK ' if not errs else 'FAIL'
        print(f'[{status}] {p.name:42s} {len(items):4d} items')
        for e in errs:
            print('    ✗', e)
            failures += 1
        if not errs:
            catalog.append(catalog_entry(spec, p))

    (out / 'catalog_seed.json').write_text(
        json.dumps(catalog, ensure_ascii=False, indent=2), encoding='utf-8')
    (out / 'PHAP_THOAI_NOTES.md').write_text(PHAP_THOAI_NOTES,
                                            encoding='utf-8')
    dt = time.time() - t0
    print(f'\n== {len(catalog)}/22 pack OK · {failures} lỗi · {dt:.1f}s ==')
    print(f'catalog_seed.json ({len(catalog)} docs) → {out}/catalog_seed.json')
    return 1 if failures else 0


if __name__ == '__main__':
    raise SystemExit(main())
