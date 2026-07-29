/*
 * Smotrim.CZ Launcher
 * Based on FLauncher (C) 2021 Étienne Fesser — GPLv3.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flauncher/flauncher_channel.dart';
import 'package:flauncher/l10n/app_localizations.dart';

/// Full-screen WebView for the Smotrim app store (https://tv.smotrim.cz).
///
/// The store is a TV-first site that runs its own D-pad navigation in
/// JavaScript (it listens for Arrow/Enter/Escape keydown). The native WebView
/// from flutter_inappwebview forwards those hardware keys, so the remote drives
/// the page directly — that's why we use it instead of webview_flutter, which
/// doesn't deliver D-pad to the page on Android TV.
///
/// App installs are caught via [onDownloadStartRequest] (the store triggers a
/// download whose URL is NOT a plain `.apk`, e.g. `version.php?...&download=1`),
/// then downloaded and handed to the system installer.
///
/// The remote's Back button walks the WebView history first; at the store's
/// root it asks for a second press ("press Back again to exit") before leaving.
class AppStorePage extends StatefulWidget {
  static const String storeUrl = "https://tv.smotrim.cz";

  const AppStorePage({super.key});

  @override
  State<AppStorePage> createState() => _AppStorePageState();
}

class _AppStorePageState extends State<AppStorePage> {
  final FLauncherChannel _channel = FLauncherChannel();
  InAppWebViewController? _controller;

  bool _pageLoading = true;
  bool _downloading = false;
  double _progress = 0;

  // connectionTimeout only covers the handshake. A connection that is
  // established and then goes quiet would otherwise hold the download loop
  // open forever, and because _downloading gates re-entry that also meant no
  // further app could be installed until the launcher was restarted.
  static const Duration _requestTimeout = Duration(seconds: 30);
  static const Duration _stallTimeout = Duration(minutes: 2);

  Future<void> _downloadAndInstall(String url, String? suggestedName) async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
      _progress = 0;
    });

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close().timeout(_requestTimeout);
      if (response.statusCode != HttpStatus.ok) {
        _showError();
        return;
      }

      final dir = await getTemporaryDirectory();
      final name = _sanitizeApkName(suggestedName);
      final file = File("${dir.path}/$name");
      final sink = file.openWrite();
      final total = response.contentLength;
      var received = 0;
      var lastPercent = -1;

      try {
        // Inactivity deadline: a slow but progressing download is never cut off,
        // while one that stops delivering is.
        await for (final chunk in response.timeout(_stallTimeout)) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) {
            final percent = received * 100 ~/ total;
            if (percent != lastPercent) {
              lastPercent = percent;
              if (mounted) setState(() => _progress = received / total);
            }
          }
        }
      } finally {
        // close() flushes and releases the handle even if the stream errors out.
        await sink.close();
      }

      await _channel.installApk(file.path);
    } catch (e) {
      debugPrint("App store install failed: $e");
      // A partial file would otherwise be handed to the installer on a retry.
      try {
        final dir = await getTemporaryDirectory();
        final partial = File("${dir.path}/${_sanitizeApkName(suggestedName)}");
        if (await partial.exists()) await partial.delete();
      } catch (_) {}
      _showError();
    } finally {
      client.close();
      if (mounted) setState(() => _downloading = false);
    }
  }

  String _sanitizeApkName(String? suggested) {
    final cleaned = (suggested ?? "").replaceAll(RegExp(r'[^A-Za-z0-9._-]'), "");
    if (cleaned.toLowerCase().endsWith(".apk") && cleaned.length > 4) return cleaned;
    return "appstore-download.apk";
  }

  /// True for the store's "install" navigation: `version.php?...&download=1`.
  /// Such links don't stream the APK on every host (they may 302 to GitHub's
  /// release page), so we resolve and install the latest APK ourselves instead
  /// of letting the WebView wander off to github.com.
  String? _installRepoFor(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final isDownload = uri.queryParameters.containsKey("download") &&
        uri.path.toLowerCase().contains("version.php");
    if (!isDownload) return null;
    final repo = uri.queryParameters["repo"];
    if (repo == null || !repo.contains("/")) return null;
    return repo;
  }

  /// Resolves the latest release of [repo] and installs its APK (universal
  /// preferred), straight from github.com — no dependency on the site's PHP.
  Future<void> _installFromRepo(String repo) async {
    if (_downloading) return;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    String? apkUrl, apkName;
    try {
      final tag = await _resolveLatestTag(client, repo);
      if (tag != null) {
        final res = await _resolveApkUrl(client, repo, tag);
        if (res != null) {
          apkUrl = res.$1;
          apkName = res.$2;
        }
      }
    } catch (e) {
      debugPrint("App store resolve failed ($repo): $e");
    } finally {
      client.close();
    }
    if (apkUrl == null) {
      _showError();
      return;
    }
    await _downloadAndInstall(apkUrl, apkName);
  }

  Future<String?> _resolveLatestTag(HttpClient client, String repo) async {
    final request =
        await client.getUrl(Uri.parse("https://github.com/$repo/releases/latest"));
    request.followRedirects = false;
    final response = await request.close().timeout(_requestTimeout);
    await response.drain().timeout(_requestTimeout);
    if (response.statusCode < 300 || response.statusCode >= 400) return null;
    final location = response.headers.value(HttpHeaders.locationHeader) ?? "";
    return RegExp(r'/tag/([^/?#]+)').firstMatch(location)?.group(1);
  }

  /// First `.apk` on the release assets page, preferring the universal build.
  Future<(String, String)?> _resolveApkUrl(HttpClient client, String repo, String tag) async {
    final request = await client
        .getUrl(Uri.parse("https://github.com/$repo/releases/expanded_assets/$tag"));
    final response = await request.close().timeout(_requestTimeout);
    if (response.statusCode != HttpStatus.ok) return null;
    final html =
        await response.transform(utf8.decoder).join().timeout(_requestTimeout);
    final matches = RegExp(r'href="([^"]*?\.apk)"', caseSensitive: false)
        .allMatches(html)
        .map((m) => m.group(1)!)
        .toList();
    if (matches.isEmpty) return null;
    String pick = matches.firstWhere(
        (u) => u.toLowerCase().contains("universal") || u.toLowerCase().contains("app-release"),
        orElse: () => matches.firstWhere((u) => u.toLowerCase().contains("arm64"),
            orElse: () => matches.first));
    if (pick.startsWith("/")) pick = "https://github.com$pick";
    final name = Uri.tryParse(pick)?.pathSegments.last ?? "appstore-download.apk";
    return (pick, name);
  }

  void _showError() {
    if (!mounted) return;
    final l = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l.downloadFailed),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  // The site is the single owner of Back: it closes its exit dialog / detail
  // card, or shows the "Exit the store?" confirm. We just relay Back to it and
  // never pop here — leaving happens only via the `exitStore` JS handler. The
  // pop fallback covers the page not being ready yet.
  Future<void> _handleBack() async {
    try {
      final handled = await _controller?.evaluateJavascript(
          source: "window.__hubBack ? (window.__hubBack(), true) : false");
      if (handled == true) return;
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  // D-pad keys → forwarded into the page as a synthetic keydown on `window`.
  // The store (tv.smotrim.cz) runs its own JS navigation off window 'keydown';
  // on Android TV the embedded WebView doesn't reliably receive D-pad itself,
  // so we capture it in Flutter and replay it into the page.
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    (String, int)? mapping;
    if (key == LogicalKeyboardKey.arrowLeft) {
      mapping = ("ArrowLeft", 37);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      mapping = ("ArrowRight", 39);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      mapping = ("ArrowUp", 38);
    } else if (key == LogicalKeyboardKey.arrowDown) {
      mapping = ("ArrowDown", 40);
    } else if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.gameButtonA) {
      mapping = ("Enter", 13);
    }
    if (mapping == null) return KeyEventResult.ignored;
    _forwardKey(mapping.$1, mapping.$2);
    return KeyEventResult.handled;
  }

  void _forwardKey(String key, int code) {
    _controller?.evaluateJavascript(source:
        "window.dispatchEvent(new KeyboardEvent('keydown',{key:'$key',code:'$key',keyCode:$code,which:$code,bubbles:true,cancelable:true}));");
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Focus(
                autofocus: true,
                onKeyEvent: _onKeyEvent,
                child: InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(AppStorePage.storeUrl)),
                initialSettings: InAppWebViewSettings(
                  // Required for onDownloadStartRequest to fire.
                  useOnDownloadStart: true,
                  // Required for shouldOverrideUrlLoading to fire.
                  useShouldOverrideUrlLoading: true,
                  javaScriptEnabled: true,
                  transparentBackground: true,
                  supportZoom: false,
                  // Hide the native Android WebView scrollbars (CSS can't touch
                  // them); scrolling itself stays enabled.
                  verticalScrollBarEnabled: false,
                  horizontalScrollBarEnabled: false,
                  overScrollMode: OverScrollMode.NEVER,
                ),
                shouldOverrideUrlLoading: (controller, action) async {
                  final url = action.request.url?.toString() ?? "";
                  final repo = _installRepoFor(url);
                  if (repo != null) {
                    // Intercept the "install" link and install the latest APK
                    // ourselves instead of navigating off to github.com.
                    _installFromRepo(repo);
                    return NavigationActionPolicy.CANCEL;
                  }
                  return NavigationActionPolicy.ALLOW;
                },
                onWebViewCreated: (controller) {
                  _controller = controller;
                  // The site owns Back; it asks us to leave only when the user
                  // confirms "Yes" in its exit dialog.
                  controller.addJavaScriptHandler(
                    handlerName: "exitStore",
                    callback: (_) {
                      if (mounted) Navigator.of(context).pop();
                      return null;
                    },
                  );
                },
                onLoadStart: (controller, url) {
                  if (mounted) setState(() => _pageLoading = true);
                },
                onLoadStop: (controller, url) async {
                  if (mounted) setState(() => _pageLoading = false);
                  // Nudge focus into the page so the site's JS key handlers
                  // start receiving D-pad events immediately.
                  await controller.evaluateJavascript(source: "window.focus();");
                },
                onReceivedError: (controller, request, error) {
                  if (mounted) setState(() => _pageLoading = false);
                },
                onDownloadStartRequest: (controller, request) {
                  final url = request.url.toString();
                  final repo = _installRepoFor(url);
                  if (repo != null) {
                    _installFromRepo(repo);
                  } else {
                    _downloadAndInstall(url, request.suggestedFilename);
                  }
                },
              ),
              ),
              if (_pageLoading)
                const Center(child: CircularProgressIndicator()),
              if (_downloading)
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black54,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            "${l.appStoreDownloading} ${(_progress * 100).clamp(0, 100).toStringAsFixed(0)}%",
                            style: const TextStyle(color: Colors.white, fontSize: 18),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
