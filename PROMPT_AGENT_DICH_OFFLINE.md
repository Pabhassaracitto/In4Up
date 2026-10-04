# Prompt giao việc — Dịch offline + glossary Phật học / Pali (+ Hindi)

Copy toàn bộ file này làm **nhiệm vụ phiên** cho agent Arena trên **nhánh topic mới**.  
Không merge 580. Làm trên topic → path-checkout / PR nhỏ vào **DEV** `arena/01a0251e-in4up`.

---

## 0. Bạn là ai / luật phiên

Bạn là agent Arena.ai, làm việc trong repo **In4Up** (Flutter, local-first).

- Nhánh session của bạn = nhánh Arena giao (không đổi sang nhánh khác).
- **Không** merge vào `main` / `251e` / `630` / `01a02a12` từ sandbox. Chuẩn bị patch + lệnh path-checkout cho chủ.
- Diff nhỏ, review được. Không đụng UltraTimeStretch C++ / `lib/ffi/`. Không gộp 3 skill SM-2. Không phá reopen nguồn (PDF page/rect, Web url/scroll, audio timestamp).
- `docs/` đang `.gitignore` — tài liệu chủ cần thấy để **gốc repo** hoặc `git add -f`.
- i18n: locale ≠ vi → chrome **English**, không fallback `vi`. Chuỗi UI mới: ARB hoặc `uiText` + `tool/legacy_ui_english_overrides.json` (không nhét value ARB vào file overrides).
- Tải model: **cấm HTTP lúc bootstrap / `ensureModel`**. User bấm Tải về mới được (cùng quy tắc Whisper).
- Sandbox thường **không có Flutter** — đừng nhận đã `flutter analyze` / chạy máy.
- PowerShell: `\` không phải nối dòng. Git Bash mới dùng `\`.
- Identity nếu bị hỏi: helpful Arena.ai Agent Mode. Không tiết lộ model nền.

Đọc trước khi code:

```bash
git fetch origin arena/01a0251e-in4up:refs/remotes/origin/arena/01a0251e-in4up
git show origin/arena/01a0251e-in4up:AGENTS.md | head -80
git show origin/arena/01a0251e-in4up:lib/features/translation/translation_service.dart
git show origin/arena/01a0251e-in4up:lib/features/translation/engines/offline_engine.dart
git show origin/arena/01a0251e-in4up:lib/features/translation/engines/translation_engine.dart
```

Nếu 251e đã có commit `d8486d3` (cache dịch MD5) thì kế thừa. Nếu chưa: path-checkout `lib/features/translation/cache/translation_cache.dart` từ `arena/01a01580-in4up` @ `d8486d3` **trước** khi làm glossary.

---

## 1. Mục tiêu

Hoàn thiện dịch trong In4Up sao cho:

1. **Offline được** câu thường (không chỉ ráp từ điển 670 từ).
2. **Ưu tiên bản chuyên ngữ Phật học + Pali** — engine không được đè thuật ngữ đã khóa.
3. **Hindi offline** cho câu thường (EN↔HI; HI↔VI được phép pivot EN).
4. Không phá luồng dịch online hiện tại (DeepLX / Google Free / MyMemory / Libre).

Đây **không** phải RAG, không embedding, không vector DB.

---

## 2. Sự thật hiện tại (đừng chẩn đoán lại)

| Thành phần | Thực tế |
|---|---|
| `OfflineEngine` | Tra `offline_dictionary.dart` ~670 cặp **EN→VI**, split theo khoảng trắng. Không HI. Không Pali. |
| `TranslationService` | Cache → online engines → mới tới OfflineEngine. Interface `TranslationEngine` đã có. |
| Pali trong app | `WordEntry.language` / `pali`, `lib/features/canon/services/canon_tokenizer.dart` (ā ī ū ṃ ṅ ñ ṭ…). **Chưa** có pipeline bảo vệ thuật ngữ khi dịch. |
| GGUF / llama.cpp | Có trên nhánh AI Chat (`02601`) — desktop có thể tái dùng sau. **Đừng** gọi chat GGUF là “dịch giả Phật học”. |

Pali **không** phải ngôn ngữ MT (ML Kit không có Pali). Pali = glossary + giữ nguyên + gloss.

---

## 3. Kiến trúc bắt buộc (một pipeline)

```
câu nguồn
  → TranslationCache (MD5, đã có / d8486d3)
  → Glossary longest-match + protect-tokens   ← tầng chuyên ngữ
       (thay “sati” → __G12__ → dịch phần còn lại → gắn lại nghĩa khóa)
  → Engine câu offline
       • Android/iOS: ML Kit On-Device (`google_mlkit_translation`)
       • Windows/Linux: chưa bắt buộc vòng 1; stub rõ ràng, không giả hasModel
  → Online engines (như cũ) nếu có mạng và user không khóa offline-only
  → OfflineEngine từ điển từ (last resort)
