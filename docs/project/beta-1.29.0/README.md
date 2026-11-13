# BETA 1.29.0 — phiếu việc cho agent con

> **Đọc file này trước, 5 phút.** Sau đó chỉ mở đúng phiếu lane của bạn.
> Không cần ai copy-paste nhiệm vụ cho bạn: Linear + repo là đủ.

## 1. Bạn đang làm ở đâu

| Thứ | Giá trị |
|---|---|
| Nhánh cha (beta hub) | `arena/60e35d65-in4up` |
| Nhánh cuối cùng sẽ nhận | `arena/01a0251e-in4up` (**251e**) — chỉ sau khi beta đạt |
| Bản phát hành đang gom | **1.29.0** (`pubspec` giữ `1.28.0+28` cho tới cổng G4 — **hub bump**, bạn không bump) |
| Linear | team `PSRC`, project **I4U**, mọi issue 1.29 dùng được lọc `project = I4U` + state `Backlog` |

Bạn **không** làm việc trên 251e. Bạn tạo nhánh riêng từ **tip của nhánh cha**:

```bash
git fetch origin arena/60e35d65-in4up
git switch -c arena/<session-id>-in4up origin/arena/60e35d65-in4up
```

## 2. Lịch sử commit — luật cứng (để rebase tuyến tính vào 251e)

1. **Một commit cho một issue Linear.** Không gộp 3 issue vào 1 commit; không tách 1 issue thành 6 commit "wip".
2. **Không merge commit.** Cấm `git merge`, cấm `git pull` (pull = merge). Chỉ `git rebase`.
3. Trước khi push lần cuối: `git rebase origin/arena/60e35d65-in4up` (nhánh cha có thể đã tiến).
4. Tối đa **1 commit phụ** cho tài liệu của chính lane bạn (nếu cần mô tả quyết định kỹ thuật).
5. Định dạng tiêu đề commit — chính xác dòng đầu, phần sau tuỳ:

```
fix(PSRC-214): nhận model ở mọi mục import [L7]
```

Nếu là tính năng mới thay vì sửa lỗi: `feat(PSRC-232): karaoke + tự cuộn trong web/PDF reader [L10]`.

6. Không `push --force` lên nhánh cha. Chỉ force lên nhánh của bạn (`--force-with-lease`).

Vì sao khắt khe: hub sẽ `git merge --ff-only` từng nhánh sau khi bạn rebase ⇒ lịch sử beta là **một đường thẳng**, cuối cùng `git rebase` nguyên khối lên 251e không sinh xung đột giả.

## 3. File nào được sửa

| Loại | Ai sửa | Ghi chú |
|---|---|---|
| File trong phiếu lane của bạn (§ "File chạm") | **bạn** | thoải mái trong phạm vi đó |
| `docs/project/KANBAN.md`, `docs/project/BETA-1.29.0.md` | **chỉ hub** | 11 agent cùng sửa = 11 xung đột; hub ghi sau khi land |
| `pubspec.yaml` / version / tag | **chỉ hub** (cổng G4) | không bump |
| `tool/priority_native_pack.json` + `generated_priority_native_pack.dart` | **bạn** (nếu có chuỗi UI mới) | chỉ **thêm ở cuối**, không sửa khoá cũ; sau đó chạy `python3 tool/generate_priority_native_pack.py` |
| Ngoài phạm vi lane | **hỏi hub trước** | mở issue/ghi chú, đừng tự mở rộng |

Chuỗi UI mới **bắt buộc** đủ 8 locale (`en, hi, zh, zh_TW, si, my, th, ja`) — quy tắc vàng #5, CI sẽ đỏ nếu thiếu.

## 4. Định nghĩa "xong" (DoD) — mọi lane như nhau

Một issue chỉ được coi là xong khi **cả 6** điều sau đúng:

1. Tái hiện được lỗi **trước** khi sửa (hoặc nói rõ vì sao không tái hiện được — môi trường, thiết bị).
2. Sửa **nguyên nhân gốc**, không chỉ thêm try/catch hay đổi câu thông báo. Nếu chỉ đổi câu chữ ⇒ ghi rõ và giải thích.
3. Có **máy bắt** (test tự động) khoá lại hành vi — đặt ở `test/<khu vực>/` và thêm vào một step có sẵn trong `.github/workflows/app_analyze.yml` (step của hub: xem `## 6`).
4. `flutter analyze` **0 error** (warning chấp nhận được, nhưng đừng thêm warning mới).
5. CI xanh trên nhánh của bạn: `app_analyze` (+ `listen_queue_tests` nếu chạm Listen/Queue, + `vieneu_engine_build` nếu chạm `native/` hoặc `android/`).
6. Ghi trong commit body: **triệu chứng → nguyên nhân gốc → cách sửa → bằng chứng** (số run CI). Máy thật chưa kiểm được thì ghi rõ "chưa kiểm máy thật: …".

