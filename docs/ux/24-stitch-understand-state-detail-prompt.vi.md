# I4U UX — Prompt chi tiết state cho Hiểu, Chat và AI Coach

> Dùng sau Prompt 11. Tạo từng state riêng, không chỉ tạo một màn hình tổng quan Desktop/Mobile.

> Keep Hiểu as a focused comprehension and analysis workspace, not a generic chat screen. Preserve the five-workspace shell, source context, contextual Chat distinction, explicit return paths, progressive disclosure, and Quiet Lexicon visual language.
>
> Create these separate states:
>
> 1. Desktop — Hiểu opened from Đọc with source text and return path.
> 2. Desktop — Hiểu opened from Nghe/Xem with video ID, timestamp, transcript, and return path.
> 3. Desktop — Source Context expanded and collapsed.
> 4. Desktop — AI Coach task selection: Explain, Analyze, Summarize, Ask deeper, Create quiz.
> 5. Desktop — Socratic Coach step active, showing one question, progress, answer field, hints, skip, and previous-step actions.
> 6. Desktop — User submits an answer and receives structured feedback without opening a second free-chat panel.
> 7. Desktop — Structured breakdown showing concept, syntax/argument structure, and academic context.
> 8. Desktop — Save to Nhớ confirmation for a concept and a flashcard.
> 9. Desktop — AI unavailable/loading/context stale state with useful fallback actions.
> 10. Mobile — Collapsed source card and active AI Coach question.
> 11. Mobile — Source card expanded with selected text/transcript context.
> 12. Mobile — Coach answer input with keyboard visible and microphone option.
> 13. Mobile — Hint/reveal/skip flow for a Socratic step.
> 14. Mobile — Feedback and next-step state.
> 15. Mobile — Save concept/flashcard to Nhớ with success and undo.
> 16. Mobile — Return to source in Đọc/Xem, preserving source ID, timestamp, selected text, and position.
>
> For every state describe:
>
> - visible/hidden elements;
> - current source context;
> - primary action;
> - AI Coach vs Global Chat entry point;
> - progress without implying a permanent skill score;
> - loading/error/fallback behavior;
> - keyboard and microphone behavior;
> - return path;
> - mobile safe area and scroll behavior.
>
> Constraints:
>
> - Never show a blank chat screen without source context.
> - Never open Global Chat and AI Coach as two competing chat panels by default.
> - Allow hint, skip, previous step, pause, and end session.
> - Keep one coach question/task primary at a time.
> - The user can save useful concepts to Nhớ without leaving Hiểu.
