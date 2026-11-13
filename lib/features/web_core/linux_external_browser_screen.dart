import 'package:in4up/core/language/localized_material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Linux has no registered webview_flutter backend. Keep the user in a usable
/// Flutter route and explicitly hand navigation to their system browser.
class LinuxExternalBrowserScreen extends StatefulWidget {
  const LinuxExternalBrowserScreen({
    super.key,
    this.initialInput = '',
    required this.normalizeInput,
    this.launch,
  });

  final String initialInput;
  final String Function(String) normalizeInput;
  final Future<bool> Function(Uri)? launch;

  @override
  State<LinuxExternalBrowserScreen> createState() =>
      _LinuxExternalBrowserScreenState();
}

class _LinuxExternalBrowserScreenState
    extends State<LinuxExternalBrowserScreen> {
  late final TextEditingController _input;
  bool _opening = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _input = TextEditingController(text: widget.initialInput);
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    if (_opening) return;
    final normalized = widget.normalizeInput(_input.text);
    final uri = Uri.tryParse(normalized);
    if (uri == null || !['http', 'https'].contains(uri.scheme) || uri.host.isEmpty) {
      setState(() => _failed = true);
      return;
    }
    setState(() {
      _opening = true;
      _failed = false;
    });
    var opened = false;
    try {
      opened = await (widget.launch?.call(uri) ??
          launchUrl(uri, mode: LaunchMode.externalApplication));
    } catch (_) {
      // A missing default browser or desktop handler must remain retryable.
    }
    if (!mounted) return;
    setState(() {
      _opening = false;
      _failed = !opened;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mở bằng trình duyệt ngoài')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Linux chưa hỗ trợ trình đọc web trong ứng dụng. Trang sẽ mở trong trình duyệt hệ thống; các công cụ đọc và viết trong ứng dụng không khả dụng.'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _input,
                    decoration: InputDecoration(
                      labelText: context.uiText('Địa chỉ web hoặc từ khóa'),
                    ),
                    onSubmitted: (_) => _open(),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _opening ? null : _open,
                    icon: const Icon(Icons.open_in_browser),
                    label: const Text('Mở bằng trình duyệt ngoài'),
                  ),
                  if (_failed) ...[
                    const SizedBox(height: 12),
                    const Text('Không mở được trình duyệt. Kiểm tra địa chỉ và trình duyệt mặc định rồi thử lại.'),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
