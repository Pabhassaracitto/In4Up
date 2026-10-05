import 'dart:io';

import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

bool _ffiInitialized = false;

/// Configure the database factory before the first dictionary DB is opened.
///
/// This is deliberately lazy: importing this feature must not initialize a
/// native SQLite library on Android/iOS.  On Windows and Linux, however,
/// calling `sqflite.openDatabase` directly uses the mobile-only factory and
/// fails at runtime.  `sqflite_common_ffi` is the supported desktop backend.
void ensureDictionaryDatabaseFactory() {
  if (!Platform.isWindows && !Platform.isLinux) return;
  if (_ffiInitialized) return;

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  _ffiInitialized = true;
}
