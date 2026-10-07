# I4U UX — Prompt chi tiết state cho Nghe & Audio Library

> Dùng sau Prompt 9. Không chỉ mô tả tổng quan Desktop/Mobile; hãy tạo và mô tả từng state riêng có tên rõ ràng.

> Keep the current I4U Quiet Lexicon Audio Library architecture. Preserve the five primary workspaces, the Nghe/Xem context switch, the distinction between Select and Play, and the Mini Player safe-area rule. Do not create an admin dashboard.
>
> Create these separate states:
>
> 1. Desktop — Empty Audio Library with three entry points: Upload file, Paste podcast/URL, and Explore curated collections.
> 2. Mobile — Empty Audio Library with the same three entry points in a thumb-friendly one-column layout.
> 3. Desktop — Populated Audio Library with Continue Listening, Recent Items, Collections, and Imported Audio.
> 4. Mobile — Populated Audio Library with Continue Listening first and compact recent items.
> 5. Desktop — Item selected but not playing; show metadata/detail without changing current playback.
> 6. Desktop — Item playing in Mini Player; show play/pause, timeline, speed, A-B loop, transcript entry, and expand action.
> 7. Mobile — Item playing in Mini Player above the five-tab bottom navigation; prove that safe area and touch targets are preserved.
> 8. Desktop — Import and transcript processing state; show user-friendly progress such as Preparing audio, Creating transcript, and Syncing text. Keep technical processing details secondary.
> 9. Desktop — Expanded Player with synchronized transcript, selected transcript text, Dictionary/Translate/Add to Nhớ actions, and optional pitch data.
> 10. Mobile — Expanded Player with transcript and one-handed playback controls.
> 11. Transcript unavailable or processing failed state; provide Retry, Play audio without transcript, and Import/choose another source.
> 12. Pitch/IPA capability states: available, analyzing, unsupported, and failed. Do not show pitch contour when no valid data exists.
> 13. A-B loop and Shadowing practice state; show start/end markers, repeat status, and exit action without turning the screen into a dense control panel.
> 14. Import success and import failure feedback; show what is ready, what is still processing, and a clear return-to-library action.
>
> For every state explicitly describe:
>
> - what is visible and hidden;
> - primary action;
> - whether selecting an item starts playback;
> - playback status and current item;
> - transcript availability;
> - how Mini Player, Expanded Player, and bottom navigation relate;
> - how scrolling behaves;
> - what happens when audio is offline or loading;
> - keyboard behavior on desktop;
> - safe-area and touch behavior on mobile.
>
> Important constraints:
>
> - Clicking a card body selects/shows details; only an explicit Play control starts playback.
> - Mini Player must never cover the five-tab navigation.
> - Do not promise pitch accent or IPA for every audio source.
> - Do not use browser-conflicting shortcuts; Space may be shown only when player focus is active.
> - Keep Continue Listening as the dominant action and do not fill the screen with analytics.
