import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme/app_spacing.dart';
import 'tuya_providers.dart';

/// Hosts Tuya's "Link Tuya App Account" authorization page in an in-app
/// WebView. When Tuya redirects to our configured `redirectUri`
/// (`botdynax://tuya-callback?code=...`), we intercept that navigation
/// before the OS ever sees it, extract the code, and exchange it for a
/// link via the backend — never touching Tuya credentials directly.
class TuyaLinkScreen extends ConsumerStatefulWidget {
  const TuyaLinkScreen({super.key});

  @override
  ConsumerState<TuyaLinkScreen> createState() => _TuyaLinkScreenState();
}

class _TuyaLinkScreenState extends ConsumerState<TuyaLinkScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _errorMessage;

  static const String _redirectScheme = 'botdynax://tuya-callback';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _handleNavigation,
          onPageFinished: (String _) => setState(() => _isLoading = false),
        ),
      );
    _loadAuthUrl();
  }

  Future<void> _loadAuthUrl() async {
    try {
      final String url = await ref.read(tuyaLinkServiceProvider).getAuthUrl();
      await _controller.loadRequest(Uri.parse(url));
    } catch (error) {
      setState(() => _errorMessage = 'Unable to start Tuya sign-in: $error');
    }
  }

  NavigationDecision _handleNavigation(NavigationRequest request) {
    if (request.url.startsWith(_redirectScheme)) {
      final Uri uri = Uri.parse(request.url);
      final String? code = uri.queryParameters['code'];
      if (code != null) {
        unawaited(_completeLink(code));
      } else {
        setState(() => _errorMessage = 'Tuya did not return an authorization code.');
      }
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  Future<void> _completeLink(String code) async {
    setState(() => _isLoading = true);
    try {
      await ref.read(tuyaLinkServiceProvider).linkAccount(code);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _errorMessage = 'Failed to link your Tuya account: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Link Tuya Account')),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
          if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(_errorMessage!, textAlign: TextAlign.center),
              ),
            ),
        ],
      ),
    );
  }
}
