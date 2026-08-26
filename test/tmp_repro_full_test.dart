// TẠM THỜI — method hoàn chỉnh. XÓA SAU.
import 'dart:io';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ignore: unused_element
Future<void> _copyFileWithProgress({
  required File src,
  required File dest,
  void Function(double progress)? onProgress,
}) async {
  final total = await src.length();
  final rs = await src.open();
  try {
    final ws = await dest.openWrite();
    try {
      var copied = 0;
      final buffer = Uint8List(8 * 1024 * 1024);
      while (true) {
        final n = await rs.readInto(buffer, 0, buffer.length);
        if (n == 0) break;
        ws.add(buffer.sublist(0, n));
        copied += n;
        if (total > 0) onProgress?.call(copied / total);
      }
      onProgress?.call(1.0);
    } finally {
      await ws.close();
    }
  } finally {
    await rs.close();
  }
}

void main() {}
