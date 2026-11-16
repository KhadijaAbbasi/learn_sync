import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

Widget createOfficeDocumentView(String url) {
  return HtmlElementView.fromTagName(
    key: ValueKey(url),
    tagName: 'iframe',
    onElementCreated: (element) {
      final frame = element as web.HTMLIFrameElement;
      frame
        ..src = url
        ..title = 'Course document'
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%';
    },
  );
}
