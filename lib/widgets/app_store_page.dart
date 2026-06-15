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
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flauncher/flauncher_channel.dart';
import 'package:flauncher/l10n/app_localizations.dart';

/// Full-screen WebView for the Smotrim app store (https://tv.smotrim.cz).
///
/// D-pad navigation is handled natively by the Android WebView (spatial focus
/// between links/buttons). The remote's Back button walks the WebView history
/// first and only leaves the store once there's nothing left to go back to.
///
/// Tapping an app whose link points to a `.apk` is intercepted: instead of the
/// WebView trying to render the binary, the launcher downloads it and hands it
/// to the system installer (same path as the player/HLS-PROXY buttons). App
/// links on the store must therefore be direct `.apk` URLs.
class AppStorePage extends StatefulWidget {
  static const String storeUrl = "https://tv.smotrim.cz";

  const AppStorePage({super.key});

  @override
  State<AppStorePage> createState() => _AppStorePageState();
}

class _AppStorePageState extends State<AppStorePage> {
  final FLauncherChannel _channel = FLauncherChannel();
  late final WebViewController _controller;

  bool _pageLoading = true;
  bool _downloading = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _pageLoading = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _pageLoading = false);
        },
        onNavigationRequest: (request) {
          if (_isApkUrl(request.url)) {
            _downloadAndInstall(request.url);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(AppStorePage.storeUrl));
  }

  bool _isApkUrl(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? "";
    return path.endsWith(".apk");
  }

  Future<void> _downloadAndInstall(String url) async {
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
      final name = _fileNameFor(url);
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

  String _fileNameFor(String url) {
    final segments = Uri.tryParse(url)?.pathSegments ?? const [];
    final segment = segments.isNotEmpty ? segments.last : "";
    if (segment.toLowerCase().endsWith(".apk")) return segment;
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (await _controller.canGoBack()) {
          await _controller.goBack();
        } else if (mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              WebViewWidget(controller: _controller),
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
