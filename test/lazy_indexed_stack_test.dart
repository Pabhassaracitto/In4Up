import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/widgets/lazy_indexed_stack.dart';

void main() {
  testWidgets('mounts only visited modes and retains them across switches', (tester) async {
    final builds = [0, 0, 0];
    Widget stack(int index) => Directionality(
          textDirection: TextDirection.ltr,
          child: LazyIndexedStack(index: index, children: [
            for (var i = 0; i < 3; i++)
              (_) {
                builds[i]++;
                return Text('mode $i');
              },
          ]),
        );
    await tester.pumpWidget(stack(0));
    expect(builds, [1, 0, 0]);
    await tester.pumpWidget(stack(1));
    expect(builds[2], 0);
    expect(find.text('mode 0', skipOffstage: false), findsOneWidget);
    expect(find.text('mode 1'), findsOneWidget);
    await tester.pumpWidget(stack(2));
    expect(find.text('mode 2'), findsOneWidget);
    expect(find.text('mode 0', skipOffstage: false), findsOneWidget);
  });
}
