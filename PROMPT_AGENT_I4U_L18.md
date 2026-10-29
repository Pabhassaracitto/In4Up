# Prompt giao việc — I4U L18 Problem

> Nguồn: owner 2026-09-30. Bản chuẩn hoá yêu cầu nằm ở
> `docs/project/I4U_L18_PROBLEM_BRIEF.md`. Kanban cards: `I4U18-*` trong
> `docs/project/KANBAN.md`.
>
> Mục tiêu vận hành: chia nhỏ để nhiều agent Arena làm song song, tránh xung đột,
> không tạo lỗi đỏ, commit ít và rõ để dễ rebase/merge/require pull.

---

## 0. Luật chung cho mọi agent

1. **Đọc trước khi code:** `AGENTS.md`, `docs/GOVERNANCE.md`, card `I4U18-*` trong
   `docs/project/KANBAN.md`, và tài liệu/handoff liên quan của lane.
2. **Branch:** nếu chạy trong Arena Agent Mode, làm trên branch session được cấp;
   không tự switch branch. Nếu làm ngoài phiên này, tạo topic branch từ tip mới
   nhất của `arena/01a0251e-in4up` theo quy trình owner.
3. **Không merge mù.** Riêng nội dung Tipiṭaka/PDF/Home có nhánh tham chiếu
   `arena/01a06931-in4up`: fetch để đọc/diff, không checkout hoặc merge toàn bộ.
   Gợi ý:
   ```bash
   git fetch origin arena/01a06931-in4up:refs/remotes/origin/arena/01a06931-in4up
   git diff --name-only HEAD..origin/arena/01a06931-in4up -- lib/features/tipitaka docs/tipitaka_database.md
   git show origin/arena/01a06931-in4up:docs/tipitaka_database.md
   ```
4. **Không để đỏ:** trước khi bàn giao phải có bằng chứng xanh. Nếu sandbox không
   có Flutter, push sớm và dùng CI làm oracle; khi CI đỏ đọc
   `docs/skills/ci-red-debugging/SKILL.md` và bisect đúng quy trình.
5. **Commit ít nhưng đủ ý:** mỗi lane tối đa khoảng 1–3 commit logic + 1 commit
   docs/Kanban nếu cần. Không tạo commit tạm rác, không force-push nhánh chung.
6. **i18n rule #5:** chuỗi UI mới phải có English fallback; thêm đủ `hi`, `zh`,
   `zh_TW`, `si` khi dùng ARB mới. Không chạy `generate_arbs.py`.
7. **Bảo vệ vùng cấm:** không đụng `lib/ffi/`/UltraTimeStretch, không gộp 3 skill
   SM-2, không phá reopen nguồn PDF/Web/Audio/Video.
8. **Bảo mật AI provider:** không hard-code key, không log key/token/header, không
   commit secrets. BYOK/local server là mặc định; OAuth/đăng nhập trực tiếp chỉ
   làm khi owner chốt và SDK/ToS phù hợp.
9. **Kanban:** chỉ đổi trạng thái khi có bằng chứng thật; thêm lịch sử append-only.

---

## 1. Agent A — Home/Chat/Tab Viết/Server API/Provider

**Card:** `I4U18-HOME-AI-001`
**Liên quan:** `API-001`, `API-002`, `API-004`, `AI-CHAT-01`, `AI-CHAT-02`,
`MODELS-002`, `docs/server_api_tu_van.md`, `PROMPT_AGENT_SERVER_API.md`,
`docs/write_tab_blueprint.md`.

### Nhiệm vụ

1. Reproduce/đọc code luồng Home Chat và Tab Viết tầng AI local.
2. Sửa các lỗi:
   - Chat trả lời chậm/kẹt spinner.
   - Fallback sai ngữ cảnh kiểu "The conversation is about a simple task...".
   - Summary/topic/action trong Tab Viết rỗng dù model local đã nạp.
3. Gắn lựa chọn Server & API/LLM vào đúng nơi người dùng cần:
   - Chat/analysis: dùng routing hiện có nếu API-002 đã được harvest.
   - Dịch/tóm tắt/chủ điểm/hành động: dùng route offline-first mặc định, remote
     khi người dùng chọn.
4. Nếu phải thêm UI provider, ưu tiên BYOK/local server OpenAI-compatible; không
   làm OAuth trừ khi owner chốt riêng.

