import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb, Listenable, visibleForTesting;
import 'package:flutter/painting.dart' show ResizeImage;
import 'package:in4up/core/language/localized_material.dart';

import '../services/dict_image_policy.dart';
import '../services/dict_mdd_worker.dart';
import '../services/dictionary_service.dart';

/// Injectable handle keeps widget lifecycle tests independent of platform I/O.
abstract interface class DictImageRead {
  Future<List<Uint8List?>> get results;
  Future<void> cancel();
}

class _WorkerRead implements DictImageRead {
  final MddReadTask task;
  _WorkerRead(this.task);
  @override
  Future<List<Uint8List?>> get results => task.results;
  @override
  Future<void> cancel() => task.cancel();
}

typedef DictImageReadStarter = Future<DictImageRead> Function(String dictId, List<String> keys);

/// Optional images are fetched only on user request, never from the network or
/// the file path in HTML. They appear after the text rather than inline.
class DictSourceImages extends StatefulWidget {
  final String dictId;
  final String definition;
  @visibleForTesting
  final DictImageReadStarter? startRead;
  @visibleForTesting
  final Listenable? sourceChanges;

  const DictSourceImages({super.key, required this.dictId, required this.definition,
    this.startRead, this.sourceChanges});

  @override
  State<DictSourceImages> createState() => _DictSourceImagesState();
}

class _DictSourceImagesState extends State<DictSourceImages> {
  late List<String> _keys;
  late Listenable _changes;
  DictImageRead? _read;
  int _generation = 0;
  bool _loading = false;
  bool _loaded = false;
  bool _missing = false;
  List<_ImageItem> _images = const [];

  @override
  void initState() {
    super.initState();
    _keys = DictImagePolicy.extract(widget.definition);
    _changes = widget.sourceChanges ?? DictionaryService.instance.resourceRevision;
    _changes.addListener(_onSourceChanged);
  }

  @override
  void didUpdateWidget(covariant DictSourceImages oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sourceChanges != widget.sourceChanges) {
      _changes.removeListener(_onSourceChanged);
      _changes = widget.sourceChanges ?? DictionaryService.instance.resourceRevision;
      _changes.addListener(_onSourceChanged);
    }
    if (oldWidget.dictId != widget.dictId || oldWidget.definition != widget.definition ||
        oldWidget.startRead != widget.startRead || oldWidget.sourceChanges != widget.sourceChanges) {
      _clear();
      _keys = DictImagePolicy.extract(widget.definition);
    }
  }

  void _evictImages() {
    for (final item in _images) { unawaited(item.provider.evict()); }
    _images = const [];
  }

  void _clear() {
    _generation++;
    final read = _read;
    _read = null;
    if (read != null) unawaited(read.cancel());
    _loading = false;
    _loaded = false;
    _missing = false;
    _evictImages();
  }

  void _onSourceChanged() {
    if (!mounted) return;
    setState(_clear);
  }

  Future<void> _load() async {
    if (_loading || _keys.isEmpty) return;
    final generation = ++_generation;
    setState(() { _loading = true; _loaded = false; _missing = false; _evictImages(); });
    try {
      final starter = widget.startRead ?? (String id, List<String> keys) async => _WorkerRead(
        await DictionaryService.instance.startMddResourceBatch(id, keys,
          maxItemBytes: DictImagePolicy.maxBytes, maxTotalBytes: 4 * DictImagePolicy.maxBytes));
      final read = await starter(widget.dictId, _keys);
      // Attach an error handler before cancelling a late-arriving task.
      final result = read.results;
      if (!mounted || generation != _generation) {
        unawaited(result.then<void>((_) {}, onError: (Object _) {}));
        unawaited(read.cancel());
        return;
      }
      _read = read;
      final data = await result;
      if (!mounted || generation != _generation) return;
      final images = <_ImageItem>[];
      var missing = data.length != _keys.length;
      for (final bytes in data) {
        final size = bytes == null ? null : DictImagePolicy.inspect(bytes);
        if (bytes == null || size == null) {
          missing = true;
        } else {
          images.add(_ImageItem(bytes, size.width));
        }
      }
      setState(() { _images = images; _missing = missing; _loaded = true; _loading = false; _read = null; });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() { _loading = false; _loaded = true; _missing = true; _read = null; });
    }
  }

  @override
  void dispose() {
    _changes.removeListener(_onSourceChanged);
    _clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Dart isolates for this worker have not been validated on Flutter web.
    if ((kIsWeb && widget.startRead == null) || _keys.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextButton.icon(
        onPressed: _loading ? null : _load,
        icon: const Icon(Icons.image_outlined, size: 18),
        label: Text(context.uiText(_loading ? 'Đang tải ảnh…' : 'Hiện ảnh MDD')),
      ),
      if (_loaded && _missing)
        Text(context.uiText('Không thể hiển thị một số ảnh từ điển.'),
          style: TextStyle(color: Colors.grey[400], fontSize: 12)),
      for (final image in _images)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360, maxHeight: 320),
            child: Image(image: image.provider, fit: BoxFit.contain,
              errorBuilder: (context, error, stack) => Text(
                context.uiText('Không thể hiển thị một số ảnh từ điển.'),
                style: TextStyle(color: Colors.grey[400], fontSize: 12))),
          ),
        ),
    ]);
  }
}

class _ImageItem {
  final ImageProvider provider;
  _ImageItem(Uint8List bytes, int width)
      : provider = ResizeImage(MemoryImage(bytes), width: width < 720 ? width : 720);
}
