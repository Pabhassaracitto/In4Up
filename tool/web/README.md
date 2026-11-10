# In4Up Web Core proxy

`lib/main_web.dart` is a browser-safe entrypoint. It does not place provider
secrets in the generated JavaScript. The optional proxy provides two routes:

- `GET /reader?url=https://...` — fetches only allowlisted reader hosts.
- `POST /translate` — forwards `{text, sourceLang, targetLang}` to the
  translation service configured in the Worker secret/environment.
- `GET /health` — deployment smoke check.

The reference implementation is `in4up_proxy_worker.js`.

## Required Worker variables

```text
ALLOWED_ORIGINS=https://<owner>.github.io
READER_ALLOWED_HOSTS=example.com,another-approved-site.org
TRANSLATION_URL=https://your-translation-backend.example/translate
TRANSLATION_API_KEY=<Worker secret, if the upstream needs one>
```

Both the browser origin and reader host allowlists are intentionally
fail-closed. An empty `ALLOWED_ORIGINS` prevents browser access; an empty
`READER_ALLOWED_HOSTS` rejects every reader target. Do not turn this into an
open proxy. Add rate limiting, authentication, or Cloudflare Turnstile before
opening the endpoint to untrusted traffic at scale.

## Flutter Web build configuration

Pass the public Worker URL at build time:

```bash
flutter build web --release \
  -t lib/main_web.dart \
  --base-href /In4Up/ \
  --dart-define=IN4UP_WEB_PROXY_BASE_URL=https://your-worker.example \
  --dart-define=IN4UP_ALLOW_DIRECT_CORS=false
```

`IN4UP_WEB_PROXY_BASE_URL` is not a secret. It is visible in the Web bundle.
The upstream translation API key must remain only in Worker secrets.

For local development, a CORS-enabled development endpoint can be enabled
explicitly with `--dart-define=IN4UP_ALLOW_DIRECT_CORS=true`. Do not use this
flag for the production Pages build.
