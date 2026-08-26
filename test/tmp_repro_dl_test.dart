// TẠM THỜI — repro pattern download (openWrite + add + close). XÓA SAU.
import 'dart:io';

// ignore: unused_element
Future<void> _dlPattern(File destFile) async {
  final sink = destFile.openWrite();
  sink.add([1]);
  await sink.close();
}

void main() {}
