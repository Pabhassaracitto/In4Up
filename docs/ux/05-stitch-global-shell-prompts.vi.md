# I4U UX — Google Stitch prompts 1–5

> Bản copy dễ dùng để gửi lần lượt vào Google Stitch.

## Shared design direction

> Design a professional modern language-learning app called I4U. The product supports reading, listening, watching, understanding, remembering, writing, vocabulary, contextual AI assistance, and media learning. Use a calm focused visual language, strong hierarchy, compact but comfortable controls, restrained color, accessible contrast, clear icons, and progressive disclosure. The interface should feel fast and uncluttered, inspired by Zen Browser and Are.na: primary navigation stays simple while advanced tools expand only when needed. Do not create a dense dashboard or expose every feature at once. Use realistic Vietnamese labels where labels are visible.

## Prompt 1 — Mobile Global Shell

> Design the mobile global shell for I4U. The default primary navigation is exactly: Home, Đọc, Nghe, Hiểu, Nhớ. Use a bottom navigation bar with five destinations. The active destination must be obvious without relying on color alone.
>
> The top app bar should show the current workspace title, a contextual primary action, a global Chat entry point, and a compact Quick Actions entry point. Do not show a long list of tools in the top bar.
>
> Show an example state for the Đọc workspace. Include a compact contextual bar with Đọc and Viết, plus a content-source control for Tài liệu, Web, PDF, and Tam tạng. Make the contextual bar horizontally scrollable or collapsible on narrow screens.
>
> Show a persistent mini audio player above the bottom navigation when audio is playing. It must be compact, expandable, dismissible or collapsible, and must not cover the main content or navigation.
>
> Show Quick Actions as a small contextual bottom sheet with only four or five relevant actions. Do not put the full command search inside Quick Actions. Provide a separate clear affordance for opening the global Command Palette.
>
> Requirements: mobile portrait, touch-first, accessible touch targets, no visual clutter, visible affordances when bars are collapsed, and support for system text scaling.

## Prompt 2 — Desktop Global Shell

> Design the desktop/web global shell for I4U. Use a collapsible left sidebar for exactly five primary workspaces: Home, Đọc, Nghe, Hiểu, Nhớ. In the collapsed state show icons with supplementary tooltips; in the expanded state show icon plus Vietnamese label.
>
> Use a top bar for the current workspace title, global search/Command Palette, contextual Chat, Quick Actions, and account/settings. Keep global controls visually separate from workspace-specific controls.
>
> Show an example of the Đọc workspace with a focused main content column and an optional right contextual panel. The right panel contains Dictionary, AI Coach, Notes, or Vocabulary, but is closed by default and easy to pin when needed.
>
> Show a persistent audio player at the bottom without blocking content. It should be expandable into playback/transcript.
>
> Demonstrate three states: minimal, expanded contextual panel, and Command Palette open. Use progressive disclosure. Requirements: keyboard-friendly, Escape closes overlays, sensible max-width, no dense admin-dashboard feeling.

## Prompt 3 — Global Chat contextual panel

> Design the contextual global Chat surface for I4U. It must be accessible from every workspace but adapt its suggested actions to the current context. It is not a sixth primary navigation tab.
>
> Show Chat in Đọc with a paragraph selected. Display the selected context, then suggest: Giải thích, Dịch, Phân tích câu, Viết lại, Tạo câu hỏi, and Thêm vào Nhớ. Keep suggestions compact and editable.
>
> Include a way to switch from contextual help to free conversation without losing the selected context. Show small examples of adaptation in Nghe/Xem and Nhớ.
>
> Make Chat a right-side panel on desktop and bottom sheet/full-screen flow on mobile. Provide close, minimize, and context-reset actions. Keep Chat distinct from specialized Contextual Tool Panel.

## Prompt 4 — Quick Actions and Command Palette

> Design two related but distinct action surfaces for I4U.
>
> Quick Actions is a small contextual surface with four or five relevant actions. In Đọc show: Mở tài liệu, Mở PDF, Mở Web, Tra từ, and Thêm vào Nhớ. It must not contain the full command search.
>
> Command Palette is a separate searchable global surface opened from the top bar or Cmd/Ctrl+K. Show results grouped by Actions, Workspaces, and Recent items. Include examples such as Mở PDF, Tạo ghi chú, Dịch đoạn chọn, Phát âm, Thêm vào Nhớ, and Mở AI Coach.
>
> Make the distinction clear: Quick Actions is discoverable and contextual; Command Palette is fast and comprehensive. Support keyboard navigation on desktop and touch selection on mobile. Do not expose every advanced tool in Quick Actions.

## Prompt 5 — Revision after Global Shell review

> Revise the current I4U Global Shell while preserving the five primary workspaces: Home, Đọc, Nghe, Hiểu, Nhớ. Keep the calm Quiet Lexicon visual language, but reduce information density in the default state.
>
> Separate Quick Actions and Command Palette clearly. Quick Actions must remain a small contextual surface with only four or five relevant actions. Command Palette must be a separate global surface.
>
> Replace product-specific core labels such as “Thêm vào Anki” with neutral labels such as “Thêm vào Nhớ” or “Lưu vào bộ thẻ”. Keep external integrations optional.
>
> Remove secondary metadata such as course statistics, focus time, and shortcut help from the primary sidebar unless explicitly opened.
>
> Keep the Reader in a true minimal reading state. Show six mini-player states: idle, playing, loading, transcript, collapsed, and expanded. Do not assign conflicting browser shortcuts. Preserve mobile, tablet, and desktop responsiveness.
>
> Keep Global Chat distinct from specialized tools such as Dictionary, Notes, and SRS.
