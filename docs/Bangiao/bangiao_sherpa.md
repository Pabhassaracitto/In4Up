# agents.md
- **`docs/skills/i18n-localization/SKILL.md`** — bắt buộc đọc khi thêm hoặc sửa UI,
  đặc biệt các chức năng mới. Phải kiểm tra chrome, ARB parity và đủ bản dịch
  `hi`/`zh`/`zh_TW`/`si` trước khi coi task hoàn tất.
# PROMPT_AGENT_SHERPA_WP3_HANDOFF.md
# Prompt giao việc — hoàn thiện Sherpa WP3 sau harvest

Bạn là agent tiếp nhận trên branch leader `arena/01a0251e-in4up`.

## Bối cảnh bắt buộc
Đọc trước `AGENTS.md`, `docs/project/PLAN.md` (PLAN-008/009/020),
`docs/project/KANBAN.md` (SHERPA-001/002/003, SHERPA-WP2/WP3),
`docs/project/MODELS.md`, `lib/features/vad/README_VAD_TTS_STREAMING.md`.
Code WP2/WP3 nằm ở commit `4cdaffb` trên branch
`origin/arena/01a039e9-in4up`; cherry-pick với `-x`, không chép snippet thủ công.

## Nhiệm vụ
1. Giữ nguyên WP2: diarize sau LRC, sidecar cạnh LRC, load map, waveform segments,
   speaker legend, file cũ fallback mono.
2. Hoàn thiện WP3 trên code đã harvest:
   - Giữ parser pure và test hiện có; không đổi grammar nếu không có lý do.
   - Dùng duy nhất `SttServiceFacade.startListening()` + `partialResultStream`.
   - Nối executor vào provider thật: play/pause, next/previous, speed ±0.25,
     toggle LRC; chỉ nối translate sau khi xác nhận API của provider.
   - Không tạo mic pipeline thứ hai; một phiên chỉ fire command đầu tiên.
   - Timeout im lặng khoảng 1.5s, tối đa 6s; dispose subscription/timer/mic sạch.
   - UI dùng màn hình hiện có: mic button, indicator, partial preview, trạng thái thiếu model.
3. Quốc tế hóa ngay từ đầu: English fallback hợp lệ; VI, HI, ZH-Hans, ZH-Hant, SI.
   Không fallback về tiếng Việt khi locale khác.

## Bẫy không được lặp lại
- Không khai báo trùng `_voiceCommandService`, `_voiceListening`, `_lastVoiceText`
  hoặc `_startVoiceCommands`; tất cả field/method phải nằm trong
  `_ListenModeScreenState`.
- Không chèn snippet vào file bằng mắt khi đã có conflict; kiểm tra `git diff`.
- Không sửa `.github/workflows/`; docs bị ignore thì `git add -f`.
- CI là oracle; chạm path app để paths-filter trigger đúng workflow.
- Kiểm tra API `dart:io`/`dart:async`; sandbox có thể không có Flutter SDK.
- Không bịa URL/model Zipformer; không auto-download.

## Kiểm tra và báo cáo
Chạy `dart format`, `flutter analyze`, test parser + diarization; xác nhận CI
App Analyze + Locale. Báo cáo:

```
WP3 DONE
- Branch/SHA:
- Harvest source:
- CI run:
- AT đạt/chờ thiết bị:
- Known limitation:
- Files:
```

Sau đó gửi SHA cho owner/leader để review, cherry-pick/harvest và nghiệm thu thiết bị.
Không tuyên bố done nếu chỉ có code mà chưa báo trạng thái CI trung thực.
# KANBAN:

        Checklist kiểm thử, CI và báo cáo SHA.

Commit tài liệu:

text

880bb10 docs(sherpa): hand off WP2 and WP3 to main

Lưu ý về branch

Tôi không thể commit trực tiếp trên main hoặc arena/01a0251e-in4up vì session này bị cố định trên:

text

arena/01a039e9-in4up

Ngoài ra push lần cuối bị từ chối vì remote branch arena/01a039e9-in4up đã có commit mới hơn từ lần sandbox re-image. Tôi không force-push để tránh ghi đè công việc remote.

Leader có thể lấy commit tài liệu bằng:

