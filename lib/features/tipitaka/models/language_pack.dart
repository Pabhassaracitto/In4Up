/// A downloadable language database published by the OpenTipitaka/Pa-Auk
/// database collection.
///
/// The files published by the source are SQLite databases wrapped in a zip
/// archive. They are source databases, not necessarily the normalized
/// `tipitaka.sqlite` file consumed by the app. The importer keeps that
/// distinction explicit so a downloaded file is never opened as an empty or
/// incompatible application database.
class TipitakaLanguagePack {
  final String code;
  final String name;
  final String nameVi;
  final String languageCode;
  final Uri downloadUri;

  const TipitakaLanguagePack({
    required this.code,
    required this.name,
    required this.nameVi,
    required this.languageCode,
    required this.downloadUri,
  });

  bool get isPali => code.startsWith('pali_');
}

class TipitakaDownloadedPack {
  final TipitakaLanguagePack pack;
  final String archivePath;
  final String? databasePath;
  final int bytes;

  const TipitakaDownloadedPack({
    required this.pack,
    required this.archivePath,
    required this.databasePath,
    required this.bytes,
  });

  bool get hasDatabase => databasePath != null;
}
