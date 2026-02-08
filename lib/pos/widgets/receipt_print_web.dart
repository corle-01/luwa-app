import 'dart:js_interop';

/// Opens a new browser window with the given HTML content and triggers print.
/// This file is only imported on web builds via conditional import.
void openPrintWindow(String receiptHtml) {
  final win = _windowOpen(''.toJS, '_blank'.toJS);
  if (win != null) {
    win.document.write(receiptHtml.toJS);
    win.document.close();
  }
}

@JS('window.open')
external _PrintWindow? _windowOpen(JSString url, JSString target);

extension type _PrintWindow(JSObject _) implements JSObject {
  external _PrintDocument get document;
}

extension type _PrintDocument(JSObject _) implements JSObject {
  external void write(JSString data);
  external void close();
}
