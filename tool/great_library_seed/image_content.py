"""GLIB-008 — nội dung ImageSet seed (4 pack).

Item schema khớp data/items.json GLIB-005: {image*, caption?, word?}.

Ràng buộc sandbox: không tải được ảnh CC0 thật → ảnh là PNG màu phẳng tự
sinh (placeholder CC0 của chính pipeline), caption song ngữ THẬT. Ảnh
OpenClipart thật thay trong v2 khi có network (giữ nguyên tên file media).
"""

from __future__ import annotations

from seed_spec import PackSpec, slugify

# Seed phát hành qua GitHub Release gl-seed-v1 (không cần Firebase Blaze):
# storage path = tên file trong release.
_STORAGE = ''


def _spec(pid, title, subtitle, desc, tags):
    return PackSpec(
        pack_id=pid,
        pack_type='image',
        title=title,
        subtitle=subtitle,
        description=desc,
        level='B1',
        tags=tags,
        attribution='Ảnh minh hoạ tự sinh bởi In4Up Seed (cc0) — '
                    'placeholder chờ thay bằng ảnh CC0/OpenClipart thật.',
        storage_path=f'{pid}.i4upack',
    )


def _items(pairs: list[tuple[str, str]]) -> list[dict]:
    return [
        {
            'image': f'{slugify(en)}.png',
            'caption': f'{en} — {vi}',
            'word': en,
        }
        for (en, vi) in pairs
    ]


_HOME: list[tuple[str, str]] = [
    ('house', 'ngôi nhà'), ('door', 'cửa chính'), ('window', 'cửa sổ'),
    ('roof', 'mái nhà'), ('wall', 'bức tường'), ('floor', 'sàn nhà'),
    ('kitchen', 'nhà bếp'), ('bedroom', 'phòng ngủ'), ('bathroom', 'phòng tắm'),
    ('living room', 'phòng khách'), ('table', 'cái bàn'), ('chair', 'cái ghế'),
    ('bed', 'cái giường'), ('lamp', 'đèn bàn'), ('mirror', 'gương'),
    ('clock', 'đồng hồ'), ('sofa', 'ghế sô-pha'), ('shelf', 'kệ sách'),
    ('curtain', 'rèm cửa'), ('pillow', 'cái gối'), ('blanket', 'chăn'),
    ('refrigerator', 'tủ lạnh'), ('stove', 'bếp'), ('sink', 'bồn rửa'),
    ('cupboard', 'tủ chén'), ('knife', 'con dao'), ('fork', 'cái nĩa'),
    ('spoon', 'cái thìa'), ('plate', 'cái đĩa'), ('bowl', 'cái bát'),
    ('cup', 'cái cốc'), ('bottle', 'chai'), ('key', 'chìa khóa'),
    ('broom', 'cây chổi'), ('bucket', 'cái xô'), ('towel', 'khăn'),
    ('soap', 'xà phòng'), ('toothbrush', 'bàn chải đánh răng'),
    ('television', 'ti vi'), ('fan', 'quạt'),
]

_NATURE: list[tuple[str, str]] = [
    ('dog', 'con chó'), ('cat', 'con mèo'), ('bird', 'con chim'),
    ('fish', 'con cá'), ('horse', 'con ngựa'), ('cow', 'con bò'),
    ('pig', 'con lợn'), ('chicken', 'con gà'), ('duck', 'con vịt'),
    ('goat', 'con dê'), ('sheep', 'con cừu'), ('elephant', 'con voi'),
    ('monkey', 'con khỉ'), ('tiger', 'con hổ'), ('rabbit', 'con thỏ'),
    ('snake', 'con rắn'), ('frog', 'con ếch'), ('butterfly', 'con bướm'),
    ('bee', 'con ong'), ('ant', 'con kiến'), ('tree', 'cái cây'),
    ('flower', 'bông hoa'), ('grass', 'cỏ'), ('leaf', 'chiếc lá'),
    ('forest', 'khu rừng'), ('mountain', 'ngọn núi'), ('river', 'con sông'),
    ('sea', 'biển'), ('lake', 'hồ'), ('rain', 'mưa'),
    ('cloud', 'đám mây'), ('sun', 'mặt trời'), ('moon', 'mặt trăng'),
    ('star', 'ngôi sao'), ('stone', 'hòn đá'), ('sand', 'cát'),
    ('island', 'hòn đảo'), ('waterfall', 'thác nước'), ('rainbow', 'cầu vồng'),
    ('wind', 'gió'),
]

