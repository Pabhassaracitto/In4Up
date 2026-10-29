import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/video/services/video_device_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('in4up/textlib');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('unexpected scan failure is not mistaken for an empty folder', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'IO_ERROR');
    });
    await expectLater(VideoDeviceChannel.scanTree('content://test/tree/root'),
        throwsA(isA<VideoScanException>()));
  });

  test('an actually empty folder is a successful empty result', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => <dynamic>[]);
    expect(await VideoDeviceChannel.scanTree('content://test/tree/root'), isEmpty);
  });
}
