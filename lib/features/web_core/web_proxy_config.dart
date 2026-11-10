/// Compile-time configuration for the browser-safe Web Core adapters.
///
/// No secret belongs here: values passed with `--dart-define` are visible in
/// the generated JavaScript. The proxy URL is public; provider credentials
/// stay in the proxy's environment.
class WebProxyConfig {
  WebProxyConfig._();

  static const String baseUrl = String.fromEnvironment(
    'IN4UP_WEB_PROXY_BASE_URL',
    defaultValue: '',
  );

  /// Development-only escape hatch for endpoints that explicitly allow CORS.
  /// It is false in production so the web build does not silently depend on a
  /// public translation/CORS proxy.
  static const bool allowDirectCors = bool.fromEnvironment(
    'IN4UP_ALLOW_DIRECT_CORS',
    defaultValue: false,
  );

  static bool get isConfigured => baseUrl.trim().isNotEmpty;

  static Uri? endpoint(String path, {Map<String, String>? queryParameters}) {
    final raw = baseUrl.trim();
    if (raw.isEmpty) return null;

    final base = Uri.tryParse(raw);
    if (base == null ||
        !base.hasAuthority ||
        (base.scheme != 'http' && base.scheme != 'https')) {
      return null;
    }

    final basePath = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    final childPath = path.startsWith('/') ? path : '/$path';

    return base.replace(
      path: '$basePath$childPath',
      queryParameters: queryParameters,
    );
  }
}
