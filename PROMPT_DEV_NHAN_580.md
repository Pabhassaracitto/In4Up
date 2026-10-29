# Prompt cho agent DEV (251e) — nhận phần còn lại từ 580

Bạn đang trên **leader DEV** `arena/01a0251e-in4up` (hoặc worktree leader).  
**Không** `git merge arena/01a01580-in4up`. 580 là khay vá; merge sẽ lệch lineage.

## Sự thật (đã đối chiếu blob 2026-08-24)

Code tính năng 580 **đã nằm trên 251e** (thường còn hơn 580):

| Việc | 251e |
|---|---|
| STT tải khi bấm (`928525a`) | Có — `stt_model_manager` / facade cùng blob |
| Chấm viết 2 tầng + reload GGUF | Có — `write_studio`, `ai_analysis`, mock |
| Mở lại MP3 dùng LRC đã lưu | Có — `source_artifact_store`, `peekCachedLrc`, hộp thoại Tạo lời |
| Cache dịch MD5 + rehydrate | Có — 251e còn thêm migrate key hashCode cũ |
| Recent file/audio id ổn định | Cùng blob |

**Đừng** checkout từ 580: `ai_engine_gemma.dart`, `ai_service_facade.dart`, cả `packages/in4up_stt/lib/`, `listen_mode_screen.dart`, `text_provider.dart`. 251e đã tích hợp llama/Sherpa/listen — đè là mất.

## Việc còn lại (chỉ tài liệu)

Hai file 580 có, DEV chưa có (hoặc sổ tay DEV thiếu mục 8–9):

1. `PROMPT_AGENT_DICH_OFFLINE.md` — prompt giao việc dịch offline + glossary Pali (251e **MISSING**).
2. `SO_TAY_CHU.md` — 580 có mục 8 (A. Repo), mục 9 (thứ tự vào DEV, tên APK `app-stable-<abi>`). Nhật ký 251e chỉ còn bản lập sổ tay cũ.

Git Bash, đứng trên worktree **leader 251e**:

```bash
git fetch origin arena/01a01580-in4up:refs/remotes/origin/arena/01a01580-in4up

git checkout origin/arena/01a01580-in4up -- \
  PROMPT_AGENT_DICH_OFFLINE.md \
  SO_TAY_CHU.md

git status
git diff --stat
# Sổ tay: nếu 251e đã tự append nhật ký mới hơn 2026-08-22 thì ĐỪNG checkout SO_TAY;
# chỉ lấy PROMPT. (Lúc viết prompt này, nhật ký 251e chưa có dòng mới hơn.)

git commit -m "docs: so tay muc 8-9 + prompt giao viec dich offline (tu 580)"
git push origin arena/01a0251e-in4up
```

PowerShell: một dòng, không dùng `\`.

Xong báo chủ: SHA commit + `git show HEAD:PROMPT_AGENT_DICH_OFFLINE.md` còn đó.