### File/vùng nên sở hữu

- `packages/in4up_ai/**`
- `lib/screens/home/**`
- `lib/features/ai_chat/**` hoặc service/facade AI hiện có
- `lib/screens/write_mode/**`, `lib/features/writing/**` nếu có
- `lib/screens/settings/ai_providers_screen.dart` nếu cần nối UI đã có
- Test thuần liên quan AI route/parser; tránh chạm Tipiṭaka/PDF/Video.

### DoD/Acceptance

- Gửi 2 tin liên tiếp không kẹt processing; nút dừng/hủy hoạt động.
- Local model trả JSON lỗi/markdown fence vẫn parse hoặc báo lỗi rõ, không làm rỗng
  toàn bộ summary/topic/action.
- Bật Server/API thì request đi đúng provider đã chọn; tắt/mất mạng fallback đúng
  chính sách.
- Key không lộ log; locale khác `vi` không còn chrome tiếng Việt.
- CI xanh; cập nhật lịch sử card `I4U18-HOME-AI-001`.

---

## 2. Agent B — Dịch Hy-MT + LLM translation routing

**Card:** `I4U18-TRANSLATE-001`
**Liên quan:** `HYMT-001`, `XLAT-001`, `XLAT-002`, `API-004`,
`PROMPT_AGENT_DICH_OFFLINE.md`.

### Nhiệm vụ

1. Kiểm lại vì sao Hy-MT vẫn "chưa được" dù HYMT-001 đã sửa handshake/model issue.
2. Sửa validator/model path/load native để lỗi thiếu/hỏng file rõ ràng và không trả
   bản dịch rỗng như thành công.
3. Cắm LLM Server/API làm engine dịch nếu API-004 đã có trong base; nếu chưa có,
   chỉ chuẩn bị seam/facade nhỏ và ghi rõ phụ thuộc, không copy code lớn.
4. Giữ nguyên glossary Phật học/Pali và protect-token trước mọi engine.

### File/vùng nên sở hữu

- `lib/features/translation/**`
- `packages/in4up_ai/**` chỉ khi cần seam nhỏ cho LLM MT
- Test translation/Hy-MT parser/validator.

### DoD/Acceptance

- Hy-MT model hợp lệ dịch được một đoạn ngắn; model thiếu/hỏng báo đúng lỗi.
- LLM translation routing không phá offline-first mặc định.
- Protect-token/glossary vẫn được giữ qua mọi engine.
- CI xanh; cập nhật lịch sử card `I4U18-TRANSLATE-001`.

---

## 3. Agent C — Dictionary + Model import offline

**Cards:** `I4U18-DICT-001`, `I4U18-MODEL-IMPORT-001`
**Liên quan:** `DICT-001`, `IMPORT-MODELS-001`, `TTS-PIPER-001`,
`MODELS-001`, `docs/Bangiao/bangiao_dictionary.md`, `docs/project/MODELS.md`.

### Nhiệm vụ

#### C1. Dictionary

1. Hỗ trợ dictionary set gồm `.mdx`, `.mdd`, `.css`/asset kèm theo.
2. Có 2 chế độ rõ: link/index thư mục để dùng ngay và import/copy vào app storage.
3. Nếu thiếu file phụ: báo thiếu file nào, vẫn cho dùng phần còn hoạt động nếu an toàn.

#### C2. Model import

1. Sửa import multi-file có thư mục `espeak` đi kèm nhưng app không tự nhận.
2. Sửa import folder báo thiếu `.onnx`/`.txt` dù file tồn tại.
3. Sửa STT offline chọn đúng file/folder nhưng báo không nhận dạng.
4. Tạo validator/bundle scanner thống nhất: quét đệ quy, nhận diện alias/tên file
   phổ biến, phân loại Piper/eSpeak/STT/Whisper/Sherpa.

### File/vùng nên sở hữu

- `lib/features/dictionary/**`
- `lib/features/tts/**`, `packages/in4up_stt/**`, model manager/import service
- `lib/screens/settings/**` phần quản lý model
- Test thuần cho scanner/validator; tránh chạm PDF/Tipiṭaka/Video.

### DoD/Acceptance

