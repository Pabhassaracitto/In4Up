import 'dart:async';

import 'package:in4up/core/language/localized_material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:in4up/features/tipitaka/models/language_pack.dart';
import 'package:in4up/features/tipitaka/screens/tipitaka_task_overlay.dart';
import 'package:in4up/features/tipitaka/services/db_service.dart';
import 'package:in4up/features/tipitaka/services/tipitaka_task_service.dart';

class TipitakaLanguagePackCatalog {
  static const _root =
      'https://dhamma.paauksociety.org/Root/Tipitaka/SqlLite%20Database/';

  static final List<TipitakaLanguagePack> packs = [
    _pack('pali_roman', 'Pāli (Roman)', 'Pāli La-tinh', 'pi', '${_root}pali%20text/tipitaka-roman-pali.db.zip'),
    _pack('vietnamese', 'Vietnamese', 'Tiếng Việt', 'vi', '${_root}vietnamese_tipitaka_translation_data-2026-04-29.db.zip'),
    _pack('english', 'English', 'Tiếng Anh', 'en', '${_root}english_tipitaka_translation_data-2026-04-28.db.zip'),
    _pack('bengali', 'Bengali', 'Bengal', 'bn', '${_root}bengali_tipitaka_translation_data-2026-07-11.db.zip'),
    _pack('chinese', 'Chinese', 'Trung Quốc', 'zh', '${_root}chinese_tipitaka_translation_data-2026-06-20.db.zip'),
    _pack('french', 'French', 'Pháp', 'fr', '${_root}french_tipitaka_translation_data-2026-04-27.db.zip'),
    _pack('german', 'German', 'Đức', 'de', '${_root}german_tipitaka_translation_data-2026-06-03.db.zip'),
    _pack('hindi', 'Hindi', 'Hindi', 'hi', '${_root}hindi_tipitaka_translation_data-2026-04-30.db.zip'),
    _pack('indonesian', 'Indonesian', 'Indonesia', 'id', '${_root}indonesian_tipitaka_translation_data-2026-04-30.db.zip'),
    _pack('japanese', 'Japanese', 'Nhật', 'ja', '${_root}japanese_tipitaka_translation_data-2026-04-27.db.zip'),
    _pack('khmer', 'Khmer', 'Khmer', 'km', '${_root}khmer_tipitaka_translation_data-2026-07-01.db.zip'),
    _pack('korean', 'Korean', 'Hàn', 'ko', '${_root}korean_tipitaka_translation_data-2026-04-25.db.zip'),
    _pack('lao', 'Lao', 'Lào', 'lo', '${_root}lao_tipitaka_translation_data-2026-07-16.db.zip'),
    _pack('marathi', 'Marathi', 'Marathi', 'mr', '${_root}marathi_tipitaka_translation_data-2026-06-16.db.zip'),
    _pack('myanmar', 'Myanmar (Burmese)', 'Miến Điện', 'my', '${_root}myanmar_tipitaka_translation_data-2026-06-24.db.zip'),
    _pack('portuguese', 'Portuguese', 'Bồ Đào Nha', 'pt', '${_root}portuguese_tipitaka_translation_data-2026-07-22.db.zip'),
    _pack('sinhala', 'Sinhala', 'Sinhala', 'si', '${_root}sinhala_tipitaka_translation_data-2026-05-23.db.zip'),
    _pack('spanish', 'Spanish', 'Tây Ban Nha', 'es', '${_root}spanish_tipitaka_translation_data-2026-05-15.db.zip'),
    _pack('thai', 'Thai', 'Thái', 'th', '${_root}thai_tipitaka_translation_data-2026-04-29.db.zip'),
    _pack('tibetan', 'Tibetan', 'Tây Tạng', 'bo', '${_root}tibetan_tipitaka_translation_data-2026-06-22.db.zip'),
    _pack('pali_thai', 'Pāli (Thai)', 'Pāli Thái', 'pi', '${_root}pali%20text/tipitaka-thai-pali.db.zip'),
    _pack('pali_sinhala', 'Pāli (Sinhala)', 'Pāli Sinhala', 'pi', '${_root}pali%20text/tipitaka-sinhala-pali.db.zip'),
    _pack('pali_myanmar', 'Pāli (Myanmar)', 'Pāli Myanmar', 'pi', '${_root}pali%20text/tipitaka-myanmar-pali.db.zip'),
  ];

  static TipitakaLanguagePack _pack(
    String code,
    String name,
    String nameVi,
    String languageCode,
    String url,
  ) => TipitakaLanguagePack(
        code: code,
        name: name,
        nameVi: nameVi,
        languageCode: languageCode,
        downloadUri: Uri.parse(url),
      );
}

