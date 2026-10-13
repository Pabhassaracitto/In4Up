# I4U UX — Shared State Contract

> Trạng thái: implementation baseline; chưa phải Dart model cụ thể.
> Mục tiêu: thống nhất state xuyên workspace trước khi chia agent.

## 1. Workspace state

```text
activeWorkspace: home | read | listen | understand | remember
readMode: read | write
listenMode: listen | watch
rememberMode: review | memorize | vocabulary | exercises | stats
```

Mỗi workspace giữ state riêng khi chuyển tab; không reset toàn bộ chỉ vì navigation.

## 2. Source fingerprint

```json
{
  "sourceType": "document|web|pdf|audio|video|pasted",
  "sourceId": "string",
  "sourceRevision": "string|null",
  "page": 18,
  "timestampMs": 84000,
  "selectedText": "string|null",
  "locale": "vi",
  "returnPath": "string",
  "createdAt": "ISO-8601"
}
```

Dùng cho:

- Đọc → Hiểu;
- Nghe/Xem → Hiểu;
- mọi thẻ Nhớ;
- Recent Activity;
- Return Path.

## 3. Semantic reading anchor

```json
{
  "sourceId": "string",
  "sourceRevision": "string|null",
  "blockId": "para_014",
  "characterOffset": 128,
  "selectedTerm": "tri giác|null",
  "locale": "vi",
  "viewportRelativeRatio": 0.35,
  "createdAt": "ISO-8601"
}
```

Fallback:

```text
blockId
→ text fingerprint
→ nearby text search
→ page/timestamp
→ source unavailable recovery
```

Không highlight khi match không đủ tin cậy.

## 4. Overlay/layer state

```text
overlay:
  none | quickActions | commandPalette | chat | toolPanel | sheet | modal

panel:
  closed | open | pinned | replaced

modalFocus:
  triggerElement | activeElement | none
```

Baseline:

```text
Command Palette/Modal > Sheet/Drawer > Tool Panel/Chat > Mini Player > Navigation
```

Trên mobile không để các surface nổi cạnh tranh vùng chạm.

## 5. Mini Player state

```text
playbackStatus: idle | loading | playing | paused | failed
transcriptStatus: unavailable | processing | available | failed
visualMode: hidden | mini | collapsed | expanded
isAudioContinuingInBackground: bool
```

Visual layer không tự ý thay đổi playback status.

## 6. Chat state

```text
chatMode: contextual | free
contextAnchor: SourceFingerprint|null
messages: list
isContextResetPending: bool
```

Global Chat không phải AI Coach. Hiểu dùng Coach task state riêng.

## 7. AI Coach state

```text
coachTask: explain | syntax | summarize | ask | quiz
coachStep: integer
coachStatus: idle | active | submitting | feedback | paused | unavailable | stale
answerDraft: string
hintLevel: none | one | two
```

Chỉ một câu hỏi/nhiệm vụ là primary tại một thời điểm.

## 8. Memory/review state

```text
reviewStatus: idle | active | revealed | rating | paused | completed
rating: notRemembered | difficult | remembered | mastered
schedule: engine-provided
softDeleteStatus: active | archived | restored | expired
syncStatus: local | syncing | synced | conflict | failed
```

UI không tự hard-code lịch SRS; scheduler cung cấp kết quả.

## 9. Shortcut state

```json
{
  "id": "open-command-palette",
  "platform": "macos|windows|linux|web",
  "keyChord": "Cmd+K",
  "scope": "global|workspace|modal|player",
  "enabled": true,
  "userOverride": null,
  "fallbackAction": "click-search-button"
}
```

Precedence:

```text
native OS/browser/input
→ active modal
→ focused component
→ workspace
→ global
```

## 10. Offline/sync event

```json
{
  "eventId": "unique-id",
  "deviceId": "device-id",
  "entityId": "entity-id",
  "entityType": "review|note|card|position",
  "operation": "create|update|delete|review",
  "logicalTime": 0,
  "baseRevision": "string|null",
  "payload": {}
}
```

- Review events: append-only, deduplicated, deterministic replay.
- Notes/edits: versioned 3-way merge.
- Delete: soft-delete, recoverable.
- Conflict: không âm thầm ghi đè.
