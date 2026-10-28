import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/bill.dart';
import '../utils/esc_pos_builder.dart';
import '../utils/formatters.dart';

enum PrinterConnectionType { bluetooth, cable }

class PrinterService extends ChangeNotifier {
  static final PrinterService _instance = PrinterService._internal();
  factory PrinterService() => _instance;
  PrinterService._internal();

  static const String _prefConnectionTypeKey = 'cfc_printer_connection_type';
  static const String _prefPaperSizeKey = 'cfc_printer_paper_size';
  static const String _prefBtMacKey = 'cfc_printer_bt_mac';
  static const String _prefBtNameKey = 'cfc_printer_bt_name';
  static const String _prefSystemPrinterNameKey = 'cfc_printer_sys_name';
  static const String _prefSystemPrinterUrlKey = 'cfc_printer_sys_url';

  // Config
  PrinterConnectionType _connectionType = PrinterConnectionType.bluetooth;
  String _paperSize = '80mm'; // '58mm' or '80mm'

  // Bluetooth State
  BluetoothInfo? _selectedBtDevice;
  List<BluetoothInfo> _availableBtDevices = [];
  bool _isBtConnected = false;
  bool _isBtScanning = false;

  // Cable / System Printer State
  Printer? _selectedSystemPrinter;
  List<Printer> _availableSystemPrinters = [];
  bool _isSystemScanning = false;

  // General State
  String? _errorMessage;
  Timer? _statusCheckTimer;

  // Getters
  PrinterConnectionType get connectionType => _connectionType;
  bool get isBluetooth => _connectionType == PrinterConnectionType.bluetooth;
  bool get isCable => _connectionType == PrinterConnectionType.cable;

  String get paperSize => _paperSize;
  bool get is58mm => _paperSize == '58mm';
  bool get is80mm => _paperSize == '80mm';

  // Bluetooth getters
  BluetoothInfo? get selectedBtDevice => _selectedBtDevice;
  List<BluetoothInfo> get availableBtDevices => _availableBtDevices;
  bool get isBtConnected => _isBtConnected;
  bool get isBtScanning => _isBtScanning;

  // System / Cable getters
  Printer? get selectedPrinter => _selectedSystemPrinter;
  Printer? get selectedSystemPrinter => _selectedSystemPrinter;
  List<Printer> get availablePrinters => _availableSystemPrinters;
  List<Printer> get availableSystemPrinters => _availableSystemPrinters;
  bool get isSystemScanning => _isSystemScanning;
  bool get isScanning => isBluetooth ? _isBtScanning : _isSystemScanning;

  String? get errorMessage => _errorMessage;
  PdfPageFormat get pageFormat => is58mm ? PdfPageFormat.roll57 : PdfPageFormat.roll80;

  /// High-level human readable status label for Home Screen Header
  String get statusTitle {
    if (isBluetooth) {
      if (_isBtConnected) {
        final name = _selectedBtDevice?.name ?? 'Thermal POS';
        return 'BT: $name ($_paperSize)';
      } else {
        return _selectedBtDevice != null ? 'BT: Reconnect' : 'BT: No Printer';
      }
    } else {
      final name = _selectedSystemPrinter?.name ?? 'Default Cable';
      return 'Cable: $name';
    }
  }

  bool get isReadyToPrint {
    if (isBluetooth) {
      return _isBtConnected;
    } else {
      return _selectedSystemPrinter != null || _availableSystemPrinters.isNotEmpty;
    }
  }

  // --------------------------------------------------------------------------
  // Initialization
  // --------------------------------------------------------------------------
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedType = prefs.getString(_prefConnectionTypeKey);
      if (savedType == 'CABLE') {
        _connectionType = PrinterConnectionType.cable;
      } else {
        _connectionType = PrinterConnectionType.bluetooth;
      }

      _paperSize = prefs.getString(_prefPaperSizeKey) ?? '80mm';
      final savedBtMac = prefs.getString(_prefBtMacKey);
      final savedBtName = prefs.getString(_prefBtNameKey);
      final savedSysName = prefs.getString(_prefSystemPrinterNameKey);
      final savedSysUrl = prefs.getString(_prefSystemPrinterUrlKey);

      // Initialize System Printers
      try {
        final sysPrinters = await Printing.listPrinters();
        _availableSystemPrinters = sysPrinters;
        if (savedSysName != null && sysPrinters.isNotEmpty) {
          _selectedSystemPrinter = sysPrinters.firstWhere(
            (p) => p.name == savedSysName || (savedSysUrl != null && p.url == savedSysUrl),
            orElse: () => sysPrinters.first,
          );
        } else if (sysPrinters.isNotEmpty) {
          _selectedSystemPrinter = sysPrinters.first;
        }
      } catch (_) {}

