# I4U UX — Component Inventory

> Trạng thái: bản nháp implementation baseline sau UX Freeze.
> Mục tiêu: tránh mỗi agent tự tạo một phiên bản component khác nhau.

## Nguyên tắc

- Ưu tiên component dùng chung trước component màn hình.
- Component không sở hữu business logic nếu chỉ là presentation.
- Mỗi overlay phải có close/back/focus behavior rõ.
- Mỗi mobile floating surface phải dùng safe-area policy chung.
- Không đưa mọi component vào một mega-widget.

## Global Shell components

| Component | Vai trò | Responsive |
|---|---|---|
| `AppShell` | Khung cấp cao, theme, route/workspace state | All |
| `PrimaryNavigation` | 5 workspace chính | Mobile bottom nav; desktop rail/sidebar |
| `DesktopSidebar` | Expanded/collapsed navigation | Desktop/tablet |
| `MobileBottomNavigation` | 5 tab và safe-area | Mobile |
| `TopAppBar` | Workspace title, global actions | All |
| `ContextBar` | Mode/source/filter trong workspace | All |
| `QuickActionsSurface` | 4–5 context actions | Popover/sheet |
| `CommandPalette` | Global search/actions | Modal/full-screen sheet |
| `GlobalChatSurface` | Contextual/free chat | Drawer/sheet |
| `OverlayStackHost` | Layer order, dismiss, focus | All |
| `BackDismissCoordinator` | Back/Escape hierarchy | All |
| `ShortcutRegistry` | Scoped configurable shortcuts | Desktop primarily |

## Persistent media components

| Component | Vai trò |
|---|---|
| `MiniPlayer` | Playback compact state |
| `ExpandedPlayer` | Transcript/deep playback |
| `TranscriptViewport` | Synchronized transcript |
| `PlaybackControls` | Play, pause, seek, speed, loop |
| `SafeAreaFloatingHost` | Position Mini Player/surfaces |

## Reading/learning components

| Component | Vai trò |
|---|---|
| `ReaderViewport` | Minimal reading content |
| `SourcePicker` | Tài liệu/Web/PDF/Tam tạng |
| `TypographySettingsSheet` | aA font/size/leading/margin |
| `SemanticTextAnchor` | Word/phrase context anchor |
| `SelectionActionBar` | Selected text actions |
| `ContextualToolPanel` | Dictionary/Notes/Nhớ |
| `SourceContextCard` | Handoff source summary |
| `ReturnPathBanner` | Return về Đọc/Nghe/Xem |

## Feedback/input components

| Component | Vai trò |
|---|---|
| `CalmSnackbar` | Success/Undo/non-blocking feedback |
| `ErrorRecoveryCard` | Retry/cache/alternative source |
| `LoadingSkeleton` | Stable loading geometry |
| `KeyboardAvoidingSurface` | Mobile input + keyboard |
| `FocusTrap` | Modal keyboard focus |
| `DraftAutosaveIndicator` | Draft saved/unsaved state |
| `ConflictResolutionDialog` | Offline sync conflict |

## Workspace components

### Home

- `ContinueLearningCard`
- `NeedsAttentionCard`
- `NextActionsList`
- `RecentActivityList`
- `QuickCaptureSurface`
- `FocusRhythmSummary` (optional/hidden by user)

### Nghe/Xem

- `AudioLibrary`
- `AudioCollectionCard`
- `ContinueListeningCard`
- `VideoViewport`
- `SubtitleModeSheet`
- `ShadowingFlow`
- `PitchCapabilityPanel`

### Hiểu

- `SourceContextPane`
- `CoachTaskPicker`
- `SocraticQuestionCard`
- `CoachFeedbackCard`
- `StructuredBreakdown`
- `CoachSessionControls`

### Nhớ

- `MemoryOverview`
- `ReviewSession`
- `ReviewFeedbackBar`
- `MemorizationStage`
- `CardInspector`
- `SoftDeleteUndo`
- `SyncStatusBanner`

## Component states required

Các component có state phức tạp phải có test/design cho:

```text
idle
loading
populated
empty
error
offline
success
focused
keyboard-visible
expanded
collapsed
dismissed
```

Không phải component nào cũng cần mọi state; nhiệm vụ phải ghi rõ state áp dụng.
