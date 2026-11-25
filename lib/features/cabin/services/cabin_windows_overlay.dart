import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef _CreateNative = Pointer<Void> Function();
typedef _Create = Pointer<Void> Function();
typedef _SetNative = Int32 Function(Pointer<Void>, Pointer<Utf16>);
typedef _Set = int Function(Pointer<Void>, Pointer<Utf16>);
typedef _DestroyNative = Void Function(Pointer<Void>);
typedef _Destroy = void Function(Pointer<Void>);

/// Owns a Windows topmost caption window. Not wired to Cabin yet.
class CabinWindowsOverlay {
  CabinWindowsOverlay() {
    if (!Platform.isWindows) throw UnsupportedError('Windows only');
    final library = DynamicLibrary.open('in4up_cabin_audio.dll');
    _create = library.lookupFunction<_CreateNative, _Create>('cabin_overlay_create');
    _set = library.lookupFunction<_SetNative, _Set>('cabin_overlay_set_text');
    _destroy = library.lookupFunction<_DestroyNative, _Destroy>('cabin_overlay_destroy');
  }

  late final _Create _create;
  late final _Set _set;
  late final _Destroy _destroy;
  Pointer<Void> _handle = nullptr;
  bool _closed = false;

  void show() {
    if (_closed || _handle != nullptr) throw StateError('Overlay already used');
    _handle = _create();
    if (_handle == nullptr) throw StateError('Could not create caption overlay');
  }

  void setCaption(String text) {
    if (_closed || _handle == nullptr) throw StateError('Overlay is not active');
    final nativeText = text.toNativeUtf16();
    try {
      if (_set(_handle, nativeText) != 0) throw StateError('Overlay is unavailable');
    } finally {
      calloc.free(nativeText);
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    if (_handle != nullptr) {
      _destroy(_handle);
      _handle = nullptr;
    }
  }
}
