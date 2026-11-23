// lib/features/great_library/ui/my_contributions_screen.dart
//
// GLIB-006 — "Đóng góp của tôi": danh sách đóng góp local + trạng thái
// pending/published/rejected + lý do từ chối (reviewerNote).

import 'package:flutter/material.dart';
import 'package:in4up/l10n/app_localizations.dart';

import '../services/contribution_store.dart';

class MyContributionsScreen extends StatelessWidget {
  const MyContributionsScreen({super.key, required this.store});

  final ContributionStore store;

  Color _statusColor(BuildContext context, String status) {
    final scheme = Theme.of(context).colorScheme;
    return switch (status) {
      'published' => scheme.primary,
      'rejected' => scheme.error,
      _ => scheme.tertiary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final records = store.all().reversed.toList(growable: false);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.glMyContributions)),
      body: records.isEmpty
          ? Center(child: Text(l10n.glNoContributions))
          : ListView.builder(
              itemCount: records.length,
              itemBuilder: (context, i) {
                final r = records[i];
                final date =
                    DateTime.fromMillisecondsSinceEpoch(r.submittedAtMs);
                return ListTile(
                  leading: Icon(Icons.upload_rounded,
                      color: _statusColor(context, r.status)),
                  title: Text(r.title),
                  subtitle: Text(
                    '${r.packId} · ${date.day}/${date.month}/${date.year}'
                    '${r.reviewerNote != null ? '\n${r.reviewerNote}' : ''}',
                  ),
                  isThreeLine: r.reviewerNote != null,
                  trailing: _StatusChip(status: r.status),
                );
              },
            ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final label = switch (status) {
      'published' => l10n.glStatusPublished,
      'rejected' => l10n.glStatusRejected,
      _ => l10n.glStatusPending,
    };
    return Chip(label: Text(label), visualDensity: VisualDensity.compact);
  }
}
