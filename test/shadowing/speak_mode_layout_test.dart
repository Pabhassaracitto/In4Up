import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/shadowing/models/shadowing_preset.dart';
import 'package:in4up/features/shadowing/models/shadowing_result.dart';
import 'package:in4up/features/shadowing/providers/shadowing_provider.dart';
import 'package:in4up/providers/player_provider.dart';
import 'package:in4up/screens/listen_mode/speak_mode_screen.dart';
import 'package:provider/provider.dart';

/// PSRC-225 — tab Nói thu gọn: Shadowing Mode đứng đầu, các khối bung/gộp
/// giữ trạng thái khi rebuild, vừa màn 360×640 không cần cuộn.
///
/// Không dựng `ShadowingProvider` thật: SpeakModeScreen chỉ đọc các getter
/// thống kê/preset/lịch sử ở nhánh idle (chưa có audio → `_EmptyAudioCard`,
/// không render `ShadowingWidget` nên không cần UnderstandProvider).
class _PlayerStub extends ChangeNotifier implements PlayerProvider {
  @override
  String? get currentSongPath => null;

  @override
  String? get currentSongTitle => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ShadowingStub extends ChangeNotifier implements ShadowingProvider {
  @override
  int? get lastScorePercent => null;

  @override
  int? get bestScorePercent => null;

  @override
  int get totalPracticeCount => 0;

  @override
  String get activePresetLabel => 'Tùy chỉnh';

  @override
  bool get activePresetLabelIsGenerated => true;

  @override
  List<ShadowingPreset> get builtInPresets => const [];

  @override
  List<ShadowingPreset> get customPresets => const [];

  @override
  List<ShadowingHistoryEntry> get savedHistory => const [];

  @override
  double get averageScorePercent => 0.0;

  @override
  double get playbackSpeed => 1.0;

  @override
  int get repeatCount => 1;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _PlayerStub player;
  late _ShadowingStub shadowing;

  setUp(() {
    player = _PlayerStub();
    shadowing = _ShadowingStub();
  });

  tearDown(() {
    player.dispose();
    shadowing.dispose();
  });

  Widget app() => MultiProvider(
        providers: [
          ChangeNotifierProvider<PlayerProvider>.value(value: player),
          ChangeNotifierProvider<ShadowingProvider>.value(value: shadowing),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SpeakModeScreen(
              onOpenYouGlish: () {},
              onOpenQuickActions: () {},
              onOpenUnderstand: () {},
            ),
          ),
        ),
      );

  test('source: Shadowing section đứng đầu, có trạng thái bung/gộp', () {
    final source =
        File('lib/screens/listen_mode/speak_mode_screen.dart').readAsStringSync();

    expect(source, contains("Key('speak-shadowing-section')"),
        reason: 'Shadowing phải được bọc key section riêng');
    expect(source, contains('const ShadowingWidget()'),
        reason: 'ShadowingWidget thật phải nằm trong section đầu tiên');
    final shadowingIdx = source.indexOf("Key('speak-shadowing-section')");
    final heroIdx = source.indexOf('_HeroCard(');
    expect(shadowingIdx, lessThan(heroIdx),
        reason: 'Shadowing phải xuất hiện trước hero trong Column');

    expect(source, contains('class SpeakModeScreen extends StatefulWidget'),
        reason: 'trạng thái bung/gộp phải sống trong State');
    expect(source, contains('_openSections'),
        reason: 'cần map trạng thái từng khối');
    expect('AnimatedSize('.allMatches(source).length, greaterThanOrEqualTo(4),
        reason: 'các khối bọc AnimatedSize để bung/gộp có animation');

    for (final id in const ['hero', 'stats', 'preset', 'history']) {
      expect(source, contains('speak-section-$id-header'),
          reason: 'khối $id cần header có key để test bung/gộp');
    }
    // Hai _TipCard nhận id khác nhau → key header sinh động từ id.
    expect(source, contains(r'speak-section-$id-header'),
        reason: 'TipCard phải sinh key header từ id');
    expect(source, contains("'tipFlow'"), reason: 'thiếu _TipCard tipFlow');
    expect(source, contains("'tipDesign'"), reason: 'thiếu _TipCard tipDesign');
  });

  testWidgets('360×640: Shadowing nằm trong màn hình đầu, không cần cuộn',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    final shadowingSection = find.byKey(const Key('speak-shadowing-section'));
    expect(shadowingSection, findsOneWidget);

    final top = tester.getTopLeft(shadowingSection).dy;
    expect(top, greaterThanOrEqualTo(0));
    expect(top, lessThan(640),
        reason: 'Shadowing phải thấy ngay ở màn hình đầu khi cuộn 0');

    final heroHeader = find.byKey(const Key('speak-section-hero-header'));
    expect(heroHeader, findsOneWidget);
    expect(tester.getTopLeft(heroHeader).dy, greaterThan(top),
        reason: 'hero phải nằm DƯỚI Shadowing');
  });

  testWidgets('gộp mặc định, tap để bung, giữ trạng thái qua rebuild',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // Mặc định gộp: thân các khối chưa render.
    expect(find.byKey(const Key('speak-stats-body')), findsNothing);
    expect(find.byKey(const Key('speak-preset-body')), findsNothing);
    expect(find.byKey(const Key('speak-history-body')), findsNothing);

    // Bung "Thống kê".
    final statsHeader = find.byKey(const Key('speak-section-stats-header'));
    await tester.ensureVisible(statsHeader);
    await tester.pumpAndSettle();
    await tester.tap(statsHeader);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('speak-stats-body')), findsOneWidget);

    // Rebuild toàn màn hình (widget mới, cùng providers) — trạng thái giữ.
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('speak-stats-body')),
      findsOneWidget,
      reason: 'trạng thái bung phải sống trong State, không reset khi rebuild',
    );

    // Gộp lại.
    await tester.ensureVisible(statsHeader);
    await tester.pumpAndSettle();
    await tester.tap(statsHeader);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('speak-stats-body')), findsNothing);
  });
}
