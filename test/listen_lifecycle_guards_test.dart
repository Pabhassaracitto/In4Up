// test/listen_lifecycle_guards_test.dart
//
// LISTEN-LRC-001 regression: provider listeners must never crash the app
// with "setState() called during build" when an async player tick lands
// mid-frame. These tests pin the SafeSetStateMixin behavior (defer during
// build, apply directly when idle, drop callbacks after dispose).

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/utils/safe_set_state.dart';

void main() {
  group('listenShouldDeferSetState', () {
    testWidgets('true during build, false when idle', (tester) async {
      var duringBuild = false;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            duringBuild = listenShouldDeferSetState();
            return const SizedBox.shrink();
          },
        ),
      );
      expect(duringBuild, isTrue);
      expect(listenShouldDeferSetState(), isFalse);
    });
  });

  group('SafeSetStateMixin', () {
    testWidgets('safeSetState during build does not throw and applies',
        (tester) async {
      await tester.pumpWidget(const _DeferProbe());
      // Build ran; the mutation was deferred, so the old label is visible.
      expect(find.text('pending'), findsOneWidget);
      // A raw setState() here would have thrown during the first pump.
      await tester.pump();
      expect(find.text('applied'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('safeSetState when idle applies on next pump', (tester) async {
      final key = GlobalKey<_DeferProbeState>();
      await tester.pumpWidget(_DeferProbe(key: key, applyInBuild: false));
      expect(find.text('pending'), findsOneWidget);

      key.currentState!.trigger('now');
      await tester.pump();
      expect(find.text('now'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('runPostFrame is dropped after dispose', (tester) async {
      final key = GlobalKey<_DeferProbeState>();
      await tester.pumpWidget(_DeferProbe(key: key, applyInBuild: false));
      key.currentState!.triggerPostFrame('late');
      // Dispose the probe before the frame runs.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(find.text('late'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}

class _DeferProbe extends StatefulWidget {
  final bool applyInBuild;

  const _DeferProbe({super.key, this.applyInBuild = true});

  @override
  State<_DeferProbe> createState() => _DeferProbeState();
}

class _DeferProbeState extends State<_DeferProbe> with SafeSetStateMixin {
  var _label = 'pending';
  var _requested = false;

  void trigger(String value) => safeSetState(() => _label = value);

  void triggerPostFrame(String value) =>
      runPostFrame(() => _label = value);

  @override
  Widget build(BuildContext context) {
    if (widget.applyInBuild && !_requested) {
      _requested = true;
      safeSetState(() => _label = 'applied');
    }
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(_label),
    );
  }
}
