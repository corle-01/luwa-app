import 'dart:js_interop';
import 'dart:typed_data';

// ═════════════════════════════════════════════════════════════════════════
// WebUSB JS Interop Bindings
// ═════════════════════════════════════════════════════════════════════════

/// Access navigator.usb (WebUSB API).
@JS('navigator.usb')
external _UsbApi? get _navigatorUsb;

/// Check if WebUSB API is available in the current browser.
@JS('navigator.usb')
external JSAny? get _navigatorUsbCheck;

/// WebUSB API entry point.
extension type _UsbApi(JSObject _) implements JSObject {
  /// Request a USB device with filters. Triggers browser pairing dialog.
  external JSPromise<_UsbDevice> requestDevice(_UsbDeviceRequestOptions options);

  /// Get previously paired devices.
  external JSPromise<JSArray<_UsbDevice>> getDevices();
}

/// Options for requestDevice().
extension type _UsbDeviceRequestOptions._(JSObject _) implements JSObject {
  external factory _UsbDeviceRequestOptions({
    JSArray<JSObject> filters,
  });
}

/// A USB device returned by the WebUSB API.
extension type _UsbDevice(JSObject _) implements JSObject {
  external String get productName;
  external String get manufacturerName;
  external int get vendorId;
  external int get productId;
  external bool get opened;

  external JSPromise<JSAny?> open();
  external JSPromise<JSAny?> close();
  external JSPromise<JSAny?> selectConfiguration(int configurationValue);
  external JSPromise<JSAny?> claimInterface(int interfaceNumber);
  external JSPromise<JSAny?> releaseInterface(int interfaceNumber);
  external JSPromise<_UsbOutTransferResult> transferOut(
      int endpointNumber, JSArrayBuffer data);

  external JSArray<_UsbConfiguration>? get configurations;
}

/// USB transfer result.
extension type _UsbOutTransferResult(JSObject _) implements JSObject {
  external String get status; // 'ok', 'stall', 'babble'
  external int get bytesWritten;
}

/// USB configuration descriptor.
extension type _UsbConfiguration(JSObject _) implements JSObject {
  external int get configurationValue;
  external JSArray<_UsbInterface> get interfaces;
}

/// USB interface descriptor.
extension type _UsbInterface(JSObject _) implements JSObject {
  external int get interfaceNumber;
  external JSArray<_UsbAlternateInterface> get alternates;
}

/// USB alternate interface descriptor.
extension type _UsbAlternateInterface(JSObject _) implements JSObject {
  external int get alternateSetting;
  external int get interfaceClass;
  external JSArray<_UsbEndpoint> get endpoints;
}

/// USB endpoint descriptor.
extension type _UsbEndpoint(JSObject _) implements JSObject {
  external int get endpointNumber;
  external String get direction; // 'in' or 'out'
  external String get type; // 'bulk', 'interrupt', 'isochronous'
}

// ═════════════════════════════════════════════════════════════════════════
// WebUSB Printer Service
// ═════════════════════════════════════════════════════════════════════════

/// Result of a WebUSB operation.
class WebUsbResult {
  final bool success;
  final String message;
  final String? deviceName;
  final int? vendorId;
  final int? productId;

  const WebUsbResult({
    required this.success,
    required this.message,
    this.deviceName,
    this.vendorId,
    this.productId,
  });
}

/// WebUSB printer service for connecting and printing to USB thermal printers
/// via the browser WebUSB API.
///
/// Requires HTTPS and user gesture for `requestDevice()`.
/// Supported in Chrome, Edge, and Opera. Not supported in Firefox or Safari.
class WebUsbPrinter {
  _UsbDevice? _device;
  int _outEndpoint = 1; // Default OUT endpoint number

  /// Whether WebUSB API is available in the current browser.
  static bool get isSupported => _navigatorUsbCheck != null;

  /// Whether a device is currently connected (paired and open).
  bool get isConnected => _device != null && _device!.opened;

  /// The name of the currently paired device, or null.
  String? get deviceName {
    if (_device == null) return null;
    final mfr = _device!.manufacturerName;
    final product = _device!.productName;
    if (mfr.isNotEmpty && product.isNotEmpty) return '$mfr $product';
    if (product.isNotEmpty) return product;
    if (mfr.isNotEmpty) return mfr;
    return 'USB Printer';
  }

