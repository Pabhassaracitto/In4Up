# Prompt 1–5 Detail — Global Shell

> Gửi prompt này vào Google Stitch sau khi đã tạo các thiết kế Global Shell Prompt 1–5. Không chỉ mô tả tổng quan; hãy tạo và đặt tên từng state riêng.

> Keep the I4U Global Shell with five primary workspaces: Home, Đọc, Nghe, Hiểu, Nhớ. Preserve Quiet Lexicon, progressive disclosure, contextual Chat, separate Quick Actions and Command Palette, persistent Mini Player, and responsive behavior for mobile, tablet, and desktop.
>
> Create these states separately:
>
> 1. Mobile — Minimal shell with bottom navigation and no active overlay.
> 2. Desktop — Minimal shell with expanded sidebar and focused workspace.
> 3. Desktop — Sidebar collapsed with icons, labels/tooltips, and restore affordance.
> 4. Desktop — Sidebar expanded with workspace labels and no secondary metadata clutter.
> 5. Mobile — Quick Actions closed and open as a small contextual bottom sheet.
> 6. Desktop — Quick Actions closed and open as a small contextual popover.
> 7. Desktop — Command Palette with grouped results: Actions, Workspaces, Recent.
> 8. Desktop — Command Palette empty/no results and loading/searching state.
> 9. Mobile — Command Palette as touch-friendly full-screen or bottom-sheet search.
> 10. Desktop — Global Chat contextual mode with selected text and suggested actions.
> 11. Desktop — Global Chat free conversation mode and context reset confirmation.
> 12. Mobile — Global Chat contextual/free mode with keyboard and close/minimize behavior.
> 13. Shell with Mini Player transition: idle, playing, collapsed, expanded, transcript available, and loading.
> 14. Mobile — Mini Player above bottom navigation while Quick Actions or a contextual sheet opens; prove no layer overlap.
> 15. Desktop — Context Panel and Chat stacking rule: one panel open, replace/split behavior, and close priority.
> 16. Mobile — Safe-area state with Mini Player, bottom navigation, keyboard, and one overlay.
> 17. Keyboard focus state: Command Palette focus, Escape close, Enter activate, arrow navigation.
> 18. Back behavior state: close overlay first, then panel, then workspace/source; preserve context.
>
> For every state describe visible/hidden elements, primary action, focus target, close/back behavior, safe-area calculation, responsive difference, and preserved workspace/context state.
>
> Constraints:
>
> - Never make Quick Actions a second Command Palette.
> - Never make Chat a sixth primary tab.
> - Never let Mini Player, Bottom Sheet, and Bottom Navigation overlap destructively.
> - Use `bottomNavigationHeight + safeAreaInset + spacingToken`, not a hard-coded device offset.
> - Do not assign browser-conflicting shortcuts until a shortcut registry exists.
