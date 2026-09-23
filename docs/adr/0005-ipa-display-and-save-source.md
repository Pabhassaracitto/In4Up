# ADR-0005: IPA toàn văn — lớp phiên âm RIÊNG + waterfall nguồn IPA 1 chiều

- **Ngày:** 2026-09-23
- **Trạng thái:** ĐÃ TRIỂN KHAI từng phần trên `arena/01a0c723-in4up`
  (P1 `e1a4382` CI 🟢 run 35687736425; P2 = READ-IPA-002 nguồn IPA khi lưu).
- **Phạm vi:** Read Mode (`text_line_widget`, `read_settings`,
  `line_ipa_service`), WordList save-path (`vocabulary_provider`,
  `ipa_resolver`, `vocab_entry_meta`, `word_actions_sheet`).
  KHÔNG đổi ColorMode, KHÔNG đổi dependency, KHÔNG đụng `mdx_parser`
  (DICT-001 / `arena/01a07234-in4up` sở hữu).

## Bối cảnh

Cần IPA ở 3 chỗ: (1) đọc toàn văn trong Read Mode, (2) điền IPA khi lưu
từ, (3) học phát âm (shadowing đã có sẵn pipeline). Các ràng buộc đã chốt
trước khi code:

- **ML Kit loại bỏ** — không có phonetic API (chỉ TTS/STT text).
- **flutter_tts không trả IPA**, Google Cloud TTS bỏ qua SSML `<phoneme>`.
- **Word-timestamp bị strip lúc parse** (`text_provider`, `synced_line`) —
  không còn data source cho karaoke theo từng từ → highlight theo nhịp
  chỉ làm được **cấp dòng** qua `activeLineNotifier`.
- Psych/nên khoa học: IPA stacked = dual-coding (chữ + ký hiệu âm thanh
  cùng dòng), chỉ bật khi đọc chủ động → tránh cognitive overload.
- Color-science: IPA KHÔNG được trộn vào ColorMode (POS/CEFR/…) — hai
  ngữ nghĩa khác nhau, trộn sẽ phá legend hiện có.

## Quyết định

1. **IPA mode là lớp riêng, 3 trạng thái** — `IpaDisplayMode`
   `hidden → activeLine → all`, toggle ở bottom-bar cạnh nút dịch
   (`Icons.abc`, cyan `0xFF4DD0E1`), dòng IPA xếp chồng dưới dòng chữ
   (fontSize × 0.75), selector trong Settings → "Phiên âm / IPA".
   (P1 / READ-IPA-001.)

2. **Một waterfall nguồn duy nhất, 1 chiều, không prompt:**
   `MDX (DictEntry.phonetic → trích /.../ hoặc [...] từ definition)
   → CMU (EN) → G2P rules → bỏ trống`.
   - Setting toàn cục `ipa_save_source`: `auto | dict | g2p | off`
     (default `auto`) — ở Settings → IPA ngay dưới IPA mode.
   - **Không bao giờ ghi đè IPA đã có** (smart-fill invariant).
   - **Validate trước khi tin** (`IpaValidator`): phải chứa ≥1 ký tự
     IPA-đặc-triệu, không lẫn dấu tiếng Việt, ≤80 ký tự — chặn
     respelling kiểu `he-lō` / câu giải nghĩa từ từ điển rác.
   - **Provenance** `WordEntry.phoneticSource ∈ {mdx, cmu, g2p, user}`
     (additive field, từ cũ = null) — hiện chip màu ở meta sheet:
     MDX xanh dương, CMU xám, G2P vàng, user tím.
   - Sửa IPA trong EditSheet/bulk-edit → `user`; xóa trắng → null
     (lần lưu ngữ cảnh sau resolver điền lại theo mode — đổi sang
     `off` để không điền nữa).
   - Display pipeline (P1) và save pipeline dùng chung eligibility
     ASCII + cùng thứ tự CMU→G2P — hành vi nhất quán.
   - Trích phonetic từ `definition` **lúc lookup** (lazy) thay vì sửa
     `mdx_parser` — tránh xung đột với DICT-001 đang làm import-time.
     (READ-IPA-005-con cho DICT-001: điền cột `phonetic` lúc import.)

3. **Nhịp highlight = cấp dòng** (`activeLineNotifier`) — không hứa
   karaoke từng từ cho tới khi có nguồn word-timestamp mới (quyết
   định capture riêng, tách card).

4. **P3 (READ-IPA-004): tô màu phoneme opt-in** theo bảng derived
   Okabe-Ito trên nền tối (nguyên âm vàng / phụ âm sky-blue / đôi
   nguyên âm tím / stress amber đậm) + legend trong Settings; **mờ IPA
   từ đã thuộc** (`MasteryZone.mastered` → alpha thấp) — cả hai default
   OFF, hai toggle riêng.

5. **Interlinear/ruby cho dòng active (READ-IPA-003):** dòng đang
   phát/được chọn render dạng word-chip (chữ trên, IPA dưới) thay vì
   SelectableText — tradeoff: mất chọn text trên CHÍNG dòng đó khi IPA
   bật (chuyển sang dòng khác là lấy lại); tap chip = nghe phát âm từ.

6. **Giao đoạn P1→P5:** P1 ✅ stacked line · P2 nguồn IPA khi lưu ·
   P3 ruby + nhấn nháy dòng · P4 phoneme color + legend + fading ·
   P5 G2P đa ngôn ngữ VI/Pali — **cần ADR + asset từ điển đóng gói**
   → giữ `proposed`, tách đợt sau (content authoring, không code-only).

## Hệ quả

- Tích cực: offline-first 100%, không friction lúc lưu, provenance
  minh bạch hiển thị được, mọi nguồn IPA đi qua 1 chỗ test được.
- Âm: entry lưu lúc CMU chưa nạp xong có thể nhận provenance `g2p`
  (thấp chất lượng hơn nhưng trung thực) — lần resolver sau không tự
  nâng cấp (đã có giá trị là không đè); user gõ tay rồi xóa → lần lưu
  ngữ cảnh sau điền lại theo mode.
- Không đụng: schema Hive/Firestore (field additive), `lib/ffi/`,
  `UltraTimeStretch`, workflow CI (token không có quyền workflows).
