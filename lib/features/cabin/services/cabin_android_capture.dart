import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';

/// Owns one Android MediaProjection capture. Consent is always requested
/// again for each new instance; a cancelled request cannot be reused.
class CabinAndroidCapture {
  CabinAndroidCapture({
    Stream<dynamic> Function()? eventStream,
    Future<dynamic> Function(String method, [Object? arguments])? invoke,
  })  : _events = eventStream ?? _nativeEvents,
        _invoke = invoke ?? _nativeInvoke;

  static const _methods = MethodChannel('in4up/cabin_system_audio');
  static const _channel = EventChannel('in4up/cabin_system_audio_events');
  static Stream<dynamic> _nativeEvents() => _channel.receiveBroadcastStream();
  static Future<dynamic> _nativeInvoke(String method, [Object? arguments]) =>
      _methods.invokeMethod<dynamic>(method, arguments);

  final Stream<dynamic> Function() _events;
  final Future<dynamic> Function(String method, [Object? arguments]) _invoke;
  // Error values rather than completeError avoid unhandled asynchronous errors
  // when consent fails while the start method call is still in flight.
  final _ready = Completer<Object?>();
  final _started = Completer<Object?>();
  StreamSubscription<dynamic>? _subscription;
  StreamController<Uint8List>? _pcm;
  bool _closed = false;
  Future<void>? _closing;
  bool _opened = false;
  bool _consumerAttached = false;
  int _bufferedPackets = 0;

  static Future<bool> isSupported() async =>
      await _methods.invokeMethod<bool>('isSupported') ?? false;
  static Future<bool> hasOverlayPermission() async =>
      await _methods.invokeMethod<bool>('hasOverlayPermission') ?? false;
  static Future<bool> requestOverlayPermission() async =>
      await _methods.invokeMethod<bool>('requestOverlayPermission') ?? false;
  static Future<void> updateCaption(String text) =>
      _methods.invokeMethod<void>('updateCaption', {'text': text});

  Future<Stream<Uint8List>> open({bool overlay = false}) async {
    if (_opened || _closed) throw StateError('Capture session already used');
    _opened = true;
    final pcm = StreamController<Uint8List>(
      onListen: () { _consumerAttached = true; },
      onCancel: close,
    );
    _pcm = pcm;
    _subscription = _events().listen(_onEvent, onError: _onError, onDone: _onDone);
    try {
      final readyError = await _ready.future.timeout(const Duration(seconds: 10));
      if (readyError != null) throw readyError;
      if (_closed) throw StateError('Capture cancelled');
      final accepted = await _invoke('start', {'overlay': overlay});
      if (accepted != true) throw StateError('Capture request was not accepted');
      final startError = await _started.future.timeout(const Duration(minutes: 2));
      if (startError != null) throw startError;
      if (_closed) throw StateError('Capture cancelled');
      return pcm.stream;
    } catch (_) {
      await close();
      rethrow;
    }
  }

  void _onEvent(dynamic event) {
    if (_closed) return;
    if (event == 'ready') {
      if (!_ready.isCompleted) _ready.complete();
    } else if (event == 'started') {
      if (!_started.isCompleted) _started.complete();
    } else if (event is Uint8List && _started.isCompleted) {
      // Limit buffering before Sherpa subscribes, rather than silently losing
      // audio or retaining unbounded data if model initialisation stalls.
      if (!_consumerAttached && ++_bufferedPackets > 30) {
        _onError(StateError('Capture consumer did not start in time'));
        return;
      }
      _pcm?.add(event);
    }
  }

  void _onError(Object error, [StackTrace? stack]) {
    if (_closed) return;
    final trace = stack ?? StackTrace.current;
    if (!_ready.isCompleted) {
      _ready.complete(error);
    } else if (!_started.isCompleted) {
      _started.complete(error);
    } else {
      _pcm?.addError(error, trace);
    }
    unawaited(close());
  }

  void _onDone() {
    if (_closed) return;
    if (!_ready.isCompleted || !_started.isCompleted) {
      _onError(StateError('Capture ended before starting'));
    } else {
      unawaited(close());
    }
  }

  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    _closed = true;
    // Resolve pending awaits when closed explicitly during the consent dialog.
    // Only the currently-awaited completer is completed with an error.
    if (!_ready.isCompleted) {
      _ready.complete(StateError('Capture cancelled'));
    } else if (!_started.isCompleted) {
      _started.complete(StateError('Capture cancelled'));
    }
    try { await _invoke('stop'); } catch (_) {}
    await _subscription?.cancel();
    _subscription = null;
    final pcm = _pcm;
    _pcm = null;
    if (pcm != null && !pcm.isClosed) unawaited(pcm.close());
  }
}
