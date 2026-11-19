import 'package:in4up/core/language/localized_material.dart';
import 'package:in4up/l10n/app_localizations.dart';

import '../engines/tts_engine.dart';
import '../tts_service.dart';

/// Uses the same persisted choice in the common settings and reader sheets.
class ReaderVoiceTile extends StatelessWidget {
  const ReaderVoiceTile(this.reader, {super.key});
  final TtsReader reader;

  @override
  Widget build(BuildContext context) {
    final service = TtsService();
    final l = AppLocalizations.of(context);
    final title = switch (reader) {
      TtsReader.read => l.read,
      TtsReader.tipitaka => 'Tipiṭaka',
      TtsReader.web => l.webReader,
      TtsReader.pdf => l.pdfReader,
    };
    return ListenableBuilder(
        listenable: service,
        builder: (context, _) {
          final pref = service.preferenceFor(reader);
          final engines = service.engineOrder;
          final info = engines.where((e) => e.id == pref?.engine).firstOrNull;
          final last =
              service.lastReader == reader ? service.lastUsedEngine : '';
          final canPickVoice = const {
            'piper_tts',
            'vieneu_tts',
            'offline_tts',
            'edge_tts'
          }.contains(pref?.engine);
          return ListTile(
            title: Text(title),
            subtitle: Text([
              if (info == null)
                l.ttsInherit
              else
                '${l.ttsOverride}: ${context.uiText(info.name)}',
              if (canPickVoice) '${l.ttsVoice}: ${pref?.voice ?? l.ttsInherit}',
              if (service.lastReader == reader && service.playbackUnavailable)
                l.ttsPlaybackUnavailable,
              if (last.isNotEmpty) '${l.ttsLastPlayback}: $last',
            ].join('\n')),
            onTap: () async {
              final id = await showDialog<String>(
                  context: context,
                  builder: (ctx) => SimpleDialog(
                        title: Text(title),
                        children: [
                          SimpleDialogOption(
                              onPressed: () => Navigator.pop(ctx, ''),
                              child: Text(l.ttsInherit)),
                          for (final engine in engines)
                            SimpleDialogOption(
                                onPressed: engine.isEnabled
                                    ? () => Navigator.pop(ctx, engine.id)
                                    : null,
                                child: Text(context.uiText(engine.name),
                                    style: TextStyle(
                                        color: engine.isEnabled
                                            ? null
                                            : Theme.of(ctx).disabledColor))),
                        ],
                      ));
              if (id == null || id == pref?.engine) return;
              await service.setReaderPreference(
                  reader, id.isEmpty ? null : ReaderVoicePreference(id));
            },
            trailing: !canPickVoice
                ? const Icon(Icons.tune)
                : IconButton(
                    icon: const Icon(Icons.record_voice_over),
                    tooltip: l.ttsVoice,
                    onPressed: () async {
                      final engine = pref!.engine;
                      final voices = await service.readerVoiceCatalog(engine);
                      if (!context.mounted) return;
                      final choice = await showDialog<ReaderVoicePreference>(
                          context: context,
                          builder: (ctx) => SimpleDialog(
                                title: Text('$title · ${l.ttsVoice}'),
                                children: [
                                  SimpleDialogOption(
                                      onPressed: () => Navigator.pop(
                                          ctx, ReaderVoicePreference(engine)),
                                      child: Text(l.ttsInherit)),
                                  for (final TtsVoice v in voices)
                                    SimpleDialogOption(
                                        onPressed: () => Navigator.pop(
                                            ctx,
                                            ReaderVoicePreference(engine,
                                                voice: v.id,
                                                locale: v.language)),
                                        child:
                                            Text('${v.language} · ${v.name}')),
                                ],
                              ));
                      if (choice != null)
                        await service.setReaderPreference(reader, choice);
                    },
                  ),
          );
        });
  }
}

/// The engine that supplied the audio (including cache/system fallback), not
/// the configured preference. Hidden while resolving, or for another reader.
class ReaderPlaybackLabel extends StatelessWidget {
  const ReaderPlaybackLabel(this.reader, {super.key});
  final TtsReader reader;

  @override
  Widget build(BuildContext context) {
    final service = TtsService();
    return ListenableBuilder(
        listenable: service,
        builder: (_, __) {
          final label =
              service.lastReader == reader ? service.lastUsedEngine : '';
          if (label.isEmpty) return const SizedBox.shrink();
          return Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 11));
        });
  }
}
