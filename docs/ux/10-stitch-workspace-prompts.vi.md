# I4U UX — Google Stitch prompts 6–12

> Dùng sau khi Global Shell đã đạt baseline. Gửi từng prompt một, theo đúng thứ tự. Mỗi prompt là một màn hình/flow riêng.
> Cập nhật: 2026-10-04

## Cách dùng

Trước mỗi prompt, nếu Stitch không giữ context, dán thêm phần `Shared design direction` trong `05-stitch-prompts.vi.md`. Giữ lại các quyết định của Global Shell: 5 workspace, Xem trong Nghe, Chat global contextual, Quick Actions riêng Command Palette, Reader minimal.

---

## Prompt 6 — Home Command Center

> Design the I4U Home workspace as a calm command center, not a dense analytics dashboard. Preserve the five primary workspaces: Home, Đọc, Nghe, Hiểu, Nhớ, and the Quiet Lexicon visual language.
>
> The Home screen must answer three questions quickly: What was I doing? What should I do next? What needs attention? Show a primary Continue Learning card that can resume the last active item, plus a small set of contextual next actions such as Continue Reading, Continue Listening, Review Due Items, and Start a Quick Capture.
>
> Include lightweight progress and recent activity, but do not show every statistic, course level, tool, or setting. Use progressive disclosure for detailed stats. Keep global Chat, Quick Actions, and profile/settings in the shell, not as competing Home cards.
>
> Show mobile and desktop behavior. On mobile use a focused one-column layout. On desktop use a restrained two-column layout with a main Continue area and a secondary Recent/Needs Attention area. Avoid gamification-heavy dashboards, excessive badges, and large collections of unrelated cards.

---

## Prompt 7 — Đọc Minimal Reader

> Design the I4U Đọc workspace in a true minimal reading state. Preserve the Global Shell and the Đọc context bar with Đọc and Viết, plus content sources Tài liệu, Web, PDF, and Tam tạng.
>
> Make the reading content the dominant visual element. Use a comfortable max-width text column, academic but readable typography, generous line height, clear paragraph spacing, and subtle progress indication. Interactive vocabulary anchors such as “tri giác” and “tiềm thức” should be discoverable but not look like heavy buttons.
>
> Show only the essential reader actions by default: back, save/bookmark, text display controls, audio access, and contextual actions for selected text. Do not show multiple statistics, quote cards, badges, vocabulary counts, or AI summaries by default.
>
> Include a selected-text state that reveals contextual actions: Dịch, Giải thích, Tra từ, Phát âm, and Thêm vào Nhớ. The actions should be compact and not cover the selected paragraph permanently.
>
> Show mobile and desktop variants. On desktop allow an optional contextual tool panel, closed by default. On mobile use a bottom sheet for contextual tools.

---

## Prompt 8 — Đọc Contextual Tool Panel

> Design the optional contextual tool panel for the I4U Đọc workspace. It must open without losing the current reading position or selected text.
>
> On desktop show a right panel that can be opened, closed, and pinned. Use structured tabs for Dictionary, Notes, and SRS/Thêm vào Nhớ. Keep Global Chat visually and functionally separate; do not duplicate a full chat conversation inside this tool panel.
>
> Show the Dictionary state for the selected word “tri giác”, including pronunciation, part of speech, level, definitions, collocations, example from the current text, and compact actions: Phát âm, Dịch, Phân tích câu, Thêm vào Nhớ.
>
> Show the Notes and SRS states as compact examples, not as three full dashboards. Preserve the main reader column and avoid a cramped three-column layout. On mobile convert the panel into a bottom sheet or full-screen tool flow with a clear close/back action.

---

## Prompt 9 — Nghe with Audio Library

> Design the I4U Nghe workspace for discovering and playing audio learning content. Preserve the five-workspace shell and use a context bar that distinguishes Nghe and Xem without creating a sixth primary destination.
>
> Show an audio library with a calm focused layout: Continue Listening, recent items, imported audio, playlists or categories, and a clear primary action to add/import audio. Do not turn the screen into a dense media management admin panel.
>
> Show the persistent mini player when audio is playing. It must not cover bottom navigation on mobile or the main content on desktop. Include an expanded player entry point with transcript, speed, loop, and save-to-Nhớ actions.
>
> Show empty, loading, and populated library states. Make the difference between selecting content and playing content clear. Support touch on mobile and keyboard-friendly selection on desktop.

---

## Prompt 10 — Xem within Nghe

> Design the Xem media mode inside the I4U Nghe workspace. Xem is not a primary workspace; it is a multimodal source containing video, audio, subtitles, and transcript.
>
> Show a video learning screen with a prominent player, optional subtitles, synchronized transcript, playback speed, replay segment, and a compact action to open contextual tools. Keep the primary experience focused on watching/listening.
>
> Include contextual actions for a selected subtitle or transcript segment: Tra từ, Dịch, Giải thích, Luyện Shadowing, and Thêm vào Nhớ. Provide a clear action called Hiểu nội dung này that can hand the current video/transcript context to the Hiểu workspace.
>
> On mobile prioritize video, current subtitle, and essential playback. On desktop allow video/transcript split view and an optional right contextual panel. Do not place all comprehension analytics on the video screen by default.

---

## Prompt 11 — Hiểu with Chat and Coach

> Design the I4U Hiểu workspace for comprehension, explanation, analysis, and guided questioning. Preserve Global Chat as a contextual capability, but make Hiểu a focused workspace rather than a generic chat screen.
>
> Show a source context area containing the current text, audio transcript, or video transcript, and a primary comprehension area with actions such as Giải thích, Tóm tắt, Hỏi đáp, Phân tích ngữ pháp, and Tạo câu hỏi kiểm tra.
>
> Make the difference between Global Chat and AI Coach clear: Global Chat supports open conversation; AI Coach guides a structured learning task with prompts, progress, and feedback. Do not show both as duplicate chat panels.
>
> Include a path to send useful results to Nhớ, such as saving a concept, phrase, question, or answer. Show mobile and desktop layouts with progressive disclosure and no excessive AI controls.

---

## Prompt 12 — Nhớ with Review and Học thuộc

> Design the I4U Nhớ workspace for review, memorization, vocabulary, and learning retention. Use Nhớ as the umbrella workspace and do not make Học thuộc a primary global tab.
>
> Show a clear secondary navigation or segmented context bar for Ôn tập, Học thuộc, Từ vựng, Bài tập, and Thống kê. Keep the first screen focused on the next useful learning action, such as items due for review or Continue Học thuộc.
>
> Show a Học thuộc flow using a sentence or phrase from Đọc/Nghe/Xem. Include progressive exercises such as reveal/cover, cloze, recall, listen-and-repeat, and confidence feedback. Keep the exercise focused and do not expose all exercise types at once.
>
> Show how a selected item can be reviewed, edited, or removed. Use neutral core labels such as Thêm vào Nhớ, Lưu vào bộ thẻ, and Ôn tập; do not make Anki the default mental model. External export/integration can appear only as an optional settings destination.
>
> Show mobile and desktop states. Prioritize one learning action at a time, clear progress, accessible controls, and a calm non-gamified visual language.
