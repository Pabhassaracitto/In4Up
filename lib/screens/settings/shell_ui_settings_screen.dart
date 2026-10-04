import 'package:in4up/core/language/localized_material.dart';

import '../../models/read_content_source.dart';
import '../../models/shell_content_order.dart';
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
  late ShellContentOrder _contentOrder;
  late ReadContentSource _defaultReadSource;
  late ListenContentSource _defaultListenSource;
  late UnderstandWorkspaceMode _defaultUnderstandMode;

  @override
  void initState() {
    super.initState();
    _compactMode = _storage.getShellCompactMode();
    _autoHideModeSwitch = _storage.getShellAutoHideModeSwitch();
    _longPressModeSwitch = _storage.getShellLongPressModeSwitch();
    _rememberLastSubMode = _storage.getShellRememberLastSubMode();
    _contentOrder = _storage.getShellContentOrder();
    _defaultReadSource = _storage.getDefaultReadContentSource();
    _defaultListenSource = _storage.getDefaultListenContentSource();
    _defaultUnderstandMode = _storage.getDefaultUnderstandWorkspaceMode();
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
      await _storage.saveReadContentSource(_defaultReadSource);
      await _storage.saveListenContentSource(_defaultListenSource);
      await _storage.saveUnderstandWorkspaceMode(_defaultUnderstandMode);
    }
  }

  Future<void> _updateDefaultReadSource(ReadContentSource value) async {
    setState(() => _defaultReadSource = value);
    await _storage.saveDefaultReadContentSource(value);
    if (!_rememberLastSubMode) await _storage.saveReadContentSource(value);
  }

  Future<void> _updateDefaultListenSource(ListenContentSource value) async {
    setState(() => _defaultListenSource = value);
    await _storage.saveDefaultListenContentSource(value);
    if (!_rememberLastSubMode) await _storage.saveListenContentSource(value);
  }

  Future<void> _updateDefaultUnderstandMode(UnderstandWorkspaceMode value) async {
    setState(() => _defaultUnderstandMode = value);
    await _storage.saveDefaultUnderstandWorkspaceMode(value);
    if (!_rememberLastSubMode) await _storage.saveUnderstandWorkspaceMode(value);
  }

  Future<void> _updateContentOrder(ShellContentOrder value) async {
    setState(() => _contentOrder = value);
    await _storage.saveShellContentOrder(value);
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
          _ContentOrderCard(
            value: _contentOrder,
            onChanged: _updateContentOrder,
          ),
          const SizedBox(height: 12),
          _DefaultReadSourceCard(
            value: _defaultReadSource,
            onChanged: _updateDefaultReadSource,
          ),
          const SizedBox(height: 12),
          _DefaultListenSourceCard(
            value: _defaultListenSource,
            onChanged: _updateDefaultListenSource,
          ),
          const SizedBox(height: 12),
          _DefaultUnderstandModeCard(
            value: _defaultUnderstandMode,
            onChanged: _updateDefaultUnderstandMode,
          ),
          const SizedBox(height: 12),
          _ToggleCard(
            title: 'Compact mode cho switch mode',
            subtitle:
                'Ẩn thanh Nghe | Nói hoặc Đọc | Viết thành dạng gọn. Chạm vào chip mode ở app bar để hiện lại khi cần.',
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
            title: 'Long-press tab chính để vào mode phụ',
            subtitle:
                'Giữ tab Nghe để vào Nói, giữ tab Đọc để vào Viết. Chip mode trên app bar vẫn hỗ trợ đổi nhanh khi cần.',
            value: _longPressModeSwitch,
            onChanged: _updateLongPressModeSwitch,
            icon: Icons.touch_app_outlined,
            color: const Color(0xFFB388FF),
          ),
          const SizedBox(height: 12),
          _ToggleCard(
            title: 'Nhớ lựa chọn workspace gần nhất',
            subtitle:
                'Khi quay lại Nghe/Đọc/Hiểu, app giữ mode và nguồn bạn dùng lần cuối. Tắt để luôn dùng mặc định bên trên.',
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

class _ContentOrderCard extends StatelessWidget {
  final ShellContentOrder value;
  final ValueChanged<ShellContentOrder> onChanged;

  const _ContentOrderCard({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF121827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF6C63FF).withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.swap_horiz_rounded,
                    color: Color(0xFFB388FF)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Thứ tự tab Nghe và Đọc',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value.isListenFirst
                ? 'Nghe bên trái thì thư viện nghe ở bên trái; Đọc bên phải thì thư viện đọc ở bên phải.'
                : 'Đọc bên trái thì thư viện đọc ở bên trái; Nghe bên phải thì thư viện nghe ở bên phải.',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<ShellContentOrder>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment<ShellContentOrder>(
                  value: ShellContentOrder.listenRead,
                  icon: Icon(Icons.headphones_rounded),
                  label: Text('Nghe → Đọc'),
                ),
                ButtonSegment<ShellContentOrder>(
                  value: ShellContentOrder.readListen,
                  icon: Icon(Icons.menu_book_rounded),
                  label: Text('Đọc → Nghe'),
                ),
              ],
              selected: {value},
              onSelectionChanged: (selection) {
                if (selection.isNotEmpty) onChanged(selection.first);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DefaultReadSourceCard extends StatelessWidget {
  const _DefaultReadSourceCard({
    required this.value,
    required this.onChanged,
  });

  final ReadContentSource value;
  final ValueChanged<ReadContentSource> onChanged;

  @override
  Widget build(BuildContext context) {
    return _EnumPreferenceCard<ReadContentSource>(
      title: 'Nguồn Đọc mặc định',
      subtitle: 'Shell mở tab Đọc với Tài liệu, Web hoặc Tam tạng theo lựa chọn này khi không nhớ phiên gần nhất.',
      icon: Icons.menu_book_outlined,
      color: const Color(0xFF2196F3),
      value: value,
      values: ReadContentSource.values,
      labelFor: (source) => source.label,
      iconFor: (source) => source.icon,
      onChanged: onChanged,
    );
  }
}

class _DefaultListenSourceCard extends StatelessWidget {
  const _DefaultListenSourceCard({
    required this.value,
    required this.onChanged,
  });

  final ListenContentSource value;
  final ValueChanged<ListenContentSource> onChanged;

  @override
  Widget build(BuildContext context) {
    return _EnumPreferenceCard<ListenContentSource>(
      title: 'Nguồn Nghe mặc định',
      subtitle: 'Ưu tiên mở thư viện âm thanh, YouTube hoặc thư viện video từ header workspace Nghe.',
      icon: Icons.headphones_outlined,
      color: const Color(0xFF6C63FF),
      value: value,
      values: ListenContentSource.values,
      labelFor: _listenSourceLabel,
      iconFor: _listenSourceIcon,
      onChanged: onChanged,
    );
  }
}

class _DefaultUnderstandModeCard extends StatelessWidget {
  const _DefaultUnderstandModeCard({
    required this.value,
    required this.onChanged,
  });

  final UnderstandWorkspaceMode value;
  final ValueChanged<UnderstandWorkspaceMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return _EnumPreferenceCard<UnderstandWorkspaceMode>(
      title: 'Mode Hiểu mặc định',
      subtitle: 'Chọn Đồng bộ khi cần ghép Audio + Text; chọn Shadowing khi muốn luyện nói theo đoạn.',
      icon: Icons.lightbulb_outline,
      color: const Color(0xFFFFB300),
      value: value,
      values: UnderstandWorkspaceMode.values,
      labelFor: _understandModeLabel,
      iconFor: _understandModeIcon,
      onChanged: onChanged,
    );
  }
}

class _EnumPreferenceCard<T> extends StatelessWidget {
  const _EnumPreferenceCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.value,
    required this.values,
    required this.labelFor,
    required this.iconFor,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final T value;
  final List<T> values;
  final String Function(T value) labelFor;
  final IconData Function(T value) iconFor;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF121827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<T>(
              showSelectedIcon: false,
              segments: [
                for (final item in values)
                  ButtonSegment<T>(
                    value: item,
                    icon: Icon(iconFor(item)),
                    label: Text(context.uiText(labelFor(item))),
                  ),
              ],
              selected: {value},
              onSelectionChanged: (selection) {
                if (selection.isNotEmpty) onChanged(selection.first);
              },
            ),
          ),
        ],
      ),
    );
  }
}

String _listenSourceLabel(ListenContentSource source) {
  return switch (source) {
    ListenContentSource.audioLibrary => 'Âm thanh',
    ListenContentSource.youtube => 'YouTube',
    ListenContentSource.videoLibrary => 'Video',
  };
}

IconData _listenSourceIcon(ListenContentSource source) {
  return switch (source) {
    ListenContentSource.audioLibrary => Icons.library_music_rounded,
    ListenContentSource.youtube => Icons.play_circle_filled,
    ListenContentSource.videoLibrary => Icons.video_library_outlined,
  };
}

String _understandModeLabel(UnderstandWorkspaceMode mode) {
  return switch (mode) {
    UnderstandWorkspaceMode.sync => 'Đồng bộ',
    UnderstandWorkspaceMode.shadowing => 'Shadowing',
  };
}

IconData _understandModeIcon(UnderstandWorkspaceMode mode) {
  return switch (mode) {
    UnderstandWorkspaceMode.sync => Icons.sync_alt_rounded,
    UnderstandWorkspaceMode.shadowing => Icons.record_voice_over,
  };
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
