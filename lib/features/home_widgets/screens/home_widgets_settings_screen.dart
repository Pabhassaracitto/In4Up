// lib/features/home_widgets/screens/home_widgets_settings_screen.dart
//
// PLAN-050 · ADR-0040 — Màn hình quản lý «Widget & Lối tắt màn hình chính».
//
// Cho phép người dùng:
//   1. Xem trước trực tiếp Thanh Lệnh Nhanh (4x1) và chọn 3 nút hành động ưa thích.
//   2. Ghim 1 chạm bất kỳ trong 4 Home Screen Widget ra màn hình chính Android
//      (`AppWidgetManager.requestPinAppWidget`).
//   3. Ghim 1 chạm các biểu tượng Lối tắt riêng (`ShortcutManager.requestPinShortcut`)
//      cho từng phòng Studio / công cụ thường dùng nhất.
//   4. Xem hướng dẫn bật Ô Cài đặt nhanh (Quick Settings Tile) trên thanh thông báo.
//
// BẤT BIẾN RULE #5: Chỉ import `localized_material.dart` (tuyệt đối không import
// `package:flutter/material.dart` cùng lúc) và dùng `context.uiText` cho chuỗi
// truyền vào thuộc tính/SnackBar.

import 'package:in4up/core/language/localized_material.dart';

import '../models/widget_quick_action.dart';
import '../services/home_widget_bridge.dart';

class _WidgetCatalogEntry {
  final HomeWidgetKind kind;
  final String sizeBadge;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;

  const _WidgetCatalogEntry({
    required this.kind,
    required this.sizeBadge,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
  });
}

class _PinnableShortcutSpec {
  final String id;
  final String label;
  final String deepLink;
  final String iconKey;
  final IconData icon;
  final Color color;

  const _PinnableShortcutSpec({
    required this.id,
    required this.label,
    required this.deepLink,
    required this.iconKey,
    required this.icon,
    required this.color,
  });
}

class HomeWidgetsSettingsScreen extends StatefulWidget {
  const HomeWidgetsSettingsScreen({super.key});

  static Route<void> route() => MaterialPageRoute<void>(
        builder: (_) => const HomeWidgetsSettingsScreen(),
      );

  @override
  State<HomeWidgetsSettingsScreen> createState() =>
      _HomeWidgetsSettingsScreenState();
}

class _HomeWidgetsSettingsScreenState extends State<HomeWidgetsSettingsScreen> {
  static const Color _bgColor = Color(0xFF080B1A);
  static const Color _cardColor = Color(0xFF141829);
  static const Color _borderColor = Color(0xFF262D47);
  static const Color _accentIndigo = Color(0xFF6C63FF);

  static const List<_WidgetCatalogEntry> _catalog = <_WidgetCatalogEntry>[
    _WidgetCatalogEntry(
      kind: HomeWidgetKind.quickBar,
      sizeBadge: '4×1',
      title: 'Thanh Lệnh Nhanh',
      subtitle: '1 chạm tra từ điển + 3 nút hành động tuỳ chọn của riêng bạn',
      icon: Icons.bolt_rounded,
      accent: Color(0xFF6C63FF),
    ),
    _WidgetCatalogEntry(
      kind: HomeWidgetKind.continueLearning,
      sizeBadge: '4×2',
      title: 'Tiếp Tục Học',
      subtitle: 'Mở lại đúng trang PDF, văn bản hoặc bài nghe đang dở với 1 chạm',
      icon: Icons.play_circle_fill_rounded,
      accent: Color(0xFF26C6DA),
    ),
    _WidgetCatalogEntry(
      kind: HomeWidgetKind.flashcardSrs,
      sizeBadge: '4×2',
      title: 'Thẻ Từ & Vườn Trí Nhớ',
      subtitle:
          'Lật nghĩa và chuyển từ ngay trên màn hình chính · giữ tách biệt Hiểu–Nghe–Đọc',
      icon: Icons.eco_rounded,
      accent: Color(0xFF00E676),
    ),
    _WidgetCatalogEntry(
      kind: HomeWidgetKind.streakPulse,
      sizeBadge: '2×2',
      title: 'Nhịp Điệu & Chuỗi Ngày Học',
      subtitle: 'Theo dõi chuỗi ngày học liên tiếp và biểu đồ hoạt động 7 ngày',
      icon: Icons.local_fire_department_rounded,
      accent: Color(0xFFFF9100),
    ),
  ];

