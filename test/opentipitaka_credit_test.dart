import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/tipitaka/widgets/opentipitaka_credit.dart';

void main() {
  test('credit dùng đúng tên và URL chính thức, không suy diễn đối tác',
      () async {
    expect(kOpenTipitakaUrl, 'https://www.opentipitaka.org/');
    final uri = Uri.parse(kOpenTipitakaUrl);
    expect(uri.host, 'www.opentipitaka.org');
    expect(uri.scheme, 'https');
  });

  testWidgets('hiện gọn dưới dạng link, bấm gọi launchUrl', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: OpenTipitakaCredit())),
    );
    expect(find.byKey(const Key('opentipitaka-credit-link')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
