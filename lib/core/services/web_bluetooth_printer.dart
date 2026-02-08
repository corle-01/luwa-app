import 'dart:js_interop';
import 'dart:typed_data';

// ═════════════════════════════════════════════════════════════════════════
// Web Bluetooth JS Interop Bindings
// ═════════════════════════════════════════════════════════════════════════

/// Access navigator.bluetooth (Web Bluetooth API).
@JS('navigator.bluetooth')
external _BluetoothApi? get _navigatorBluetooth;

/// Check if Web Bluetooth API is available in the current browser.
@JS('navigator.bluetooth')
external JSAny? get _navigatorBluetoothCheck;

/// Web Bluetooth API entry point.
extension type _BluetoothApi(JSObject _) implements JSObject {
  /// Request a Bluetooth device with filters. Triggers browser pairing dialog.
  external JSPromise<_BluetoothDevice> requestDevice(
      _BluetoothRequestOptions options);

  /// Get previously paired devices (requires permission).
  external JSPromise<JSArray<_BluetoothDevice>> getDevices();
}

/// Options for requestDevice().
extension type _BluetoothRequestOptions._(JSObject _) implements JSObject {
  external factory _BluetoothRequestOptions({
    JSArray<_BluetoothScanFilter>? filters,
    JSArray<JSString>? optionalServices,
    bool acceptAllDevices,
  });
}

/// Bluetooth scan filter.
extension type _BluetoothScanFilter._(JSObject _) implements JSObject {
  external factory _BluetoothScanFilter({
    JSArray<JSString>? services,
    JSString? name,
    JSString? namePrefix,
  });
}

/// A Bluetooth device.
extension type _BluetoothDevice(JSObject _) implements JSObject {
  external String get id;
  external String? get name;
  external _BluetoothRemoteGattServer? get gatt;
}

/// GATT server for the device.
extension type _BluetoothRemoteGattServer(JSObject _) implements JSObject {
  external bool get connected;
  external JSPromise<_BluetoothRemoteGattServer> connect();
  external void disconnect();
  external JSPromise<_BluetoothRemoteGattService> getPrimaryService(
      JSString serviceUUID);
}

/// GATT service.
extension type _BluetoothRemoteGattService(JSObject _) implements JSObject {
  external String get uuid;
  external JSPromise<_BluetoothRemoteGattCharacteristic> getCharacteristic(
      JSString characteristicUUID);
}

/// GATT characteristic.
extension type _BluetoothRemoteGattCharacteristic(JSObject _)
    implements JSObject {
  external String get uuid;
  external JSPromise<JSAny?> writeValue(JSArrayBuffer value);
  external JSPromise<JSAny?> writeValueWithResponse(JSArrayBuffer value);
  external JSPromise<JSAny?> writeValueWithoutResponse(JSArrayBuffer value);
}

// ═════════════════════════════════════════════════════════════════════════
// Bluetooth Printer Service UUIDs
// ═════════════════════════════════════════════════════════════════════════

/// Common Bluetooth printer service UUIDs used by various thermal printers.
///
/// Different manufacturers use different GATT service/characteristic UUIDs.
/// These cover the most common thermal printers found in POS environments.
class BluetoothPrinterUuids {
  BluetoothPrinterUuids._();

  /// Standard Serial Port Profile (SPP) emulated over BLE.
  static const String sppService = '00001101-0000-1000-8000-00805f9b34fb';

  /// Common Chinese thermal printer service (e.g., Xprinter, POS-58, etc.)
  static const String thermalService = '000018f0-0000-1000-8000-00805f9b34fb';

  /// Common Chinese thermal printer write characteristic.
  static const String thermalCharWrite = '00002af1-0000-1000-8000-00805f9b34fb';

  /// Alternative service for some printers (Goojprt, Milestone, etc.)
  static const String altService1 = '49535343-fe7d-4ae5-8fa9-9fafd205e455';

  /// Alternative write characteristic.
  static const String altCharWrite1 = '49535343-8841-43f4-a8d4-ecbe34729bb3';

  /// Another common BLE printer service.
  static const String altService2 = 'e7810a71-73ae-499d-8c15-faa9aef0c3f2';

  /// Another common write characteristic.
  static const String altCharWrite2 = 'bef8d6c9-9c21-4c9e-b632-bd58c1009f9f';

  /// All known service UUIDs for scanning.
  static const List<String> allServices = [
    thermalService,
    altService1,
    altService2,
  ];

  /// Service-to-characteristic mapping for auto-detection.
  static const Map<String, String> serviceCharacteristicMap = {
    thermalService: thermalCharWrite,
    altService1: altCharWrite1,
    altService2: altCharWrite2,
  };
}

