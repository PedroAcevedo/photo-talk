import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'photoTalkTheme.dart';

/// Opens an external media link (YouTube / Spotify / Apple Music / any web
/// URL) in a full-screen modal WebView. Designed to satisfy the spec's
/// "opening external media links in an overlay within the application,
/// allowing the user to move back and forth without losing the main
/// session context."
///
/// Push it with [Navigator.of(context, rootNavigator: true).push] so it
/// sits above the Music+Captions screen; pop it to return exactly to the
/// same photo / caption / player state.
class ExternalMediaOverlay extends StatefulWidget {
  const ExternalMediaOverlay({
    Key? key,
    required this.url,
    this.title,
  }) : super(key: key);

  final String url;
  final String? title;

  /// Convenience push. Uses the root navigator so the overlay covers the
  /// bottom nav too — the recipient sees an unambiguous "modal" surface.
  static Future<void> open(
    BuildContext context, {
    required String url,
    String? title,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ExternalMediaOverlay(url: url, title: title),
      ),
    );
  }

  @override
  State<ExternalMediaOverlay> createState() => _ExternalMediaOverlayState();
}

class _ExternalMediaOverlayState extends State<ExternalMediaOverlay> {
  late final WebViewController _controller;
  double _progress = 0.0;
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    final normalized = _normalizeUrl(widget.url);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) {
          if (!mounted) return;
          setState(() => _progress = p / 100.0);
        },
        onPageStarted: (_) {
          if (!mounted) return;
          setState(() {
            _loading = true;
            _loadError = null;
          });
        },
        onPageFinished: (_) {
          if (!mounted) return;
          setState(() => _loading = false);
        },
        onWebResourceError: (err) {
          if (!mounted) return;
          setState(() {
            _loading = false;
            _loadError = err.description;
          });
        },
      ))
      ..loadRequest(Uri.parse(normalized));
  }

  /// Turn common share URLs into their embed variants so the WebView shows
  /// a compact player instead of the full site chrome.
  ///
  /// Supported today:
  ///   youtu.be/<id> and youtube.com/watch?v=<id> → youtube.com/embed/<id>
  ///   open.spotify.com/{track|album|playlist}/<id> → open.spotify.com/embed/{...}
  ///
  /// Any URL that doesn't match falls through unchanged.
  static String _normalizeUrl(String raw) {
    try {
      final uri = Uri.parse(raw.trim());
      final host = uri.host.toLowerCase();

      // YouTube
      if (host == 'youtu.be' && uri.pathSegments.isNotEmpty) {
        final id = uri.pathSegments.first;
        return 'https://www.youtube.com/embed/$id';
      }
      if ((host == 'youtube.com' ||
              host == 'www.youtube.com' ||
              host == 'm.youtube.com') &&
          uri.queryParameters['v'] != null) {
        return 'https://www.youtube.com/embed/${uri.queryParameters['v']}';
      }

      // Spotify
      if ((host == 'open.spotify.com' || host == 'spotify.com') &&
          uri.pathSegments.length >= 2 &&
          {'track', 'album', 'playlist', 'episode'}
              .contains(uri.pathSegments.first)) {
        return 'https://open.spotify.com/embed/${uri.pathSegments.first}/${uri.pathSegments[1]}';
      }
    } catch (_) {}
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PhotoTalkPalette.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: PhotoTalkPalette.background,
        foregroundColor: PhotoTalkPalette.textPrimary,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Close and return to the photo',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          widget.title == null || widget.title!.isEmpty
              ? 'Media'
              : widget.title!,
          style: PhotoTalkText.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: (_loading || _progress > 0 && _progress < 1)
              ? LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  minHeight: 2,
                  backgroundColor: PhotoTalkPalette.divider,
                  valueColor:
                      const AlwaysStoppedAnimation(PhotoTalkPalette.primary),
                )
              : const SizedBox(height: 2),
        ),
      ),
      body: _loadError != null
          ? _errorState()
          : WebViewWidget(controller: _controller),
    );
  }

  Widget _errorState() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.link_off_rounded,
              color: PhotoTalkPalette.accentRose, size: 48),
          const SizedBox(height: 12),
          Text("Couldn't open this link",
              style: PhotoTalkText.h2, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            _loadError ?? '',
            textAlign: TextAlign.center,
            style: PhotoTalkText.caption,
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('Go back to the photo'),
          ),
        ],
      ),
    );
  }
}