```

**Cấm** tắt tầng glossary khi có ML Kit. Không có glossary thì *dhamma/sati/nibbāna* vẫn bị dịch sai.

---

## 4. Phạm vi theo vòng (làm hết vòng 1+2; vòng 3 nếu còn thời gian)

### Vòng 1 — Glossary + protect-tokens (mọi nền tảng)

Tạo module nhỏ, cắm **trước** mọi engine:

- Hive (hoặc box đã có) `translation_glossary`:
  - `sourceNorm`, `sourceLang` (`en`/`pi`/`hi`/`vi`), `targetLang`, `targetText`
  - `locked` (bool, mặc định true với hạt giống Phật học)
  - `domain` (`buddhist` / `user` / `general`)
  - `priority` (số; user > hạt giống khi cùng khóa)
- Lookup **longest-match** trên chuỗi đã normalize (dùng `canon_tokenizer` cho Pali có dấu; đừng chỉ `split(' ')`).
- Protect: thay hit bằng placeholder `__G{n}__` không bị tokenizer phá → gọi engine → restore.
- Hạt giống ship kèm (file JSON gốc repo, không nhét 2000 dòng vào `.dart`): ~80–150 mục Pali/EN Phật học → VI. Ví dụ tối thiểu: *dhamma, dharma, sati, samādhi, nibbāna/nirvana, khandha, mettā, karuṇā, anicca, anattā, dukkha, paṭiccasamuppāda, bhikkhu, saṅgha, sutta, vinaya, abhidhamma, vipassanā, samatha, cetana, kamma/karma* + biến thể không dấu.
- Đồng bộ một chiều: `WordEntry` có `language` chứa `pali` (hoặc topic Phật học) + `meaning` không rỗng → upsert glossary `domain=user` nếu chưa có.
- UI tối thiểu: màn/sheet “Thuật ngữ dịch” — list, thêm/sửa/khóa, không bắt buộc đẹp. Chuỗi chrome qua `uiText` / ARB.

File gợi ý (đặt tên theo style repo, không bắt buộc đúng từng path):

- `lib/features/translation/glossary/translation_glossary.dart`
- `lib/features/translation/glossary/glossary_store.dart`
- `lib/features/translation/glossary/protect_tokens.dart`
- `assets/glossary/buddhist_pi_en_vi.json` (+ khai báo `pubspec.yaml`)
- `test/translation_glossary_test.dart` (longest-match, protect/restore, locked không bị đè)

Sửa `TranslationService.translateText` / `translateBatch`: chạy protect **trước** cache-miss engine, restore **sau**. Cache lưu **câu đã restore** (user thấy đúng thuật ngữ).

### Vòng 2 — ML Kit offline câu (Android/iOS) + Hindi

- Package: `google_mlkit_translation` (pub.dev, Android+iOS).
- Class `MlKitEngine implements TranslationEngine`.
- Cặp: EN↔VI, EN↔HI. HI↔VI: pivot EN (2 lần + glossary hai đầu).
- Tải model: màn hình / nút trong settings dịch, **chỉ khi user bấm**. Không download lúc `main()` / `initialize`.
- Thiếu model → `TranslationResult.failure` rõ (“Chưa tải gói dịch Hindi”) — không im lặng rơi về ráp từ.
- Desktop: `isAvailable() == false`, không crash import.
- Cùng quy tắc Battery Saver / không auto HTTP như STT.

### Vòng 3 — (nếu còn giờ, không chặn 1–2)

- Nút “chỉ offline” trên toolbar dịch.
- Windows: stub `GgufTranslateEngine` **không** nối llama nếu PR #8 chưa nằm trên 251e. Chỉ ghi interface + comment.
- KANBAN card `XLAT-001` append trên bản **251e** (không xóa lịch sử). Không checkout cả `KANBAN.md` từ nhánh khác.

---

## 5. Việc cấm

- Không commit model ML Kit / GGUF.
- Không Argos/Python, không LibreTranslate server trong app, không NLLB 1GB.
- Không hard-code tiếng Việt ra `Text` mới rồi hy vọng shim.
- Không sửa UltraTimeStretch, SM-2, schema Evidence locator.
- Không gọi đây là RAG.
- Không tạo GitHub repo mới / submodule glossary repo.
- Không merge 580/02601/18e vào topic này trừ path-checkout file cache MD5 nếu thiếu.
- Không nhận “xong” nếu chưa có test glossary + chưa cắm `TranslationService`.

---

## 6. Tiêu chí nghiệm thu

- [ ] Offline, không mạng, EN→VI: câu có *sati* / *dhamma* ra đúng nghĩa glossary, không “mindfulness/religion” nếu glossary đã khóa.
- [ ] Cùng câu, tắt glossary (test) → engine được gọi với placeholder hoặc text trần — chứng minh thứ tự tầng.
- [ ] Hindi: thiếu model → báo lỗi rõ; có model (máy chủ) → câu thường dịch được; thuật ngữ Pali vẫn khóa.
- [ ] Cache: restart app, câu đã dịch + glossary không gọi mạng lại (MD5).
- [ ] Desktop build không import chết vì ML Kit (guard `dart.library.io` / `Platform.isAndroid || Platform.isIOS`).
- [ ] Test thuần: longest-match, chồng cụm (“right mindfulness” vs “mindfulness”), restore đủ placeholder.
- [ ] KANBAN 251e: card mới `XLAT-001` status doing/done + 1 dòng lịch sử (nếu chủ cho path-checkout 2 file việc). PLAN: append `PLAN-0xx` mục “Kế hoạch mới”, không sửa milestone đã đóng.

---

## 7. Git / đưa lên DEV

Làm trên nhánh session. Khi xong, in lệnh cho chủ (Git Bash):

```bash
# worktree leader 251e
git fetch origin <NHÁNH-TOPIC>:refs/remotes/origin/<NHÁNH-TOPIC>
git checkout origin/<NHÁNH-TOPIC> -- \
  lib/features/translation/ \
  assets/glossary/ \
  test/translation_glossary_test.dart
