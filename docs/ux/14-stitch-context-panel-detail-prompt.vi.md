# I4U UX — Prompt bổ sung để Stitch mô tả từng state

> Dùng khi Stitch chỉ trả về phần tổng quan Desktop/Mobile mà chưa mô tả từng trạng thái tương tác.

> Do not provide only a high-level overview. Create and describe each state separately, with one clearly named screen for every state. Keep the I4U Quiet Lexicon style and preserve the Reader content behind or beside the tool surface.
>
> Create these separate states:
>
> 1. Desktop — Context Panel closed/minimal, showing only the entry affordance.
> 2. Desktop — Dictionary tab open for the selected word “tri giác”.
> 3. Desktop — Notes tab open with an existing note and an input state.
> 4. Desktop — Nhớ/SRS tab open showing save-to-memory confirmation and next review information.
> 5. Desktop — Context Panel pinned while the user continues reading.
> 6. Desktop — Context Panel closed with the Reader position preserved.
> 7. Mobile — Bottom Sheet peek state, showing only the selected word and primary actions.
> 8. Mobile — Bottom Sheet expanded Dictionary state at approximately 60–65% height.
> 9. Mobile — Notes state with the software keyboard open; keep the input visible above the keyboard.
> 10. Mobile — Nhớ/SRS save state with success feedback and a clear return-to-reading action.
> 11. Mobile — Bottom Sheet dismissed, returning to the same Reader position and selected context.
>
> For every state, explicitly describe:
>
> - what is visible;
> - what is hidden;
> - the primary action;
> - the close/back gesture;
> - whether the Reader scroll position changes;
> - how the selected word/context is preserved;
> - how the layout differs between desktop and mobile;
> - what happens when content is too long.
>
> Do not show all three tool tabs as full content at the same time. The active tab is primary; inactive tabs should be represented only by labels, badges, or compact previews. Do not turn the Context Panel into a second Chat interface.