// ═════════════════════════════════════════════════════════════════════════
// WebBluetooth Printer Service
// ═════════════════════════════════════════════════════════════════════════

/// Result of a Web Bluetooth operation.
class WebBluetoothResult {
  final bool success;
  final String message;
  final String? deviceName;
  final String? deviceId;

  const WebBluetoothResult({
    required this.success,
    required this.message,
    this.deviceName,
    this.deviceId,
  });
}

/// Web Bluetooth printer service for connecting and printing to Bluetooth
/// thermal printers via the browser Web Bluetooth API.
///
/// Requires HTTPS and user gesture for `requestDevice()`.
/// Supported in Chrome, Edge, and Opera. Not supported in Firefox or Safari.
class WebBluetoothPrinter {
  _BluetoothDevice? _device;
  _BluetoothRemoteGattServer? _server;
  _BluetoothRemoteGattCharacteristic? _writeCharacteristic;
  String? _connectedServiceUuid;

  /// Whether Web Bluetooth API is available in the current browser.
  static bool get isSupported => _navigatorBluetoothCheck != null;

  /// Whether a device is currently connected via GATT.
  bool get isConnected => _server != null && _server!.connected;

  /// The name of the currently paired device, or null.
  String? get deviceName {
    if (_device == null) return null;
    return _device!.name ?? 'Bluetooth Printer';
  }

  /// The ID of the currently paired device, or null.
  String? get deviceId => _device?.id;

