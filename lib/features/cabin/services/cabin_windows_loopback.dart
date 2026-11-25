import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'cabin_loopback_stream.dart';

typedef _CreateNative = Pointer<Void> Function();
typedef _Create = Pointer<Void> Function();
typedef _IntNative = Int32 Function(Pointer<Void>);
typedef _IntCall = int Function(Pointer<Void>);
typedef _ReadNative = Int32 Function(Pointer<Void>, Pointer<Float>, Int32);
typedef _Read = int Function(Pointer<Void>, Pointer<Float>, int);
typedef _DestroyNative = Void Function(Pointer<Void>);
typedef _Destroy = void Function(Pointer<Void>);

/// WASAPI playback loopback. A device and all its FFI calls belong to one
/// Dart isolate; the native side owns a separate COM capture thread.
class CabinWindowsLoopback implements CabinLoopbackDevice {
  CabinWindowsLoopback() {
    if (!Platform.isWindows) throw UnsupportedError('Windows only');
    final lib = DynamicLibrary.open('in4up_cabin_audio.dll');
    _create = lib.lookupFunction<_CreateNative, _Create>('cabin_loopback_create');
    _start = lib.lookupFunction<_IntNative, _IntCall>('cabin_loopback_start');
    _rate = lib.lookupFunction<_IntNative, _IntCall>('cabin_loopback_sample_rate');
    _channels = lib.lookupFunction<_IntNative, _IntCall>('cabin_loopback_channels');
    _read = lib.lookupFunction<_ReadNative, _Read>('cabin_loopback_read');
    _destroy = lib.lookupFunction<_DestroyNative, _Destroy>('cabin_loopback_destroy');
  }

  late final _Create _create;
  late final _IntCall _start;
  late final _IntCall _rate;
  late final _IntCall _channels;
  late final _Read _read;
  late final _Destroy _destroy;
  Pointer<Void> _handle = nullptr;
  bool _closed = false;
  int _channelCount = 0;

  @override
  void start() {
    if (_closed || _handle != nullptr) throw StateError('Loopback already used');
    _handle = _create();
    if (_handle == nullptr) throw StateError('Cannot allocate loopback session');
    final result = _start(_handle);
    if (result != 0) throw StateError('Cannot start loopback ($result)');
    _channelCount = _channels(_handle);
    if (_channelCount <= 0 || _channelCount > 32) {
      throw StateError('Unsupported loopback channel count');
    }
  }

  Pointer<Void> get _activeHandle {
    if (_closed || _handle == nullptr) throw StateError('Loopback is not active');
    return _handle;
  }

  @override
  int get sampleRate => _rate(_activeHandle);

  @override
  int get channels => _channelCount;

  @override
  Float32List read(int maxFrames) {
    final handle = _activeHandle;
    if (maxFrames <= 0 || _channelCount <= 0) {
      throw ArgumentError('Invalid frame count');
    }
    final buffer = calloc<Float>(maxFrames * _channelCount);
    try {
      final count = _read(handle, buffer, maxFrames);
      if (count < 0) throw StateError('Loopback capture failed ($count)');
      if (count > maxFrames) throw StateError('Invalid loopback frame count');
      // Copy before freeing native memory; consumers may retain this packet.
      return Float32List.fromList(buffer.asTypedList(count * _channelCount));
    } finally {
      calloc.free(buffer);
    }
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    if (_handle != nullptr) {
      _destroy(_handle);
      _handle = nullptr;
    }
  }
}
