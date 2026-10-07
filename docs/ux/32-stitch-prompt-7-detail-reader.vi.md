# Prompt 7 Detail — Đọc Minimal Reader

> Gửi prompt này vào Google Stitch sau khi đã tạo Đọc Minimal Reader Prompt 7. Tạo từng state riêng, không chỉ tổng quan Desktop/Mobile.

> Keep the I4U Reader in a true minimal reading state: content is sovereign, tool panel is closed by default, progress is subtle, and contextual tools appear only when requested. Preserve Đọc/Viết, sources Tài liệu/Web/PDF/Tam tạng, the five-workspace shell, and Quiet Lexicon.
>
> Create these states separately:
>
> 1. Mobile — Empty Reader/source picker with Tài liệu, Web, PDF, Tam tạng.
> 2. Desktop — Empty Reader/source picker with clear import/open actions.
> 3. Mobile — Source loading state with skeleton that does not jump layout.
> 4. Desktop — Source loading state with progress and cancel/retry.
> 5. Mobile — Loaded minimal Reader with text, subtle progress, vocabulary anchors, and no panel.
> 6. Desktop — Loaded minimal Reader with max-width text column and closed contextual panel.
> 7. Source error/unavailable state with retry, choose another source, and preserved prior source.
> 8. aA typography sheet open: font, size, line height, margins, serif/sans options, and reset.
> 9. Selected text with contextual action bar; show overflow behavior on narrow screens.
> 10. Selected word with Dictionary/Translate/Pronunciation/Add to Nhớ actions.
> 11. Bookmark/save success and failure/undo feedback.
> 12. Audio entry from selected text and transition to Mini Player without losing selection.
> 13. Mobile keyboard open while a contextual note/tool sheet is active.
> 14. Mobile Context Sheet peek/expanded/dismissed with Reader position preserved.
> 15. Desktop Context Panel open/closed with scroll and selection restoration.
> 16. Reader return state after closing a tool, preserving source, page, anchor, and scroll position.
>
> For every state describe visible/hidden elements, primary action, source status, selection/scroll preservation, keyboard/safe-area behavior, close/back action, and overflow handling.
>
> Constraints:
>
> - Do not make Reader a dashboard.
> - Do not show statistics, badges, quote cards, or AI summaries by default.
> - On mobile show three priority actions plus More when five actions do not fit.
> - A 340px text width is not a hard-coded requirement; use available width, responsive padding, and max-width.
> - `aA` settings must not reset reading position.
> - Tool panel opens to serve Reader and must not replace Reader context silently.