  /// Request a Bluetooth printer from the user (triggers browser pairing dialog).
  ///
  /// Scans for devices advertising common thermal printer BLE services.
  /// Falls back to `acceptAllDevices` if no filtered devices are found.
  Future<WebBluetoothResult> requestDevice({bool acceptAll = false}) async {
    if (!isSupported) {
      return const WebBluetoothResult(
        success: false,
        message: 'Web Bluetooth tidak didukung oleh browser ini. '
            'Gunakan Chrome, Edge, atau Opera.',
      );
    }

    try {
      _BluetoothRequestOptions options;

      if (acceptAll) {
        // Show all Bluetooth devices (broader scan)
        options = _BluetoothRequestOptions(
          acceptAllDevices: true,
          optionalServices: BluetoothPrinterUuids.allServices
              .map((s) => s.toJS)
              .toList()
              .toJS,
        );
      } else {
        // Filter by known thermal printer services
        options = _BluetoothRequestOptions(
          filters: [
            // Filter by common thermal printer service UUIDs
            _BluetoothScanFilter(
              services: [BluetoothPrinterUuids.thermalService.toJS].toJS,
            ),
            _BluetoothScanFilter(
              services: [BluetoothPrinterUuids.altService1.toJS].toJS,
            ),
            _BluetoothScanFilter(
              services: [BluetoothPrinterUuids.altService2.toJS].toJS,
            ),
            // Also filter by common printer name prefixes
            _BluetoothScanFilter(namePrefix: 'Printer'.toJS),
            _BluetoothScanFilter(namePrefix: 'POS'.toJS),
            _BluetoothScanFilter(namePrefix: 'MTP'.toJS),
            _BluetoothScanFilter(namePrefix: 'RPP'.toJS),
            _BluetoothScanFilter(namePrefix: 'BlueTooth'.toJS),
            _BluetoothScanFilter(namePrefix: 'Thermal'.toJS),
            _BluetoothScanFilter(namePrefix: 'XP-'.toJS),
          ].toJS,
          optionalServices: BluetoothPrinterUuids.allServices
              .map((s) => s.toJS)
              .toList()
              .toJS,
          acceptAllDevices: false,
        );
      }

      _device = await _navigatorBluetooth!.requestDevice(options).toDart;

      return WebBluetoothResult(
        success: true,
        message: 'Perangkat Bluetooth berhasil dipasangkan: $deviceName',
        deviceName: deviceName,
        deviceId: deviceId,
      );
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('User cancelled') ||
          errorMsg.contains('NotFoundError')) {
        // If filtered search found nothing, suggest acceptAll
        if (!acceptAll) {
          return const WebBluetoothResult(
            success: false,
            message: 'Tidak ada printer ditemukan. '
                'Coba gunakan mode "Tampilkan Semua Perangkat".',
          );
        }
        return const WebBluetoothResult(
          success: false,
          message: 'Tidak ada perangkat yang dipilih.',
        );
      }
      return WebBluetoothResult(
        success: false,
        message: 'Gagal memasangkan perangkat Bluetooth: $errorMsg',
      );
    }
  }

  /// Connect to the GATT server and discover the print characteristic.
  ///
  /// Tries each known thermal printer service UUID until one works.
  Future<WebBluetoothResult> connect() async {
    if (_device == null) {
      return const WebBluetoothResult(
        success: false,
        message: 'Tidak ada perangkat Bluetooth yang dipasangkan. '
            'Pilih perangkat terlebih dahulu.',
      );
    }

    final gatt = _device!.gatt;
    if (gatt == null) {
      return const WebBluetoothResult(
        success: false,
        message: 'Perangkat tidak mendukung GATT.',
      );
    }

    try {
      // Connect to GATT server
      _server = await gatt.connect().toDart;

      // Try each known service UUID
      for (final entry
          in BluetoothPrinterUuids.serviceCharacteristicMap.entries) {
        try {
          final service =
              await _server!.getPrimaryService(entry.key.toJS).toDart;
          _writeCharacteristic =
              await service.getCharacteristic(entry.value.toJS).toDart;
          _connectedServiceUuid = entry.key;

          return WebBluetoothResult(
            success: true,
            message: 'Terhubung ke $deviceName',
            deviceName: deviceName,
            deviceId: deviceId,
          );
        } catch (_) {
          // This service/characteristic pair not available, try next
          continue;
        }
      }

      // None of the known UUIDs worked
      _server?.disconnect();
      _server = null;
      return const WebBluetoothResult(
        success: false,
        message: 'Tidak dapat menemukan layanan printer yang kompatibel. '
            'Pastikan perangkat adalah printer thermal BLE.',
      );
    } catch (e) {
      _server = null;
      return WebBluetoothResult(
        success: false,
        message: 'Gagal terhubung ke Bluetooth: $e',
      );
    }
  }

  /// Send raw ESC/POS bytes to the connected Bluetooth printer.
  ///
  /// BLE has a maximum transmission unit (MTU) typically around 20-512 bytes.
  /// This method chunks the data into packets of [chunkSize] bytes and adds
  /// a small delay between chunks for printer buffer management.
  Future<WebBluetoothResult> sendData(Uint8List data,
      {int chunkSize = 100}) async {
    if (_writeCharacteristic == null || !isConnected) {
      return const WebBluetoothResult(
        success: false,
        message: 'Printer Bluetooth tidak terhubung.',
      );
    }

    try {
      int offset = 0;
      while (offset < data.length) {
        final end =
            (offset + chunkSize > data.length) ? data.length : offset + chunkSize;
        final chunk = data.sublist(offset, end);

        final jsBuffer = chunk.buffer.toJS;

        try {
          // Try writeValueWithoutResponse first (faster)
          await _writeCharacteristic!
              .writeValueWithoutResponse(jsBuffer)
              .toDart;
        } catch (_) {
          // Fall back to writeValue (with response)
          try {
            await _writeCharacteristic!
                .writeValueWithResponse(jsBuffer)
                .toDart;
          } catch (_) {
            // Last resort: legacy writeValue
            await _writeCharacteristic!.writeValue(jsBuffer).toDart;
          }
        }

        offset = end;

        // Small delay between chunks to prevent buffer overflow
        if (offset < data.length) {
          await Future.delayed(const Duration(milliseconds: 20));
        }
      }

      return WebBluetoothResult(
        success: true,
        message: 'Data terkirim ke $deviceName (${data.length} bytes)',
        deviceName: deviceName,
        deviceId: deviceId,
      );
    } catch (e) {
      return WebBluetoothResult(
        success: false,
        message: 'Gagal mengirim data ke printer Bluetooth: $e',
      );
    }
  }

  /// Disconnect from the Bluetooth device.
  Future<WebBluetoothResult> disconnect() async {
    final name = deviceName;

    try {
      _server?.disconnect();
    } catch (_) {
      // Ignore disconnect errors
    }

    _writeCharacteristic = null;
    _server = null;
    _connectedServiceUuid = null;
    // Keep _device reference so we can reconnect without re-pairing

    return WebBluetoothResult(
      success: true,
      message: 'Terputus dari $name',
    );
  }

  /// Fully unpair: disconnect and forget the device reference.
  Future<WebBluetoothResult> unpair() async {
    await disconnect();
    _device = null;
    return const WebBluetoothResult(
      success: true,
      message: 'Perangkat Bluetooth dihapus.',
    );
  }

  /// Print ESC/POS data: connect, send, and optionally disconnect.
  ///
  /// This is the main method to call for printing. It handles the full
  /// lifecycle: connect -> send data -> keep connection alive.
  Future<WebBluetoothResult> print(Uint8List escPosData,
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

    return WebBluetoothResult(
      success: true,
      message: 'Berhasil mencetak melalui Bluetooth ($deviceName)',
      deviceName: deviceName,
      deviceId: deviceId,
    );
  }
}
