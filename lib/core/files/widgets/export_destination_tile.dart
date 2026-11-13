// lib/core/files/widgets/export_destination_tile.dart
//
// PSRC-204 · ADR-0029 — Ô chọn "Lưu vào: …" + nút "Đổi…" dùng chung cho mọi
// hộp thoại xuất (Media/Audio/Video, Cabin…).
//
// Hành vi bám chặt ADR-0029 § 2 & § 7:
//   - Luôn hiển thị rõ đường dẫn đích hiện tại (`Download/In4Up`, `On My iPhone/In4Up`…).
//   - Bấm "Đổi…" chỉ đổi cho riêng lần xuất đang mở; lần sau quay về mặc định.
//   - Nếu người dùng chủ động đánh dấu "Luôn lưu vào thư mục này", lựa chọn đó
//     mới trở thành mặc định mới của hồ sơ.
//   - Nếu thư mục đã lưu trước đó bị xoá / thu hồi quyền SAF, hiện cảnh báo 1 lần
//     ngay tại đây và tự dùng lại mặc định gốc.

import 'package:in4up/core/language/localized_material.dart';
// KHÔNG `show Text` từ material: giữ shim `Text` của `localized_material.dart` (Rule 5).
import 'package:flutter/material.dart' hide Text;

import '../export_destination.dart';
import '../export_destination_service.dart';

class ExportDestinationPickerCard extends StatelessWidget {
  const ExportDestinationPickerCard({
    super.key,
    required this.session,
    required this.onChanged,
    this.service,
    this.accentColor = const Color(0xFF26C6DA),
  });

  final ExportDestinationSession? session;
  final VoidCallback onChanged;
  final ExportDestinationService? service;
  final Color accentColor;

  ExportDestinationService get _svc =>
      service ?? ExportDestinationService.instance;

  Future<void> _pickFolder() async {
    final active = session;
    if (active == null) return;
    final picked = await _svc.pickCustomDestination();
    if (picked == null) return;
    active.selectOverride(picked);
    onChanged();
  }

  Future<void> _resetSavedDefault() async {
    final active = session;
    if (active == null) return;
    final builtIn = await _svc.resetToBuiltInDefault();
    active.overrideDestination = builtIn;
    active.rememberAsDefault = false;
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final active = session;
    final displayPath =
        active?.effectiveDestination.displayPath ?? 'Download/$kIn4UpPublicFolderName';
    final hasOverride = active?.hasOverride ?? false;
    final isCustomSavedDefault = active != null &&
        !hasOverride &&
        !active.effectiveDestination.isBuiltInDefault;
    final fellBack = active?.resolution.fellBackToBuiltInDefault ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasOverride
              ? accentColor.withValues(alpha: 0.45)
              : Colors.white12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.folder_open_rounded, size: 18, color: accentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.uiText(
                    'Lưu vào: $displayPath',
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: active == null ? null : _pickFolder,
                style: OutlinedButton.styleFrom(
                  foregroundColor: accentColor,
                  side: BorderSide(color: accentColor.withValues(alpha: 0.6)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  context.uiText('Đổi…'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (fellBack) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: Color(0xFFFFB74D),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    context.uiText(
                      'Thư mục đã lưu không còn truy cập được — đã quay về mặc định (${active!.resolution.destination.displayPath}).',
                    ),
                    style: const TextStyle(
                      color: Color(0xFFFFCC80),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (hasOverride && active != null) ...[
            const SizedBox(height: 6),
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () {
                active.rememberAsDefault = !active.rememberAsDefault;
                onChanged();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: active.rememberAsDefault,
                        activeColor: accentColor,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onChanged: (v) {
                          active.rememberAsDefault = v ?? false;
                          onChanged();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.uiText('Luôn lưu vào thư mục này'),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        active.clearOverride();
                        onChanged();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white54,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: const Size(0, 26),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        context.uiText('Dùng mặc định'),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!active.rememberAsDefault)
              Padding(
                padding: const EdgeInsets.only(left: 28, top: 2),
                child: Text(
                  context.uiText(
                    'Chỉ áp dụng cho lần xuất này — lần sau tự quay về mặc định.',
                  ),
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ),
          ] else if (isCustomSavedDefault) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _resetSavedDefault,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white54,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(0, 24),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  context.uiText('Về mặc định gốc'),
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
