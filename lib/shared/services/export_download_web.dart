import 'dart:js_interop';
import 'dart:convert';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

/// Triggers a CSV file download in the browser.
///
/// Creates a Blob from the CSV content, generates an object URL,
/// and programmatically clicks a hidden anchor element to start the download.
/// This file is only imported on web builds via conditional import.
void downloadCsv(String csvContent, String fileName) {
  // Add BOM (Byte Order Mark) for Excel UTF-8 compatibility
  final bom = [0xEF, 0xBB, 0xBF];
  final contentBytes = utf8.encode(csvContent);
  final allBytes = Uint8List(bom.length + contentBytes.length);
  allBytes.setAll(0, bom);
  allBytes.setAll(bom.length, contentBytes);

  final blob = web.Blob(
    [allBytes.toJS].toJS,
    web.BlobPropertyBag(type: 'text/csv;charset=utf-8'),
  );

  final url = web.URL.createObjectURL(blob);

  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = url;
  anchor.download = fileName;
  anchor.style.display = 'none';

  web.document.body!.appendChild(anchor);
  anchor.click();
  web.document.body!.removeChild(anchor);
  web.URL.revokeObjectURL(url);
}
