// TẠM THỜI — test File.open() async. XÓA SAU.
import 'dart:io';

// ignore: unused_element
Future<void> _copyPattern3(File src) async {
  final rs = await src.open();
  await rs.close();
}

void main() {}
