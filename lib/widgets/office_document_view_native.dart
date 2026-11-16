import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

Widget createOfficeDocumentView(String url) {
  final controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setBackgroundColor(Colors.transparent)
    ..loadRequest(Uri.parse(url));
  return WebViewWidget(controller: controller);
}
