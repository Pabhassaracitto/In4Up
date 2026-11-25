// test/mascot/shell_action_hub_test.dart
//
// MASCOT-001 — test cầu thực thi ShellActionHub + hợp đồng mở rộng của
// ShellNavigationRequest (PLAN-050 §5, ADR-0036 D3). Không cần thiết bị.

import 'package:flutter_test/flutter_test.dart';

import 'package:in4up/core/navigation/shell_navigation_request.dart';
import 'package:in4up/features/mascot/mascot_intent_registry.dart';
import 'package:in4up/features/mascot/shell_action_hub.dart';

void main() {
  tearDown(() {
    ShellNavigationRequest.pending.value = null;
    ShellNavigationRequest.pendingToolId.value = null;
  });

  ShellActionCallbacks makeCallbacks({
    void Function(int)? onListen,
    void Function(int)? onRead,
    void Function(String)? onTool,
  }) {
    return ShellActionCallbacks(
      onSetListenMode: onListen ?? (_) {},
      onSetReadMode: onRead ?? (_) {},
      onHandleTool: onTool == null
          ? (String id) async {}
          : (String id) async => onTool(id),
    );
  }

  group('ShellNavigationRequest — hợp đồng mở rộng', () {
    test('openRead/openListen cũ giữ nguyên hành vi', () {
      ShellNavigationRequest.openRead();
      expect(ShellNavigationRequest.pending.value,
          ShellNavigationTarget.read);
      ShellNavigationRequest.openListen();
      expect(ShellNavigationRequest.pending.value,
          ShellNavigationTarget.listen);
    });

    test('openHome/openUnderstand/openRemember phát đúng đích', () {
      ShellNavigationRequest.openHome();
      expect(
          ShellNavigationRequest.pending.value, ShellNavigationTarget.home);
      ShellNavigationRequest.openUnderstand();
      expect(ShellNavigationRequest.pending.value,
          ShellNavigationTarget.understand);
      ShellNavigationRequest.openRemember();
      expect(ShellNavigationRequest.pending.value,
          ShellNavigationTarget.remember);
    });

    test('openTool đặt payload toolId TRƯỚC khi phát pending', () {
      ShellNavigationRequest.openTool('tipitaka');
      expect(ShellNavigationRequest.pending.value,
          ShellNavigationTarget.tool);
      expect(ShellNavigationRequest.pendingToolId.value, 'tipitaka');
    });
  });

  group('ShellActionHub', () {
    test('mode → callback đúng sub-mode index', () async {
      int? listen;
      int? read;
      final callbacks = makeCallbacks(
        onListen: (i) => listen = i,
        onRead: (i) => read = i,
      );
      ShellActionHub.instance.attach(callbacks);

      final speak = await ShellActionHub.instance
          .execute(MascotIntentRegistry.byId('mode_speak')!);
      expect(speak.executed, isTrue);
      expect(listen, 1);

      final watch = await ShellActionHub.instance
          .execute(MascotIntentRegistry.byId('mode_watch')!);
      expect(watch.executed, isTrue);
      expect(listen, 2);

      final write = await ShellActionHub.instance
          .execute(MascotIntentRegistry.byId('mode_write')!);
      expect(write.executed, isTrue);
      expect(read, 1);

      final listenMode = await ShellActionHub.instance
          .execute(MascotIntentRegistry.byId('mode_listen')!);
      expect(listenMode.executed, isTrue);
      expect(listen, 0);

      ShellActionHub.instance.detach(callbacks);
    });

    test('tool → callback nhận đúng id _handleTool', () async {
      final seen = <String>[];
      final callbacks = makeCallbacks(onTool: seen.add);
      ShellActionHub.instance.attach(callbacks);

      final result = await ShellActionHub.instance
          .execute(MascotIntentRegistry.byId('pdf_reader')!);
      expect(result.executed, isTrue);
      expect(seen, ['pdf_reader']);

      ShellActionHub.instance.detach(callbacks);
    });

    test('tab → phát ShellNavigationRequest, không cần callback', () async {
      final callbacks = makeCallbacks();
      ShellActionHub.instance.attach(callbacks);

      final result = await ShellActionHub.instance
          .execute(MascotIntentRegistry.byId('tab_understand')!);
      expect(result.executed, isTrue);
      expect(ShellNavigationRequest.pending.value,
          ShellNavigationTarget.understand);

      ShellActionHub.instance.detach(callbacks);
    });

    test('chưa gắn hub → không thực thi nhưng không ném', () async {
      // Đảm bảo hub rỗng: gắn rồi gỡ một callbacks dummy.
      final dummy = makeCallbacks();
      ShellActionHub.instance.attach(dummy);
      ShellActionHub.instance.detach(dummy);
      expect(ShellActionHub.instance.isAttached, isFalse);

      final result = await ShellActionHub.instance
          .execute(MascotIntentRegistry.byId('mode_speak')!);
      expect(result.executed, isFalse);
      expect(result.reason, isNotNull);
    });

    test('detach sai thể hiện thì hub vẫn giữ callbacks cũ', () async {
      final first = makeCallbacks();
      final second = makeCallbacks();
      ShellActionHub.instance.attach(first);
      ShellActionHub.instance.detach(second);
      expect(ShellActionHub.instance.isAttached, isTrue);
      ShellActionHub.instance.detach(first);
      expect(ShellActionHub.instance.isAttached, isFalse);
    });

    test('playback P0 chỉ đăng ký — trả executed:false, không gọi tool',
        () async {
      var toolCalled = false;
      final callbacks = makeCallbacks(onTool: (_) => toolCalled = true);
      ShellActionHub.instance.attach(callbacks);

      final result = await ShellActionHub.instance
          .execute(MascotIntentRegistry.byId('playback_play')!);
      expect(result.executed, isFalse);
      expect(result.reason, isNotNull);
      expect(toolCalled, isFalse,
          reason: 'P0 không tự chế đường phát thứ hai (PLAN-050 §9)');

      ShellActionHub.instance.detach(callbacks);
    });
  });
}
