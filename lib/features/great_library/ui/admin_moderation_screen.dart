// lib/features/great_library/ui/admin_moderation_screen.dart
//
// GLIB-007 — màn admin moderation (PLAN-049 §GLIB-007): hàng chờ pending →
// xem chi tiết manifest → Duyệt / Từ chối (bắt buộc lý do) / Ẩn.
// Gate: chỉ mở khi AdminGate.isAdmin() (entry trên Thư Viện Chung đã ẩn với
// tài khoản thường — AT3). Preview nội dung tái dùng flow GLIB-004 (manifest
// trong contribution + tải pack về xem trước — gắn vào bản sau).

import 'package:flutter/material.dart';
import 'package:in4up/l10n/app_localizations.dart';

import '../services/admin_moderation_service.dart';

class AdminModerationScreen extends StatefulWidget {
  const AdminModerationScreen({super.key, required this.service});

  final AdminModerationService service;

  @override
  State<AdminModerationScreen> createState() => _AdminModerationScreenState();
}

class _AdminModerationScreenState extends State<AdminModerationScreen> {
  List<PendingContribution>? _queue;
  String? _error;
  final Set<String> _busy = <String>{};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final queue = await widget.service.loadQueue();
      if (!mounted) return;
      setState(() {
        _queue = queue;
        _error = null;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  Future<void> _act(
    PendingContribution c,
    Future<ModerationResult> Function() action,
  ) async {
    setState(() => _busy.add(c.contributionId));
    final result = await action();
    if (!mounted) return;
    setState(() => _busy.remove(c.contributionId));
    final l10n = AppLocalizations.of(context)!;
    if (result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.glModerationDone)),
      );
      _reload();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('${l10n.glModerationFailed} (${result.errorCode})')),
      );
    }
  }

  Future<String?> _askReason({required String title}) {
    final controller = TextEditingController();
    final l10n = AppLocalizations.of(context)!;
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(hintText: l10n.glReasonHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.glBack),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(l10n.glContributeSubmit),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.glModerationTitle)),
      body: _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.glErrorLoading),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(l10n.glRetry),
                  ),
                ],
              ),
            )
          : _queue == null
              ? const Center(child: CircularProgressIndicator())
              : _queue!.isEmpty
                  ? Center(child: Text(l10n.glModerationEmpty))
                  : RefreshIndicator(
                      onRefresh: _reload,
                      child: ListView.builder(
                        itemCount: _queue!.length,
                        itemBuilder: (context, i) =>
                            _buildCard(context, _queue![i]),
                      ),
                    ),
    );
  }

  Widget _buildCard(BuildContext context, PendingContribution c) {
    final l10n = AppLocalizations.of(context)!;
    final busy = _busy.contains(c.contributionId);
    final manifest = c.manifest;
    final type = (manifest['type'] as String?) ?? '?';
    final level = (manifest['level'] as String?) ?? '';
    final entryCount = manifest['entryCount'];
    final date = DateTime.fromMillisecondsSinceEpoch(c.submittedAtMs);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(c.title.isEmpty ? c.packId : c.title,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '$type · $level · ${l10n.glItemCount(entryCount is int ? entryCount : 0)} · '
              '${date.day}/${date.month}/${date.year} · ${c.authorUid}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if ((manifest['description'] as String?)?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(manifest['description'] as String),
              ),
            const SizedBox(height: 8),
            if (busy)
              const LinearProgressIndicator()
            else
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.icon(
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(l10n.glApprove),
                    onPressed: () => _act(c, () => widget.service.approve(c)),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: Text(l10n.glReject),
                    onPressed: () async {
                      final reason =
                          await _askReason(title: l10n.glRejectReason);
                      if (reason == null || reason.isEmpty) return;
                      await _act(c,
                          () => widget.service.reject(c, reason: reason));
                    },
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.visibility_off_rounded, size: 18),
                    label: Text(l10n.glHide),
                    onPressed: () async {
                      final reason =
                          await _askReason(title: l10n.glHideReason);
                      if (reason == null || reason.isEmpty) return;
                      await _act(
                          c, () => widget.service.hide(c, reason: reason));
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