## 5. Khi bị chặn

- Thiếu file/quyền/dữ liệu để tái hiện: **vẫn phải** sửa phần chứng minh được, ghi rõ phần chưa kiểm, đừng đoán bừa.
- Phát hiện issue nằm ngoài phạm vi lane: ghi vào cuối phiếu lane (§ "Phát hiện thêm") **và** báo hub; đừng tự sửa file của lane khác.
- Nếu sửa của bạn đụng file chung với lane khác (xem § 3), ghi rõ trong commit body để hub biết thứ tự land.

## 6. CI: chạy cái gì, ở đâu

| Workflow | Khi nào chạy | Dùng để |
|---|---|---|
| `app_analyze.yml` | mọi push (`arena/**`) | analyze + toàn bộ test + Rule 5 (i18n) |
| `listen_queue_tests.yml` | push đụng Listen/Queue/TTS | 5 job test phát lại |
| `vieneu_engine_build.yml` | push đụng `native/**`, `third_party/**`, `android/**` | build APK arm64 + kiểm 3 `.so` |
| `deploy-web.yml` | push đụng `lib/**`, `web/**` | build web (beta **không** publish) |

Hub đã có công cụ đọc lỗi CI: log/artifact Actions bị chặn từ sandbox, nên nếu bạn cần xem lỗi build, dùng annotation:
`scripts/ci/emit_failure_annotation.py` (xem đầu file để biết cách dùng).

## 7. Bản đồ lane (1.29.0)

Đợt này gom **35 issue audit 1.28.0** (PSRC-199…233). Backlog cũ (≤ PSRC-196) **không** thuộc cổng beta — xem `L11`.

| Lane | Tên | Issue | Phiếu |
|---|---|---|---|
| L1 | Live cabin | 199, 200, 201, 223 | `L1-cabin.md` |
| L2 | Âm thanh & video | 202, 203, 205, 219, 220 | `L2-audio-video.md` |
| L3 | Tab Đọc: thư viện, `.docx`, OCR, giọng song ngữ, highlight | 206, 207, 208, 209, 210, 230, 233 | `L3-tab-doc.md` |
| L4 | Bong bóng dịch | 211 | `L4-bong-bong-dich.md` |
| L5 | Web & YouTube trên Linux | 212, 213 | `L5-linux.md` |
| L6 | VieNeu / Vieu-TTS | 214, 215, 216, 217, 218 | `L6-vieneu-engine.md` |
| L7 | Tệp: nơi lưu + "Mở bằng" | 204, 222 | `L7-tep-va-noi-luu.md` |
| L8 | Android: giọng đọc hệ thống | 221 | `L8-android-system-tts.md` |
| L9 | Shadowing: tab Nói & Hiểu | 224, 225, 226, 227, 228 | `L9-shadowing.md` |
| **L10** | PDF/Web reader: karaoke, tự cuộn, tốc độ **(mới, tách từ L3)** | 229, 231, 232 | `L10-pdf-web-reader.md` |
| **L11** | Backlog cũ + chốt In Review **(ngoài cổng 1.29.0)** | ~27 issue ≤ 196, PSRC-6, PSRC-14 | `L11-backlog-cu.md` |

Số hiệu L1–L9 giữ nguyên như `../BETA-1.29.0.md` § 2 (chủ dự án đã dùng). L10 và L11 là hai lane mới: L10 vì L3 quá tải, L11 để backlog cũ có chủ.

Tổng issue trong cổng beta: **35** (PSRC-199…233) = 4+5+7+1+2+5+2+1+5+3. Mỗi issue thuộc **đúng một** lane.
Đợt 2 (cùng khu vực, sau beta): 172, 174, 178, 179, 180, 193, 194, 195, 196 — đã gán lane ở từng phiếu, **không** thuộc cổng.

Thứ tự land đề xuất (hub): L7 (đang làm) → L1 → L8 → L9 → L2 → L3 → L10 → L4 → L5 → L6 → L11.

## 8. Tin nhắn mẫu để chủ dự án gửi cho agent

Xem `PROMPTS.md` — mỗi lane một câu, không cần dán thêm nội dung gì.
