# I4U UX — Capability Breakdown & Arena Agent Plan

> Trạng thái: kế hoạch giao việc; chưa tạo branch agent và chưa code.
> Mục tiêu: một capability rõ ràng/branch, tối đa 1–3 commit.

## Phase 0 — Foundation contracts

### C-00 — Shared shell contracts

- **Phạm vi:** state enums/contracts, source fingerprint, semantic anchor, overlay policy.
- **Không làm:** visual redesign, business feature.
- **Dependencies:** none.
- **Bàn giao:** contract doc/tests hoặc model seam.

### C-01 — Shortcut Registry

- **Phạm vi:** scoped shortcuts, platform guard, user enable/disable, fallback.
- **Không làm:** gán hàng loạt shortcut vào mọi màn hình.
- **Dependencies:** C-00.

### C-02 — Safe-area and overlay policy

- **Phạm vi:** shared layout tokens, viewInsets/keyboard, layer precedence.
- **Không làm:** sửa từng màn hình riêng lẻ ngoài policy.
- **Dependencies:** C-00.

## Phase 1 — Global Shell

### C-10 — Desktop sidebar/navigation

- Expanded/collapsed sidebar.
- 5 workspace navigation.
- Preserve workspace state.

### C-11 — Mobile bottom navigation

- 5 tabs.
- Safe-area.
- Active state/accessibility.

### C-12 — Back/dismiss coordinator

- Modal → panel → source return → route history.
- Escape/back/hardware back.
- Draft/session protection.

### C-13 — Quick Actions surface

- Context-only actions.
- Popover/sheet responsive.
- No command search duplication.

### C-14 — Command Palette

- Search input.
- grouped results.
- empty/loading.
- focus trap/return focus.

### C-15 — Global Chat surface

- contextual/free mode.
- reset context.
- desktop drawer/mobile sheet.
- no AI Coach coupling.

### C-16 — Mini Player shell integration

- idle/loading/playing/paused/expanded.
- layer integration.
- audio continues when sheet hides player.

## Phase 2 — Workspace shells

### C-20 — Home Command Center

- Continue card.
- Needs Attention.
- Next Actions.
- Recent Activity.
- Quick Capture.
- stale/offline states.

### C-21 — Reader minimal shell

- source picker/loading/error.
- reader viewport.
- aA settings.
- semantic anchor restore.

### C-22 — Reader contextual actions/panel

- selection bar.
- dictionary/notes/remember panel.
- mobile sheet/desktop drawer.

### C-23 — Audio Library

- empty/populated/select/play.
- import/processing.
- mini/expanded player.

### C-24 — Watch mode

- video/subtitle/transcript.
- manual scroll/resume.
- reduced video.
- handoff to Understand.

### C-25 — Understand/AI Coach

- source context.
- task selection.
- Socratic steps.
- feedback/hints.
- save to Remember.

### C-26 — Remember/review/memorization

- due review.
- review session.
- five-stage memorization.
- soft delete/undo.
- offline/sync/conflict.

## Phase 3 — Cross-cutting QA

### C-30 — Responsive/accessibility QA

- text scale;
- keyboard;
- screen reader labels;
- touch targets;
- orientation;
- safe-area;
- overlay stacking.

### C-31 — State preservation QA

- source return;
- semantic anchor;
- playback continuity;
- drafts;
- offline conflicts.

## Dependency order

```text
C-00
├── C-01
├── C-02
└── C-12

C-01 + C-02
→ C-10..C-16

C-10..C-16
→ C-20..C-26

C-20..C-26
→ C-30..C-31
```

## Agent handoff format

```text
Branch:
Capability:
Goal:
Allowed files:
Forbidden scope:
Dependencies:
Required states:
Tests:
Manual QA:
Maximum commits: 1–3
Commit format:
Definition of Done:
```

## Merge policy

- Không giao hai agent sửa cùng một shell file trong cùng phase nếu tránh được.
- Foundation trước workspace.
- Mỗi agent báo cáo file, test, known issues.
- Không commit generated artifacts ngoài convention.
- Không refactor unrelated.
