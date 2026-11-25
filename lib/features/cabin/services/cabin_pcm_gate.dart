import 'dart:typed_data';

/// While the app speaks, replace loopback with silence rather than feeding its
/// own translation into ASR. This deliberately also silences the source.
Uint8List gateCabinSystemPcm(Uint8List pcm, {required bool mute}) =>
    mute ? Uint8List(pcm.length) : pcm;