- Chọn folder MDX+MDD+CSS tra được từ và asset/format không lỗi.
- Piper import bằng multi-file và folder đều nhận đủ model/config/tokens/espeak data.
- STT offline import bằng folder nhận đúng loại model; lỗi thiếu file chỉ ra file cần bổ sung.
- Không copy dữ liệu lớn ngoài ý muốn khi user chọn chế độ link.
- CI xanh; cập nhật lịch sử card tương ứng.

---

## 4. Agent D — Video Library + Listen Library

**Cards:** `I4U18-VIDEO-LIB-001`, `I4U18-LISTEN-LIB-001`
**Liên quan:** `VID-001`, `AUDLIB-001`, `LISTEN-*`, `docs/Bangiao/bangiao_video.md`,
`docs/audio_library_plan.md`.

### Nhiệm vụ

#### D1. Video

1. Thêm quét thư mục video bằng SAF, quét đệ quy nếu platform hỗ trợ.
2. Hiển thị thư viện video trực quan: filter/sort/search, recent/favorite.
3. Ghép subtitle cùng tên/thư mục; giữ vị trí phát gần nhất.
4. Không chỉ thêm từng file đơn lẻ như hiện tại.

#### D2. Listen

1. Thêm bộ lọc album, tác giả/nghệ sĩ, yêu thích.
2. Thêm playlist/list thủ công.
3. Thêm smart playlist tối thiểu: recent, favorite, by folder/tag/unplayed nếu dữ liệu có.
4. Không phá transcript/LRC/reopen timestamp.

### File/vùng nên sở hữu

- `lib/features/video/**`
- `lib/features/audio_library/**`, `lib/screens/listen_mode/**`, provider/tab Nghe hiện có
- Service metadata/media scan.

### DoD/Acceptance

- Chọn folder có nhiều video → list cập nhật, không duplicate khi scan lại.
- Phát video có/không phụ đề; reopen đúng vị trí.
- Tab Nghe lọc được album/tác giả/yêu thích và tạo playlist thủ công.
- LRC/transcript vẫn đúng audio sau khi đổi filter/playlist.
- CI xanh; cập nhật lịch sử card tương ứng.

---

## 5. Agent E — Tipiṭaka

**Card:** `I4U18-TIPITAKA-001`
**Liên quan:** `TIPITAKA-001`, `docs/Bangiao/bangiao_tipitaka.md`,
`docs/tipitaka_database.md`, `docs/tipitaka_worklist_learning_plan.md`,
`lib/features/tipitaka/**`, `test/tipitaka_*`.

### Bắt buộc đọc nhánh 06931 trước khi làm

```bash
git fetch origin arena/01a06931-in4up:refs/remotes/origin/arena/01a06931-in4up
git diff --name-only HEAD..origin/arena/01a06931-in4up -- lib/features/tipitaka docs/tipitaka_database.md docs/tipitaka_worklist_learning_plan.md test/tipitaka_*.dart
git show origin/arena/01a06931-in4up:docs/tipitaka_database.md
```

Không checkout/merge toàn bộ nhánh 06931. Nếu cần lấy code, path-checkout chọn lọc
hoặc port tay từng file sau khi hiểu diff.

### Nhiệm vụ

1. Import pack ngôn ngữ độc lập: không chặn Tiếng Việt chỉ vì chưa có Pali.
2. Khi thiếu Pali, hiển thị gợi ý rõ: nên import Pali trước để đối chiếu tốt hơn;
   các tính năng song ngữ/căn hàng thì disable/giảm cấp có giải thích.
3. Thay tiêu đề mã bằng tiêu đề nội dung thật; chỉ hiện mã kỹ thuật ở chi tiết/debug.
4. Cây thư viện: `Tam Tạng Chính Văn → Tạng (Kinh/Luật/Luận) → nhóm/bộ → bài kinh`.
5. Nút mục lục chi tiết trong từng bài.
6. Multi-tab kiểu Obsidian; split view xem 2 tab cùng lúc.
7. TTS theo đoạn/bài, giữ vị trí đọc.

### DoD/Acceptance

- Import pack Việt không có Pali vẫn đọc được.
- Cây thư viện không lộ mã như `ABH01A_ATT` ở title chính.
- Mở 2 bài, split view, cuộn/đổi tab không mất vị trí.
- TTS phát/dừng từng đoạn; không phá Learn by Heart/link nguồn nếu đang có.
- CI xanh; cập nhật lịch sử card `I4U18-TIPITAKA-001`.

