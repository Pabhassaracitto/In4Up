# Background removal — Phase 2 seam

Phase 1 uses `google_mlkit_subject_segmentation` and is the default engine in
Wordlist. The interface lives at:

- `lib/features/background_removal/base_background_remover.dart`
- `MlKitBackgroundRemover`
- `RmbgBackgroundRemover`
- `BackgroundRemovalService`
- `RmbgModelStore` — kiểm tra/import `ApplicationDocumentsDirectory/rmbg14.onnx`

`RmbgBackgroundRemover` is deliberately injectable. The default build does not
import an ONNX package and does not contain `rmbg14.onnx`, so the default APK
stays small. When Phase 2 is scheduled:

1. Add the ONNX runtime package to `pubspec.yaml` only in the Phase 2 build
   profile. The project request names `onnxruntime_flutter`; verify the package
   API/version used by the team before pinning it. The currently maintained
   alternative is `flutter_onnxruntime`.
2. Download or import `rmbg14.onnx` into `ApplicationDocumentsDirectory` and
   validate its size/hash before marking it installed.
3. Implement the injected `RmbgInference` callback. Create the ONNX session,
   tensorize, run inference, and post-process the alpha mask inside a top-level
   `compute` entry point. Do not pass an open ONNX session between isolates.
4. Encode the post-processed RGBA image as PNG and return `Uint8List`.
5. Construct `BackgroundRemovalService(rmbg: ...)`. It catches model/RAM/
   runtime failures and retries `MlKitBackgroundRemover` automatically.

The model URL, expected size, checksum and license must be configured by the
application owner; no model URL is hard-coded in Phase 1.