class TipsLanguagePackScreen extends StatefulWidget {
  const TipsLanguagePackScreen({super.key});

  @override
  State<TipsLanguagePackScreen> createState() => _TipsLanguagePackScreenState();
}

class _TipsLanguagePackScreenState extends State<TipsLanguagePackScreen> {
  String? _downloadingCode;
  bool _hasPali = false;

  @override
  void initState() {
    super.initState();
    _refreshLanguages();
  }

  Future<void> _refreshLanguages() async {
    try {
      final db = await TipitakaDb.openReady();
      final info = await TipitakaDb.info(db);
      if (mounted) setState(() => _hasPali = info.availableLanguages.contains('pi'));
    } catch (_) {
      if (mounted) setState(() => _hasPali = false);
    }
  }

  String _taskPhaseLabel(BuildContext context, TipitakaTaskPhase phase) {
    return switch (phase) {
      TipitakaTaskPhase.queued => context.uiText('Đang xếp hàng'),
      TipitakaTaskPhase.downloading => context.uiText('Đang tải'),
      TipitakaTaskPhase.extracting => context.uiText('Đang giải nén'),
      TipitakaTaskPhase.importing => context.uiText('Đang import'),
      TipitakaTaskPhase.completed => context.uiText('Đã hoàn tất'),
      TipitakaTaskPhase.failed => context.uiText('Thất bại'),
    };
  }

  Future<void> _download(TipitakaLanguagePack pack) async {
    if (_downloadingCode != null) return;
    final taskId = 'language:${pack.code}';
    setState(() => _downloadingCode = pack.code);
    TipitakaTaskOverlay.show(context, taskId);

    final task = TipitakaTaskCoordinator.instance.downloadAndImport(pack);
    unawaited(task.then((status) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status.phase == TipitakaTaskPhase.completed
                ? context.uiText(
                    'Đã tải và import ${pack.name} trực tiếp vào thư viện Tipiṭaka.',
                  )
                : context.uiText('Không thể tải ${pack.name}: ${status.error}'),
          ),
          duration: const Duration(seconds: 6),
        ),
      );
      setState(() => _downloadingCode = null);
      _refreshLanguages();
    }));
  }

  @override
  Widget build(BuildContext context) {
    final isVietnamese = Localizations.localeOf(context).languageCode == 'vi';
    return Scaffold(
      appBar: AppBar(
        title: Text(isVietnamese ? 'Gói ngôn ngữ Tipiṭaka' : 'Tipiṭaka Language Packs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            tooltip: context.uiText('Mở trang nguồn Pa-Auk'),
            onPressed: () => launchUrl(
              Uri.parse('https://dhamma.paauksociety.org/Root/Tipitaka/SqlLite%20Database'),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_hasPali ? Icons.check_circle_outline : Icons.info_outline),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _hasPali
                        ? context.uiText(
                            'Mỗi gói ngôn ngữ có thể import độc lập.',
                          )
                        : context.uiText(
                            'Bạn vẫn có thể import và đọc Tiếng Việt ngay. Nên import Pāli trước hoặc sau để đối chiếu tốt hơn; khi chưa có Pāli, xem song ngữ và căn hàng sẽ tạm giảm cấp.',
                          ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: TipitakaLanguagePackCatalog.packs.length,
              itemBuilder: (context, index) {
                final pack = TipitakaLanguagePackCatalog.packs[index];
                return ValueListenableBuilder<List<TipitakaTaskStatus>>(
                  valueListenable: TipitakaTaskCoordinator.instance.tasks,
                  builder: (context, tasks, child) {
                    TipitakaTaskStatus? status;
                    for (final item in tasks) {
                      if (item.id == 'language:${pack.code}') status = item;
                    }
                    final isDownloading =
                        _downloadingCode == pack.code || status?.isActive == true;
                    final statusText = status == null
                        ? null
                        : '${_taskPhaseLabel(context, status.phase)}'
                            '${status.error == null ? '' : ': ${status.error}'}';
                    return Card(
                      margin: const EdgeInsets.fromLTRB(12, 5, 12, 5),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Icon(pack.isPali ? Icons.menu_book : Icons.translate),
                        ),
                        title: Text(pack.name),
                        subtitle: Text(
                          statusText == null
                              ? (isVietnamese ? pack.nameVi : pack.languageCode)
                              : '${isVietnamese ? pack.nameVi : pack.languageCode} · $statusText',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: SizedBox(
                          width: 52,
                          child: isDownloading
                              ? Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: CircularProgressIndicator(value: status?.progress),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.download),
                                  tooltip: isVietnamese ? 'Tải và giải nén' : 'Download and extract',
                                  onPressed: () => _download(pack),
                                ),
                        ),
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