Bash

git fetch origin arena/01a039e9-in4up
git cherry-pick -x 880bb10

Sau đó cập nhật vào arena/01a0251e-in4up/main theo quy trình harvest. File prompt mới nằm ở root repo:

text

PROMPT_AGENT_SHERPA_WP3_HANDOFF.md


In4Up
arena/01a039e9-in4up

GitHub has an outage that may affect your use of some features. View status
Workspace

Diff

- **`docs/skills/ci-red-debugging/SKILL.md`** — bắt buộc đọc khi CI GitHub Actions đỏ
  mà không tải được log (`gh run view --log` EOF) hoặc không có Flutter SDK local.
  Kèm script 1-lệnh `scripts/ci_check.sh` trong cùng folder.
- **`docs/skills/i18n-localization/SKILL.md`** — bắt buộc đọc khi thêm hoặc sửa UI,
  đặc biệt các chức năng mới. Phải kiểm tra chrome, ARB parity và đủ bản dịch
  `hi`/`zh`/`zh_TW`/`si` trước khi coi task hoàn tất.

## Tài liệu kiến trúc (không code mù — đọc trước khi đổi kiến trúc)

# Prompt giao việc — hoàn thiện Sherpa WP3 sau harvest

Bạn là agent tiếp nhận trên branch leader `arena/01a0251e-in4up`.

## Bối cảnh bắt buộc
Đọc trước `AGENTS.md`, `docs/project/PLAN.md` (PLAN-008/009/020),
`docs/project/KANBAN.md` (SHERPA-001/002/003, SHERPA-WP2/WP3),
`docs/project/MODELS.md`, `lib/features/vad/README_VAD_TTS_STREAMING.md`.
Code WP2/WP3 nằm ở commit `4cdaffb` trên branch
`origin/arena/01a039e9-in4up`; cherry-pick với `-x`, không chép snippet thủ công.

## Nhiệm vụ
1. Giữ nguyên WP2: diarize sau LRC, sidecar cạnh LRC, load map, waveform segments,
   speaker legend, file cũ fallback mono.
2. Hoàn thiện WP3 trên code đã harvest:
   - Giữ parser pure và test hiện có; không đổi grammar nếu không có lý do.
   - Dùng duy nhất `SttServiceFacade.startListening()` + `partialResultStream`.
   - Nối executor vào provider thật: play/pause, next/previous, speed ±0.25,
     toggle LRC; chỉ nối translate sau khi xác nhận API của provider.
   - Không tạo mic pipeline thứ hai; một phiên chỉ fire command đầu tiên.
   - Timeout im lặng khoảng 1.5s, tối đa 6s; dispose subscription/timer/mic sạch.
   - UI dùng màn hình hiện có: mic button, indicator, partial preview, trạng thái thiếu model.
3. Quốc tế hóa ngay từ đầu: English fallback hợp lệ; VI, HI, ZH-Hans, ZH-Hant, SI.
   Không fallback về tiếng Việt khi locale khác.

## Bẫy không được lặp lại
- Không khai báo trùng `_voiceCommandService`, `_voiceListening`, `_lastVoiceText`
  hoặc `_startVoiceCommands`; tất cả field/method phải nằm trong
  `_ListenModeScreenState`.
- Không chèn snippet vào file bằng mắt khi đã có conflict; kiểm tra `git diff`.
- Không sửa `.github/workflows/`; docs bị ignore thì `git add -f`.
- CI là oracle; chạm path app để paths-filter trigger đúng workflow.
- Kiểm tra API `dart:io`/`dart:async`; sandbox có thể không có Flutter SDK.
- Không bịa URL/model Zipformer; không auto-download.

## Kiểm tra và báo cáo
Chạy `dart format`, `flutter analyze`, test parser + diarization; xác nhận CI
App Analyze + Locale. Báo cáo:

```
WP3 DONE
- Branch/SHA:
- Harvest source:
- CI run:
- AT đạt/chờ thiết bị:
- Known limitation:
- Files:
```

Sau đó gửi SHA cho owner/leader để review, cherry-pick/harvest và nghiệm thu thiết bị.
Không tuyên bố done nếu chỉ có code mà chưa báo trạng thái CI trung thực.

