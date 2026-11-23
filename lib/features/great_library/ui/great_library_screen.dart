// lib/features/great_library/ui/great_library_screen.dart
//
// GLIB-004 — Thư Viện Chung I4U (PLAN-049, ADR-0031).
// Màn chính: tìm kiếm + lọc loại + sắp xếp + danh sách pack (pull-to-refresh).
// Chuỗi chrome qua AppLocalizations (rule vàng #5, ARB ×26 locale);
// TÊN/mô tả pack là nội dung cộng đồng → giữ nguyên nguồn, không dịch.
//
// Entry: Quick Actions (main_shell _handleTool 'great_library').

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../great_library_controller.dart';
import '../great_library_wiring.dart';
import '../models/gl_pack_entry.dart';
import '../models/pack_manifest.dart';
import '../services/gl_catalog_service.dart';
import 'pack_detail_screen.dart';

class GreatLibraryScreen extends StatefulWidget {
  const GreatLibraryScreen({super.key, this.controller});

  /// Inject trong test; null → dựng mặc định qua wiring (async).
  final GreatLibraryController? controller;

  @override
  State<GreatLibraryScreen> createState() => _GreatLibraryScreenState();
}

class _GreatLibraryScreenState extends State<GreatLibraryScreen> {
  GreatLibraryController? _controller;

  @override
  void initState() {
    super.initState();
    final injected = widget.controller;
    if (injected != null) {
      _controller = injected;
      _controller!.load();
    } else {
      createGreatLibraryController().then((controller) {
        if (!mounted) return;
        setState(() => _controller = controller);
        controller.load();
      });
    }
  }

  IconData _iconFor(PackType? type) {
    switch (type) {
      case PackType.vocab:
        return Icons.spellcheck_rounded;
      case PackType.audio:
        return Icons.headphones_rounded;
      case PackType.image:
        return Icons.photo_library_rounded;
      case null:
        return Icons.inventory_2_rounded;
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.glLibraryTitle)),
      body: controller == null
          ? const Center(child: CircularProgressIndicator())
          : AnimatedBuilder(
              animation: controller,
              builder: (context, _) => _buildBody(context, controller),
            ),
    );
  }

  Widget _buildBody(BuildContext context, GreatLibraryController controller) {
    if (controller.isLoading && controller.visibleEntries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.errorMessage != null && controller.visibleEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48),
            const SizedBox(height: 12),
            Text(AppLocalizations.of(context)!.glErrorLoading),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => controller.load(forceRefresh: true),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(AppLocalizations.of(context)!.glRetry),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        _buildSearchAndFilters(context, controller),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => controller.load(forceRefresh: true),
            child: _buildList(context, controller),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters(
      BuildContext context, GreatLibraryController controller) {
    final query = controller.query;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)!.glSearchHint,
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            onChanged: (text) => controller.setQuery(GlCatalogQuery(
              type: query.type,
              srcLang: query.srcLang,
              dstLang: query.dstLang,
              level: query.level,
              tag: query.tag,
              text: text,
              sort: query.sort,
            )),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _filterChip(context, controller, null),
              _filterChip(context, controller, PackType.vocab),
              _filterChip(context, controller, PackType.audio),
              _filterChip(context, controller, PackType.image),
              const Spacer(),
              PopupMenuButton<GlPackSort>(
                icon: const Icon(Icons.sort_rounded),
                initialValue: query.sort,
                onSelected: (sort) => controller.setQuery(GlCatalogQuery(
                  type: query.type,
                  srcLang: query.srcLang,
                  dstLang: query.dstLang,
                  level: query.level,
                  tag: query.tag,
                  text: query.text,
                  sort: sort,
                )),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: GlPackSort.newest,
                    child: Text(AppLocalizations.of(context)!.glSortNewest),
                  ),
                  PopupMenuItem(
                    value: GlPackSort.mostDownloaded,
                    child: Text(AppLocalizations.of(context)!.glSortMostDownloaded),
                  ),
                  PopupMenuItem(
                    value: GlPackSort.topRated,
                    child: Text(AppLocalizations.of(context)!.glSortTopRated),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip(BuildContext context, GreatLibraryController controller,
      PackType? type) {
    final selected = controller.query.type == type;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(_typeLabel(context, type)),
        selected: selected,
        onSelected: (_) {
          final query = controller.query;
          controller.setQuery(GlCatalogQuery(
            type: type,
            srcLang: query.srcLang,
            dstLang: query.dstLang,
            level: query.level,
            tag: query.tag,
            text: query.text,
            sort: query.sort,
          ));
        },
      ),
    );
  }

  Widget _buildList(BuildContext context, GreatLibraryController controller) {
    final entries = controller.visibleEntries;
    if (entries.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Center(child: Text(AppLocalizations.of(context)!.glEmpty)),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) =>
          _buildPackCard(context, controller, entries[index]),
    );
  }

  Widget _buildPackCard(BuildContext context,
      GreatLibraryController controller, GlPackEntry entry) {
    final manifest = entry.manifest;
    final downloaded = controller.downloadedIds.contains(entry.packId);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: CircleAvatar(child: Icon(_iconFor(manifest.type))),
        // Nội dung pack (user content) — giữ nguyên nguồn, không dịch.
        title: Text(manifest.title,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${manifest.author.displayName} · ${manifest.level} · '
          '${manifest.stats.downloads}↓ · ${_formatBytes(entry.fileBytes)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: downloaded
            ? const Icon(Icons.check_circle_rounded, color: Colors.green)
            : const Icon(Icons.download_rounded),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PackDetailScreen(
              entry: entry,
              controller: controller,
            ),
          ),
        ),
      ),
    );
  }
}

String _typeLabel(BuildContext context, PackType? type) {
  final l10n = AppLocalizations.of(context)!;
  switch (type) {
    case PackType.vocab:
      return l10n.glFilterVocab;
    case PackType.audio:
      return l10n.glFilterAudio;
    case PackType.image:
      return l10n.glFilterImage;
    case null:
      return l10n.glFilterAll;
  }
}
