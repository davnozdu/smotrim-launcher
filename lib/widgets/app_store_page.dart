/*
 * Smotrim.CZ Launcher
 * Based on FLauncher (C) 2021 Étienne Fesser — GPLv3.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import 'dart:async';
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

  bool _exitArmed = false;
  Timer? _exitTimer;

  @override
  void dispose() {
    _exitTimer?.cancel();
    super.dispose();
  }

  Future<void> _downloadAndInstall(String url, String? suggestedName) async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
      _progress = 0;
    });

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
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
        await for (final chunk in response) {
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

  Future<void> _handleBack() async {
    if (await (_controller?.canGoBack() ?? Future.value(false))) {
      await _controller?.goBack();
      _disarmExit();
      return;
    }
    if (_exitArmed) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    _exitArmed = true;
    final l = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(l.pressBackAgainToExit),
        duration: const Duration(milliseconds: 2500),
      ));
    _exitTimer?.cancel();
    _exitTimer = Timer(const Duration(milliseconds: 2500), () => _exitArmed = false);
  }

  void _disarmExit() {
    _exitArmed = false;
    _exitTimer?.cancel();
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
                  javaScriptEnabled: true,
                  transparentBackground: true,
                  supportZoom: false,
                  // Hide the native Android WebView scrollbars (CSS can't touch
                  // them); scrolling itself stays enabled.
                  verticalScrollBarEnabled: false,
                  horizontalScrollBarEnabled: false,
                  overScrollMode: OverScrollMode.NEVER,
                ),
                onWebViewCreated: (controller) => _controller = controller,
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
                  _downloadAndInstall(request.url.toString(), request.suggestedFilename);
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
