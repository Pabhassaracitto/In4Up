# GLIB-008 — Seed pipeline Thư Viện Chung (P0, curated-only)

Build 22 pack `.i4upack` seed EN→VI theo ideation §9.3, đúng schema GLIB-005
(`pack_content.dart`) để nhập qua `PackImportService`.

## Chạy

```bash
python3 tool/great_library_seed/build_seed_packs.py
# → tool/great_library_seed/dist/*.i4upack + catalog_seed.json
```

AT GLIB-008: **mọi pack parse pass validator** (khắc `PackFile.build` +
`PackContent.parse`) và license/attribution đầy đủ — script in FAIL nếu
vi phạm, exit code ≠ 0.

## 22 pack (ideation §9.3)

| # | Pack | Nguồn / trạng thái nội dung |
|---|---|---|
| 1 | `seed_vocab_500_verbs` | 118 động từ lõi tự soạn (CC0); v2 nạp NGSL đủ 500 |
| 2 | `seed_vocab_irregular_verbs` | 111 cặp V1/V2/V3 tự soạn (CC0) |
| 3 | `seed_vocab_phrasal_verbs` | 60 cụm lõi tự soạn; v2 mở rộng 300 |
| 4–7 | `seed_vocab_ngsl_*` | 4×~40 từ theo chủ đề tự soạn (CC0); v2 nạp NGSL |
| 8 | `seed_vocab_adj_adv` | 61 tính/trạng từ tự soạn |
| 9 | `seed_vocab_collocations` | 50 collocations tự soạn + ví dụ |
| 10 | `seed_vocab_academic_wordlist` | 61 từ học thuật phong cách NAWL tự soạn |
| 11–14 | `seed_audio_{grimm,andersen,aesop,graded}` | truyện tự viết lại (CC0) + LRC THẬT; **audio v1 tone placeholder** |
| 15 | `seed_audio_example_sentences` | 24 câu song ngữ tự soạn + LRC; v2 thêm Tatoeba (CC-BY) + TTS bulk |
| 16–18 | `seed_audio_phap_thoai_*` | PLACEHOLDER hợp lệ; audio pháp thoại thật (app có quyền) thêm lúc soạn — xem `dist/PHAP_THOAI_NOTES.md` |
| 19–22 | `seed_image_*` | caption song ngữ THẬT; ảnh v1 PNG tự sinh (CC0) — v2 thay ảnh OpenClipart |

## Ràng buộc sandbox & lộ trình

- **Không network ngoài GitHub** → chưa tải được NGSL/NAWL CSV, audio
  LibriVox, ảnh OpenClipart, câu Tatoeba. Nội dung v1 **tự soạn CC0** để
  pipeline + schema + import chạy end-to-end thật; TODO nạp nguồn mở ghi
  trong docstring từng module (`load_wordlist_external`).
- **Audio**: vocab `audio:` trỏ `media/<word>.mp3` (TTS bulk pipeline app
  sinh 1 lần lúc soạn trên máy chủ, không chạy sandbox). AudioPack dùng WAV
  tone placeholder rõ ràng + transcript LRC thật.
- **Ảnh**: PNG màu phẳng tự sinh (không Pillow), caption song ngữ thật.

## Publish (owner, 1 lần)

`seed_publish.py` upload 22 pack + ghi `gl_packs/*` từ `catalog_seed.json`
(cần service account + `pip install firebase-admin`). Trước đó owner phải
deploy Firestore/Storage rules theo `docs/great_library_firestore_schema.md`
§4 — **đây là việc owner vẫn nợ**; chưa deploy thì catalog đọc không ra.

## Test

`test/great_library/seed_schema_test.dart` build pack in-memory từ cùng
schema này và assert khớp `PackFile`/`PackContent` parser (chạy trong CI).
