// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Opens a new browser window with the given HTML content and triggers print.
/// This file is only imported on web builds via conditional import.
void openPrintWindow(String receiptHtml) {
  final printWindow = html.window.open('', '_blank');
  if (printWindow != null) {
    printWindow.document.write(receiptHtml);
    printWindow.document.close();
    // The window.onload script in the HTML will trigger print()
  }
}
