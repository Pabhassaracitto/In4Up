# MILESTONES — Ma trận lộ trình VipSound / INUP

> Ma trận phân bổ theo **Tab | Chức năng | Ưu tiên | Version | Trạng thái**.
> Trạng thái: 🟢 Stable · 🟡 Wiring/Partial · 🔴 Not started · ⚪ Backlog.
> Nguồn: `lib/screens/main_shell.dart` (4 tab: `Chế độ Đọc`📖 / `Chế độ Nghe`🎧 / `Chế độ Hiểu`💡 / `Vườn Trí Nhớ`🧠) + `packages/` + `native/`.

---

## v11.0 (Current) — Ổn định lõi STT Isolate & Local Storage

| Tab | Chức năng | Ưu tiên | Version | Trạng thái |
|-----|-----------|---------|---------|------------|
| 📖 Đọc | Reader CEFR (A1–C2) + POS highlight | High | v11.0 | 🟢 Stable |
| 📖 Đọc | Multi-engine translate (Google/DeepLX/Libre/Zalo AI) | High | v11.0 | 🟢 Stable |
| 📖 Đọc | Web Reader + PDF Reader (native render + annotation) | Med | v11.0 | 🟢 Stable |
| 🎧 Nghe | UltraTimeStretch 0.05x–10x (C++ FFI, SIMD) | High | v11.0 | 🟢 Stable |
| 🎧 Nghe | Waveform cuộn + fixed playhead, A-B loop, gap | High | v11.0 | 🟢 Stable |
| 💡 Hiểu | Đồng bộ audio–text (LRC/SRT) | High | v11.0 | 🟢 Stable |
| 💡 Hiểu | Shadowing mode + chấm phát âm | Med | v11.0 | 🟡 Wiring |
| 💡 Hiểu | STT Isolate (Whisper `_with_params` + WAV loader) | High | v11.0 | 🟢 Sealed (cần on-device test) |
| 💡 Hiểu | Diarization heuristic (Sprint 1) | Med | v11.0 | 🟢 Stable |
| 🧠 Nhớ | Vocab SRS SM-2 + growth stages | High | v11.0 | 🟢 Stable |
| 🧠 Nhớ | Cross-device sync (Firestore, offline-first Hive) | Med | v11.0 | 🟢 Stable |
| Tools | YouTube / YouGlish / Word Map / Triangle / Venn / Stats | Med | v11.0 | 🟢 Stable |
| Core | Content-Anchored UID (`ContentId`) | High | v11.0 | 🟢 Sealed |

---

## v11.1 — Quốc tế hóa (i18n)

| Tab | Chức năng | Ưu tiên | Version | Trạng thái |
|-----|-----------|---------|---------|------------|
| All | Trích xuất chuỗi hard-code → `.arb` | High | v11.1 | 🔴 Not started |
| All | Setup `l10n.yaml` + `generate: true` + `AppLocalizations` | High | v11.1 | 🔴 Not started (chỉ có dep `intl: 0.20.2` + `flutter_localizations`) |
| All | English (en) | High | v11.1 | 🔴 Not started |
| All | 中文 (zh) | Med | v11.1 | 🔴 Not started |
| All | Sinhala / Tamil (Sri Lanka — `si`/`ta`) | Med | v11.1 | 🔴 Not started |
| All | Hindi / Indian languages (`hi`/…) | Med | v11.1 | 🔴 Not started |

---

## v11.2 — "Địa hình tri thức" (Memory Garden)

| Tab | Chức năng | Ưu tiên | Version | Trạng thái |
|-----|-----------|---------|---------|------------|
| 🧠 Nhớ | Trạng thái `UNBORN` (chưa nảy mầm) cho vocab mới | High | v11.2 | ⚪ Backlog |
| 🧠 Nhớ | Easing `smoothstep()` cho transition giữa growth stage | High | v11.2 | ⚪ Backlog |
| 🧠 Nhớ | Hiệu ứng "địa hình" trực quan (3D/layered) | Med | v11.2 | ⚪ Backlog |

---

## v12.0 — Local AI Chat (Gemma/Llama)

| Tab | Chức năng | Ưu tiên | Version | Trạng thái |
|-----|-----------|---------|---------|------------|
| (new) AI | `AiEngineGemma` isolate + system prompt | High | v12.0 | 🟡 Foundation có sẵn (`packages/vipsound_ai/src/engine/ai_engine_gemma.dart`) |
| (new) AI | `AiModelLoader` + `AiServiceFacade` | High | v12.0 | 🟡 Foundation có sẵn |
| (new) AI | Chat UI + tích hợp context vocab/CEFR | Med | v12.0 | ⚪ Backlog |
| (new) AI | Llama backend (thay thế/bên cạnh Gemma) | Low | v12.0 | ⚪ Backlog |

---

## Chú thích trạng thái
- 🟢 **Stable/Sealed**: đã ship, không dự định đảo lộn.
- 🟡 **Wiring/Partial**: code có nhưng chưa hoàn thiện/cần test (vd: word-timestamp parse, AiEngineGemma foundation).
- 🔴 **Not started**: có thể có dep nhưng chưa implement.
- ⚪ **Backlog**: chưa chạm vào.

> Khi hoàn thành 1 hàng, đánh dấu 🟢 và cập nhật [`KANBAN.md`](./KANBAN.md) tương ứng. Không xóa các mục đã Seal — chúng là tham chiếu kiến trúc.