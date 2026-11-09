import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/tipitaka/models/book.dart';
import 'package:in4up/features/tipitaka/models/collection.dart';
import 'package:in4up/features/tipitaka/services/library_state_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('catalogue snapshot persists only for the matching database identity',
      () async {
    final snapshot = TipitakaLibrarySnapshot(
      databaseIdentity: 'tipitaka:test.sqlite:100:1234',
      collections: const [
        TipitakaCollection(
          id: 8,
          namePali: 'Sutta Piṭaka',
          nameEn: 'Sutta Piṭaka',
          nameVi: 'Tạng Kinh',
          orderIndex: 1,
        ),
      ],
      books: const [
        TipitakaBook(
          id: 19,
          collectionId: 8,
          code: 'MN01M_MUL',
          namePali: 'Majjhima Nikāya',
          nameEn: 'Middle Length Discourses',
          nameVi: 'Trung Bộ Kinh',
          orderIndex: 2,
          metadataJson: '{"source_table":"mn01m_mul"}',
        ),
      ],
      languages: const {'pi', 'en', 'vi'},
    );

    await TipitakaLibraryStateStore.saveSnapshot(snapshot);

    final restored = await TipitakaLibraryStateStore.loadSnapshot(
      'tipitaka:test.sqlite:100:1234',
    );
    expect(restored?.collections.single.nameVi, 'Tạng Kinh');
    expect(restored?.books.single.displayTitle('vi'), 'Trung Bộ Kinh');
    expect(restored?.books.single.catalogSection,
        TipitakaCatalogSection.canonical);
    expect(restored?.languages, {'pi', 'en', 'vi'});
    expect(
      await TipitakaLibraryStateStore.loadSnapshot('tipitaka:new.sqlite:200:2'),
      isNull,
    );
  });

  test('expanded index nodes survive collapse/reopen and app restart', () async {
    const databaseIdentity = 'tipitaka:test.sqlite:100:1234';
    await TipitakaLibraryStateStore.setNodeExpanded(
        databaseIdentity, 'section:canonical', true);
    await TipitakaLibraryStateStore.setNodeExpanded(
        databaseIdentity, 'collection:canonical:8', true);
    await TipitakaLibraryStateStore.setNodeExpanded(
        databaseIdentity, 'book:19', true);
    await TipitakaLibraryStateStore.saveExpandedNodes(databaseIdentity, {
      'section:canonical',
      'collection:canonical:8',
      'book:19',
    });

    expect(await TipitakaLibraryStateStore.loadExpandedNodes(databaseIdentity), {
      'section:canonical',
      'collection:canonical:8',
      'book:19',
    });
    expect(
      await TipitakaLibraryStateStore.loadExpandedNodes('tipitaka:other.sqlite'),
      isNull,
    );

    await TipitakaLibraryStateStore.setNodeExpanded(
        databaseIdentity, 'book:19', false);
    expect(await TipitakaLibraryStateStore.loadExpandedNodes(databaseIdentity), {
      'section:canonical',
      'collection:canonical:8',
    });
  });
}
