import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Fullscreen WebView that loads the Kashier payment session URL and
/// listens for the redirect to the `/api/v1/wallet/kashier-callback` route.
///
/// On a successful callback it waits a moment (so the backend can credit the
/// wallet) then pops with `true`. On failure it pops with `false`.
///
/// **السلامة:** هذا الـ Widget لا يرمي أبداً من [initState]. إذا كان الرابط
/// غير صالح أو فشل إنشاء/تحميل الـ WebView، نعرض شاشة خطأ ودّية مع زر رجوع
/// وزر «فتح في المتصفح» بدلاً من ErrorWidget الذي يكسر التطبيق.
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
  WebViewController? _controller;
  bool _finished = false;
  bool _failed = false;

  // The backend callback path we watch for.
  static const String _callbackPath = '/api/v1/wallet/kashier-callback';

  /// Whether [widget.checkoutUrl] هو رابط http(s) صالح يمكن فتحه.
  bool get _hasValidUrl {
    final url = widget.checkoutUrl.trim();
    return url.isNotEmpty &&
        (url.startsWith('http://') || url.startsWith('https://'));
  }

  @override
  void initState() {
    super.initState();
    // ── لا نرمي أبداً من initState ──────────────────────────────────
    if (!_hasValidUrl) {
      _failed = true;
      return;
    }
    // على الويب لا يمكن تضمين بوابة الدفع داخل WebView (يتطلب webview_flutter_web
    // وبوابة Kashier تحجب التضمين داخل iframe). نفتح الرابط في المتصفح مباشرة
    // حتى لا نصل لخطأ الـ Assertion في منصة الويب.
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_openInBrowser());
      });
      return;
    }
    try {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: (request) {
              _handleUrl(request.url);
              return NavigationDecision.navigate;
            },
            onPageStarted: (url) => _handleUrl(url),
            onPageFinished: (url) {
              _handleUrl(url);
              _handlePageFinished(url);
            },
            onWebResourceError: (error) {
              // أخطاء الموارد الثانوية (favicon / صور) غير قاتلة؛ نعرض
              // شاشة الخطأ فقط لو فشل تحميل الصفحة الرئيسية نفسها.
              if (!_finished && !_failed && (error.isForMainFrame ?? false)) {
                // نُجدول الـ setState بعد نهاية الـ frame حتى لا يُستدعى
                // أثناء مرحلة الـ build (كان يسبب خطأ أحمر عند السطر 70).
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _failed = true);
                });
              }
            },
          ),
        )
        ..loadRequest(Uri.parse(widget.checkoutUrl));
    } catch (_) {
      // أي استثناء هنا (رابط غير صالح، منصة بلا WebView...) يُعرض كشاشة
      // خطأ بدلاً من كسر التطبيق.
      _failed = true;
    }
  }

  void _handleUrl(String url) {
    if (_finished || _failed) return;

    // Watch for the backend callback redirect.
    // Kashier v3 redirects to the merchantRedirect URL (our /kashier-callback)
    // carrying the sessionId; the backend then renders an HTML success/failure
    // page. We treat reaching the callback path as the signal to close.
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
      Future.delayed(const Duration(seconds: 3), () {
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

  /// Called by the navigation delegate when a page finishes loading.
  /// We inspect the rendered HTML to detect the backend's success/failure
  /// page (in case the redirect URL lacks query params).
  void _handlePageFinished(String url) {
    if (_finished || _failed) return;
    final controller = _controller;
    if (controller == null) return;
    controller
        .runJavaScriptReturningResult("document.body.innerText")
        .then((result) {
          final text = result.toString().toLowerCase();
          if (text.contains('تم شحن المحفظة بنجاح') ||
              text.contains('success')) {
            _finished = true;
            Future.delayed(const Duration(seconds: 1), () {
              if (mounted) Navigator.of(context).pop(true);
            });
          } else if (text.contains('فشل') || text.contains('خطأ')) {
            _finished = true;
            Future.delayed(const Duration(seconds: 1), () {
              if (mounted) Navigator.of(context).pop(false);
            });
          }
        })
        .catchError((_) {
          // ignore — page text not readable
        });
  }

  /// يفتح رابط الدفع في المتصفح الخارجي (تشخيص/بديل عند فشل الـ WebView،
  /// وهو المسار الوحيد على الويب).
  Future<void> _openInBrowser() async {
    try {
      final url = widget.checkoutUrl.trim();
      final uri = Uri.tryParse(url);
      if (uri == null || !uri.hasScheme) {
        _showSnack('رابط الدفع غير صالح');
        return;
      }
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) _showSnack('تعذر فتح المتصفح الخارجي');
    } catch (_) {
      if (mounted) _showSnack('تعذر فتح المتصفح الخارجي');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: const Text('شحن المحفظة', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        actions: [
          if (_hasValidUrl)
            IconButton(
              tooltip: 'فتح في المتصفح',
              icon: const Icon(Icons.open_in_browser, color: Colors.white),
              onPressed: _openInBrowser,
            ),
        ],
      ),
      // WebViewWidget فقط لو اتبنى الـ controller بنجاح وبدون أخطاء.
      body: kIsWeb
          ? _buildWebExternalBody()
          : (_failed || controller == null)
          ? _buildErrorBody()
          : WebViewWidget(controller: controller),
    );
  }

  /// شاشة الويب: فتحنا الدفع في تبويب المتصفح، نعرض رسالة إرشادية.
  Widget _buildWebExternalBody() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.open_in_new_rounded,
              color: Color(0xFF7ED957),
              size: 56,
            ),
            const SizedBox(height: 16),
            const Text(
              'تم فتح صفحة الدفع في المتصفح',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'أكمل الدفع في تبويب المتصفح ثم عُد إلى التطبيق.',
              style: TextStyle(color: Colors.white60, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(false),
              icon: const Icon(Icons.close),
              label: const Text('إغلاق'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7ED957),
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBody() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: Colors.white38,
              size: 56,
            ),
            const SizedBox(height: 16),
            const Text(
              'تعذر فتح صفحة الدفع',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'تحقق من اتصالك بالإنترنت ثم أعد المحاولة.',
              style: TextStyle(color: Colors.white60, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close),
                  label: const Text('إغلاق'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                  ),
                ),
                if (_hasValidUrl) ...[
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _openInBrowser,
                    icon: const Icon(Icons.open_in_browser),
                    label: const Text('فتح في المتصفح'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7ED957),
                      foregroundColor: Colors.black,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
