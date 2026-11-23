// test/great_library/contribute_wizard_test.dart
//
// GLIB-006 — widget test wizard: 3 bước, nguồn thủ công thêm từ, cam kết
// bản quyền bắt buộc, gửi thành công → onSubmitted + record local pending.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:in4up/l10n/app_localizations.dart';
import 'package:in4up/features/great_library/models/pack_manifest.dart';
import 'package:in4up/features/great_library/services/contribution_store.dart';
import 'package:in4up/features/great_library/services/pack_contribution_service.dart';
import 'package:in4up/features/great_library/services/pack_storage_backend.dart';
import 'package:in4up/features/great_library/ui/contribute_wizard_screen.dart';
import 'package:in4up/providers/vocabulary_provider.dart';
import 'package:provider/provider.dart';

class _FakeStorage implements PackStorageBackend {
  @override
  String get backendId => 'firebase';
  @override
  Future<Uint8List> download(PackStorageRef ref, {int? start, int? end}) =>
      throw UnimplementedError();
  @override
  Future<int> contentLength(PackStorageRef ref) => throw UnimplementedError();
  @override
  Future<void> upload(PackStorageRef ref, List<int> bytes,
      {void Function(int, int)? onProgress}) async {}
  @override
  Uri publicUrl(PackStorageRef ref) => Uri.parse('https://x/${ref.path}');
}

class _FakeTransport implements ContributionTransport {
  @override
  Future<String> submitContribution({
    required String packId,
    required Map<String, dynamic> manifestJson,
    required String storageBackend,
    required String storagePath,
    required int zipBytes,
    required String sha256,
  }) async =>
      'contrib_$packId';
}

PackContributionService _service(MemoryContributionStore store) =>
    PackContributionService(
      store: store,
      storage: _FakeStorage(),
      transport: _FakeTransport(),
      authorUid: 'u1',
      authorName: 'Tester',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('in4up_glib006_test');
    Hive.init(directory.path);
    await VocabularyProvider.ensureBoxOpen();
  });

  testWidgets('wizard 3 bước: soạn tay → metadata → cam kết → gửi thành công',
      (tester) async {
    final store = MemoryContributionStore();
    var submitted = false;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('vi'),
      home: ChangeNotifierProvider<VocabularyProvider>(
        create: (_) => VocabularyProvider(),
        child: ContributeWizardScreen(
          service: _service(store),
          onSubmitted: () => submitted = true,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Bước 1: chọn "Soạn mới thủ công" (RadioListTile value=false).
    await tester.tap(find.byWidgetPredicate(
        (w) => w is RadioListTile<bool> && w.value == false));
    await tester.pumpAndSettle();
    // Nhập từ + nghĩa (2 TextField đầu của form thủ công).
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'apple');
    await tester.enterText(fields.at(1), 'quả táo');
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pumpAndSettle();

    // Continue từng bước qua key (Stepper dựng đủ 3 cụm controls).
    await tester.tap(find.byKey(const ValueKey('gl_wizard_continue_0')));
    await tester.pumpAndSettle();

    // Bước 2: nhập tên pack (TextField đầu trong bước metadata).
    await tester.enterText(find.byType(TextField).at(0), 'Pack thử');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('gl_wizard_continue_1')));
    await tester.pumpAndSettle();

    // Bước 3: tick cam kết bản quyền rồi gửi.
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('gl_wizard_continue_2')));
    await tester.pumpAndSettle();

    expect(submitted, isTrue, reason: 'records=${store.all().length}');
    expect(store.all().length, 1);
    expect(store.all().single.status, 'pending');
  });
}
