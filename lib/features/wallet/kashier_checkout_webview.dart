import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Fullscreen WebView that loads the Kashier payment session URL and
/// listens for the redirect to the `/api/v1/wallet/kashier-callback` route.
///
/// On a successful callback it waits a moment (so the backend can credit the
/// wallet) then pops with `true`. On failure it pops with `false`.
class KashierCheckoutWebView extends StatefulWidget {
  final String checkoutUrl;
  final String sessionId;

  const KashierCheckoutWebView({
    super.key,
    required this.checkoutUrl,
    required this.sessionId,
  });

  @override
  State<KashierCheckoutWebView> createState() => _KashierCheckoutWebViewState();
}

class _KashierCheckoutWebViewState extends State<KashierCheckoutWebView> {
  late final WebViewController _controller;
  bool _finished = false;

  // The backend callback path we watch for.
  static const String _callbackPath = '/api/v1/wallet/kashier-callback';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            _handleUrl(request.url);
            return NavigationDecision.navigate;
          },
          onPageStarted: (url) => _handleUrl(url),
          onPageFinished: (url) => _handleUrl(url),
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  void _handleUrl(String url) {
    if (_finished) return;

    // Watch for the backend callback redirect.
    if (url.contains(_callbackPath)) {
      final uri = Uri.tryParse(url);
      final status = uri?.queryParameters['status']?.toLowerCase();
      final paymentStatus = uri?.queryParameters['paymentStatus']
          ?.toUpperCase();

      final isSuccess =
          status == 'success' ||
          paymentStatus == 'SUCCESS' ||
          paymentStatus == 'PAID';

      _finished = true;
      // Give the backend a moment to credit the wallet before closing.
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.of(context).pop(isSuccess);
      });
      return;
    }

    // Some Kashier flows signal failure via a query param on the checkout page.
    final uri = Uri.tryParse(url);
    final failure =
        uri?.queryParameters['status']?.toLowerCase() == 'failed' ||
        uri?.queryParameters['paymentStatus']?.toUpperCase() == 'FAILED';
    if (failure) {
      _finished = true;
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) Navigator.of(context).pop(false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: const Text('شحن المحفظة', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