      // Initialize Bluetooth
      if (isBluetooth) {
        await scanBluetoothPrinters();
        if (savedBtMac != null && _availableBtDevices.isNotEmpty) {
          final matched = _availableBtDevices.firstWhere(
            (d) => d.macAdress == savedBtMac,
            orElse: () => _availableBtDevices.first,
          );
          _selectedBtDevice = matched;
          // Attempt auto-connect
          await connectBluetooth(matched);
        } else if (savedBtMac != null && savedBtName != null) {
          final stub = BluetoothInfo(name: savedBtName, macAdress: savedBtMac);
          _selectedBtDevice = stub;
          await connectBluetooth(stub);
        }
      }

      // Start periodic status check for Bluetooth connection
      _startStatusTimer();
      notifyListeners();
    } catch (e) {
      debugPrint('[PrinterService] Init error: $e');
    }
  }

  void _startStatusTimer() {
    _statusCheckTimer?.cancel();
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (isBluetooth && _selectedBtDevice != null) {
        await checkBluetoothConnection();
      }
    });
  }

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    super.dispose();
  }

  // --------------------------------------------------------------------------
  // Connection Type & Paper Size Switchers
  // --------------------------------------------------------------------------
  Future<void> setConnectionType(PrinterConnectionType type) async {
    _connectionType = type;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefConnectionTypeKey, type == PrinterConnectionType.bluetooth ? 'BLUETOOTH' : 'CABLE');
    } catch (_) {}

    if (type == PrinterConnectionType.bluetooth) {
      await scanBluetoothPrinters();
      if (_selectedBtDevice != null && !_isBtConnected) {
        await connectBluetooth(_selectedBtDevice!);
      }
    } else {
      await scanSystemPrinters();
    }
  }

  Future<void> setPaperSize(String size) async {
    if (size != '58mm' && size != '80mm') return;
    _paperSize = size;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefPaperSizeKey, size);
    } catch (_) {}
  }

  // --------------------------------------------------------------------------
  // Bluetooth Management
  // --------------------------------------------------------------------------
  Future<List<BluetoothInfo>> scanBluetoothPrinters() async {
    _isBtScanning = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final bool isBtOn = await PrintBluetoothThermal.bluetoothEnabled;
      if (!isBtOn) {
        _errorMessage = 'Bluetooth is currently turned OFF. Please enable Bluetooth in tablet settings.';
        _isBtConnected = false;
        _isBtScanning = false;
        notifyListeners();
        return [];
      }

      final List<BluetoothInfo> list = await PrintBluetoothThermal.pairedBluetooths;
      _availableBtDevices = list;

      if (_selectedBtDevice != null) {
        final stillExists = list.any((d) => d.macAdress == _selectedBtDevice!.macAdress);
        if (!stillExists && list.isNotEmpty) {
          _selectedBtDevice = list.first;
        }
      } else if (list.isNotEmpty) {
        _selectedBtDevice = list.first;
      }

      await checkBluetoothConnection();
    } catch (e) {
      _errorMessage = 'Bluetooth scan failed: $e';
    } finally {
      _isBtScanning = false;
      notifyListeners();
    }
    return _availableBtDevices;
  }

  Future<bool> connectBluetooth(BluetoothInfo device) async {
    _errorMessage = null;
    notifyListeners();
    try {
      final connected = await PrintBluetoothThermal.connect(macPrinterAddress: device.macAdress);
      _isBtConnected = connected;
      _selectedBtDevice = device;

      if (connected) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefBtMacKey, device.macAdress);
        await prefs.setString(_prefBtNameKey, device.name);
      } else {
        _errorMessage = 'Failed to connect to ${device.name}. Ensure printer is turned on and paired.';
      }
      notifyListeners();
      return connected;
    } catch (e) {
      _isBtConnected = false;
      _errorMessage = 'Connection error: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> disconnectBluetooth() async {
    try {
      await PrintBluetoothThermal.disconnect;
      _isBtConnected = false;
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> checkBluetoothConnection() async {
    try {
      final bool status = await PrintBluetoothThermal.connectionStatus;
      if (_isBtConnected != status) {
        _isBtConnected = status;
        notifyListeners();
      }
      return status;
    } catch (_) {
      _isBtConnected = false;
      notifyListeners();
      return false;
    }
  }

  // --------------------------------------------------------------------------
  // System / Cable Printer Management
  // --------------------------------------------------------------------------
  Future<List<Printer>> scanSystemPrinters() async {
    _isSystemScanning = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final printers = await Printing.listPrinters();
      _availableSystemPrinters = printers;
      if (_selectedSystemPrinter != null) {
        final exists = printers.any((p) => p.name == _selectedSystemPrinter!.name);
        if (!exists && printers.isNotEmpty) {
          _selectedSystemPrinter = printers.first;
        }
      } else if (printers.isNotEmpty) {
        _selectedSystemPrinter = printers.first;
      }
    } catch (e) {
      _errorMessage = 'Cable printer discovery failed: $e';
    } finally {
      _isSystemScanning = false;
      notifyListeners();
    }
    return _availableSystemPrinters;
  }

  Future<void> selectPrinter(Printer printer) async {
    _selectedSystemPrinter = printer;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefSystemPrinterNameKey, printer.name);
      await prefs.setString(_prefSystemPrinterUrlKey, printer.url);
    } catch (_) {}
  }

  // --------------------------------------------------------------------------
  // ESC/POS Direct Print
  // --------------------------------------------------------------------------

  /// Sends raw ESC/POS byte sequence directly to Bluetooth thermal printer
  Future<bool> printEscPosBytes(List<int> bytes) async {
    if (!isBluetooth) return false;

    // Check or reconnect
    bool connected = _isBtConnected;
    if (!connected && _selectedBtDevice != null) {
      connected = await connectBluetooth(_selectedBtDevice!);
    }

    if (!connected) {
      _errorMessage = 'Printer is not connected. Connect via Bluetooth in Printer Settings.';
      notifyListeners();
      return false;
    }

    try {
      final success = await PrintBluetoothThermal.writeBytes(bytes);
      return success;
    } catch (e) {
      _errorMessage = 'ESC/POS Write error: $e';
      notifyListeners();
      return false;
    }
  }

  /// Print Test Slip (ESC/POS if Bluetooth, PDF if Cable)
  Future<bool> printTestReceipt() async {
    if (isBluetooth) {
      if (_selectedBtDevice == null && _availableBtDevices.isNotEmpty) {
        _selectedBtDevice = _availableBtDevices.first;
      }
      final devName = _selectedBtDevice?.name ?? 'Thermal Bluetooth Printer';
      final bytes = EscPosBuilder.buildTestTicket(
        is58mm: is58mm,
        printerName: devName,
        connectionType: 'Bluetooth Thermal (ESC/POS)',
      );
      return await printEscPosBytes(bytes);
    }

    // Cable Print Test Slip fallback
    return await _printTestReceiptPdf();
  }

  Future<bool> _printTestReceiptPdf() async {
    try {
      final pdf = pw.Document();
      final now = DateTime.now();
      final format = pageFormat;
      final isCompact = is58mm;

      pdf.addPage(
        pw.Page(
          pageFormat: format,
          margin: pw.EdgeInsets.all(isCompact ? 6 : 12),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Center(
                  child: pw.Text(
                    'CHEMBIKKAL FOOD COURT',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: isCompact ? 12 : 16,
                    ),
                  ),
                ),
                pw.Center(
                  child: pw.Text(
                    'Printer Diagnostic & Test Slip (Cable)',
                    style: pw.TextStyle(fontSize: isCompact ? 8 : 10, color: PdfColors.grey700),
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Configured Width:', style: pw.TextStyle(fontSize: isCompact ? 8 : 10)),
                    pw.Text(_paperSize, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: isCompact ? 8 : 10)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Selected Printer:', style: pw.TextStyle(fontSize: isCompact ? 8 : 10)),
                    pw.Expanded(
                      child: pw.Text(
                        _selectedSystemPrinter?.name ?? 'System Default',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: isCompact ? 8 : 10),
                      ),
                    ),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Timestamp:', style: pw.TextStyle(fontSize: isCompact ? 8 : 10)),
                    pw.Text(Formatters.formatDateTime(now), style: pw.TextStyle(fontSize: isCompact ? 8 : 10)),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
                pw.SizedBox(height: 6),
                pw.Center(
                  child: pw.Text(
                    'CABLE PRINTER CONNECTION OK',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: isCompact ? 10 : 13,
                    ),
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
                pw.SizedBox(height: 8),
                pw.Center(
                  child: pw.Text(
                    '*** END OF TEST PRINT ***',
                    style: pw.TextStyle(fontSize: isCompact ? 8 : 9, fontWeight: pw.FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        ),
      );

      if (_selectedSystemPrinter != null) {
        return await Printing.directPrintPdf(
          printer: _selectedSystemPrinter!,
          onLayout: (format) async => pdf.save(),
          name: 'CFC_Printer_Test.pdf',
        );
      } else {
        return await Printing.layoutPdf(
          onLayout: (format) async => pdf.save(),
          name: 'CFC_Printer_Test.pdf',
        );
      }
    } catch (_) {
      return false;
    }
  }

  /// High level Bill Print:
  /// Uses ESC/POS stream directly to thermal printer if Bluetooth,
  /// or falls back to system printer if Cable
  Future<bool> printBill(Bill bill, {String restaurantName = 'CFC FOOD COURT'}) async {
    if (isBluetooth) {
      final bytes = EscPosBuilder.buildBillTicket(
        bill,
        is58mm: is58mm,
        restaurantName: restaurantName,
      );
      final ok = await printEscPosBytes(bytes);
      if (ok) return true;
    }
    return false;
  }
}
