import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../shared/themes/app_theme.dart';
import '../../core/services/printer_service.dart';
import '../../core/services/escpos_generator.dart';
import '../../core/services/web_usb_printer.dart';
import '../../core/services/web_bluetooth_printer.dart';

/// Printer management settings page.
///
/// Allows the user to add, edit, delete, test, and set a default thermal
/// printer. Supports Browser, USB, Network, and Bluetooth connection types
/// with 80mm or 58mm paper width.
class PrinterSettingsPage extends StatefulWidget {
  const PrinterSettingsPage({super.key});

  @override
  State<PrinterSettingsPage> createState() => _PrinterSettingsPageState();
}

class _PrinterSettingsPageState extends State<PrinterSettingsPage> {
  final PrinterService _service = PrinterService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Start with browser-default if no printers are saved.
    if (_service.printers.isEmpty) {
      _service.addPrinter(PrinterConfig.browserDefault());
    }
  }

  // ─── Actions ──────────────────────────────────────────────────

  void _showAddPrinterDialog() => _showPrinterDialog();

  void _showEditPrinterDialog(PrinterConfig config) =>
      _showPrinterDialog(existing: config);

  void _showPrinterDialog({PrinterConfig? existing}) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final addressCtrl = TextEditingController(text: existing?.address ?? '');
    var selectedType = existing?.type ?? PrinterType.usb;
    var selectedWidth = existing?.paperWidth ?? 80;
    var setAsDefault = existing?.isDefault ?? false;
    String? pairedDeviceName;
    bool isPairing = false;

    // Check if a device is already paired for existing printers
    if (existing != null) {
      if (existing.type == PrinterType.usb && _service.webUsb.deviceName != null) {
        pairedDeviceName = _service.webUsb.deviceName;
      } else if (existing.type == PrinterType.bluetooth &&
          _service.webBluetooth.deviceName != null) {
        pairedDeviceName = _service.webBluetooth.deviceName;
      }
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final needsAddress =
                selectedType == PrinterType.network;
            final needsPairing =
                selectedType == PrinterType.usb ||
                selectedType == PrinterType.bluetooth;

            // Check current pairing status based on selected type
            String? currentPairedName;
            if (selectedType == PrinterType.usb) {
              currentPairedName = pairedDeviceName ?? _service.webUsb.deviceName;
            } else if (selectedType == PrinterType.bluetooth) {
              currentPairedName = pairedDeviceName ?? _service.webBluetooth.deviceName;
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.print_rounded,
                      color: Color(0xFF6366F1),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEdit ? 'Edit Printer' : 'Tambah Printer',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Printer name
                      _fieldLabel('Nama Printer'),
                      const SizedBox(height: 6),
                      TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          hintText: 'Contoh: Kasir Utama',
                          prefixIcon: const Icon(Icons.label_outline, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Connection type
                      _fieldLabel('Tipe Koneksi'),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: PrinterType.values.map((type) {
                          final isSelected = selectedType == type;
                          return ChoiceChip(
                            label: Text(printerTypeLabel(type)),
                            selected: isSelected,
                            onSelected: (sel) {
                              if (sel) {
                                setDialogState(() => selectedType = type);
                              }
                            },
                            avatar: Icon(
                              _iconForType(type),
                              size: 16,
                              color: isSelected
                                  ? Colors.white
                                  : AppTheme.textSecondary,
                            ),
                            selectedColor: const Color(0xFF6366F1),
                            labelStyle: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : AppTheme.textPrimary,
                            ),
                            backgroundColor: AppTheme.backgroundColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: isSelected
                                    ? const Color(0xFF6366F1)
                                    : AppTheme.borderColor,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),

                      // Paper width
                      _fieldLabel('Lebar Kertas'),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _paperWidthOption(
                            label: '80 mm',
                            subtitle: '48 kolom',
                            value: 80,
                            selected: selectedWidth,
                            onTap: () =>
                                setDialogState(() => selectedWidth = 80),
                          ),
                          const SizedBox(width: 12),
                          _paperWidthOption(
                            label: '58 mm',
                            subtitle: '32 kolom',
                            value: 58,
                            selected: selectedWidth,
                            onTap: () =>
                                setDialogState(() => selectedWidth = 58),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Network address (only for network type)
                      if (needsAddress) ...[
                        _fieldLabel('Alamat IP : Port'),
                        const SizedBox(height: 6),
                        TextField(
                          controller: addressCtrl,
                          decoration: InputDecoration(
                            hintText: '192.168.1.100:9100',
                            prefixIcon:
                                const Icon(Icons.dns_outlined, size: 20),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Device pairing section (USB / Bluetooth)
                      if (needsPairing) ...[
                        _fieldLabel('Pasangkan Perangkat'),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.backgroundColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Paired device info
                              if (currentPairedName != null) ...[
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF10B981)
                                                .withValues(alpha: 0.4),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        currentPairedName,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981)
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Terpasang',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF10B981),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                              ] else ...[
                                Row(
                                  children: [
                                    Icon(
                                      selectedType == PrinterType.usb
                                          ? Icons.usb_off_rounded
                                          : Icons.bluetooth_disabled_rounded,
                                      size: 16,
                                      color: AppTheme.textTertiary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Belum ada perangkat yang dipasangkan',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: AppTheme.textTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                              ],

                              // Pair / Re-pair button
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: isPairing
                                          ? null
                                          : () async {
                                              setDialogState(
                                                  () => isPairing = true);

                                              PrintResult result;
                                              if (selectedType ==
                                                  PrinterType.usb) {
                                                result = await _service
                                                    .pairUsbDevice();
                                                if (result.success) {
                                                  pairedDeviceName =
                                                      _service.webUsb.deviceName;
                                                  // Auto-fill name if empty
                                                  if (nameCtrl.text
                                                      .trim()
                                                      .isEmpty) {
                                                    nameCtrl.text =
                                                        pairedDeviceName ??
                                                            'USB Printer';
                                                  }
                                                }
                                              } else {
                                                result = await _service
                                                    .pairBluetoothDevice();
                                                if (result.success) {
                                                  pairedDeviceName = _service
                                                      .webBluetooth.deviceName;
                                                  if (nameCtrl.text
                                                      .trim()
                                                      .isEmpty) {
                                                    nameCtrl.text =
                                                        pairedDeviceName ??
                                                            'BT Printer';
                                                  }
                                                }
                                              }

                                              setDialogState(
                                                  () => isPairing = false);

                                              if (!result.success &&
                                                  ctx.mounted) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content:
                                                        Text(result.message),
                                                    behavior:
                                                        SnackBarBehavior
                                                            .floating,
                                                    backgroundColor:
                                                        AppTheme.errorColor,
                                                  ),
                                                );
                                              }
                                            },
                                      icon: isPairing
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child:
                                                  CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : Icon(
                                              currentPairedName != null
                                                  ? Icons.refresh_rounded
                                                  : (selectedType ==
                                                          PrinterType.usb
                                                      ? Icons.usb_rounded
                                                      : Icons
                                                          .bluetooth_searching_rounded),
                                              size: 18,
                                            ),
                                      label: Text(
                                        isPairing
                                            ? 'Mencari...'
                                            : currentPairedName != null
                                                ? 'Ganti Perangkat'
                                                : 'Pasangkan Perangkat',
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor:
                                            const Color(0xFF6366F1),
                                        side: const BorderSide(
                                          color: Color(0xFF6366F1),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Show "All Devices" button for Bluetooth
                                  if (selectedType == PrinterType.bluetooth) ...[
                                    const SizedBox(width: 8),
                                    Tooltip(
                                      message: 'Tampilkan semua perangkat BLE',
                                      child: OutlinedButton(
                                        onPressed: isPairing
                                            ? null
                                            : () async {
                                                setDialogState(
                                                    () => isPairing = true);

                                                final result = await _service
                                                    .pairBluetoothDevice(
                                                        acceptAll: true);
                                                if (result.success) {
                                                  pairedDeviceName = _service
                                                      .webBluetooth.deviceName;
                                                  if (nameCtrl.text
                                                      .trim()
                                                      .isEmpty) {
                                                    nameCtrl.text =
                                                        pairedDeviceName ??
                                                            'BT Printer';
                                                  }
                                                }

                                                setDialogState(
                                                    () => isPairing = false);

                                                if (!result.success &&
                                                    ctx.mounted) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content:
                                                          Text(result.message),
                                                      behavior:
                                                          SnackBarBehavior
                                                              .floating,
                                                      backgroundColor:
                                                          AppTheme.errorColor,
                                                    ),
                                                  );
                                                }
                                              },
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              AppTheme.textSecondary,
                                          side: BorderSide(
                                            color: AppTheme.borderColor,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12),
                                        ),
                                        child: const Text('Semua'),
                                      ),
                                    ),
                                  ],
                                ],
                              ),

                              // Browser support warning
                              if ((selectedType == PrinterType.usb &&
                                      !WebUsbPrinter.isSupported) ||
                                  (selectedType == PrinterType.bluetooth &&
                                      !WebBluetoothPrinter.isSupported)) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color: const Color(0xFFFECACA)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.warning_amber_rounded,
                                        size: 16,
                                        color: Color(0xFFDC2626),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          selectedType == PrinterType.usb
                                              ? 'WebUSB tidak didukung browser ini. Gunakan Chrome/Edge.'
                                              : 'Web Bluetooth tidak didukung browser ini. Gunakan Chrome/Edge.',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: const Color(0xFFDC2626),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Set as default
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: SwitchListTile(
                          title: Text(
                            'Jadikan printer utama',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            'Digunakan secara default saat mencetak struk',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppTheme.textTertiary,
                            ),
                          ),
                          value: setAsDefault,
                          onChanged: (v) =>
                              setDialogState(() => setAsDefault = v),
                          activeColor: const Color(0xFF6366F1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Batal',
                    style: GoogleFonts.inter(color: AppTheme.textSecondary),
                  ),
                ),
                FilledButton(
                  onPressed: () {
                    if (nameCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Nama printer harus diisi'),
                        ),
                      );
                      return;
                    }

                    // Build address from paired device info
                    String? deviceAddress;
                    if (needsAddress) {
                      deviceAddress = addressCtrl.text.trim();
                    } else if (selectedType == PrinterType.usb) {
                      final usb = _service.webUsb;
                      deviceAddress = usb.deviceName ?? existing?.address;
                    } else if (selectedType == PrinterType.bluetooth) {
                      final bt = _service.webBluetooth;
                      deviceAddress = bt.deviceName ?? existing?.address;
                    } else {
                      deviceAddress = existing?.address;
                    }

                    final config = PrinterConfig(
                      id: existing?.id ??
                          DateTime.now().millisecondsSinceEpoch.toString(),
                      name: nameCtrl.text.trim(),
                      type: selectedType,
                      paperWidth: selectedWidth,
                      address: deviceAddress,
                      isDefault: setAsDefault,
                    );

                    setState(() {
                      if (isEdit) {
                        _service.updatePrinter(config);
                      } else {
                        _service.addPrinter(config);
                      }
                    });

                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isEdit
                              ? 'Printer berhasil diperbarui'
                              : 'Printer berhasil ditambahkan',
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                  ),
                  child: Text(isEdit ? 'Simpan' : 'Tambah'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDelete(PrinterConfig config) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Hapus Printer',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Yakin ingin menghapus printer "${config.name}"?',
          style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Batal',
              style: GoogleFonts.inter(color: AppTheme.textSecondary),
            ),
          ),
          FilledButton(
            onPressed: () {
              setState(() => _service.removePrinter(config.id));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Printer dihapus'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  Future<void> _testPrint(PrinterConfig config) async {
    setState(() => _isLoading = true);

    final result = await _service.testPrint(config);

    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              result.success ? Icons.check_circle : Icons.error_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(result.message)),
          ],
        ),
        backgroundColor:
            result.success ? AppTheme.successColor : AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showPreviewDialog(PrinterConfig config) {
    final receipt = EscPosReceiptPrinter(paperWidth: config.paperWidth);
    final bytes = receipt.generateTestReceipt(
      outletName: 'UTTER APP',
      paperWidth: config.paperWidth,
    );

    // Convert bytes to a text representation (printable ASCII only).
    final preview = String.fromCharCodes(
      bytes.where((b) => b == 0x0A || (b >= 0x20 && b < 0x7F)),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            const Icon(Icons.preview_rounded,
                color: Color(0xFF6366F1), size: 22),
            const SizedBox(width: 8),
            Text(
              'Print Preview',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Text(
                '${config.paperWidth}mm',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: config.paperWidth == 80 ? 480 : 340,
          height: 420,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppTheme.borderColor),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Text(
                preview,
                style: GoogleFonts.courierPrime(
                  fontSize: config.paperWidth == 80 ? 11 : 10,
                  height: 1.3,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _testPrint(config);
            },
            icon: const Icon(Icons.print_rounded, size: 18),
            label: const Text('Cetak'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final printers = _service.printers;
    final defaultPrinter = _service.defaultPrinter;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan Printer'),
        actions: [
          FilledButton.icon(
            onPressed: _showAddPrinterDialog,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Tambah Printer'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : printers.isEmpty
              ? _buildEmptyState()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Default printer card
                      _buildDefaultPrinterCard(defaultPrinter),
                      const SizedBox(height: 24),

                      // Info banner
                      _buildInfoBanner(),
                      const SizedBox(height: 24),

                      // All printers list
                      Text(
                        'Daftar Printer',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${printers.length} printer terdaftar',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...printers
                          .map((p) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _PrinterCard(
                                  config: p,
                                  onEdit: () => _showEditPrinterDialog(p),
                                  onDelete: () => _confirmDelete(p),
                                  onSetDefault: () {
                                    setState(() => _service.setDefault(p.id));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '"${p.name}" dijadikan printer utama',
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                  onTestPrint: () => _testPrint(p),
                                  onPreview: () => _showPreviewDialog(p),
                                ),
                              ))
                          ,
                    ],
                  ),
                ),
    );
  }

  // ─── Sub-widgets ──────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.print_disabled_rounded,
              size: 64, color: AppTheme.textTertiary),
          const SizedBox(height: 16),
          Text(
            'Belum ada printer',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tambahkan printer untuk mencetak struk',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textTertiary,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _showAddPrinterDialog,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Tambah Printer'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultPrinterCard(PrinterConfig? printer) {
    if (printer == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.textTertiary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.print_disabled_rounded,
                  color: AppTheme.textTertiary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Belum ada printer utama',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Pilih salah satu printer sebagai default',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.print_rounded,
                color: Colors.white, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Printer Utama',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  printer.name,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _chipWhite(printerTypeLabel(printer.type)),
                    const SizedBox(width: 8),
                    _chipWhite('${printer.paperWidth}mm'),
                    if (printer.address != null &&
                        printer.address!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _chipWhite(printer.address!),
                    ],
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _testPrint(printer),
            icon: const Icon(Icons.print_rounded, color: Colors.white),
            tooltip: 'Test Print',
          ),
        ],
      ),
    );
  }

  Widget _chipWhite(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    final usbSupported = WebUsbPrinter.isSupported;
    final btSupported = WebBluetoothPrinter.isSupported;
    final usbConnected = _service.webUsb.isConnected;
    final btConnected = _service.webBluetooth.isConnected;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: Color(0xFF2563EB), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dukungan Printer',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E40AF),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tersedia 3 mode koneksi: Browser Print, USB (WebUSB), '
                      'dan Bluetooth (Web Bluetooth). USB dan Bluetooth '
                      'memerlukan Chrome/Edge/Opera dan HTTPS. '
                      'Pasangkan perangkat di dialog Tambah/Edit Printer.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF1E40AF),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Connection status chips
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _statusChip(
                Icons.language_rounded,
                'Browser',
                true,
                const Color(0xFF2563EB),
              ),
              _statusChip(
                Icons.usb_rounded,
                usbConnected
                    ? 'USB: ${_service.webUsb.deviceName}'
                    : usbSupported
                        ? 'USB: Siap'
                        : 'USB: Tidak Didukung',
                usbSupported,
                usbConnected
                    ? const Color(0xFF059669)
                    : const Color(0xFF6B7280),
              ),
              _statusChip(
                Icons.bluetooth_rounded,
                btConnected
                    ? 'BT: ${_service.webBluetooth.deviceName}'
                    : btSupported
                        ? 'BT: Siap'
                        : 'BT: Tidak Didukung',
                btSupported,
                btConnected
                    ? const Color(0xFF7C3AED)
                    : const Color(0xFF6B7280),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip(
      IconData icon, String label, bool available, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: available
            ? color.withValues(alpha: 0.08)
            : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: available
              ? color.withValues(alpha: 0.2)
              : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: available ? color : const Color(0xFF9CA3AF)),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: available ? color : const Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondary,
      ),
    );
  }

  Widget _paperWidthOption({
    required String label,
    required String subtitle,
    required int value,
    required int selected,
    required VoidCallback onTap,
  }) {
    final isSelected = value == selected;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF6366F1).withValues(alpha: 0.06)
                : AppTheme.backgroundColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF6366F1)
                  : AppTheme.borderColor,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? const Color(0xFF6366F1)
                      : AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForType(PrinterType type) {
    switch (type) {
      case PrinterType.browser:
        return Icons.language_rounded;
      case PrinterType.usb:
        return Icons.usb_rounded;
      case PrinterType.bluetooth:
        return Icons.bluetooth_rounded;
      case PrinterType.network:
        return Icons.wifi_rounded;
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Printer Card Widget
// ═════════════════════════════════════════════════════════════════════════

class _PrinterCard extends StatefulWidget {
  final PrinterConfig config;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSetDefault;
  final VoidCallback onTestPrint;
  final VoidCallback onPreview;

  const _PrinterCard({
    required this.config,
    required this.onEdit,
    required this.onDelete,
    required this.onSetDefault,
    required this.onTestPrint,
    required this.onPreview,
  });

  @override
  State<_PrinterCard> createState() => _PrinterCardState();
}

class _PrinterCardState extends State<_PrinterCard> {
  bool _hovering = false;

  Color get _typeColor {
    switch (widget.config.type) {
      case PrinterType.browser:
        return const Color(0xFF2563EB);
      case PrinterType.usb:
        return const Color(0xFF059669);
      case PrinterType.bluetooth:
        return const Color(0xFF7C3AED);
      case PrinterType.network:
        return const Color(0xFFD97706);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _hovering
                ? const Color(0xFF6366F1)
                : config.isDefault
                    ? const Color(0xFF6366F1).withValues(alpha: 0.3)
                    : AppTheme.borderColor,
            width: _hovering || config.isDefault ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _hovering
                  ? const Color(0xFF6366F1).withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: _hovering ? 12 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: icon + name + badges + menu
            Row(
              children: [
                // Printer icon
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _typeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _iconForType(config.type),
                    color: _typeColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),

                // Name and details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              config.name,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (config.isDefault) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'UTAMA',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _typeBadge(config.type, _typeColor),
                          const SizedBox(width: 6),
                          _detailChip(
                            Icons.straighten_rounded,
                            '${config.paperWidth}mm',
                          ),
                          if (config.address != null &&
                              config.address!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            _detailChip(
                              Icons.link_rounded,
                              config.address!,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Action buttons
                if (_hovering || config.isDefault)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _actionButton(
                        icon: Icons.preview_rounded,
                        tooltip: 'Preview',
                        onTap: widget.onPreview,
                      ),
                      _actionButton(
                        icon: Icons.print_rounded,
                        tooltip: 'Test Print',
                        onTap: widget.onTestPrint,
                      ),
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert,
                          color: AppTheme.textSecondary,
                          size: 20,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        onSelected: (value) {
                          switch (value) {
                            case 'edit':
                              widget.onEdit();
                            case 'default':
                              widget.onSetDefault();
                            case 'delete':
                              widget.onDelete();
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                const Icon(Icons.edit_rounded, size: 18),
                                const SizedBox(width: 8),
                                Text('Edit',
                                    style: GoogleFonts.inter(fontSize: 14)),
                              ],
                            ),
                          ),
                          if (!config.isDefault)
                            PopupMenuItem(
                              value: 'default',
                              child: Row(
                                children: [
                                  const Icon(Icons.star_rounded, size: 18),
                                  const SizedBox(width: 8),
                                  Text('Jadikan Utama',
                                      style: GoogleFonts.inter(fontSize: 14)),
                                ],
                              ),
                            ),
                          const PopupMenuDivider(),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_rounded,
                                    size: 18, color: AppTheme.errorColor),
                                const SizedBox(width: 8),
                                Text(
                                  'Hapus',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: AppTheme.errorColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeBadge(PrinterType type, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        printerTypeLabel(type),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _detailChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.textTertiary),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: AppTheme.textSecondary),
        ),
      ),
    );
  }

  IconData _iconForType(PrinterType type) {
    switch (type) {
      case PrinterType.browser:
        return Icons.language_rounded;
      case PrinterType.usb:
        return Icons.usb_rounded;
      case PrinterType.bluetooth:
        return Icons.bluetooth_rounded;
      case PrinterType.network:
        return Icons.wifi_rounded;
    }
  }
}