_ACTIONS: list[tuple[str, str]] = [
    ('walking', 'đi bộ'), ('running', 'chạy'), ('sitting', 'ngồi'),
    ('standing', 'đứng'), ('sleeping', 'ngủ'), ('eating', 'ăn'),
    ('drinking', 'uống'), ('cooking', 'nấu ăn'), ('reading', 'đọc sách'),
    ('writing', 'viết'), ('drawing', 'vẽ'), ('singing', 'hát'),
    ('dancing', 'nhảy múa'), ('swimming', 'bơi'), ('riding a bicycle', 'đạp xe'),
    ('driving', 'lái xe'), ('working', 'làm việc'), ('studying', 'học'),
    ('teaching', 'dạy học'), ('playing', 'chơi'), ('laughing', 'cười'),
    ('crying', 'khóc'), ('smiling', 'mỉm cười'), ('listening', 'lắng nghe'),
    ('talking', 'nói chuyện'), ('washing', 'rửa; giặt'), ('cleaning', 'dọn dẹp'),
    ('shopping', 'mua sắm'), ('climbing', 'leo trèo'), ('jumping', 'nhảy'),
    ('carrying', 'mang vác'), ('opening', 'mở'), ('closing', 'đóng'),
    ('pushing', 'đẩy'), ('pulling', 'kéo'), ('throwing', 'ném'),
    ('catching', 'bắt lấy'), ('cutting', 'cắt'), ('painting', 'sơn; vẽ tranh'),
]

_SUPPORT: list[tuple[str, str]] = [
    # Minh hoạ bổ trợ một số từ trong VocabPack 1 (động từ lõi).
    ('go', 'đi'), ('come', 'đến'), ('run', 'chạy'), ('walk', 'đi bộ'),
    ('sit', 'ngồi'), ('stand', 'đứng'), ('eat', 'ăn'), ('drink', 'uống'),
    ('sleep', 'ngủ'), ('read', 'đọc'), ('write', 'viết'), ('cook', 'nấu'),
    ('smile', 'mỉm cười'), ('help', 'giúp đỡ'), ('give', 'cho'),
    ('take', 'lấy'), ('open', 'mở'), ('close', 'đóng'), ('pull', 'kéo'),
    ('push', 'đẩy'), ('carry', 'mang'), ('cut', 'cắt'), ('draw', 'vẽ'),
    ('swim', 'bơi'), ('fly', 'bay'), ('jump', 'nhảy'), ('listen', 'nghe'),
    ('watch', 'xem'), ('play', 'chơi'), ('work', 'làm việc'),
    ('learn', 'học'), ('teach', 'dạy'), ('sing', 'hát'), ('dance', 'nhảy'),
    ('buy', 'mua'), ('sell', 'bán'), ('pay', 'trả tiền'), ('win', 'thắng'),
    ('lose', 'thua'), ('love', 'yêu thương'),
]

IMAGE_HOME = (
    _spec(
        'seed_image_home_objects',
        'Đồ vật trong nhà (caption song ngữ)',
        'Objects around the house',
        'Bộ ảnh đồ vật trong nhà kèm caption Anh–Việt. Ảnh v1 là placeholder '
        'tự sinh (CC0) — v2 thay bằng ảnh CC0 thật.',
        ['image', 'home', 'caption'],
    ),
    _items(_HOME),
)

IMAGE_NATURE = (
    _spec(
        'seed_image_animals_nature',
        'Động vật & thiên nhiên',
        'Animals & nature',
        'Bộ ảnh động vật và thiên nhiên kèm caption Anh–Việt (placeholder tự '
        'sinh CC0).',
        ['image', 'animals', 'nature'],
    ),
    _items(_NATURE),
)

IMAGE_ACTIONS = (
    _spec(
        'seed_image_daily_actions',
        'Hoạt động hằng ngày (minh hoạ động từ)',
        'Daily actions illustrated',
        'Bộ ảnh minh hoạ các động từ hoạt động hằng ngày kèm caption song ngữ '
        '(placeholder tự sinh CC0).',
        ['image', 'actions', 'verbs'],
    ),
    _items(_ACTIONS),
)

IMAGE_SUPPORT = (
    _spec(
        'seed_image_vocab_support',
        'Ảnh minh hoạ bổ trợ VocabPack 1–8',
        'Support images for vocab packs',
        'Ảnh minh hoạ gắn theo từ, bổ trợ các VocabPack động từ/chủ đề '
        '(placeholder tự sinh CC0).',
        ['image', 'vocab-support'],
    ),
    _items(_SUPPORT),
)

IMAGE_PACKS = [IMAGE_HOME, IMAGE_NATURE, IMAGE_ACTIONS, IMAGE_SUPPORT]
