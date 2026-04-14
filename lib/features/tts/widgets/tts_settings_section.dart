// lib/features/tts/widgets/tts_settings_section.dart

import 'package:flutter/material.dart';
import '../tts_service.dart';
import '../tts_settings.dart';

/// Widget cài đặt TTS - nhúng vào Settings sheet hiện có
class TtsSettingsSection extends StatefulWidget {
  final Color primaryColor;

  const TtsSettingsSection({
    super.key,
    this.primaryColor = const Color(0xFF6C63FF),
  });

  @override
  State<TtsSettingsSection> createState() => _TtsSettingsSectionState();
}

class _TtsSettingsSectionState extends State<TtsSettingsSection> {
  final _ttsService = TtsService();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _ttsService,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── HEADER ──
            _SectionHeader(
              icon: Icons.record_voice_over,
              title: 'Text-to-Speech',
              color: widget.primaryColor,
            ),
            const SizedBox(height: 12),

            // ── PRIORITY MODE ──
            _PrioritySelector(
              current: _ttsService.priority,
              color: widget.primaryColor,
              onChanged: (p) {
                _ttsService.setPriority(p);
              },
            ),
            const SizedBox(height: 16),

            // ── ENGINE ORDER ──
            _EngineOrderSection(
              engines: _ttsService.engineOrder,
              color: widget.primaryColor,
              onReorder: (engines) {
                _ttsService.reorderEngines(engines);
              },
              onToggle: (id, enabled) {
                _ttsService.toggleEngine(id, enabled);
              },
            ),
            const SizedBox(height: 16),

            // ── API KEYS ──
            _ApiKeySection(
              fptKey: _ttsService.fptApiKey,
              zaloKey: _ttsService.zaloApiKey,
              color: widget.primaryColor,
              onFptKeyChanged: (key) {
                _ttsService.configure(fptApiKey: key);
              },
              onZaloKeyChanged: (key) {
                _ttsService.configure(zaloApiKey: key);
              },
            ),
            const SizedBox(height: 16),

            // ── ENGINE STATUS ──
            _EngineStatusSection(color: widget.primaryColor),
            const SizedBox(height: 16),

            // ── CACHE INFO ──
            _CacheSection(color: widget.primaryColor),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════
// PRIORITY SELECTOR
// ═══════════════════════════════════════════

class _PrioritySelector extends StatelessWidget {
  final TtsPriority current;
  final Color color;
  final ValueChanged<TtsPriority> onChanged;

