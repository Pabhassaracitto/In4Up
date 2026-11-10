# Web Core support matrix

The browser entrypoint is `lib/main_web.dart`. It is deliberately separate
from the native `lib/main.dart` entrypoint so FFI, native filesystem and
platform-only plugins do not enter the Web compilation graph.

## Supported in Web Core

| Capability | Implementation | State |
|---|---|---|
| Flutter UI | `lib/main_web.dart` | Supported |
| Basic reading | paste text + reader proxy | Supported |
| Browser audio | ordinary HTTP(S) URL via `just_audio` Web | Supported |
| Translation | controlled Worker/backend proxy | Requires `IN4UP_WEB_PROXY_BASE_URL`; no offline Hy-MT claim |
| Local draft/vocabulary | `shared_preferences` Web storage | Supported |
| Firebase Auth | Firebase Web popup | Optional; requires Firebase Auth setup |
| Firestore vocabulary sync | `cloud_firestore` Web | Optional; requires rules/auth |
| YouTube wrapper | same-origin `web/yt_embed.html` | Supported when Pages wrapper is deployed |
| Native FFI/STT/PDFium/background audio | Native entrypoint only | Intentionally not in Web Core |

## Release checks

A Web release is not accepted until CI verifies:

```bash
flutter pub get
flutter test test/web_core_contract_test.dart
flutter build web --release \
  -t lib/main_web.dart \
  --base-href /In4Up/ \
  --dart-define=IN4UP_WEB_PROXY_BASE_URL=https://your-worker.example \
  --dart-define=IN4UP_ALLOW_DIRECT_CORS=false
```

The production build must not set `IN4UP_ALLOW_DIRECT_CORS=true`. Translation
and reader traffic must use an allowlisted proxy with an origin allowlist.

Minimal Firestore rule for the optional vocabulary sync (adapt it to the
project's complete rules before deploying):

```text
match /users/{uid}/web_core_vocab/{wordId} {
  allow read, write: if request.auth != null && request.auth.uid == uid;
}
```

The Web Core is not a promise that every mobile/desktop feature is available
in a browser. Native-only actions must be hidden or explain their limitation
instead of producing a platform exception.
