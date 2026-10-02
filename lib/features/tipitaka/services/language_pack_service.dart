import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:in4up/features/tipitaka/models/language_pack.dart';

/// Downloads and extracts Pa-Auk Tipiṭaka language packages.
///
/// Downloads are explicit user actions; this service is never called during
/// app startup. The extracted source DB is handed to the in-app database
/// importer by the screen, where it is normalized or merged directly.
class TipitakaLanguagePackService {
  const TipitakaLanguagePackService();

  Future<TipitakaDownloadedPack> download(
    TipitakaLanguagePack pack, {
    void Function(int receivedBytes, int? totalBytes)? onProgress,
  }) async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(documents.path, 'in4up', 'tipitaka', 'packs'));
    await directory.create(recursive: true);

    final archivePath = p.join(directory.path, '${pack.code}.zip');
    final databasePath = p.join(directory.path, '${pack.code}.db');
    final temporaryPath = '$archivePath.part';
    final client = http.Client();

    try {
      final request = http.Request('GET', pack.downloadUri);
      final response = await client.send(request).timeout(
        const Duration(minutes: 10),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Tải gói ${pack.name} thất bại (HTTP ${response.statusCode}).',
          uri: pack.downloadUri,
        );
      }

      final output = File(temporaryPath).openWrite();
      var received = 0;
      await for (final chunk in response.stream) {
        output.add(chunk);
        received += chunk.length;
        onProgress?.call(received, response.contentLength);
      }
      await output.close();

      final archiveFile = File(archivePath);
      if (await archiveFile.exists()) await archiveFile.delete();
      await File(temporaryPath).rename(archivePath);

      final extracted = await _extractDatabase(
        archivePath,
        databasePath,
        directory,
      );
      return TipitakaDownloadedPack(
        pack: pack,
        archivePath: archivePath,
        databasePath: extracted,
        bytes: received,
      );
    } finally {
      client.close();
      final partial = File(temporaryPath);
      if (await partial.exists()) await partial.delete();
    }
  }

  /// Returns the DB inside a zip, or the archive itself when the server
  /// returned a raw SQLite file. Only the basename is written, preventing a
  /// malicious zip entry from escaping the app's pack directory.
  Future<String?> _extractDatabase(
    String archivePath,
    String destinationPath,
    Directory outputDirectory,
  ) async {
    final file = File(archivePath);
    final header = await file.open();
    final firstBytes = await header.read(4);
    await header.close();

    // SQLite files begin with "SQLite format 3\0". A raw DB can be sent
    // straight to the in-app importer even if the URL has a .zip suffix.
    final isZip = firstBytes.length >= 4 &&
        firstBytes[0] == 0x50 &&
        firstBytes[1] == 0x4b &&
        firstBytes[2] == 0x03 &&
        firstBytes[3] == 0x04;
    if (!isZip) {
      final rawPath = p.setExtension(destinationPath, '.sqlite');
      await file.copy(rawPath);
      return rawPath;
    }

    final input = InputFileStream(archivePath);
    try {
      final archive = ZipDecoder().decodeStream(input);
      for (final entry in archive) {
        if (!entry.isFile) continue;
        final name = entry.name.toLowerCase();
        if (!(name.endsWith('.db') || name.endsWith('.sqlite'))) continue;

        final outputPath = p.join(outputDirectory.path, p.basename(destinationPath));
        final output = OutputFileStream(outputPath);
        entry.writeContent(output);
        output.closeSync();
        return outputPath;
      }
    } finally {
      input.closeSync();
    }
    return null;
  }
}
