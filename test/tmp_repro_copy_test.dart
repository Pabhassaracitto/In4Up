// TẠM THỜI — repro pattern copy (openRead + close). XÓA SAU KHI CHẨN ĐOÁN.
import 'dart:io';

// ignore: unused_element
Future<void> _copyPattern(File src) async {
  final rs = src.openRead();
  await rs.close();
}

void main() {}
