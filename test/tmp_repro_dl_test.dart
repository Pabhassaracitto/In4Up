// TẠM THỜI — repro pattern download với imports của loader. XÓA SAU.
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
Future<void> _dlPattern(File destFile) async {
  final sink = destFile.openWrite();
  sink.add([1]);
  await sink.close();
}

void main() {}