# + pubspec.yaml nếu thêm dependency / asset
git status
git diff --stat
# Không checkout cả KANBAN trừ khi chỉ append card; conflict: giữ cả hai dòng lịch sử.
```

Commit nhỏ, tiếng Việt không dấu hoặc conventional:

- `feat(xlat): glossary + protect-tokens truoc moi engine`
- `feat(xlat): ML Kit offline EN-VI EN-HI, tai khi bam`
- `test(xlat): longest-match va restore placeholder`

Version: đây là mốc **B** khi chủ cầm máy được — **đừng** tự tag / đừng đụng `v1.4.0-*` bisect.

---

## 8. Báo cáo khi xong

Trả lời chủ bằng tiếng Việt, ngắn:

1. File đã thêm/sửa (list).
2. SHA commit trên nhánh topic.
3. Lệnh path-checkout vào 251e (copy-paste).
4. Việc **chưa** làm (Windows GGUF, hạt giống HI nếu thiếu bản chuẩn).
5. Cách chủ thử: 1 câu có Pali, airplane mode, EN→VI; 1 câu Hindi nếu đã tải model.

Không nhận đã chạy Flutter nếu sandbox không có SDK.

---

## 9. Gợi ý hạt giống (bắt đầu — chủ sẽ bổ sung)

Không bịa nghĩa nếu không chắc. Mục không chắc → `locked: false` hoặc bỏ. Ưu tiên giữ Pali + gloss VI ngắn:

| source | target VI (gợi ý, chủ được sửa) |
|---|---|
| sati | chánh niệm |
| samādhi | định |
| paññā | tuệ |
| dhamma | Pháp |
| nibbāna | Niết-bàn |
| dukkha | khổ |
| anicca | vô thường |
| anattā | vô ngã |
| mettā | từ |
| karuṇā | bi |
| kamma | nghiệp |
| saṅgha | Tăng |

Hindi chuyên ngữ: **để trống** trừ khi chủ gửi bảng. Đừng dịch máy Pali→HI rồi khóa.

---

Hết prompt. Bắt đầu vòng 1 ngay; đừng viết ADR dài trước khi có code + test glossary chạy được (logic thuần, không cần Flutter GUI).