| LHB-002 | Vanishing cloze scaffolding 4 tầng + first-letter mnemonics + i18n vi/en/hi/zh/zh_TW/si | ✅ done | cherry-pick 0ed55c8 → fb483df (chờ CI + nghiệm thu UX) |
| LHB-003 | Voice Recall (ghi mic + fuzzy align + gợi ý FSRS) + Nối xích câu kệ + Anki Cloze {{c1::}} | ✅ done | cherry-pick 10fecd3 → 19efa2d + fix transcribeAuto (0177c35 → 4f123e6); chờ CI + nghiệm thu mic |
| SOUNDLIST-630-02 | transcriptFromLrcLines: end = dòng KHÔNG TRỐNG kế tiếp (dòng trống phá highlight) | ✅ done | c978432 (providers copy sống); CI Soundlist xanh 32663677483 |
| AUDLIB-001 | Audio Library P1 (MediaStore) — fix content:// playback + VAD-only fallback + sherpa pubspec | ✅ done | thâu hoạch 01a0018e 70c4efc; CI xanh 33037686097 + 33037686068 (chờ nghiệm thu thiết bị) |
| LANG-03033-01 | Chrome i18n Soundlist/LHB/shell + hi/zh/zh_TW/si (thâu hoạch 01a03033) + fix 2 regression | ✅ done | ff f149d5a + fix 10 file bị dd081fb revert (a5ee489) + fix rule5 ARB (881d8aa); CI xanh 33078187839 |
| READ-630-06 | Bôi nhiều chữ mặc định; box-từng-từ tuỳ chọn (chip cam + settings); sheet lưu từ hiện từ cũ + Sửa | ✅ done | thâu hoạch 01a01580 db5c6ed (path-checkout 6 file) + fix 5 lỗi compile; CI xanh 33082501188 (chờ nghiệm thu thiết bị) |
| XLAT-001 | Dịch offline: glossary Phật học/Pali + protect-tokens trước mọi engine + ML Kit (EN↔VI, EN↔HI; HI↔VI pivot EN) + offline-only | ✅ done | code + test thuần (sandbox KHÔNG có Flutter SDK → chờ CI + nghiệm thu thiết bị) |

    XANH run 32855255220 (tip 3797dcc — full harvest) + run 32789473478
    (core fix, d43cc3d). Chờ nghiệm thu UX thiết bị (banner chat, import
    .gguf progress, tải URL chỉ WiFi, xóa model)