  /// Request a USB printer from the user (triggers browser pairing dialog).
  ///
  /// Uses common thermal printer vendor IDs as filters. If no filters match,
  /// falls back to showing all USB devices.
  Future<WebUsbResult> requestDevice() async {
    if (!isSupported) {
      return const WebUsbResult(
        success: false,
        message: 'WebUSB tidak didukung oleh browser ini. '
            'Gunakan Chrome, Edge, atau Opera.',
      );
    }

    try {
      // Common thermal printer vendor IDs:
      // 0x0483 - STMicroelectronics (many Chinese printers)
      // 0x0416 - WinChipHead (CH340 based printers)
      // 0x1A86 - QinHeng Electronics (CH340)
      // 0x04B8 - Epson
      // 0x0DD4 - Custom (receipt printers)
      // 0x0FE6 - ICS Electronics (Kontron)
      // 0x0525 - Netchip Technology (PLX)
      // 0x20D1 - unknown thermal printers
      // 0x0456 - Analog Devices
      // 0x1FC9 - NXP
      //
      // We use an empty filter to let the user pick any USB device,
      // since vendor IDs vary widely across thermal printer brands.
      final options = _UsbDeviceRequestOptions(
        filters: <JSObject>[].toJS,
      );

      _device = await _navigatorUsb!.requestDevice(options).toDart;

      return WebUsbResult(
        success: true,
        message: 'Perangkat USB berhasil dipasangkan: $deviceName',
        deviceName: deviceName,
        vendorId: _device!.vendorId,
        productId: _device!.productId,
      );
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('No device selected') ||
          errorMsg.contains('NotFoundError')) {
        return const WebUsbResult(
          success: false,
          message: 'Tidak ada perangkat yang dipilih.',
        );
      }
      return WebUsbResult(
        success: false,
        message: 'Gagal memasangkan perangkat USB: $errorMsg',
      );
    }
  }

  /// Get previously paired devices (does not trigger browser dialog).
  Future<List<WebUsbResult>> getPairedDevices() async {
    if (!isSupported) return [];

    try {
      final devices = await _navigatorUsb!.getDevices().toDart;
      return devices.toDart.map((d) {
        final mfr = d.manufacturerName;
        final product = d.productName;
        String name = 'USB Printer';
        if (mfr.isNotEmpty && product.isNotEmpty) {
          name = '$mfr $product';
        } else if (product.isNotEmpty) {
          name = product;
        }
        return WebUsbResult(
          success: true,
          message: name,
          deviceName: name,
          vendorId: d.vendorId,
          productId: d.productId,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Open connection to the paired device, configure it, and claim interface.
  Future<WebUsbResult> connect() async {
    if (_device == null) {
      return const WebUsbResult(
        success: false,
        message: 'Tidak ada perangkat USB yang dipasangkan. '
            'Pilih perangkat terlebih dahulu.',
      );
    }

    try {
      // Open device
      if (!_device!.opened) {
        await _device!.open().toDart;
      }

      // Select configuration (usually configuration 1)
      await _device!.selectConfiguration(1).toDart;

      // Find the correct interface and OUT endpoint
      _outEndpoint = _findOutEndpoint();

      // Claim interface 0
      await _device!.claimInterface(0).toDart;

      return WebUsbResult(
        success: true,
        message: 'Terhubung ke $deviceName',
        deviceName: deviceName,
      );
    } catch (e) {
      return WebUsbResult(
        success: false,
        message: 'Gagal membuka koneksi USB: $e',
      );
    }
  }

  /// Find the bulk OUT endpoint number from device configuration.
  int _findOutEndpoint() {
    try {
      final configs = _device!.configurations;
      if (configs == null) return 1;

      for (final config in configs.toDart) {
        for (final iface in config.interfaces.toDart) {
          for (final alt in iface.alternates.toDart) {
            for (final ep in alt.endpoints.toDart) {
              if (ep.direction == 'out' &&
                  (ep.type == 'bulk' || ep.type == 'interrupt')) {
                return ep.endpointNumber;
              }
            }
          }
        }
      }
    } catch (_) {
      // Fall through to default
    }
    return 1; // Default endpoint
  }

  /// Send raw ESC/POS bytes to the connected USB printer.
  ///
  /// Automatically chunks the data into packets of [chunkSize] bytes
  /// to avoid USB transfer size limits.
  Future<WebUsbResult> sendData(Uint8List data, {int chunkSize = 512}) async {
    if (_device == null || !_device!.opened) {
      return const WebUsbResult(
        success: false,
        message: 'Printer USB tidak terhubung.',
      );
    }

    try {
      // Send data in chunks to avoid buffer overflow on some printers
      int offset = 0;
      while (offset < data.length) {
        final end =
            (offset + chunkSize > data.length) ? data.length : offset + chunkSize;
        final chunk = data.sublist(offset, end);

        final jsBuffer = chunk.buffer.toJS;
        final result =
            await _device!.transferOut(_outEndpoint, jsBuffer).toDart;

        if (result.status != 'ok') {
          return WebUsbResult(
            success: false,
            message: 'Transfer USB gagal: status=${result.status}',
          );
        }

        offset = end;
      }

      return WebUsbResult(
        success: true,
        message: 'Data terkirim ke $deviceName (${data.length} bytes)',
        deviceName: deviceName,
      );
    } catch (e) {
      return WebUsbResult(
        success: false,
        message: 'Gagal mengirim data ke printer USB: $e',
      );
    }
  }

  /// Disconnect from the USB device.
  Future<WebUsbResult> disconnect() async {
    if (_device == null) {
      return const WebUsbResult(
        success: true,
        message: 'Tidak ada perangkat yang terhubung.',
      );
    }

    try {
      if (_device!.opened) {
        await _device!.releaseInterface(0).toDart;
        await _device!.close().toDart;
      }
      final name = deviceName;
      _device = null;
      return WebUsbResult(
        success: true,
        message: 'Terputus dari $name',
      );
    } catch (e) {
      _device = null;
      return WebUsbResult(
        success: false,
        message: 'Error saat memutuskan koneksi: $e',
      );
    }
  }

  /// Print ESC/POS data: connect, send, and optionally disconnect.
  ///
  /// This is the main method to call for printing. It handles the full
  /// lifecycle: connect -> send data -> keep connection alive.
  Future<WebUsbResult> print(Uint8List escPosData,
      {bool keepConnected = true}) async {
    // Connect if not already connected
    if (!isConnected) {
      final connectResult = await connect();
      if (!connectResult.success) return connectResult;
    }

    // Send data
    final sendResult = await sendData(escPosData);
    if (!sendResult.success) return sendResult;

    // Disconnect if not keeping connection
    if (!keepConnected) {
      await disconnect();
    }

    return WebUsbResult(
      success: true,
      message: 'Berhasil mencetak melalui USB ($deviceName)',
      deviceName: deviceName,
    );
  }
}
