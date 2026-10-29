# Prompt giao việc — Giọng Edge: chọn nam vẫn phát nữ + danh sách giọng setting tab Đọc quá dài (TTS-EDGE-VOICE-003 + READ-SET-VOICE-COLLAPSE-001)

Copy toàn bộ file này làm **nhiệm vụ phiên** cho agent Arena. 2 mục cùng vùng
giọng Edge/Microsoft.

## 0. Luật phiên (đọc trước khi code)

- Nhánh session Arena cấp; PR nhắm **`251e`** (`arena/01a0251e-in4up`);
  **rebase 251e mới nhất trước** khi mở PR.
- Đọc `AGENTS.md`. Quy tắc vàng: i18n chuỗi mới đủ `en/hi/zh/zh_TW/si`;
  KHÔNG chạy `tool/generate_arbs.py`; build release Android `--flavor stable`.
- Cập nhật card `TTS-EDGE-VOICE-003` + `READ-SET-VOICE-COLLAPSE-001` trong
  `docs/project/KANBAN.md`. Commit nhỏ, push ngay. CI:
  `.github/workflows/app_analyze.yml`.
- **Cross-ref** card `TTS-EDGE-VOICE-002` (đã có fix picker gập + khoá cache
  theo giọng — đọc trước để không làm lại/nhầm).

## 1. Triệu chứng (bản 1.10.4)

- **(12)** Chọn giọng **nam** (Edge/Microsoft, vd Nam Minh) nhưng **vẫn phát
  giọng nữ** (Hoài My).
- **(21)** Setting tab Đọc → chỗ giọng Microsoft liệt kê **quá nhiều ngôn
  ngữ**, chiếm chỗ.

## 2. Những gì đã loại trừ (đừng làm lại)

- `TTS-EDGE-VOICE-002` đã làm: picker gập theo ngôn ngữ (ExpansionTile) +
  khoá cache TTS thêm giọng/tốc độ/cao độ + bậc thang `_resolveEdgeVoice`.
  ⇒ Nếu vẫn phát nữ, lỗi có thể ở **cache cũ chưa dọn** ( khoá cache trước
  khi có fix) hoặc **giọng lưu không được đọc** khi phát.

## 3. Nơi cần đọc

- `lib/features/tts/tts_service.dart` — `_trySpeakOnline`, `_resolveEdgeVoice`,
  cache TTS (khóa theo giọng).
- `lib/features/tts/edge_voice_prefs.dart` — giọng Edge lưu theo ngôn ngữ.
- `lib/features/tts/widgets/tts_settings_section.dart` — `_EdgeVoicePicker`.
- Picker giọng trong **setting tab Đọc** (mục 21).

## 4. Việc phải làm

1. **Trace đường phát:** khi chọn giọng nam → giá trị giọng có được **đọc**
   khi gọi Edge không? (log `voiceId` thực tế gửi). Nếu đọc đúng giọng nam
   mà vẫn nghe nữ ⇒ lỗi **cache** (file MP3 giọng nữ cũ được reuse) ⇒ sửa
   khóa cache đảm bảo phân biệt giọng + **dọn cache** khi đổi giọng/phần
   mềm cập nhật.
2. **Nghiệm thu bằng tai** trên máy thật (cần owner/máy): chọn Nam Minh →
   nghe giọng nam; đổi Hoài My → giọng nữ.
3. **Mục 21:** áp dụng pattern gập của `TTS-EDGE-VOICE-002` (ExpansionTile)
   cho danh sách giọng trong **setting tab Đọc**: chỉ hiện vài ngôn ngữ phổ
   biến + "thêm" sổ ra ngôn ngữ khác.
4. **i18n** + **test** thuần (khóa cache phân biệt giọng; bậc thang chọn
   giọng), nối `app_analyze.yml`.

## 5. Nghiệm thu

1. Chọn giọng **nam** → nghe **giọng nam** (máy thật, owner xác nhận).
2. Đổi giọng nữ → giọng nữ. Không nghe lẫn giọng cũ (cache sạch).
3. Setting tab Đọc: danh sách giọng gọn (phổ biến + sổ ra), không chiếm chỗ.
4. `flutter analyze` 0 error + CI xanh + test mới pass.
