/// Platform hook for configuring SQLite on desktop.
///
/// `sqflite` owns the Android/iOS database factory, but it does not provide a
/// Windows/Linux implementation.  The conditional import keeps the FFI
/// implementation out of platforms where it is not needed (and out of web
/// builds that do not support dart:io).
export 'dict_database_platform_stub.dart'
    if (dart.library.io) 'dict_database_platform_io.dart';
