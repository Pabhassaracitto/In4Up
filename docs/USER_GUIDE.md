# In4Up — Offline import and learning workflows

> Updated 2026-09-30 · Card `I4U18-DOCS-001`
> **English** · [Tiếng Việt](USER_GUIDE.vi.md)
>
> Button names below use the English locale. In another locale, their position
> is unchanged and untranslated chrome falls back to English, never Vietnamese.
> Models, dictionaries, books and media are not stored in Git.

## 1. Before you begin

- Keep at least twice the imported file size free for copying or extraction.
- Keep In4Up in the foreground during large imports. On Android, open **Home →
  Manage AI Models → Stop battery optimization** if downloads are interrupted.
- Keep an original backup. Clearing the app's data also clears imported data in
  its private storage.
- Use only data you are allowed to use. Never post API keys, copyrighted files
  or private content in an issue or log.

### What the current UI supports

| Workflow | Supported now | Current limitation |
|---|---|---|
| Piper/eSpeak/Whisper/Zipformer | Import or explicit download in **Manage AI Models** | Piper needs a voice and phonemizer; Zipformer needs all model components |
| Server/API/BYOK | OpenAI-compatible cloud, Ollama, LM Studio and per-capability routing | Plain HTTP is accepted only for private LAN addresses |
| Dictionary | Import `.mdx`, enable/disable/delete, offline lookup | The picker does not yet link separate `.mdd` or CSS files |
| Tipiṭaka | Import `.db/.sqlite/.sqlite3/.zip`; download Pa-Auk packs | Install Pāli first for the best bilingual alignment |
| Listen | Scan Android audio, search, select many files as a playlist | The selected-file playlist is not yet a named persistent playlist |
| Video | Add and play one local file at a time | Folder scan, filters and video playlists are not in the current UI |
| PDF/OCR/TTS/IPA | Text PDFs; Android/iOS OCR; sentence TTS; IPA in Read mode | OCR is unavailable on desktop/web; scanned PDFs need OCR |

## 2. Import Piper, eSpeak and offline STT

Open **Home → Manage AI Models**. Completion means the relevant card says
**Installed/Ready**; merely selecting a file is not enough.

### Piper TTS and `espeak-ng-data`

Piper needs:

1. A voice `<voice>.onnx`, normally `<voice>.onnx.json`, and for some Sherpa
   bundles `tokens.txt` or `<voice>_tokens.txt`.
2. A shared `espeak-ng-data` directory containing `phontab`.

Recommended flow:

1. Under **3. TTS — Piper**, select **Download voice** and wait for installation.
2. If the eSpeak row still says it is missing, download the phonemizer there.
3. Select the installed voice for its language.
4. Open **Settings → Text-to-Speech**, put Piper in the source order and test a
   short sentence with networking disabled.

For files you already have, use **Import folder** for an extracted complete
bundle. If Android SAF cannot expose the directory, use **Import files** and
select ONNX, JSON and token files together. Do not select only one file from
inside `espeak-ng-data`.

If the voice does not appear, verify the ONNX file is complete, import its JSON
and tokens when supplied, install `espeak-ng-data`, then reopen the model screen.
A missing or damaged Piper component should fall back to system TTS rather than
crash the app.

### Whisper for files and LRC

1. Under **1. STT — Whisper**, download a model level or import a valid
   `ggml-*.bin`.
2. Open **Listen**, load audio, select **Generate lyrics/LRC**, then choose a
   language (`auto` when unsure) and model.
3. For Hindi, CJK or another non-Latin script, try `base`/`small` when `tiny`
   produces incorrect Latin output.

### Zipformer for offline/live recognition

A profile requires all of:

```text
tokens.txt
encoder*.onnx
decoder*.onnx
joiner*.onnx
```

Under **5. Offline STT — Zipformer**, choose the correct profile. VI offline +
VAD works in Cabin and file/LRC flows; EN streaming is for token-by-token Cabin
recognition and must not be used for file transcription. Download it or import
all files/folder together. If recognition fails, check the selected profile and
missing components; do not mix files from different models.

Developer layouts and ADB paths are in [`project/MODELS.md`](project/MODELS.md).

## 3. Configure Server/API, BYOK and a local server

Open **Home → Manage AI Models → Server & API (cloud / LAN)**.

### Cloud BYOK

1. Select **Add provider**, then a Gemini, Groq, OpenRouter or OpenAI preset.
2. Add a display label and your own provider key.
3. Select **Test connection**, then **Load models**.
4. Select Chat/STT/TTS models supported by that endpoint, save, and enable the
   provider.
5. Choose routing separately for each capability:
   - **Offline first**: local model, then API fallback.
   - **Online first**: API, then local fallback.
   - **Offline only**: no API request.

The key is obscured on screen, but provider configuration is currently stored
locally by the app. Do not use a privileged key on a shared device. Set spend
limits with the provider and revoke the key after device loss.

### Ollama or LM Studio on your LAN

1. Start an OpenAI-compatible server on the computer and load a model.
2. Bind it to the LAN, not only `127.0.0.1`, and allow its port through a
   private-network firewall.
