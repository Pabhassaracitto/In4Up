// TẠM THỜI — test RandomAccessFile.readInto. XÓA SAU.
import 'dart:io';
import 'dart:typed_data';

// ignore: unused_element
Future<void> _p(File src) async {
  final rs = await src.open();
  final buffer = Uint8List(8);
  final n = await rs.readInto(buffer, 0, buffer.length);
  await rs.close();
  // ignore: unused_local_variable
  final int x = n;
}

void main() {}
