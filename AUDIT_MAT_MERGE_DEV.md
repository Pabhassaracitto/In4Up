# Rà soát mất chức năng do merge vào DEV (251e)

Đối chiếu **tip DEV** `a01d140` (2026-08-24) với các bản còn đủ (580 `d8486d3`/`e4b51ff`, 296a wave 1, 02601 llama).  
**Không** merge cả 580 vào 251e.

---

## Kết luận ngắn

Phần lớn thứ từng “mất sau merge” **đã nằm lại trên DEV**.  
Còn thiếu chủ yếu là **sổ tay / prompt**, **KANBAN cũ chưa đổi trạng thái**, và vài lỗi **chưa từng sửa** (không phải do merge).

Cầm máy theo checklist mục 3 — đừng merge thêm nhánh cho đến khi tick xong.

---

## 1. Bảng rà (code trên `origin/arena/01a0251e-in4up`)

| Chức năng | Trạng thái trên DEV | Ghi chú |
|---|---|---|
| Viết 2 tầng + `_buildAiReviewCard` / Rewrite / Summary | **Còn** | `inputText` + `_hasMatchingAiAnalysis` + `forceReload`. Card KANBAN **FIX-630-03** vẫn `doing` — **lỗi giấy**, không phải mất code |
| STT tải khi bấm (không auto HTTP lúc mở) | **Còn** | Nút Tải về + `ensureModel` không auto |
| Sherpa / engine / registry | **Còn** | Đủ `stt_engine_sherpa.dart` + enum `sherpa` |
| Piper TTS | **Còn** | `piper_tts_engine.dart` |
| Mở lại MP3 → LRC đã lưu + hỏi Tạo lời | **Còn** | `peekCachedLrc`, `confirmAndGenerateLrc` |
| Cache dịch MD5 + rehydrate document | **Còn** | 251e còn migrate key `hashCode` cũ |
| I2U Chat màn hình | **Còn** | `ai_chat_screen.dart` + Home card |
| llama.cpp CMake Android | **Còn** | `android/app/src/main/cpp/ai/CMakeLists.txt` |
| LANG wave 1 HI/ZH/SI (376 key, `commonConfirm` đã dịch) | **Còn** | `language_roadmap.dart`, `generate_arbs.py` đã vô hiệu, rule #5 EN |
| Learn-by-heart | **Còn** | merge `15deaf0` |
| Sổ tay mục 8–9 (A. Repo, tên APK, thứ tự nhận hàng) | **Thiếu** | `SO_TAY_CHU.md` DEV còn bản lập sổ cũ |
| `PROMPT_AGENT_DICH_OFFLINE.md` | **Thiếu** | chưa lên 251e |
| Glossary Phật học / ML Kit offline | **Chưa làm** | không phải mất merge |
| LRC tiếng Việt bị ép `'en'` | **Chưa sửa** | hardcode trong `player_stt_mixin.dart` — **không** phải mất merge |
| Windows zip 9.6 KB + tên `in4up-Windows-1.5` | **Lỗi workflow** | zip nhầm thư mục `Release` đầu tiên |

---

## 2. Việc DEV cần làm (path-checkout, không merge)

Git Bash, worktree **leader 251e**:

```bash
git fetch origin arena/01a01580-in4up:refs/remotes/origin/arena/01a01580-in4up

git checkout origin/arena/01a01580-in4up -- \
  SO_TAY_CHU.md \
  PROMPT_AGENT_DICH_OFFLINE.md \
  AUDIT_MAT_MERGE_DEV.md

# Nếu 251e đã tự ghi nhật ký sổ tay sau 2026-08-24 thì BỎ SO_TAY_CHU.md,
# chỉ lấy 2 file prompt/audit.

git status
git commit -m "docs: so tay 8-9 + prompt dich + audit mat merge"
git push origin arena/01a0251e-in4up
```

KANBAN: sửa tay card **FIX-630-03** → `done`, append 1 dòng lịch sử (không checkout cả `KANBAN.md`).

**Cấm** checkout từ 580: `gemma`, `facade`, cả `in4up_stt/lib/`, `listen_mode_screen.dart`, `text_provider.dart`.

---

## 3. Checklist cầm máy (nghiệm thu “còn chứ không mất”)

- [ ] Tab Viết: Chấm nhanh + Tầng 2 hiện kết quả (có hoặc không `.gguf`)
- [ ] Settings STT: bấm Tải về được; mở app không tự HTTP
- [ ] Mở lại MP3 đã tạo lời → lời hiện, không chạy Whisper
- [ ] Locale HI/ZH/SI: nút Confirm không còn English (trừ key keep-English)
- [ ] Home → I2U Chat mở được
- [ ] Không merge nhánh mới cho đến khi 5 mục trên xanh trên **máy**

---

## 4. Trả lời: pull nhánh con trước rồi mới merge DEV?

**Có — đó là cách đúng.** Không phải merge nhánh cũ thẳng vào DEV.

```
DEV 251e (sống)          topic (cắt từ tip cũ)
     │                         │
     │     fetch + merge/rebase DEV → topic
     │     giải conflict TRÊN TOPIC
     │     giữ file sống của DEV (bảng dưới)
     │                         │
     │◄──── chỉ nhận khi FF hoặc diff --name-only sạch
```

### Trên nhánh con (Git Bash)

```bash
git fetch origin arena/01a0251e-in4up:refs/remotes/origin/arena/01a0251e-in4up
git merge origin/arena/01a0251e-in4up
# hoặc: git rebase origin/arena/01a0251e-in4up
# Xong: git diff --name-only origin/arena/01a0251e-in4up
# Chỉ được còn file của ĐÚNG tính năng topic.
git push origin HEAD
```

Rồi trên DEV: `git merge --ff-only origin/arena/TOPIC`  
Không FF được → **đừng** merge; path-checkout list file.

### Pull trước **không** cứu nếu lúc conflict chọn nhầm

File **không được lấy từ topic cũ** (giữ bản DEV):

- `packages/in4up_ai/lib/src/engine/ai_engine_gemma.dart`
- `packages/in4up_ai/lib/src/facade/ai_service_facade.dart`
- `packages/in4up_stt/lib/` (cả thư mục)
- `lib/screens/read_mode/write_studio_screen.dart`
- `lib/screens/listen_mode/listen_mode_screen.dart`
- `lib/providers/text_provider.dart`
- `SO_TAY_CHU.md` (trừ khi topic chỉ append nhật ký)

`KANBAN.md`: giữ **cả hai** dòng lịch sử; ô Trạng thái = dòng mới hơn theo giờ.

---

Hết. Agent DEV: làm mục 2 rồi dừng. Không “khôi phục” write/STT/LRC-cache — chúng đã có trên tip.
