# I4U UX — Prompt chi tiết state cho Xem trong Nghe

> Dùng sau Prompt 10. Không chỉ tạo tổng quan Desktop/Mobile; tạo và mô tả từng state riêng.

> Keep Xem as a media mode inside Nghe, not a sixth workspace. Preserve the five-workspace shell, the Quiet Lexicon visual language, transcript context, safe-area behavior, and the explicit bridge “Hiểu nội dung này”. Avoid a default three-column desktop layout.
>
> Create these separate states:
>
> 1. Desktop — Video mode with original subtitles only, minimal controls.
> 2. Desktop — Video + synchronized transcript split view.
> 3. Desktop — Transcript manually scrolled, auto-scroll paused, with “Theo lại câu đang phát”.
> 4. Desktop — Selected subtitle text with contextual actions: Tra từ, Dịch, Giải thích, Shadowing, Thêm vào Nhớ.
> 5. Desktop — Lexicon Inspector open for a selected word, without creating a third full-width column.
> 6. Desktop — “Hiểu nội dung này” handoff confirmation showing source, timestamp, selected transcript, and return-to-Xem path.
> 7. Mobile — Video with compact current subtitle and essential controls.
> 8. Mobile — Subtitle display modes: original only, original plus translation, translation on demand, and subtitles hidden.
> 9. Mobile — Transcript list with auto-scroll active.
> 10. Mobile — Transcript manually scrolled with auto-scroll paused and resume action.
> 11. Mobile — Selected subtitle with compact actions; use three priority actions plus a clear More affordance if five actions do not fit.
> 12. Mobile — Shadowing preparation, microphone permission, recording, processing, completed, and failed states.
> 13. Mobile — “Hiểu nội dung này” handoff with preserved video ID, timestamp, selected text, and return path.
> 14. Mobile — Reduced/minimized video while browsing transcript, proving the transcript remains usable.
>
> For every state explicitly describe:
>
> - visible and hidden elements;
> - primary action;
> - subtitle mode;
> - transcript scroll behavior;
> - current timestamp and playback position;
> - whether video is pinned, minimized, or scrolling;
> - how contextual actions open;
> - how the user returns to Xem;
> - how bottom navigation and safe area remain usable;
> - behavior when transcript, translation, or microphone is unavailable.
>
> Constraints:
>
> - Do not show video, transcript, and a full Lexicon Inspector as three equal columns by default.
> - Do not force bilingual subtitles on users who want immersion.
> - Manual transcript scrolling pauses auto-scroll and exposes a clear resume action.
> - “Hiểu nội dung này” is user-triggered and must preserve source context; do not silently navigate.
> - Shadowing needs explicit microphone permission and processing states.
