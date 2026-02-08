/// Conditional export for platform-specific CSV download.
///
/// On web builds (where dart.library.js_interop is available),
/// uses browser APIs to trigger a file download.
/// On all other platforms, uses the no-op stub.
export 'export_download_stub.dart'
    if (dart.library.js_interop) 'export_download_web.dart';
