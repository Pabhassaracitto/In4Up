# Prompt 11 Detail — 16 states: Hiểu, Global Chat & Socratic AI Coach

> Gửi toàn bộ nội dung prompt này vào Google Stitch sau khi đã chạy Prompt 11 architecture. Mỗi state phải được tạo/mô tả riêng, không chỉ tổng quan Desktop/Mobile.

## Shared context

> Keep I4U Hiểu as a source-anchored comprehension and analysis workspace, not a blank chat screen. Preserve the five-workspace shell: Home, Đọc, Nghe, Hiểu, Nhớ. Global Chat is a global open-ended capability; AI Coach is a structured Socratic learning flow inside Hiểu. Never show two competing chat panels. Preserve source ID, timestamp/page, selected text, scroll position, and return path.

## Required states

Create and clearly name these 16 states:

1. Desktop — Hiểu opened from Đọc with source text.
2. Desktop — Hiểu opened from Nghe/Xem with video, timestamp, transcript, and return path.
3. Desktop — Source Context collapsed and expanded.
4. Desktop — AI Coach task selection with five tasks.
5. Desktop — Socratic Coach active with one question, progress, input, hint, skip, previous, pause.
6. Desktop — Answer submitted and structured pedagogical feedback.
7. Desktop — Structured breakdown: concept, syntax/argument, academic context.
8. Desktop — Save concept/flashcard to Nhớ confirmation without leaving Hiểu.
9. Desktop — AI loading, unavailable, context stale, and offline fallback.
10. Mobile — Collapsed source card and active Coach question.
11. Mobile — Expanded source card/sheet with source context.
12. Mobile — Answer input with keyboard and microphone option.
13. Mobile — Hint/reveal/skip flow.
14. Mobile — Feedback and next step.
15. Mobile — Save to Nhớ success with Undo.
16. Mobile — Return to Đọc/Xem preserving source fingerprint.

For every state explicitly show: visible/hidden elements, one primary action, source context, Coach vs Global Chat entry point, progress without permanent skill scoring, loading/error behavior, keyboard/microphone behavior, safe area, pause/exit, and return path.

Constraints: one Coach question at a time; allow Hint, Skip, Previous, Pause, End; no blank chat; no competing chat panels; save to Nhớ in place; use `Mở trong Hiểu` rather than overly academic labels such as `Khảo đàm` when a shorter label is clearer.
