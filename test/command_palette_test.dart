import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:in4up/widgets/shell/command_palette.dart';

void main() {
  test('command filtering matches labels and keywords', () {
    const command = I4uCommand(
      id: 'open-reader',
      label: 'Mở Đọc',
      icon: Icons.menu_book,
      keywords: ['read', 'source'],
    );
    expect(command.matches('source'), isTrue);
    expect(command.matches('audio'), isFalse);
    expect(command.matches(''), isTrue);
  });
}