---

## 6. Agent F — Read IPA + PDF/OCR/TTS

**Cards:** `I4U18-READ-IPA-001`, `I4U18-PDF-OCR-TTS-001`
**Liên quan:** `READ-IPA-001…006`, `SRC-630-01`, `PDF-W0`, `PDF-W1`, `OCR-001`,
`docs/pdf_reader_readera_upgrade.md`, ADR-0003/0004/0009.

### Nhiệm vụ

#### F1. Read IPA/Word line mode

1. Sửa chế độ dòng khi mở file Word/DOCX.
2. Thêm bottom snackbar/sheet hướng dẫn chạm dòng/từ để hiện IPA/tra từ.
3. Cho mở lại hướng dẫn qua Help/tooltip; i18n đầy đủ.

#### F2. PDF/OCR spinner

1. Phân biệt PDF có text layer với PDF scan; không bật OCR vô hạn khi không cần.
2. OCR có timeout/cancel token/error state rõ.
3. Không phá reopen identity/geometry theo ADR-0003/0004.

#### F3. PDF TTS controls

1. Sửa state machine Play/Pause/Stop/Next line.
2. Pause phải dừng âm đang phát; Stop phải chặn callback phát tiếp.
3. Next line chỉ phát đúng dòng kế tiếp, không lướt nhanh nhiều dòng.
4. Guard double-tap/reentrant callbacks.

### Lưu ý

`flutter clean` chỉ là bước loại trừ build cache; đừng coi đó là fix chính. Nếu
clean làm hết lỗi tạm thời, vẫn phải tìm state/cache/controller nào gây lệch.

### DoD/Acceptance

- DOCX mở được line mode, chạm hiện IPA/word sheet.
- Mở PDF text-layer không spinner OCR vô hạn; PDF scan có cancel/timeout.
- Play→Pause dừng âm; Next line không auto-skip hàng loạt; Stop không phát lại.
- Test state machine hoặc widget test cho các trạng thái chính nếu có thể.
- CI xanh; cập nhật lịch sử card tương ứng.

---

## 7. Agent G — Hướng dẫn sử dụng và QA liên lane

**Card:** `I4U18-DOCS-001`
**Liên quan:** README, `docs/`, Settings/Help nếu có UI.

### Nhiệm vụ

1. Viết hướng dẫn sử dụng ngắn, dễ làm theo cho:
   - Import model Piper/eSpeak/STT offline.
   - Cấu hình Server/API/BYOK/local server.
   - Import/link từ điển MDX/MDD/CSS.
   - Import Tipiṭaka pack và Pali.
   - Video/Listen library scan, filter, playlist.
   - PDF/OCR/TTS và IPA.
2. Nếu thêm entry Help trong app, phải i18n đúng rule #5.
3. Tạo checklist QA thủ công cho owner nghiệm thu trên thiết bị.

### DoD/Acceptance

- Người dùng đọc guide có thể tự thực hiện các luồng chính và biết cách xử lý lỗi
  thường gặp.
- Không commit ảnh/video/model lớn vào repo.
- Docs link không chết; `git diff --check` sạch; nếu có UI thì CI xanh.
- Cập nhật lịch sử card `I4U18-DOCS-001`.

---

## 8. Prompt ngắn để copy cho từng agent

Dùng đoạn sau và thay `AGENT X` bằng lane cụ thể ở trên:

```text
Bạn là agent Arena làm lane I4U L18 — AGENT X.
Đọc trước: AGENTS.md, docs/GOVERNANCE.md, docs/project/I4U_L18_PROBLEM_BRIEF.md,
PROMPT_AGENT_I4U_L18.md, và card I4U18-* tương ứng trong docs/project/KANBAN.md.
Làm đúng branch session Arena cấp, không switch branch. Không merge mù nhánh khác;
nếu lane Tipiṭaka/PDF/Home cần tham chiếu 06931 thì fetch/read bằng git show/diff.
Giữ phạm vi file theo lane, commit 1–3 commit logic + checkpoint Kanban nếu cần.
Không để CI đỏ, không hard-code secret, i18n rule #5. Khi xong: ghi bằng chứng test/CI,
append lịch sử Kanban và tóm tắt rủi ro còn lại.
```
