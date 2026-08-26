// TẠM THỜI — test File.open() sync. XÓA SAU.
import 'dart:io';

// ignore: unused_element
Future<void> _copyPattern2(File src) async {
  final rs = src.open();
  await rs.close();
}

void main() {}
