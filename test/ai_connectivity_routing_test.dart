// YT-AUDIT-06 (IN4-104) — Định tuyến AI theo LOẠI MẠNG.
//
// Yêu cầu owner (2026-10-20):
//   "Luôn ưu tiên mạng nếu dùng wifi; còn nếu phát hiện dùng mạng di động thì
//    ưu tiên cục bộ, nhưng nếu không thành công thì qua mạng."
//
// Trước đây `planLlmRoute()` chỉ có 3 mode TĨNH và không hề biết wifi hay 4G.
// Test này pin phần THUẦN (`resolveRouteMode` / `classifyConnectivity`) —
// không cần thiết bị, không cần plugin, không gọi mạng.
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up_ai/in4up_ai.dart';

void main() {
  group('resolveRouteMode — auto theo loại mạng', () {
    test('wifi ⇒ onlineFirst (ưu tiên mạng, hỏng mới local)', () {
      expect(
        resolveRouteMode(AiRouteMode.auto, AiNetworkKind.wifi),
        AiRouteMode.onlineFirst,
      );
    });

    test('mạng di động ⇒ offlineFirst (máy trước, hỏng mới qua mạng)', () {
      expect(
        resolveRouteMode(AiRouteMode.auto, AiNetworkKind.mobile),
        AiRouteMode.offlineFirst,
      );
    });

    test('không có mạng ⇒ offlineOnly (tuyệt đối không gọi API)', () {
      expect(
        resolveRouteMode(AiRouteMode.auto, AiNetworkKind.none),
        AiRouteMode.offlineOnly,
      );
    });
  });

  group('resolveRouteMode — tôn trọng lựa chọn rõ ràng của người dùng', () {
    test('3 mode cũ đi qua NGUYÊN VẸN ở mọi loại mạng', () {
      for (final kind in AiNetworkKind.values) {
        for (final mode in const [
          AiRouteMode.offlineFirst,
          AiRouteMode.onlineFirst,
          AiRouteMode.offlineOnly,
        ]) {
          expect(
            resolveRouteMode(mode, kind),
            mode,
            reason: '$mode trên $kind không được bị auto ghi đè',
          );
        }
      }
    });
  });

  group('classifyConnectivity — rút gọn ConnectivityResult', () {
    test('rỗng / none ⇒ none', () {
      expect(classifyConnectivity(const []), AiNetworkKind.none);
      expect(
        classifyConnectivity([ConnectivityResult.none]),
        AiNetworkKind.none,
      );
    });

    test('wifi / ethernet ⇒ wifi', () {
      expect(
        classifyConnectivity([ConnectivityResult.wifi]),
        AiNetworkKind.wifi,
      );
      expect(
        classifyConnectivity([ConnectivityResult.ethernet]),
        AiNetworkKind.wifi,
      );
    });

    test('mobile ⇒ mobile', () {
      expect(
        classifyConnectivity([ConnectivityResult.mobile]),
        AiNetworkKind.mobile,
      );
    });

    test('wifi + mobile cùng lúc ⇒ ưu tiên wifi (Android hay trả cả hai)', () {
      expect(
        classifyConnectivity([
          ConnectivityResult.mobile,
          ConnectivityResult.wifi,
        ]),
        AiNetworkKind.wifi,
      );
    });

    test('none + wifi ⇒ wifi (phần tử none không được át wifi)', () {
      expect(
        classifyConnectivity([
          ConnectivityResult.none,
          ConnectivityResult.wifi,
        ]),
        AiNetworkKind.wifi,
      );
    });
  });

  group('ghép với planLlmRoute — route THẬT', () {
    test('wifi ⇒ [remote, local]', () {
      final plan = planLlmRoute(
        mode: resolveRouteMode(AiRouteMode.auto, AiNetworkKind.wifi),
        remoteAvailable: true,
        localModelReady: true,
      );
      expect(plan.remoteFirst, isTrue);
      expect(plan.stops, [AiLlmRouteStop.remote, AiLlmRouteStop.local]);
    });

    test('4G + có model local ⇒ [local, remote] (máy trước)', () {
      final plan = planLlmRoute(
        mode: resolveRouteMode(AiRouteMode.auto, AiNetworkKind.mobile),
        remoteAvailable: true,
        localModelReady: true,
      );
      expect(plan.remoteFirst, isFalse);
      expect(plan.stops, [AiLlmRouteStop.local, AiLlmRouteStop.remote]);
      // "nếu không thành công thì qua mạng" ⇒ remote VẪN có mặt.
      expect(plan.usesRemote, isTrue);
    });

    test('4G + chưa có model local ⇒ [remote, local] (API là đường duy nhất)',
        () {
      final plan = planLlmRoute(
        mode: resolveRouteMode(AiRouteMode.auto, AiNetworkKind.mobile),
        remoteAvailable: true,
        localModelReady: false,
      );
      expect(plan.remoteFirst, isTrue);
      expect(plan.stops, [AiLlmRouteStop.remote, AiLlmRouteStop.local]);
    });

    test('không mạng ⇒ [local], KHÔNG có stop remote', () {
      final plan = planLlmRoute(
        mode: resolveRouteMode(AiRouteMode.auto, AiNetworkKind.none),
        remoteAvailable: true,
        localModelReady: true,
      );
      expect(plan.usesRemote, isFalse,
          reason: 'không mạng ⇒ tuyệt đối không gọi API');
      expect(plan.stops, [AiLlmRouteStop.local]);
    });
  });

  group('AiRoutingPrefs — auto là mặc định mới', () {
    test('modeOf mặc định trả auto', () {
      const prefs = AiRoutingPrefs();
      for (final cap in AiRouteCapability.values) {
        expect(prefs.modeOf(cap), AiRouteMode.auto);
      }
    });

    test('auto sống sót qua JSON round-trip', () {
      const prefs = AiRoutingPrefs(
        modes: {AiRouteCapability.chat: AiRouteMode.auto},
      );
      final decoded = AiRoutingPrefs.fromJson(prefs.toJson());
      expect(decoded.modeOf(AiRouteCapability.chat), AiRouteMode.auto);
    });
  });
}