### AUDLIB-001 — Audio Library P1: nghiệm thu + 3 fix từ 01a0018e (content://, VAD-only, pubspec)
- **Trạng thái:** done (chờ owner build 70c4efc+ và nghiệm thu trên thiết bị)
- **Nguồn:** owner yêu cầu nghiệm thu `arena/01a0018e-in4up` (2026-08-25) —
  fix 3 lỗi từ audit thiết bị của owner: pub get đỏ (sherpa duplicate),
  mở bài từ tab Thư viện không chạy (content://), "Chỉ VAD" báo lỗi.
- **Nội dung (thâu hoạch ff 01a0018e → 0855cb3, 8 file +111/−69):**
  - `AudioLibraryService.resolvePlayablePath()`: content:// → copy sang cache
    trước khi phát (just_audio/ExoPlayer không phát content:// ổn định) — dùng
    ở `AudioLibraryView._openEntry` + `ListenLibraryScreen._openAudio`
    (kể cả mở lại file đã lưu ở tab Gần đây).
  - `SoundAutoTocService._evenSplitFallback()`: PURE, chia đều 2–8 đoạn
    ~60s/đoạn; áp vào MỌI early-return (copy content:// fail, waveform rỗng,
    energies <6, slices <2) → file ≥ ~12s luôn tạo được mục lục thô kể cả
    VAD-only, không cần Whisper.
  - `packages/in4up_stt/pubspec.yaml`: bỏ `sherpa_onnx: ^1.13.4` trùng khai báo
    (duplicate key làm pub get fail), giữ `^1.13.6`.
  - Dọn `sound_auto_toc_dialog.dart` (bỏ PlayerProvider import + biến unused),
    `stt_model_settings_screen.dart` (bỏ import googleapis/analytics auto-import
    nhầm + material trùng — 0855cb3).
  - `docs/soundlist_ci_workflow.yml` v5 (commit-back log khi đỏ + paths đủ
    Audio Library + pubspec) — **workflow đang chạy vẫn là bản cũ**; owner copy
    v5 vào `.github/workflows/soundlist_tests.yml` nếu muốn (agent không có
    quyền workflows).
- **Nghiệm thu (2026-08-25, agent arena/01a0251e-in4up):** review code từng file
  OK (resolvePlayablePath fallback an toàn `path ?? uri`; _evenSplitFallback
  đúng biên 2×minSegment; pubspec 1 key duy nhất). CI: App Analyze + Locale
  XANH run 33037686097 + Soundlist XANH run 33037686068 (analyze + test).
  01a0018e xanh sẵn run 32946979440 trước khi thâu hoạch.
- **Chờ owner (thiết bị):** (1) tab Thư viện → chạm 1 bài → phát được;
  (2) ⚡ Tự tạo mục lục → Chỉ VAD → ra "Đoạn 1 · 00:00…" kể cả file content://;
  (3) VAD+Whisper vẫn chạy. Xong → bước P2 (chọn thư mục âm thanh).
- **Lịch sử:**
  - 2026-08-25 | created→done | agent arena/01a0251e-in4up | ff-merge
    01a0018e (70c4efc, nhánh đã merge sẵn 251e 2cfb53b) + cleanup import;
    CI xanh 33037686097/33037686068
### LANG-03033-01 — Chrome i18n Soundlist/LHB/shell (thâu hoạch 01a03033) + 3 fix nghiệm thu
- **Trạng thái:** done (CI xanh; chờ owner nghiệm thu: mở app locale ≠ vi →
  chrome Soundlist/LHB/shell hiện bản dịch hi/zh/zh_TW/si/EN, không Việt)
- **Nguồn:** owner yêu cầu nghiệm thu `arena/01a03033-in4up` (2026-08-27).
- **Nội dung thâu hoạch (ff 1982867 → f149d5a, 79 file):**
  - Bản dịch + fallback nhóm chrome Soundlist (Âm mục, Điểm, Đoạn, Mục lục,
    Chương, Ghi chú, Đánh dấu, Tìm kiếm, Phát, Thêm, Xóa, Đổi tên, …) +
    status notifications cho **hi/zh/zh_TW/si**; fallback: locale → EN →
    an toàn, **không bao giờ fallback về Việt**.
  - 6 file qua localized Material/Text bridge (soundlist_panel,
    sound_list_screen, sound_auto_toc_dialog, sound_mark_edit_sheet,
    selection_save_sheet, vocab_entry_meta) + import-swap 11 file.
  - Regenerate `generated_ui_translations.dart` (791 entries) +
    `generated_legacy_ui_fallbacks.dart` (1640 keys); ARB +78 key
    (audit_*, lhb_*, chrome shell/LHB/soundlist).
- **Fix 1 — regression merge (a5ee489):** merge dd081fb (01a03033) resolution
  giữ BẢN CŨ → revert im lặng 10 file (mất auto-TOC background + D16,
  dialog auto-TOC mới, LHB-002 scaffolding 4 tầng, LHB-003 wiring) →
  compile error CI đỏ. KANBAN.md cũng bị rơi 6 card 251e (AUDLIB-001,
  HARVEST-1580-01, LHB-002/003, LISTEN-825-01, MODELS-002) — đã khôi phục
  toàn bộ từ 1982867. Fix: 3-way merge-file đúng base (e02ac7e soundlist /
  35d1d48 LHB) — ours = đủ tính năng 251e + theirs = i18n. Verify: feature
  markers + i18n imports + i18n data ('Âm mục' → hi ध्वनि सूची / zh 音频目录 /
  zh_TW 音訊目錄 / si ශ්‍රව්‍ය ලැයිස්තුව).
- **Fix 2 — rule5 (881d8aa):** (a) app_ar.arb 3 subtitle có GIÁ TRỊ TIẾNG
  VIỆT (generator fallback sai) → về EN; (b) 78 key mới chưa dịch T3 →
  keep-English (chính sách ADR-0002) — 19 locale từng tụt dưới sàn ratchet.
- **Bằng chứng:** App Analyze + Locale XANH run 33078187839; Soundlist XANH
  33076735293. Verify local: replica đủ 11 check của
  locale_chrome_no_vietnamese_test → 0 vi phạm.
- **Lịch sử:**
  - 2026-08-27 | created→done | agent arena/01a0251e-in4up | ff-merge 01a03033
    + 3 fix (regression 10 file + khôi phục KANBAN + rule5 ARB/keep-English);
    CI xanh 33078187839

### READ-630-06 — Bôi nhiều chữ mặc định; box-từng-từ tuỳ chọn; sheet lưu hiện từ cũ
- **Trạng thái:** done (CI xanh; chờ owner nghiệm thu trên thiết bị)
- **Nguồn:** chủ yêu cầu nghiệm thu `arena/01a01580-in4up` (2026-08-27) —
  thâu hoạch commit `db5c6ed` bằng path-checkout 6 file (pattern SO_TAY).
- **Nội dung:**
  - **2 cách chọn:** mặc định bôi nhiều chữ (mọi màu POS/CEFR, như chế độ
    không màu); "box từng từ" là TUỲ CHỌN — chip lưới cam trên ReadTopBar
    (cạnh chip màu) + toggle trong ReadSettingsSheet; persist qua
    ReaderDisplaySettings (prefs).
  - Box từng từ: long-press box → sheet lưu từ (nền lưu hàng loạt sau này);
    render qua ColoredTextWidget.
  - **Sheet lưu từ đủ dữ liệu từ cũ:** `_loadRelated()` chạy khi mở sheet
    (postFrame) — trước đó không bao giờ chạy → mất bảng từ cũ. Entry đã
    có: VocabEntryMetaInfo (IPA, loại, chủ đề, ngôn ngữ) + nút Sửa
    (VocabEntryEditSheet — cùng bảng PDF/Web: thêm/bớt tag); chip ngôn ngữ
    en/vi/pali/my + ngôn ngữ đã có (không ô gõ mã mới); cụm/từ liên đới
    hiện lại khi WordList có mục gần giống.
- **Fix nghiệm thu (code 1580 db5c6ed dính 5 lỗi compile — chưa qua CI):**
  1. text_provider: dòng rác 'returoadTextFile: File not found: $path');'
     (merge-corrupt) — xóa.
  2. text_provider: tail corrupt — 'notifyListeners();' + block Auto-split
     nhân đôi + thừa đóng class — dọn.
  3. Thiếu TextProvider.setWordTapBoxes (read_top_bar + read_settings_sheet
     gọi) + thiếu import reader_display_settings — bổ sung setter delegate.
  4. _buildTextContent: 'lineIndex: index' mà index không có scope — truyền
     index từ caller.
  5. Mảnh rác 'otifyListeners();' (thiếu n) sót ở _applyLines — khôi phục.
  Verify: diff chéo 6 file với bản gốc 251e (2f64c18) — chỉ còn đúng diff
  feature; balance-check 6 file OK.
- **Bằng chứng:** App Analyze + Locale XANH run 33082501188.
- **Lịch sử:**
  - 2026-08-27 | created→done | agent arena/01a0251e-in4up | path-checkout
    6 file từ db5c6ed + 5 fix compile; CI xanh 33082501188
  - 2026-08-29 | fix bug layout rộng | agent arena/01a0251e-in4up | e715d85:
    _WordTapChip chỉ gắn nhánh compact (width<620 || height<700) → màn rộng
    (Windows/tablet) không có nút; bù vào Row không compact + icon tắt
    select_all → grid_view_outlined (khớp "nút lưới")

### XLAT-001 — Dịch offline: glossary Phật học/Pali + protect-tokens + ML Kit (XLAT)
- **Trạng thái:** done (code + test thuần; chờ CI + nghiệm thu thiết bị)
- **Nội dung:**
  - **Vòng 1 — Glossary + protect-tokens (mọi nền tảng):** module
    `lib/features/translation/glossary/` (thuần Dart: `translation_glossary.dart`,
    `protect_tokens.dart` + `glossary_store.dart` Hive box `translation_glossary`).
    Lookup longest-match trên chuỗi đã normalize (dùng `CanonTokenizer`,
    Pali có dấu khớp biến thể không dấu), word boundary, tie-break
    priority (user 100 > hạt giống 0) + domain. Protect = thay hit bằng
    `__G{n}__` → engine dịch phần còn lại → restore nghĩa khóa. Cache
    (MD5) lưu câu ĐÃ RESTORE; glossary đổi → clear cache.
    - Hạt giống 226 mục Pali/EN Phật học → VI: `assets/glossary/buddhist_pi_en_vi.json`
      (locked=true; chưa có hạt giống HI — chờ bảng từ chủ).
    - Đồng bộ 1 chiều từ WordEntry (language Pali hoặc topic Phật học +
      meaning không rỗng → entry domain=user nếu chưa có, không ghi đè).
    - UI: màn "Thuật ngữ dịch" (list/thêm/sửa/khóa/xóa) mở từ Cài đặt
      engine dịch; chuỗi chrome qua uiText + override English.
  - **Vòng 2 — ML Kit offline (Android/iOS) + Hindi:** `MlKitEngine`
    (package `google_mlkit_translation` 0.15.x) — engine dịch CÂU, cắm
    TRƯỚC online engines trong pipeline. Cặp EN↔VI, EN↔HI; HI↔VI pivot
    qua EN (2 bước + glossary hai đầu) khi đủ model. Model CHỈ tải khi
    user bấm "Tải về" trong Cài đặt engine dịch (không auto lúc mở app,
    cùng quy tắc Whisper). Thiếu model → failure rõ "Chưa tải gói dịch
    <lang>" — không rơi im lặng về ráp từ. Desktop: isAvailable=false,
    import không crash.
  - **Vòng 3:** toggle "Chỉ dùng dịch offline" (persist SharedPreferences);
    KANBAN card này. (Windows GGUF stub CHƯA làm — chờ PR #8 trên 251e.)
  - Pipeline `TranslationService`: cache → glossary(protect) → ML Kit →
    online (nếu mạng + không khóa offline-only) → từ điển offline
    (last resort) → restore → cache.
- **File:** thêm `lib/features/translation/glossary/{translation_glossary,
  protect_tokens,glossary_store,glossary_sheet}.dart`,
  `lib/features/translation/engines/mlkit_engine.dart`,
  `assets/glossary/buddhist_pi_en_vi.json`, `test/translation_glossary_test.dart`;
  sửa `translation_service.dart`, `translation_toolbar.dart`,
  `vocabulary_provider.dart`, `pubspec.yaml`,
  `tool/legacy_ui_english_overrides.json` + generated fallbacks, PLAN-019.
- **Bằng chứng:** `test/translation_glossary_test.dart` (normalize,
  longest-match, boundary, restore, luật khóa, sync WordEntry, thứ tự
  tầng pipeline, pivot HI→VI, ML Kit desktop). **Lưu ý:** sandbox KHÔNG
  có Flutter SDK — chưa chạy `flutter analyze`/`flutter test`; owner cần
  `flutter pub get` (dependency mới) + chạy CI/test trước nghiệm thu.
- **Lịch sử:**
  - 2026-08-23 | created | owner via prompt giao việc (dịch offline +
    glossary Phật học/Pali + Hindi) | agent arena/01a02ffc-in4up
  - 2026-08-23 | doing→done | agent arena/01a02ffc-in4up | code + test thuần;
    cache MD5 kế thừa sẵn trên 251e (không cần path-checkout d8486d3);
    chưa build máy (sandbox không có Flutter SDK) — chờ CI + nghiệm thu
  - 2026-08-29 | thu hoạch vào 251e | agent arena/01a0251e-in4up |
    cherry-pick 4 SHA dbab77e→aa84747 thành ad874b6/e648d64/753d790/26a5c51
    (KHÔNG lấy read_top_bar/text_provider từ 02ffc — giữ nút lưới 1580);
    fix import WordEntry sai đường dẫn da2ea37 (bị vỡ cả trên 02ffc — chưa
    từng compile); PLAN-016 trùng số với card Tab Nghe trên DEV → PLAN-019;
    pubspec.lock chưa có google_mlkit_translation — CI pub get tự sync, chủ
    chạy `flutter pub get` trên máy rồi commit lock; chờ CI xanh + nghiệm
    thu máy: EN→VI, EN→HI, một câu có sati/nibbāna
  - 2026-08-29 | 3 lỗi compile tìm qua oracle CI (log/blob bị chặn) |
    agent arena/01a0251e-in4up | (1) DropdownButtonFormField initialValue→
    value ×3 (b497738); (2) translation_glossary thiếu import protect_tokens
    (f916244); (3) **Hive Box KHÔNG có putIfAbsent** (02ffc tưởng như Map)
    → `await box.put(...)` trong _doInit (commit này). Bisect 7 vòng CI
    ~2m/vòng, skill ci-red-debugging. Bài học: code 02ffc chưa từng qua
    compiler — mọi harvest tương tự phải coi "chưa compile" là mặc định

### SHERPA-WP2 — Waveform màu theo người nói
- **Trạng thái:** doing (chờ harvest/CI/thiết bị).
- **Nội dung:** sau VAD/Whisper LRC, gọi `HeuristicDiarizationService`, lưu `SpeakerSidecar` cạnh LRC; load map + segment refs khi mở LRC; truyền `speakerColorMap` vào `RollingWaveformView`; legend Người 1/2/…; file cũ fallback mono.
- **AT:** fixture silence-gap tạo ≥2 speaker colors; file không sidecar không crash; test `packages/in4up_stt/test/diarization_service_test.dart`.
- **Bằng chứng:** `4cdaffb` (chờ leader cherry-pick `-x`), chưa có CI do SDK không có.

### SHERPA-WP3 — Voice command qua STT facade
- **Trạng thái:** doing (parser/service/UI code bàn giao; còn CI/thiết bị).
- **Nội dung:** parser pure 8 nhóm lệnh VN+EN + không dấu; executor callback; `VoiceCommandService` một mic session, partial stream, first-match debounce, silence 1.5s/max 6s; UI mic/indicator/preview trong Listen Mode; i18n EN fallback + VI/HI/ZH-Hans/ZH-Hant/SI.
- **AT:** parser table test; engine thiếu model trả failure rõ; thiết bị kiểm tra pause/speed/next/previous/LRC.
- **Known limitation:** `translate` chưa nối action provider vì cần owner xác nhận API toggle translation; không giả lập hành vi.
- **Bằng chứng:** `4cdaffb`, leader cherry-pick `-x`; CI chưa chạy trong sandbox.
# PLAN

### PLAN-019 — Dịch offline: glossary Phật học/Pali + protect-tokens + ML Kit (XLAT-001)
- Nguồn: người sở hữu (2026-08-23, qua prompt giao việc cho agent
  arena/01a02ffc-in4up — "Dịch offline + glossary Phật học / Pali (+ Hindi)")
- Trạng thái: proposed
- Milestone đề xuất: ngoài M0–M3 (phạm vi Đọc/Dịch, không đụng knowledge MVA)
- Chi tiết:
  - **Vòng 1 (mọi nền tảng):** glossary Hive + lookup longest-match
    (normalize Pali/Việt qua CanonTokenizer) + protect-tokens `__G{n}__`
    cắm TRƯỚC mọi engine; hạt giống 226 mục Pali/EN → VI (locked);
    đồng bộ 1 chiều WordEntry(Pali/Phật học) → glossary domain=user;
    UI "Thuật ngữ dịch".
  - **Vòng 2 (Android/iOS):** ML Kit on-device (google_mlkit_translation)
    — engine dịch câu offline, EN↔VI, EN↔HI; HI↔VI pivot qua EN
    (2 bước + glossary hai đầu); model chỉ tải khi user bấm; thiếu model
    → failure rõ, không rơi về ráp từ.
  - **Vòng 3:** toggle "chỉ offline"; KANBAN XLAT-001.
  - Pipeline: cache MD5 → glossary → ML Kit → online (nếu mạng + không
    khóa offline) → từ điển offline (last resort) → restore.
  - KHÔNG phải RAG/embedding/vector DB. KHÔNG gọi chat GGUF là "dịch giả
    Phật học". Pali không phải ngôn ngữ MT — Pali = glossary + giữ nguyên + gloss.
  - **Chưa làm (đề xuất tiếp theo):** Windows `GgufTranslateEngine` stub
    (chỉ khi PR #8 đã nằm trên 251e); hạt giống HI (chờ bảng từ chủ gửi);
    seed tiếng HI hiện để trống theo lệnh chủ.
- Bằng chứng: card XLAT-001 (KANBAN) + test/translation_glossary_test.dart.
  Lưu ý: sandbox không có Flutter SDK — code + test chưa chạy máy,
  chờ `flutter pub get` + CI + nghiệm thu thiết bị của chủ.
- Lịch sử:
  - 2026-08-23 | created | owner via prompt | "I4U | READ Translate"

### PLAN-020 — Sherpa WP2/WP3 handoff: speaker waveform + voice commands
- Nguồn: owner (2026-09-03), triển khai trên agent branch `arena/01a039e9-in4up`.
- Trạng thái: doing (code đã bàn giao, chờ leader harvest + CI + thiết bị).
- Phạm vi: WP2 nối heuristic diarization → `.spk.json` sidecar → waveform màu/legend; WP3 parser lệnh VN+EN, executor/service dùng `SttServiceFacade`, mic UI Listen Mode.
- Quy tắc: không chờ Meetily Rust/Zipformer; không auto-download model; thiếu model phải báo rõ; English là fallback và feature quan trọng có VI/HI/ZH-Hans/ZH-Hant/SI.
- Bằng chứng code: commit `4cdaffb` trên `arena/01a039e9-in4up` (leader cherry-pick `-x`). Sandbox không có Flutter/Dart nên chưa tự xác nhận analyze/test.
- Lịch sử: 2026-09-03 | created→doing | agent arena/01a039e9-in4up | bàn giao leader.

# lid/core/language/generated_legacy_ui_fallbacks.dart:
  '⚙️ Engine dịch thuật': '⚙️ Translation engines',
  'Gói dịch offline (ML Kit — Android/iOS)': 'Offline translation packs (ML Kit — Android/iOS)',
  'ML Kit chỉ chạy trên Android/iOS.': 'ML Kit runs on Android/iOS only.',
  'Chỉ tải khi bạn bấm — không tự tải lúc mở app.': 'Downloaded only when you tap — never on app startup.',
  'Chưa hỗ trợ': 'Not supported',
  'Xóa gói': 'Delete model',
  'Lỗi tải gói {value0}': 'Failed to download {value0} pack',
  'Đã tải gói {value0}': 'Downloaded {value0} pack',
  'Chỉ dùng dịch offline': 'Offline-only translation',
  'Bỏ qua engine online (ML Kit + từ điển offline).': 'Skips online engines (ML Kit + offline dictionary only).',
  'Thuật ngữ dịch (glossary)': 'Translation glossary',
  'Khóa thuật ngữ Phật học/Pali — engine không được đè.': 'Locks Buddhist/Pali terms — engines cannot override them.',
  'Thuật ngữ dịch': 'Translation glossary',
  'Thuật ngữ khóa giữ nguyên khi dịch — engine không được đè.': 'Locked terms keep their meaning when translating — engines cannot override them.',
  'Tìm thuật ngữ...': 'Search terms...',
  'Chưa có thuật ngữ nào.': 'No terms yet.',
  'Bấm + để thêm.': 'Tap + to add one.',
  'Phật học': 'Buddhist',
  'Người dùng': 'User',
  'Chung': 'General',
  'Sửa thuật ngữ': 'Edit term',
  'Thêm thuật ngữ': 'Add term',
  'Từ nguồn': 'Source term',
  'Ngôn ngữ nguồn': 'Source language',
  'Ngôn ngữ đích': 'Target language',
  'Bản dịch khóa': 'Locked translation',
  'Khóa — engine không được đè': 'Locked — engine cannot override',
  'Xóa thuật ngữ này?': 'Delete this term?',
  'Đã lưu thuật ngữ': 'Term saved',