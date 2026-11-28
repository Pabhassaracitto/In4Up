// lib/features/great_library/ui/great_library_screen.dart
//
// GLIB-004 — Thư Viện Chung I4U (PLAN-049, ADR-0036).
// Màn chính: tìm kiếm + lọc loại + sắp xếp + danh sách pack (pull-to-refresh).
// Chuỗi chrome qua AppLocalizations (rule vàng #5, ARB ×26 locale);
// TÊN/mô tả pack là nội dung cộng đồng → giữ nguyên nguồn, không dịch.
//
// Entry: Quick Actions (main_shell _handleTool 'great_library').

import 'package:flutter/material.dart';
import 'package:in4up/l10n/app_localizations.dart';
import 'package:in4up_ai/in4up_ai.dart';
import 'package:provider/provider.dart';

import '../../../providers/vocabulary_provider.dart';
import '../contribution_wiring.dart';
import '../great_library_controller.dart';
import '../great_library_wiring.dart';
import '../models/gl_pack_entry.dart';
import '../models/pack_manifest.dart';
import '../../../services/firebase_rest_auth.dart';
import '../services/admin_gate.dart';
import '../services/admin_moderation_service.dart';
import '../services/contribution_ai_suggest.dart';
import '../services/gl_catalog_service.dart';
import '../services/moderation_transport_firestore.dart';
import 'admin_moderation_screen.dart';
import 'contribute_wizard_screen.dart';
import 'my_contributions_screen.dart';
import 'pack_detail_screen.dart';

class GreatLibraryScreen extends StatefulWidget {
  const GreatLibraryScreen({super.key, this.controller, this.adminGate});

  /// Inject trong test; null → dựng mặc định qua wiring (async).
  final GreatLibraryController? controller;

  /// GLIB-007: gate admin (inject trong test — tránh FirebaseRestAuth/Hive).
  /// Null → dựng gate thật (Firestore + FirebaseRestAuth).
  final AdminGate? adminGate;

  @override
  State<GreatLibraryScreen> createState() => _GreatLibraryScreenState();
}

class _GreatLibraryScreenState extends State<GreatLibraryScreen> {
  GreatLibraryController? _controller;

  Future<bool>? _adminGateFuture;

  @override
  void initState() {
    super.initState();
    // GLIB-007: gate admin — inject test hoặc đọc gl_config/admins 1 lần
    // (cache trong phiên).
    final injectedGate = widget.adminGate;
    _adminGateFuture = injectedGate != null
        ? injectedGate.isAdmin()
        : () async {
            final auth = FirebaseRestAuth();
            await auth.restoreSession();
            final uid = auth.currentUser?.uid ?? '';
            return AdminGate(
              fetcher: FirestoreAdminGateFetcher(),
              currentUid: uid,
            ).isAdmin();
          }();
    final injected = widget.controller;
    if (injected != null) {
      _controller = injected;
      _controller!.load();
    } else {
      // Truyền provider app-wide để import vocab ghi vào đúng instance (GLIB-005).
      createGreatLibraryController(
              vocabulary: context.read<VocabularyProvider>())
          .then((controller) {
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
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.glLibraryTitle),
        actions: [
          // GLIB-006 — wizard đóng góp (P1).
          IconButton(
            tooltip: AppLocalizations.of(context)!.glContribute,
            icon: const Icon(Icons.upload_file_rounded),
            onPressed: () async {
              final bundle = await createContributionBundle();
              if (!context.mounted) return;
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ContributeWizardScreen(
                    service: bundle.service,
                    aiSuggest: ContributionAiSuggest(
                      providerResolver: () async {
                        final store = AiProviderStore.instance;
                        await store.ensureLoaded();
                        return store
                            .resolveProvider(AiRouteCapability.chat);
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: AppLocalizations.of(context)!.glMyContributions,
            icon: const Icon(Icons.history_rounded),
            onPressed: () async {
              final bundle = await createContributionBundle();
              if (!context.mounted) return;
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      MyContributionsScreen(store: bundle.store),
                ),
              );
            },
          ),
          // GLIB-007 — entry "Duyệt pack": chỉ hiện khi uid ∈ gl_config/admins
          // (AT3: tài khoản thường không thấy entry, rules vẫn chặn server).
          FutureBuilder<bool>(
            future: _adminGateFuture,
            builder: (context, snap) {
              if (snap.data != true) return const SizedBox.shrink();
              return IconButton(
                tooltip: AppLocalizations.of(context)!.glModerationTitle,
                icon: const Icon(Icons.admin_panel_settings_rounded),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AdminModerationScreen(
                        service: AdminModerationService(
                          transport: FirestoreModerationTransport(),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
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
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _filterChip(context, controller, null),
              _filterChip(context, controller, PackType.vocab),
              _filterChip(context, controller, PackType.audio),
              _filterChip(context, controller, PackType.image),
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
    return ChoiceChip(
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
    final downloaded = controller.downloadedIds.contains(entry.packId) ||
        controller.isInstalled(entry.packId);
    final hasUpdate = controller.hasUpdate(entry);
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
        trailing: hasUpdate
            ? Tooltip(
                message:
                    AppLocalizations.of(context)!.glUpdateAvailable,
                child: const Icon(Icons.system_update_alt_rounded,
                    color: Colors.amber),
              )
            : downloaded
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
