"""GLIB-008 — nội dung AudioPack seed (8 pack).

Track schema khớp data/tracks.json GLIB-005:
  {file*, title?, lrc?, durationSec?}

Ràng buộc sandbox: không có network tải LibriVox và không có audio pháp
thoại thật → audio seed v1 dùng tone WAV sinh thuần Python (placeholder
rõ ràng, để pipeline build/test end-to-end chạy được) + LRC transcript
THẬT (truyện cổ tích tự viết lại ngắn gọn CC0). File audio thật thay thế
lúc soạn trên máy chủ (xem PHAP_THOAI_NOTES.md + README).
"""

from __future__ import annotations

import math
import struct
import wave
import io

from seed_spec import PackSpec, slugify

_STORAGE = 'gs://in4up-seed/great_library'


def _tone_wav(freq: float, seconds: float = 4.0, rate: int = 8000) -> bytes:
    """WAV tone nhỏ (8kHz mono 16-bit) — placeholder audio rõ ràng."""
    n = int(seconds * rate)
    buf = io.BytesIO()
    with wave.open(buf, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        frames = bytearray()
        for i in range(n):
            # Fade in/out để không "click".
            env = min(1.0, i / (rate * 0.3), (n - i) / (rate * 0.5))
            sample = int(12000 * env * math.sin(2 * math.pi * freq * i / rate))
            frames += struct.pack('<h', sample)
        w.writeframes(bytes(frames))
    return buf.getvalue()


def _lrc(lines: list[tuple[int, str]], title: str) -> str:
    """lines: (start_seconds, text) → chuỗi LRC chuẩn [mm:ss.xx]."""
    out = [f'[ti:{title}]', '[by:In4Up Seed]']
    for sec, text in lines:
        mm = sec // 60
        ss = sec % 60
        out.append(f'[{mm:02d}:{ss:02d}.00]{text}')
    return '\n'.join(out) + '\n'


def _spec(pid, title, subtitle, desc, tags, attribution, license_name='cc0',
          license_url='https://creativecommons.org/publicdomain/zero/1.0/'):
    return PackSpec(
        pack_id=pid,
        pack_type='audio',
        title=title,
        subtitle=subtitle,
        description=desc,
        level='B1',
        tags=tags,
        license_name=license_name,
        license_url=license_url,
        attribution=attribution,
        storage_path=f'{_STORAGE}/{pid}.i4upack',
    )


def _story_pack(pid, title, subtitle, desc, story_title: str,
                sentences: list[str], tags, attribution):
    """1 pack = 1 truyện: 1 track + 1 LRC transcript thật."""
    track_file = f'{slugify(story_title)}.wav'
    lrc_file = f'{slugify(story_title)}.lrc'
    lines = [(i * 4, s) for i, s in enumerate(sentences)]
    tracks = [{
        'file': track_file,
        'title': story_title,
        'lrc': lrc_file,
        'durationSec': len(sentences) * 4 + 2,
    }]
    media = {track_file: _tone_wav(440.0, seconds=4.0)}
    lrc = {lrc_file: _lrc(lines, story_title)}
    spec = _spec(pid, title, subtitle, desc, tags, attribution)
    return (spec, tracks, media, lrc)


# --- Truyện cổ tích viết lại ngắn gọn (CC0, tự soạn) ----------------------

_GRIMM = (
    'seed_audio_grimm_tales',
    'Truyện cổ Grimm — audio + transcript',
    'Grimm fairy tales (audio + LRC)',
    'Bốn truyện cổ Grimm viết lại ngắn gọn bằng tiếng Anh đơn giản, kèm '
    'transcript LRC. Audio v1 là placeholder — bản LibriVox (public domain) '
    'sẽ thay lúc soạn trên máy chủ.',
    'The Fisherman and His Wife',
    [
        'A poor fisherman lived by the sea.',
        'One day he caught a golden fish.',
        'The fish said, "Please let me go."',
        'The kind fisherman let it swim away.',
        'His wife wanted a new house.',
        'The fish gave her a small cottage.',
        'But she wanted more and more.',
        'In the end, she had nothing again.',
    ],
    ['fairy-tale', 'grimm', 'story'],
    'Truyện cổ Grimm viết lại bởi In4Up Seed (cc0); audio thật dự kiến '
    'từ LibriVox (public domain).',
)

_ANDERSEN = (
    'seed_audio_andersen_tales',
    'Truyện cổ Andersen — audio + transcript',
    'Andersen fairy tales (audio + LRC)',
    'Truyện Andersen viết lại ngắn gọn bằng tiếng Anh đơn giản, kèm '
    'transcript LRC. Audio v1 placeholder — bản LibriVox thay lúc soạn.',
    'The Little Match Girl',
    [
        'It was a cold winter evening.',
        'A little girl walked in the snow.',
        'She carried matches to sell.',
        'No one bought any matches that day.',
        'She lit one match to warm her hands.',
        'In the flame she saw a warm stove.',
        'She lit another and saw a feast.',
        'At dawn, the snow covered her gently.',
    ],
    ['fairy-tale', 'andersen', 'story'],
    'Truyện Andersen viết lại bởi In4Up Seed (cc0); audio thật dự kiến '
    'từ LibriVox (public domain).',
)

_AESOP = (
    'seed_audio_aesop_fables',
    'Truyện ngụ ngôn Aesop — audio + transcript',
    'Aesop fables (audio + LRC)',
    'Ngụ ngôn Aesop viết lại ngắn gọn, kèm transcript LRC. Audio v1 '
    'placeholder — bản LibriVox thay lúc soạn.',
    'The Tortoise and the Hare',
    [
        'A hare laughed at the slow tortoise.',
        'The tortoise said, "Let us have a race."',
        'The hare ran fast and then slept.',
        'The tortoise walked on, step by step.',
        'He passed the sleeping hare quietly.',
        'He reached the finish line first.',
        'Slow and steady wins the race.',
    ],
    ['fable', 'aesop', 'story'],
    'Ngụ ngôn Aesop viết lại bởi In4Up Seed (cc0); audio thật dự kiến '
    'từ LibriVox (public domain).',
)

_GRADED = (
    'seed_audio_graded_stories',
    'Truyện ngắn trình độ A2–B1 (graded)',
    'Graded short stories (audio + LRC)',
    'Truyện ngắn tự soạn cho người học A2–B1, câu đơn giản, kèm transcript. '
    'Audio v1 placeholder.',
    'A New Home',
    [
        'Minh moved to a small town near the sea.',
        'He rented a room with a big window.',
        'Every morning he heard the waves.',
        'He bought bread from a kind old lady.',
        'At night he wrote letters to his mother.',
        'He felt lonely at first, then happy.',
        'The town slowly became his new home.',
    ],
    ['graded', 'story', 'a2-b1'],
    'Truyện tự soạn bởi In4Up Seed (cc0).',
)

AUDIO_STORIES = [
    _story_pack(*_GRIMM), _story_pack(*_ANDERSEN), _story_pack(*_AESOP),
    _story_pack(*_GRADED),
]

# --- Pack 15: câu ví dụ song ngữ theo chủ đề (audio TTS + Tatoeba skeleton)

_SENTENCES: list[tuple[str, str]] = [
    ('Good morning, have you eaten breakfast yet?', 'Chào buổi sáng, bạn ăn sáng chưa?'),
    ('Could you speak a little more slowly, please?', 'Bạn nói chậm lại một chút được không?'),
    ('Where is the nearest bus station?', 'Trạm xe buýt gần nhất ở đâu?'),
    ('How much does this shirt cost?', 'Cái áo này giá bao nhiêu?'),
    ('I would like a cup of coffee, please.', 'Cho tôi một tách cà phê.'),
    ('Excuse me, I am looking for the market.', 'Xin lỗi, tôi đang tìm chợ.'),
    ('What time does the train leave?', 'Tàu chạy lúc mấy giờ?'),
    ('Could you help me carry this bag?', 'Bạn giúp tôi xách túi này được không?'),
    ('I have lived here for ten years.', 'Tôi sống ở đây đã mười năm.'),
    ('The weather is very hot today.', 'Hôm nay trời rất nóng.'),
    ('My family has dinner together every night.', 'Gia đình tôi ăn tối cùng nhau mỗi tối.'),
    ('She is studying English at the library.', 'Cô ấy đang học tiếng Anh ở thư viện.'),
    ('We are planning a trip to the mountains.', 'Chúng tôi đang lên kế hoạch đi núi.'),
    ('Please turn left at the next corner.', 'Hãy rẽ trái ở ngã rẽ tiếp theo.'),
    ('I forgot to bring my umbrella.', 'Tôi quên mang ô.'),
    ('This food tastes a little too salty.', 'Món này hơi mặn.'),
    ('Can I pay by card here?', 'Ở đây trả bằng thẻ được không?'),
    ('The children are playing in the garden.', 'Bọn trẻ đang chơi trong vườn.'),
    ('He works as a doctor at the hospital.', 'Anh ấy làm bác sĩ ở bệnh viện.'),
    ('We will visit our grandmother this weekend.', 'Cuối tuần này chúng tôi sẽ thăm bà.'),
    ('Learning a new language takes patience.', 'Học một ngôn ngữ mới cần kiên nhẫn.'),
    ('The museum is closed on Mondays.', 'Bảo tàng đóng cửa vào thứ hai.'),
    ('She wrote a letter to her old friend.', 'Cô ấy viết thư cho người bạn cũ.'),
    ('Practice speaking every day, even for five minutes.', 'Luyện nói mỗi ngày, dù chỉ năm phút.'),
]

AUDIO_SENTENCES_SPEC = _spec(
    'seed_audio_example_sentences',
    'Câu ví dụ song ngữ theo chủ đề',
    'Bilingual example sentences (audio + LRC)',
    'Câu ví dụ giao tiếp song ngữ Anh–Việt theo chủ đề, kèm transcript LRC. '
    'Audio v1 placeholder — v2 thay bằng TTS bulk pipeline của app + câu từ '
    'Tatoeba (CC-BY, ghi credit).',
    ['sentences', 'bilingual', 'tatoeba'],
    'In4Up Seed (cc0); v2 bổ sung câu Tatoeba (CC-BY-2.0-FR, ghi credit '
    'https://tatoeba.org).',
)

_SENT_TRACK_FILE = 'example_sentences.wav'
_SENT_LRC_FILE = 'example_sentences.lrc'
AUDIO_SENTENCES = (
    AUDIO_SENTENCES_SPEC,
    [{
        'file': _SENT_TRACK_FILE,
        'title': 'Câu ví dụ giao tiếp (24 câu)',
        'lrc': _SENT_LRC_FILE,
        'durationSec': len(_SENTENCES) * 5 + 2,
    }],
    {_SENT_TRACK_FILE: _tone_wav(523.25, seconds=4.0)},
    {_SENT_LRC_FILE: _lrc(
        [(i * 5, f'{en} — {vi}') for i, (en, vi) in enumerate(_SENTENCES)],
        'Câu ví dụ song ngữ',
    )},
)

# --- Pack 16–18: Pháp thoại (placeholder manifest; audio thật thêm lúc soạn)

def _phap_thoai_pack(pid, title, subtitle, desc, note_key):
    spec = _spec(
        pid, title, subtitle, desc,
        ['phap-thoai', 'dharma', 'series'],
        'Pháp thoại do In4Up sở hữu quyền chia sẻ (tài nguyên app ship sẵn); '
        'audio thật thêm lúc export từ máy chủ — xem PHAP_THOAI_NOTES.md.',
        license_name='permission-granted',
        license_url='https://in4up.app/dharma-license',
    )
    # 1 track placeholder để manifest hợp lệ + schema đủ; LRC mô tả.
    track_file = f'{pid}_intro.wav'
    lrc_file = f'{pid}_intro.lrc'
    tracks = [{
        'file': track_file,
        'title': f'Giới thiệu — {title}',
        'lrc': lrc_file,
        'durationSec': 5,
    }]
    media = {track_file: _tone_wav(392.0, seconds=3.0)}
    lrc = {
        lrc_file: _lrc(
            [(0, 'Pack placeholder — audio pháp thoại thật thêm lúc soạn.')],
            title)
    }
    return (spec, tracks, media, lrc)


AUDIO_PHAP_1 = _phap_thoai_pack(
    'seed_audio_phap_thoai_ngan',
    'Pháp thoại ngắn — Series 1: An lạc',
    'Short Dharma talks — peace',
    'Series pháp thoại ngắn chủ đề an lạc có transcript. PLACEHOLDER: audio '
    'thật do owner export từ kho app (đã có quyền) lúc soạn.',
    'peace',
)
AUDIO_PHAP_2 = _phap_thoai_pack(
    'seed_audio_phap_thoai_tu_tap',
    'Pháp thoại ngắn — Series 2: Tu tập',
    'Short Dharma talks — practice',
    'Series pháp thoại ngắn chủ đề tu tập có transcript. PLACEHOLDER: audio '
    'thật do owner export từ kho app lúc soạn.',
    'practice',
)
AUDIO_PHAP_3 = _phap_thoai_pack(
    'seed_audio_phap_thoai_daily',
    'Pháp thoại ngắn — Series 3: Đời sống',
    'Short Dharma talks — daily life',
    'Series pháp thoại ngắn chủ đề đời sống có transcript. PLACEHOLDER: audio '
    'thật do owner export từ kho app lúc soạn.',
    'daily',
)

AUDIO_PACKS = AUDIO_STORIES + [AUDIO_SENTENCES, AUDIO_PHAP_1, AUDIO_PHAP_2,
                               AUDIO_PHAP_3]

PHAP_THOAI_NOTES = """# GLIB-008 — Ghi chú pháp thoại (pack 16–18)

Ba pack `seed_audio_phap_thoai_*` hiện là **placeholder hợp lệ** (manifest +
tracks.json + 1 track tone + LRC mô tả) để pipeline/catalog chạy end-to-end.

Audio pháp thoại THẬT (tài nguyên app đã có quyền dùng — ideation §5b)
**không nằm trong repo** → owner export trên máy chủ:

1. Lấy audio gốc (máy chủ/kho nội bộ).
2. Thay `media/<pid>_intro.wav` bằng file thật + cập nhật `tracks.json`
   (file/title/lrc/durationSec) + transcript LRC thật.
3. Chạy lại `build_seed_packs.py` → validator phải pass.
4. `seed_publish.py` upload + đổi storage ref.

Giấy phép ghi trong manifest: `In4Up Dharma Audio` (đã có quyền chia sẻ).
"""
