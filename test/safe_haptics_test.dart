import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/platform/safe_haptics.dart';

void main() {
  test('desktop and web do not invoke the unsupported haptic channel', () async {
    for (final platform in const [
      TargetPlatform.windows,
      TargetPlatform.macOS,
      TargetPlatform.linux,
      TargetPlatform.fuchsia,
    ]) {
      var called = false;
      await SafeHaptics.runForPlatform(
        () async {
          called = true;
        },
        platform: platform,
      );
      expect(called, isFalse, reason: '$platform has no haptic backend');
    }

    var webCalled = false;
    await SafeHaptics.runForPlatform(
      () async {
        webCalled = true;
      },
      platform: TargetPlatform.android,
      isWeb: true,
    );
    expect(webCalled, isFalse);
  });

  test('mobile haptics run, but a missing plugin cannot break the action',
      () async {
    var called = false;
    await SafeHaptics.runForPlatform(
      () async {
        called = true;
      },
      platform: TargetPlatform.android,
    );
    expect(called, isTrue);

    await expectLater(
      SafeHaptics.runForPlatform(
        () async => throw MissingPluginException('no haptic implementation'),
        platform: TargetPlatform.iOS,
      ),
      completes,
    );
  });
}
