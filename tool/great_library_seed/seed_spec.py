"""GLIB-008 — PackSpec + slugify dùng chung cho mọi content module."""

from __future__ import annotations

from dataclasses import dataclass, field


@dataclass
class PackSpec:
    """Mô tả 1 pack seed — fields bắt buộc khớp PackManifest (GLIB-001)."""

    pack_id: str
    pack_type: str  # 'vocab' | 'audio' | 'image'
    title: str
    subtitle: str
    description: str
    language: str = 'en'
    target_language: str = 'vi'
    level: str = 'A1'  # A1..C1
    tags: list[str] = field(default_factory=list)
    # license_name = wire enum PackLicense GLIB-001: 'cc0' | 'cc-by' |
    # 'cc-by-nc' | 'self-made' | 'permission-granted'.
    license_name: str = 'cc0'
    license_url: str = 'https://creativecommons.org/publicdomain/zero/1.0/'
    attribution: str = ''
    version: int = 1
    # storage: seed P0 để local asset — owner upload lên Storage sau (path
    # này là gợi ý; catalog doc gl_packs/<id> trỏ tới).
    storage_path: str = ''


def slugify(text: str) -> str:
    out = []
    for ch in text.lower():
        if ch.isalnum():
            out.append(ch)
        elif ch in (' ', '-', '_'):
            out.append('_')
    slug = ''.join(out).strip('_')
    while '__' in slug:
        slug = slug.replace('__', '_')
    return slug[:40]


