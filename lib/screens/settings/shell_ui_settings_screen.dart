import 'package:flutter/material.dart';

import '../../services/storage_service.dart';

class ShellUiSettingsScreen extends StatefulWidget {
  const ShellUiSettingsScreen({super.key});

  @override
  State<ShellUiSettingsScreen> createState() => _ShellUiSettingsScreenState();
}

class _ShellUiSettingsScreenState extends State<ShellUiSettingsScreen> {
  final StorageService _storage = StorageService();

  late bool _compactMode;
  late bool _autoHideModeSwitch;
  late bool _longPressModeSwitch;
  late bool _rememberLastSubMode;

  @override
  void initState() {
    super.initState();
    _compactMode = _storage.getShellCompactMode();
    _autoHideModeSwitch = _storage.getShellAutoHideModeSwitch();
    _longPressModeSwitch = _storage.getShellLongPressModeSwitch();
    _rememberLastSubMode = _storage.getShellRememberLastSubMode();
  }

  Future<void> _updateCompactMode(bool value) async {
    setState(() => _compactMode = value);
    await _storage.saveShellCompactMode(value);
  }

  Future<void> _updateAutoHideModeSwitch(bool value) async {
    setState(() => _autoHideModeSwitch = value);
    await _storage.saveShellAutoHideModeSwitch(value);
  }

  Future<void> _updateLongPressModeSwitch(bool value) async {
    setState(() => _longPressModeSwitch = value);
    await _storage.saveShellLongPressModeSwitch(value);
  }

  Future<void> _updateRememberLastSubMode(bool value) async {
    setState(() => _rememberLastSubMode = value);
    await _storage.saveShellRememberLastSubMode(value);
    if (!value) {
      await _storage.saveShellListenSubMode(0);
      await _storage.saveShellReadSubMode(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B1A),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tùy chỉnh giao diện shell',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Compact mode · Auto-hide · Mode switch',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            title: 'Ưu tiên cho người dùng nâng cao',
            subtitle:
                'Mặc định app ưu tiên dễ thấy. Các tùy chọn dưới đây giúp tiết kiệm không gian và thao tác nhanh hơn.',
            child: const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),
          _ToggleCard(
            title: 'Compact mode cho switch mode',
            subtitle:
                'Ẩn thanh Nghe | Nói hoặc Đọc | Viết thành dạng gọn. Chạm vào chip mode ở app bar để hiện lại.',
            value: _compactMode,
            onChanged: _updateCompactMode,
            icon: Icons.compress,
            color: const Color(0xFF26C6DA),
          ),
          const SizedBox(height: 12),
          _ToggleCard(
            title: 'Auto-hide switch mode',
            subtitle:
                'Khi đang ở tab có mode phụ, thanh switch sẽ tự thu gọn sau vài giây và có thể gọi lại bằng chip mode trên app bar.',
            value: _autoHideModeSwitch,
            onChanged: _updateAutoHideModeSwitch,
            icon: Icons.visibility_off_outlined,
            color: const Color(0xFFFFB300),
          ),
          const SizedBox(height: 12),
          _ToggleCard(
            title: 'Long-press chip mode để đổi nhanh',
            subtitle:
                'Long-press chip mode trên app bar để đổi giữa Nghe ↔ Nói hoặc Đọc ↔ Viết mà không cần mở thanh switch.',
            value: _longPressModeSwitch,
            onChanged: _updateLongPressModeSwitch,
            icon: Icons.touch_app_outlined,
            color: const Color(0xFFB388FF),
          ),
          const SizedBox(height: 12),
          _ToggleCard(
            title: 'Nhớ mode phụ gần nhất',
            subtitle:
                'Khi quay lại tab Nghe hoặc Đọc, app sẽ mở đúng submode bạn dùng lần cuối thay vì luôn quay về mode chính.',
            value: _rememberLastSubMode,
            onChanged: _updateRememberLastSubMode,
            icon: Icons.history_toggle_off,
            color: const Color(0xFF66BB6A),
          ),
          const SizedBox(height: 16),
          const _SectionCard(
            title: 'Gợi ý sử dụng',
            subtitle:
                '• Người mới: tắt compact mode và auto-hide để dễ khám phá.\n'
                '• Người dùng quen tay: bật compact mode + nhớ mode gần nhất.\n'
                '• Muốn thao tác cực nhanh: bật thêm long-press đổi mode.',
            child: SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData icon;
  final Color color;

  const _ToggleCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: SwitchListTile.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: color,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        secondary: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            subtitle,
            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF121827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
          ),
          if (child is! SizedBox) ...[
            const SizedBox(height: 12),
            child,
          ],
        ],
      ),
    );
  }
}
