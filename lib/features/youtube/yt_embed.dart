import 'package:webview_flutter/webview_flutter.dart';

/// YouTube iframe embed that avoids error 153 (player configuration)
/// in Android WebView by using youtube-nocookie + IFrame API + a real Referer.
class YtEmbed {
  YtEmbed._();

  static const String baseUrl = 'https://www.youtube-nocookie.com';
  static const String userAgent =
      'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  static String html(String videoId, {bool autoplay = false}) {
    final id = _escapeJs(videoId.trim());
    final ap = autoplay ? 1 : 0;
    return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
<meta name="referrer" content="strict-origin-when-cross-origin">
<style>
  html,body,#player{margin:0;padding:0;height:100%;width:100%;background:#000;overflow:hidden;}
</style>
</head>
<body>
<div id="player"></div>
<script>
  window._in4upSeek = function(s) {
    try { if (window._ytp && window._ytp.seekTo) window._ytp.seekTo(s, true); } catch (e) {}
  };
  window._in4upPause = function() {
    try { if (window._ytp && window._ytp.pauseVideo) window._ytp.pauseVideo(); } catch (e) {}
  };
  window._in4upPlay = function() {
    try { if (window._ytp && window._ytp.playVideo) window._ytp.playVideo(); } catch (e) {}
  };
  function onYouTubeIframeAPIReady() {
    window._ytp = new YT.Player('player', {
      height: '100%',
      width: '100%',
      videoId: '$id',
      host: 'https://www.youtube-nocookie.com',
      playerVars: {
        playsinline: 1,
        rel: 0,
        modestbranding: 1,
        enablejsapi: 1,
        origin: 'https://www.youtube-nocookie.com',
        autoplay: $ap,
        cc_load_policy: 0
      },
      events: {
        onReady: function() {
          setInterval(function() {
            try {
              if (window._ytp && window._ytp.getCurrentTime && window.YtSync) {
                YtSync.postMessage(String(window._ytp.getCurrentTime()));
              }
            } catch (e) {}
          }, 250);
        }
      }
    });
  }
</script>
<script src="https://www.youtube.com/iframe_api"></script>
</body>
</html>
''';
  }

  static void load(
    WebViewController controller,
    String videoId, {
    bool autoplay = false,
  }) {
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(userAgent)
      ..loadHtmlString(html(videoId, autoplay: autoplay), baseUrl: baseUrl);
  }

  static String _escapeJs(String value) => value
      .replaceAll('\\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll('"', r'\"')
      .replaceAll('\n', '');
}