  const _PrioritySelector({
    required this.current,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chế độ phát',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[400],
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: TtsPriority.values.map((p) {
            final isSelected = p == current;
            return GestureDetector(
              onTap: () => onChanged(p),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        isSelected ? color : Colors.grey.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          p.icon,
                          size: 14,
                          color: isSelected ? color : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          p.label,
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected ? color : Colors.grey[300],
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p.description,
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════
// ENGINE ORDER (kéo thả)
// ═══════════════════════════════════════════

class _EngineOrderSection extends StatelessWidget {
  final List<TtsEngineInfo> engines;
  final Color color;
  final ValueChanged<List<TtsEngineInfo>> onReorder;
  final void Function(String id, bool enabled) onToggle;

  const _EngineOrderSection({
    required this.engines,
    required this.color,
    required this.onReorder,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Thứ tự nguồn phát',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[400],
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              'Kéo để sắp xếp',
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: engines.length,
          onReorder: (oldIndex, newIndex) {
            final list = List<TtsEngineInfo>.from(engines);
            if (newIndex > oldIndex) newIndex--;
            final item = list.removeAt(oldIndex);
            list.insert(newIndex, item);
            onReorder(list);
          },
          itemBuilder: (context, index) {
            final engine = engines[index];
            return Container(
              key: ValueKey(engine.id),
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: engine.isEnabled
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.white.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: engine.isEnabled
                      ? color.withValues(alpha: 0.3)
                      : Colors.grey.withValues(alpha: 0.1),
                ),
              ),
              child: ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.drag_handle,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                title: Text(
                  engine.name,
                  style: TextStyle(
                    fontSize: 13,
                    color: engine.isEnabled ? Colors.white : Colors.grey[600],
                  ),
                ),
                subtitle: Row(
                  children: [
                    Text(
                      engine.description,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (engine.needsApiKey) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.key,
                        size: 10,
                        color: Colors.orange[300],
                      ),
                    ],
                    if (!engine.isOnline) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.cloud_off,
                        size: 10,
                        color: Colors.grey[500],
                      ),
                    ],
                  ],
                ),
                trailing: Switch(
                  value: engine.isEnabled,
                  onChanged: (v) => onToggle(engine.id, v),
                  activeThumbColor: color,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════
// API KEYS
// ═══════════════════════════════════════════

class _ApiKeySection extends StatelessWidget {
  final String? fptKey;
  final String? zaloKey;
  final Color color;
  final ValueChanged<String> onFptKeyChanged;
  final ValueChanged<String> onZaloKeyChanged;

  const _ApiKeySection({
    required this.fptKey,
    required this.zaloKey,
    required this.color,
    required this.onFptKeyChanged,
    required this.onZaloKeyChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'API Keys (tùy chọn, miễn phí)',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[400],
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        _ApiKeyField(
          label: 'FPT.AI API Key',
          hint: 'Đăng ký miễn phí tại fpt.ai',
          value: fptKey,
          onChanged: onFptKeyChanged,
          color: color,
        ),
        const SizedBox(height: 8),
        _ApiKeyField(
          label: 'Zalo AI API Key',
          hint: 'Đăng ký miễn phí tại zalo.ai',
          value: zaloKey,
          onChanged: onZaloKeyChanged,
          color: color,
        ),
      ],
    );
  }
}

class _ApiKeyField extends StatefulWidget {
  final String label;
  final String hint;
  final String? value;
  final ValueChanged<String> onChanged;
  final Color color;

  const _ApiKeyField({
    required this.label,
    required this.hint,
    required this.value,
    required this.onChanged,
    required this.color,
  });

  @override
  State<_ApiKeyField> createState() => _ApiKeyFieldState();
}

class _ApiKeyFieldState extends State<_ApiKeyField> {
  late TextEditingController _controller;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value ?? '');
  }

  @override
  void didUpdateWidget(covariant _ApiKeyField old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _controller.text = widget.value ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasKey = widget.value != null && widget.value!.isNotEmpty;

    return TextField(
      controller: _controller,
      obscureText: _obscure,
      style: const TextStyle(color: Colors.white, fontSize: 12),
      onSubmitted: widget.onChanged,
      onChanged: (v) {
        if (v.trim().length > 10 || v.isEmpty) {
          widget.onChanged(v.trim());
        }
      },
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: TextStyle(color: Colors.grey[500], fontSize: 12),
        hintText: widget.hint,
        hintStyle: TextStyle(color: Colors.grey[700], fontSize: 10),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        prefixIcon: Icon(
          hasKey ? Icons.check_circle : Icons.key,
          size: 16,
          color: hasKey ? Colors.green : Colors.grey,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscure ? Icons.visibility_off : Icons.visibility,
            size: 16,
            color: Colors.grey,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// ENGINE STATUS
// ═══════════════════════════════════════════

class _EngineStatusSection extends StatelessWidget {
  final Color color;
  const _EngineStatusSection({required this.color});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, bool>>(
      future: TtsService().checkEngineStatus(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox(
            height: 30,
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        return Wrap(
          spacing: 6,
          runSpacing: 4,
          children: snap.data!.entries.map((e) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (e.value ? Colors.green : Colors.red)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    e.value ? Icons.check_circle : Icons.cancel,
                    size: 12,
                    color: e.value ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    e.key,
                    style: TextStyle(
                      fontSize: 10,
                      color: e.value ? Colors.green[200] : Colors.red[200],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════
// CACHE
// ═══════════════════════════════════════════

class _CacheSection extends StatelessWidget {
  final Color color;
  const _CacheSection({required this.color});

  @override
  Widget build(BuildContext context) {
    final service = TtsService();

    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        service.getCacheSizeMB(),
        service.getCacheCount(),
      ]),
      builder: (context, snap) {
        final sizeMB = snap.data?[0] as double? ?? 0;
        final count = snap.data?[1] as int? ?? 0;

        return Row(
          children: [
            Icon(Icons.storage, size: 14, color: Colors.grey[500]),
            const SizedBox(width: 6),
            Text(
              'Cache: $count files (${sizeMB.toStringAsFixed(1)} MB)',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
            const Spacer(),
            if (count > 0)
              GestureDetector(
                onTap: () async {
                  await service.clearCache();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã xóa cache TTS!')),
                  );
                },
                child: Text(
                  'Xóa',
                  style: TextStyle(fontSize: 11, color: Colors.red[300]),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════
// HEADER
// ═══════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