3. Put phone and computer on the same Wi-Fi and use the computer's LAN IP:
   - Ollama: `http://192.168.1.10:11434`
   - LM Studio: `http://192.168.1.10:1234`
4. Test, load models, select the capability model and save.

Do not use `localhost` from a phone: it means the phone itself. Public endpoints
must use HTTPS; plain HTTP is restricted to private LAN hosts.

Troubleshooting: timeout usually means a changed IP, firewall, VPN or access
point isolation; 401 means a missing/invalid key; zero models means no model is
loaded or `/v1/models` is unsupported. If a green provider is not used, check it
is enabled, has a model for that capability and routing is not **Offline only**.

## 4. Import/link MDX, MDD and CSS dictionaries

Open **Dictionary/Manage dictionaries**, select **+**, and choose `.mdx`. Wait
for a card with an entry count greater than zero. In Read mode, tap a known word
to see offline MDX results; available meaning/IPA can be reused when saving it.

A typical dictionary set is:

```text
MyDictionary.mdx
MyDictionary.mdd
style.css
```

**Current limitation:** the production picker accepts MDX only. Although the
internal service has an MDD seam, the manager does not yet offer MDD/CSS linking.
Import MDX for text lookup, keep companion files beside it with matching names,
and do not treat successful MDX import as proof that external audio/images/CSS
are linked.

For zero entries, copy the source to local storage, verify it is a complete,
unprotected MDX variant, keep enough free space, and test with a known small
MDX. A malformed file must fail clearly without creating a fake empty card.

## 5. Import Tipiṭaka and Pāli packs

1. Open **Tipiṭaka Library → Data/Storage**.
2. Either select **Import DB or language pack from device** (`.db`, `.sqlite`,
   `.sqlite3`, `.zip`) or **Download Pa-Auk language pack**.
3. Install **Pāli (Roman)** first, then a translation for the best bilingual
   alignment. A future Tipiṭaka lane may allow translations independently; the
   current guide does not claim that behavior before its UI is merged.
4. Select **Check DB**. A ready database shows collection, book, segment and
   language counts.
5. Open the library, select collection → book → passage, search a Pāli phrase
   and test bilingual display.

If a ZIP fails, confirm it contains a complete SQLite database and there is room
to extract it. If alignment reports missing Pāli, install Pāli and retry the
translation. Large developer imports are described in
[`tipitaka_database.md`](tipitaka_database.md).

## 6. Listen and Video libraries

### Listen: scan, search and quick playlist

1. Open **Listen → Library** and grant Audio/Music access when asked.
2. Select **Scan library** or pull to refresh. Search by title or artist.
3. Tap an item to play it. If MediaStore finds nothing, use **Recent → Add
   audio** to pick a file manually.
4. In the audio drawer, select **Choose multiple files**. In4Up copies them to
   persistent app storage, plays the first and displays a quick playlist.

Clearing this playlist does not delete original files. If a `content://` item
cannot play, manually import it so the app can make a local copy.

### Local video

Open **Watch/Video → Add video**, choose `mp4`, `mkv`, `webm`, `mov`, `avi` or
`m4v`, then tap its card. The current UI adds individual files only. Folder scan,
filtering and playlists must not be marked as available until the corresponding
L18 lane is merged. For codec failures, try MP4 H.264/AAC or remux the file; the
app should report an error instead of staying black.

## 7. PDF, OCR, TTS and IPA

### Text PDF and TTS

1. Open **Read → Reading Library → Device → Open PDF**.
2. Navigate with TOC/search/page controls.
3. Use Play on the TTS bar; adjust language and speed. Sentence highlighting
   and automatic page advance should follow playback.
4. Tap/select text to look it up, save it or speak the selection.

A PDF with no searchable/selectable text is probably image-only.

### OCR

- Android/iOS: choose **Scan image** in Reading Library, then **Capture & scan
  document** (Android) or **Choose existing image**. Review and correct the text
  before loading it into Read mode.
- In an image-only PDF, select **Scan text on this page** in the TTS bar. This
  renders and recognizes the current page; it does not permanently add a text
  layer to the original PDF.
- OCR is not currently available on desktop/web.

Use a straight, evenly lit image. Pāḷi Roman uses the Latin recognizer; verify
`ā ī ū ṃ ṅ ñ ṭ ḍ ṇ ḷ` before saving or speaking the result.

### TTS and IPA in Read mode

The speaker/Play control uses the engine order in **Settings → Text-to-Speech**.
The **IPA/abc** button cycles **Off → Active line → All text**. When IPA is on,
use the legend panel to toggle phoneme colour groups and tap a word chip to hear
it. Saved-word IPA prefers available MDX data, then configured fallbacks. Not
every language or Pāli word has a packaged G2P result.

## 8. Reporting a problem

Record the build, device/OS, app locale, exact navigation steps, source filename
and size, and the complete error text. Do not attach copyrighted sources unless
permitted. For API issues, redact the entire key/token and report only the
provider, sanitized base URL, HTTP status and structured error code. The owner
can run [`manual_qa_I4U18_DOCS_001.md`](manual_qa_I4U18_DOCS_001.md) for the
cross-lane device acceptance pass.
