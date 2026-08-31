import 'package:flutter/material.dart';
import 'package:in4up/features/tipitaka/models/collection.dart';
import 'package:in4up/features/tipitaka/models/book.dart';
import 'package:in4up/features/tipitaka/services/db_service.dart';
import 'package:in4up/features/tipitaka/screens/reader_screen.dart';

class TipitakaLibraryScreen extends StatefulWidget {
  const TipitakaLibraryScreen({super.key});

  @override
  State<TipitakaLibraryScreen> createState() => _TipitakaLibraryScreenState();
}

class _TipitakaLibraryScreenState extends State<TipitakaLibraryScreen> {
  List<TipitakaCollection> collections = [];
  TipitakaCollection? selectedCollection;
  List<TipitakaBook> books = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    // In production, get DB instance from provider or singleton
    // Here we assume DB is already initialized via TipitakaDb.init(path)
    try {
      final db = await TipitakaDb.init('/data/user/0/com.in2up/databases');
      final cols = await TipitakaDb.getCollections(db);
      setState(() => collections = cols);
    } catch (e) {
      // DB not ready; show placeholder
      setState(() {
        collections = [
          const TipitakaCollection(id: 1, namePali: 'Vinaya Piṭaka', nameEn: 'Vinaya Pitaka', nameVi: 'Tạng Luật', orderIndex: 1),
          const TipitakaCollection(id: 2, namePali: 'Sutta Piṭaka', nameEn: 'Sutta Pitaka', nameVi: 'Tạng Kinh', orderIndex: 2),
          const TipitakaCollection(id: 3, namePali: 'Abhidhamma Piṭaka', nameEn: 'Abhidhamma Pitaka', nameVi: 'Tạng Vi Diệu Pháp', orderIndex: 3),
        ];
      });
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _selectCollection(TipitakaCollection col) async {
    setState(() => selectedCollection = col);
    try {
      final db = await TipitakaDb.init('/data/user/0/com.in2up/databases');
      final bs = await TipitakaDb.getBooksByCollection(db, col.id);
      setState(() => books = bs);
    } catch (_) {
      // Fallback placeholder books for DN, MN, SN, AN, Khuddaka
      setState(() {
        books = [
          TipitakaBook(id: 1, collectionId: col.id, code: 'DN', namePali: 'Dīgha Nikāya', nameEn: 'Long Discourses', nameVi: 'Trường A-hàm', orderIndex: 1),
          TipitakaBook(id: 2, collectionId: col.id, code: 'MN', namePali: 'Majjhima Nikāya', nameEn: 'Middle Discourses', nameVi: 'Trung A-hàm', orderIndex: 2),
          TipitakaBook(id: 3, collectionId: col.id, code: 'SN', namePali: 'Saṃyutta Nikāya', nameEn: 'Connected Discourses', nameVi: 'Tương Ưng A-hàm', orderIndex: 3),
          TipitakaBook(id: 4, collectionId: col.id, code: 'AN', namePali: 'Aṅguttara Nikāya', nameEn: 'Numerical Discourses', nameVi: 'Tăng Chi A-hàm', orderIndex: 4),
        ];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tipiṭaka Library')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ListView.builder(
                    itemCount: collections.length,
                    itemBuilder: (ctx, i) {
                      final c = collections[i];
                      final isSel = selectedCollection?.id == c.id;
                      return ListTile(
                        selected: isSel,
                        title: Text(c.nameEn.isNotEmpty ? c.nameEn : c.namePali),
                        subtitle: Text(c.nameVi),
                        onTap: () => _selectCollection(c),
                      );
                    },
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: books.isEmpty
                      ? const Center(child: Text('Chọn Piṭaka để xem sách'))
                      : ListView.builder(
                          itemCount: books.length,
                          itemBuilder: (ctx, i) {
                            final b = books[i];
                            return ListTile(
                              title: Text('${b.code} - ${b.nameVi.isNotEmpty ? b.nameVi : b.nameEn}'),
                              subtitle: Text(b.namePali),
                              onTap: () {
                                // Push reader with first segment placeholder
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TipitakaReaderScreen(bookId: b.id, bookCode: b.code),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}