  List<WidgetQuickActionId> _selectedSlots = const <WidgetQuickActionId>[];
  NativeHomeWidgetStatus _status = NativeHomeWidgetStatus.unsupported;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final slots = await HomeWidgetBridge.instance.loadQuickBarSlots();
    final status = await HomeWidgetBridge.instance.getStatus();
    if (!mounted) return;
    setState(() {
      _selectedSlots = slots;
      _status = status;
      _loading = false;
    });
  }

  IconData _iconForAction(WidgetQuickActionId action) {
    switch (action) {
      case WidgetQuickActionId.voiceCapture:
        return Icons.mic_rounded;
      case WidgetQuickActionId.ocrScan:
        return Icons.document_scanner_rounded;
      case WidgetQuickActionId.screenTranslate:
        return Icons.translate_rounded;
      case WidgetQuickActionId.aiChat:
        return Icons.auto_awesome_rounded;
      case WidgetQuickActionId.liveCabin:
        return Icons.record_voice_over_rounded;
      case WidgetQuickActionId.reviewDue:
        return Icons.eco_rounded;
      case WidgetQuickActionId.tipitaka:
        return Icons.menu_book_rounded;
      case WidgetQuickActionId.youtube:
        return Icons.ondemand_video_rounded;
    }
  }

  Color _colorForAction(WidgetQuickActionId action) {
    switch (action) {
      case WidgetQuickActionId.voiceCapture:
        return const Color(0xFFFF5252);
      case WidgetQuickActionId.ocrScan:
        return const Color(0xFF42A5F5);
      case WidgetQuickActionId.screenTranslate:
        return const Color(0xFF26C6DA);
      case WidgetQuickActionId.aiChat:
        return const Color(0xFFAB47BC);
      case WidgetQuickActionId.liveCabin:
        return const Color(0xFFFFA726);
      case WidgetQuickActionId.reviewDue:
        return const Color(0xFF00E676);
      case WidgetQuickActionId.tipitaka:
        return const Color(0xFFFFD54F);
      case WidgetQuickActionId.youtube:
        return const Color(0xFFEF5350);
    }
  }

  Future<void> _onToggleActionSlot(WidgetQuickActionId tapped) async {
    if (_selectedSlots.contains(tapped)) {
      _showToast('Nút này đang nằm trên Thanh Lệnh Nhanh');
      return;
    }
    // Đẩy nút mới vào cuối và dịch 2 nút gần nhất sang trái để luôn giữ đúng 3 ô.
    final updated = <WidgetQuickActionId>[
      if (_selectedSlots.length >= 2) _selectedSlots[1],
      if (_selectedSlots.length >= 3) _selectedSlots[2],
      tapped,
    ];
    final saved = await HomeWidgetBridge.instance.saveQuickBarSlots(updated);
    if (!mounted) return;
    setState(() {
      _selectedSlots = saved;
    });
    _showToast('Đã cập nhật Thanh Lệnh Nhanh ngoài màn hình chính');
  }

  Future<void> _resetDefaultSlots() async {
    final defaults = WidgetQuickActionId.defaultQuickBarSlots(
      isAndroid: HomeWidgetBridge.instance.isAndroidHost,
    );
    final saved = await HomeWidgetBridge.instance.saveQuickBarSlots(defaults);
    if (!mounted) return;
    setState(() {
      _selectedSlots = saved;
    });
    _showToast('Đã khôi phục 3 nút mặc định');
  }

  Future<void> _pinWidget(HomeWidgetKind kind) async {
    if (!_status.isRequestPinSupported) {
      _showToast(
        'Trình khởi chạy hiện tại không hỗ trợ ghim tự động — hãy nhấn giữ màn hình chính rồi chọn Tiện ích (Widgets)',
      );
      return;
    }
    final ok = await HomeWidgetBridge.instance.requestPinWidget(kind);
    if (!mounted) return;
    if (ok) {
      _showToast('Hãy xác nhận hộp thoại của hệ thống để đặt Widget lên màn hình');
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (mounted) _loadState();
      });
    } else {
      _showToast(
        'Không gọi được hộp thoại ghim — bạn có thể nhấn giữ màn hình chính rồi chọn Tiện ích In4Up',
      );
    }
  }

  Future<void> _pinShortcut(_PinnableShortcutSpec spec) async {
    final translatedLabel = context.uiText(spec.label);
    final ok = await HomeWidgetBridge.instance.requestPinShortcut(
      id: spec.id,
      shortLabel: translatedLabel,
      deepLinkUri: spec.deepLink,
      iconKey: spec.iconKey,
    );
    if (!mounted) return;
    if (ok) {
      _showToast('Hãy xác nhận hộp thoại để thêm lối tắt 1 chạm ra màn hình chính');
    } else {
      _showToast(
        'Bạn cũng có thể nhấn giữ biểu tượng ứng dụng In4Up ngoài màn hình chính để kéo lối tắt ra',
      );
    }
  }

  void _showToast(String viMessage) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.uiText(viMessage)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  List<_PinnableShortcutSpec> _buildShortcutSpecs() {
    final isAndroid = HomeWidgetBridge.instance.isAndroidHost;
    return <_PinnableShortcutSpec>[
      const _PinnableShortcutSpec(
        id: 'pin_dict_search',
        label: 'Tra từ điển',
        deepLink: 'in4up://action/dict_search?src=shortcut',
        iconKey: 'search',
        icon: Icons.search_rounded,
        color: Color(0xFF6C63FF),
      ),
      const _PinnableShortcutSpec(
        id: 'pin_voice_capture',
        label: 'Ghi chú nói',
        deepLink: 'in4up://action/voice_capture?autostart=1&src=shortcut',
        iconKey: 'mic',
        icon: Icons.mic_rounded,
        color: Color(0xFFFF5252),
      ),
      const _PinnableShortcutSpec(
        id: 'pin_ocr_scan',
        label: 'Quét OCR',
        deepLink: 'in4up://action/ocr_scan?src=shortcut',
        iconKey: 'ocr',
        icon: Icons.document_scanner_rounded,
        color: Color(0xFF42A5F5),
      ),
      if (isAndroid)
        const _PinnableShortcutSpec(
          id: 'pin_screen_translate',
          label: 'Dịch màn hình',
          deepLink: 'in4up://action/screen_translate?src=shortcut',
          iconKey: 'translate',
          icon: Icons.translate_rounded,
          color: Color(0xFF26C6DA),
        ),
      const _PinnableShortcutSpec(
        id: 'pin_review_due',
        label: 'Ôn tập ngay',
        deepLink: 'in4up://action/review_due?mode=srs&src=shortcut',
        iconKey: 'leaf',
        icon: Icons.eco_rounded,
        color: Color(0xFF00E676),
      ),
      const _PinnableShortcutSpec(
        id: 'pin_tipitaka',
        label: 'Tipiṭaka',
        deepLink: 'in4up://nav/studio?target=tipitaka&src=shortcut',
        iconKey: 'book',
        icon: Icons.menu_book_rounded,
        color: Color(0xFFFFD54F),
      ),
      const _PinnableShortcutSpec(
        id: 'pin_listen',
        label: 'Phòng Nghe',
        deepLink: 'in4up://nav/studio?target=listen&src=shortcut',
        iconKey: 'headphones',
        icon: Icons.headphones_rounded,
        color: Color(0xFF29B6F6),
      ),
      const _PinnableShortcutSpec(
        id: 'pin_speak',
        label: 'Phòng Nói',
        deepLink: 'in4up://nav/studio?target=speak&src=shortcut',
        iconKey: 'mic',
        icon: Icons.record_voice_over_rounded,
        color: Color(0xFFFFA726),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final availableActions = WidgetQuickActionId.values
        .where(
          (item) => item.isSupportedOn(
            isAndroid: HomeWidgetBridge.instance.isAndroidHost,
          ),
        )
        .toList(growable: false);

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Widget & Lối tắt màn hình chính'),
        actions: <Widget>[
          IconButton(
            onPressed: _loadState,
            tooltip: context.uiText('Làm mới trạng thái'),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
              children: <Widget>[
                _buildLiveQuickBarPreview(),
                const SizedBox(height: 16),
                _buildSlotCustomizerCard(availableActions),
                const SizedBox(height: 20),
                _buildSectionHeader(
                  icon: Icons.widgets_rounded,
                  title: 'Bộ 4 Widget 1–2 chạm',
                  trailing: _status.totalPinnedCount > 0
                      ? '${_status.totalPinnedCount}'
                      : null,
                ),
                const SizedBox(height: 10),
                for (final entry in _catalog) ...<Widget>[
                  _buildWidgetCatalogCard(entry),
                  const SizedBox(height: 10),
                ],
                if (HomeWidgetBridge.instance.isAndroidHost) ...<Widget>[
                  const SizedBox(height: 14),
                  _buildSectionHeader(
                    icon: Icons.push_pin_rounded,
                    title: 'Ghim biểu tượng 1 chạm riêng',
                  ),
                  const SizedBox(height: 8),
                  _buildShortcutGrid(),
                ],
                const SizedBox(height: 20),
                _buildTipsCard(),
              ],
            ),
    );
  }

  Widget _buildLiveQuickBarPreview() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF181E36), Color(0xFF101426)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accentIndigo.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.visibility_rounded,
                size: 15,
                color: Color(0xFF9FA8DA),
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Xem trước Thanh Lệnh Nhanh (4×1)',
                  style: TextStyle(
                    color: Color(0xFF9FA8DA),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: _resetDefaultSlots,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: const Color(0xFF90CAF9),
                ),
                child: const Text(
                  'Mặc định',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFF0B0E1D),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: _borderColor),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: _accentIndigo,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.search_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Tra từ điển In4Up...',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ),
                for (final slot in _selectedSlots) ...<Widget>[
                  const SizedBox(width: 6),
                  Tooltip(
                    message: context.uiText(slot.sourceTitle),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _colorForAction(slot).withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _colorForAction(slot).withValues(alpha: 0.55),
                        ),
                      ),
                      child: Icon(
                        _iconForAction(slot),
                        size: 18,
                        color: _colorForAction(slot),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotCustomizerCard(List<WidgetQuickActionId> availableActions) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Chọn 3 nút nhanh bên cạnh ô Từ điển',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Chạm vào một công cụ bên dưới để đưa lên Thanh Lệnh Nhanh',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availableActions.map((action) {
              final slotIndex = _selectedSlots.indexOf(action);
              final selected = slotIndex >= 0;
              final accent = _colorForAction(action);
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _onToggleActionSlot(action),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? accent.withValues(alpha: 0.2)
                        : const Color(0xFF0E1222),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? accent : _borderColor,
                      width: selected ? 1.4 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        _iconForAction(action),
                        size: 16,
                        color: selected ? accent : Colors.white70,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        action.sourceTitle,
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.white70,
                          fontSize: 12.5,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                      if (selected) ...<Widget>[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '#${slotIndex + 1}',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(growable: false),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    String? trailing,
  }) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 18, color: _accentIndigo),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (trailing != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _accentIndigo.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              trailing,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWidgetCatalogCard(_WidgetCatalogEntry entry) {
    final activeCount = _status.countOf(entry.kind);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: activeCount > 0
              ? entry.accent.withValues(alpha: 0.6)
              : _borderColor,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: entry.accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(entry.icon, color: entry.accent, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        entry.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        entry.sizeBadge,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  entry.subtitle,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    if (activeCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E676).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 13,
                              color: Color(0xFF00E676),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'Đã ghim',
                              style: TextStyle(
                                color: Color(0xFF00E676),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Spacer(),
                    if (_status.isRequestPinSupported)
                      FilledButton.tonalIcon(
                        onPressed: () => _pinWidget(entry.kind),
                        style: FilledButton.styleFrom(
                          backgroundColor: entry.accent.withValues(alpha: 0.2),
                          foregroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.add_to_home_screen_rounded, size: 16),
                        label: const Text('Ghim ra màn hình chính'),
                      )
                    else if (HomeWidgetBridge.instance.isIosHost)
                      const Text(
                        'Nhấn giữ màn hình chính → (+)',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutGrid() {
    final specs = _buildShortcutSpecs();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Tạo một biểu tượng riêng trên màn hình chính cho công cụ bạn mở nhiều nhất mỗi ngày:',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: specs.map((spec) {
              return OutlinedButton.icon(
                onPressed: () => _pinShortcut(spec),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: spec.color.withValues(alpha: 0.45)),
                  backgroundColor: spec.color.withValues(alpha: 0.1),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 8,
                  ),
                ),
                icon: Icon(spec.icon, size: 16, color: spec.color),
                label: Text(
                  spec.label,
                  style: const TextStyle(fontSize: 12.5),
                ),
              );
            }).toList(growable: false),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF101528),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.tips_and_updates_rounded,
                size: 18,
                color: Color(0xFFFFD54F),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Mẹo truy cập siêu nhanh 1–2 chạm',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '• Nhấn giữ biểu tượng In4Up ngoài màn hình chính để mở nhanh Tra từ, Ghi chú nói, Quét OCR hoặc Ôn tập.',
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
          ),
          SizedBox(height: 6),
          Text(
            '• Trên Android, kéo thanh thông báo từ trên xuống → bấm Chỉnh sửa → kéo ô «I4U Dịch màn hình» hoặc «I4U Ghi chú nói» lên hàng đầu để bật ngay khi đang đọc báo hoặc lướt web ở ứng dụng khác.',
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
          ),
          SizedBox(height: 6),
          Text(
            '• Trên iPhone / iPad, nhấn giữ nền Màn hình chính hoặc Màn hình khoá → bấm dấu (+) góc trên → tìm «In4Up» để đặt Widget cỡ Nhỏ, Vừa hoặc Widget Màn hình khoá.',
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
          ),
          SizedBox(height: 6),
          Text(
            '• Nhấn giữ một tài liệu PDF/Văn bản, bài nghe gần đây hoặc thẻ công cụ trên Android rồi chọn «Đưa ra màn hình chính» để tạo biểu tượng mở thẳng 1 chạm.',
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}
