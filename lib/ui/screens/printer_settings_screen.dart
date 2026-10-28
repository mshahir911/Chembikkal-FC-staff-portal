import 'package:flutter/material.dart';
import '../../core/services/printer_service.dart';
import '../../core/theme/app_theme.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final PrinterService _printerService = PrinterService();
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _printerService.addListener(_onServiceUpdate);
    if (_printerService.isBluetooth) {
      _printerService.scanBluetoothPrinters();
    } else {
      _printerService.scanSystemPrinters();
    }
  }

  @override
  void dispose() {
    _printerService.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _handleTestPrint() async {
    setState(() => _isTesting = true);
    final success = await _printerService.printTestReceipt();
    if (mounted) {
      setState(() => _isTesting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Test slip sent directly to thermal printer via ESC/POS!'
                : (_printerService.errorMessage ?? 'Test print failed or dialogue cancelled.'),
          ),
          backgroundColor: success ? AppTheme.cashGreen : AppTheme.primary,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBluetooth = _printerService.isBluetooth;
    final is58mm = _printerService.is58mm;
    final isScanning = _printerService.isScanning;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          tooltip: 'Back to Home',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Printer & Thermal Setup',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: isScanning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                  )
                : const Icon(Icons.refresh_rounded, color: AppTheme.textPrimary),
            tooltip: 'Rescan Printers',
            onPressed: isScanning
                ? null
                : () {
                    if (isBluetooth) {
                      _printerService.scanBluetoothPrinters();
                    } else {
                      _printerService.scanSystemPrinters();
                    }
                  },
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppTheme.surfaceBorder, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Error banner if any
                if (_printerService.errorMessage != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade300, width: 0.9),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: Colors.amber.shade900, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _printerService.errorMessage!,
                            style: TextStyle(fontSize: 12, color: Colors.amber.shade900, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Section 1: Choose Printer Connection Mode (Bluetooth vs Cable)
                _buildSectionHeader(
                  title: '1. Printer Connection Interface',
                  subtitle: 'Select whether your thermal printer connects via Bluetooth or USB Cable.',
                  icon: Icons.settings_input_composite_rounded,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildChoiceCard(
                        title: 'Bluetooth Thermal',
                        subtitle: 'Wireless Direct ESC/POS\n(POS-58, POS-80, Portable)',
                        icon: Icons.bluetooth_rounded,
                        isSelected: isBluetooth,
                        onTap: () => _printerService.setConnectionType(PrinterConnectionType.bluetooth),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildChoiceCard(
                        title: 'Cable / USB',
                        subtitle: 'Wired POS Printer\n(Epson, TVS, System Print)',
                        icon: Icons.usb_rounded,
                        isSelected: !isBluetooth,
                        onTap: () => _printerService.setConnectionType(PrinterConnectionType.cable),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Section 2: Choose Paper Width (58mm vs 80mm)
                _buildSectionHeader(
                  title: isBluetooth ? '2. Bluetooth Paper Roll Width' : '2. Paper Roll Width',
                  subtitle: 'Select the thermal paper roll width installed in your printer.',
                  icon: Icons.aspect_ratio_rounded,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildChoiceCard(
                        title: '58 mm',
                        subtitle: '2-inch Compact Thermal\n(32 Columns / Mini Slip)',
                        icon: Icons.receipt_rounded,
                        isSelected: is58mm,
                        onTap: () => _printerService.setPaperSize('58mm'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildChoiceCard(
                        title: '80 mm',
                        subtitle: '3-inch Standard POS\n(48 Columns / Full Counter Slip)',
                        icon: Icons.receipt_long_rounded,
                        isSelected: !is58mm,
                        onTap: () => _printerService.setPaperSize('80mm'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Section 3: Device Discovery & Connection
                if (isBluetooth) ...[
                  _buildBluetoothDevicesSection(context),
                ] else ...[
                  _buildCableDevicesSection(context),
                ],

                const SizedBox(height: 24),

                // Section 4: ESC/POS Test Slip & Troubleshooting
                _buildTestPrintSection(context),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Bluetooth Devices Section
  // --------------------------------------------------------------------------
  Widget _buildBluetoothDevicesSection(BuildContext context) {
    final devices = _printerService.availableBtDevices;
    final selected = _printerService.selectedBtDevice;
    final isConnected = _printerService.isBtConnected;
    final isScanning = _printerService.isBtScanning;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: '3. Paired Bluetooth Thermal Printers',
          subtitle: 'Pair your Bluetooth thermal printer in Android Settings first, then connect here.',
          icon: Icons.bluetooth_searching_rounded,
          trailing: TextButton.icon(
            onPressed: isScanning ? null : () => _printerService.scanBluetoothPrinters(),
            icon: const Icon(Icons.refresh_rounded, size: 16, color: AppTheme.primary),
            label: Text(
              isScanning ? 'Scanning...' : 'Scan Paired',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primary),
            ),
          ),
        ),
        const SizedBox(height: 10),

        Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.surfaceBorder, width: 0.9),
          ),
          child: Column(
            children: [
              if (isScanning && devices.isEmpty) ...[
                const Padding(
                  padding: EdgeInsets.all(28.0),
                  child: Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(color: AppTheme.primary),
                        SizedBox(height: 12),
                        Text(
                          'Searching for paired Bluetooth devices...',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else if (devices.isEmpty) ...[
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.bluetooth_disabled_rounded, size: 30, color: AppTheme.primary),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No Bluetooth Printers Found',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '1. Turn on your thermal printer.\n2. Open your tablet\'s Bluetooth settings and Pair with the printer (PIN is usually 0000 or 1234).\n3. Tap "Scan Paired" below.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _printerService.scanBluetoothPrinters(),
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Scan Paired Devices', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: devices.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.surfaceBorder),
                  itemBuilder: (context, index) {
                    final dev = devices[index];
                    final isThisSelected = selected != null && selected.macAdress == dev.macAdress;
                    final isThisConnected = isThisSelected && isConnected;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isThisConnected
                              ? AppTheme.cashGreenBg
                              : (isThisSelected ? AppTheme.primaryLight : AppTheme.surfaceLight),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isThisConnected
                                ? AppTheme.cashGreen
                                : (isThisSelected ? AppTheme.primary : AppTheme.surfaceBorder),
                            width: 0.8,
                          ),
                        ),
                        child: Icon(
                          Icons.print_rounded,
                          color: isThisConnected
                              ? AppTheme.cashGreen
                              : (isThisSelected ? AppTheme.primary : AppTheme.textSecondary),
                          size: 20,
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              dev.name.isEmpty ? 'Unknown Printer' : dev.name,
                              style: TextStyle(
                                fontWeight: isThisSelected ? FontWeight.w800 : FontWeight.w600,
                                fontSize: 14,
                                color: isThisConnected ? AppTheme.cashGreen : AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          if (isThisConnected)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.cashGreenBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.cashGreen, width: 0.8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_rounded, size: 12, color: AppTheme.cashGreen),
                                  SizedBox(width: 4),
                                  Text(
                                    'Connected',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.cashGreen),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      subtitle: Text(
                        'MAC: ${dev.macAdress}',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                      trailing: isThisConnected
                          ? OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red.shade700,
                                side: BorderSide(color: Colors.red.shade300, width: 0.8),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () => _printerService.disconnectBluetooth(),
                              child: const Text('Disconnect', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            )
                          : ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () => _printerService.connectBluetooth(dev),
                              child: const Text('Connect', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // Cable Devices Section
  // --------------------------------------------------------------------------
  Widget _buildCableDevicesSection(BuildContext context) {
    final printers = _printerService.availableSystemPrinters;
    final selectedPrinter = _printerService.selectedSystemPrinter;
    final isScanning = _printerService.isSystemScanning;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: '3. Connected Cable / System Printers',
          subtitle: 'Select the wired USB printer connected to this device.',
          icon: Icons.usb_rounded,
          trailing: TextButton.icon(
            onPressed: isScanning ? null : () => _printerService.scanSystemPrinters(),
            icon: const Icon(Icons.refresh_rounded, size: 16, color: AppTheme.primary),
            label: Text(
              isScanning ? 'Scanning...' : 'Scan USB',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primary),
            ),
          ),
        ),
        const SizedBox(height: 10),

        Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.surfaceBorder, width: 0.9),
          ),
          child: printers.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      const Icon(Icons.print_disabled_rounded, size: 30, color: AppTheme.primary),
                      const SizedBox(height: 12),
                      const Text(
                        'No Cable Printers Detected',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Connect your printer with a USB OTG cable or configure system print services.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _printerService.scanSystemPrinters(),
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Rescan USB', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: printers.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.surfaceBorder),
                  itemBuilder: (context, index) {
                    final p = printers[index];
                    final isSelected = selectedPrinter != null && selectedPrinter.name == p.name;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Icon(
                        Icons.print_rounded,
                        color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                      ),
                      title: Text(
                        p.name,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 14,
                          color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        p.url.isNotEmpty ? p.url : 'System Port / USB',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 20)
                          : OutlinedButton(
                              style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                              onPressed: () => _printerService.selectPrinter(p),
                              child: const Text('Select', style: TextStyle(fontSize: 11)),
                            ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // ESC/POS Test Slip Section
  // --------------------------------------------------------------------------
  Widget _buildTestPrintSection(BuildContext context) {
    final isBluetooth = _printerService.isBluetooth;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.surfaceBorder, width: 0.9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppTheme.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.receipt_long_rounded, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ESC/POS Thermal Test Slip',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isBluetooth
                          ? 'Prints directly to thermal roll using ESC/POS commands (no PDF).'
                          : 'Sends test diagnostic slip to wired system printer.',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _isTesting ? null : _handleTestPrint,
              icon: _isTesting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.print_rounded, size: 18),
              label: Text(
                _isTesting ? 'Sending ESC/POS Bytes...' : 'Print Test Diagnostic Slip',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // UI Helpers
  // --------------------------------------------------------------------------
  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildChoiceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isSelected ? AppTheme.primaryLight : AppTheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppTheme.primary : AppTheme.surfaceBorder,
              width: isSelected ? 1.8 : 0.9,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        if (isSelected)
                          const Icon(Icons.check_circle_rounded, size: 16, color: AppTheme.primary),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isSelected ? AppTheme.primary.withAlpha(200) : AppTheme.textSecondary,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
