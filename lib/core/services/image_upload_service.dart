import 'dart:async';
import 'dart:typed_data';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Result of a file picker operation on web.
class PickedFile {
  final String name;
  final String mimeType;
  final Uint8List bytes;

  PickedFile({
    required this.name,
    required this.mimeType,
    required this.bytes,
  });
}

/// Service for picking images from the browser and uploading them to
/// Supabase Storage.
///
/// Uses `dart:js_interop` + `package:web` for the HTML file input (no
/// `dart:html` dependency -- compatible with Flutter 3.38+).
class ImageUploadService {
  static const _bucketName = 'product-images';
  static final _supabase = Supabase.instance.client;
  static const _uuid = Uuid();

  /// Opens the browser file picker filtered to images.
  /// Returns a [PickedFile] if the user selects a file, or `null` if cancelled.
  static Future<PickedFile?> pickImage() async {
    final completer = Completer<PickedFile?>();

    final input =
        web.document.createElement('input') as web.HTMLInputElement;
    input.type = 'file';
    input.accept = 'image/jpeg,image/png,image/webp,image/gif';

    // Listen for file selection
    input.addEventListener(
      'change',
      (web.Event event) {
        final files = input.files;
        if (files == null || files.length == 0) {
          completer.complete(null);
          return;
        }

        final file = files.item(0)!;
        final reader = web.FileReader();

        reader.addEventListener(
          'load',
          (web.Event e) {
            final result = reader.result;
            if (result == null) {
              completer.complete(null);
              return;
            }
            // result is an ArrayBuffer as JSObject
            final arrayBuffer = result as JSArrayBuffer;
            final bytes = arrayBuffer.toDart.asUint8List();
            completer.complete(PickedFile(
              name: file.name,
              mimeType: file.type,
              bytes: bytes,
            ));
          }.toJS,
        );

        reader.addEventListener(
          'error',
          (web.Event e) {
            completer.complete(null);
          }.toJS,
        );

        reader.readAsArrayBuffer(file);
      }.toJS,
    );

    // Handle cancel (focus returns to window without a file selected)
    // Use a delayed check since there's no reliable "cancel" event for file inputs
    input.addEventListener(
      'cancel',
      (web.Event event) {
        completer.complete(null);
      }.toJS,
    );

    input.click();

    return completer.future;
  }

  /// Uploads [bytes] to Supabase Storage under the product-images bucket.
  ///
  /// Returns the public URL of the uploaded image.
  /// The file is stored as `products/{productId}/{uuid}.{ext}`.
  static Future<String> uploadImage({
    required String productId,
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    // Determine file extension from the original file name
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : 'jpg';
    final storagePath = 'products/$productId/${_uuid.v4()}.$ext';

    await _supabase.storage.from(_bucketName).uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(
            contentType: mimeType,
            upsert: true,
          ),
        );

    // Get the public URL
    final publicUrl =
        _supabase.storage.from(_bucketName).getPublicUrl(storagePath);
    return publicUrl;
  }

  /// Deletes an image from Supabase Storage by its public URL.
  ///
  /// Extracts the storage path from the URL and removes the file.
  static Future<void> deleteImage(String publicUrl) async {
    // Public URL format:
    // https://<ref>.supabase.co/storage/v1/object/public/product-images/products/...
    // We need the path after "product-images/"
    final marker = '$_bucketName/';
    final idx = publicUrl.indexOf(marker);
    if (idx == -1) return;

    final storagePath = publicUrl.substring(idx + marker.length);
    await _supabase.storage.from(_bucketName).remove([storagePath]);
  }
}
