import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../data/models/bill.dart';
import '../../data/models/order_item.dart';
import '../services/printer_service.dart';
import 'formatters.dart';

class PrintResult {
  final bool success;
  final bool printedToThermal;
  final String? savedPdfPath;
  final String message;

  const PrintResult({
    required this.success,
    required this.printedToThermal,
    this.savedPdfPath,
    required this.message,
  });
}

class ReceiptPrinter {
  /// Saves raw PDF bytes directly to local storage (Downloads/CFC_Bills or App Documents)
  static Future<File?> saveBillPdfToStorage(Uint8List pdfBytes, String filename) async {
    Directory? targetDir;

    // 1. Try public standard Android Download directory (/storage/emulated/0/Download/CFC_Bills)
    try {
      final downloadDir = Directory('/storage/emulated/0/Download/CFC_Bills');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      targetDir = downloadDir;
    } catch (_) {}

    // 2. Try getDownloadsDirectory() via path_provider
    if (targetDir == null) {
      try {
        final dir = await getDownloadsDirectory();
        if (dir != null) {
          final sub = Directory('${dir.path}/CFC_Bills');
          if (!await sub.exists()) {
            await sub.create(recursive: true);
          }
          targetDir = sub;
        }
      } catch (_) {}
    }

    // 3. Try getExternalStorageDirectory()
    if (targetDir == null) {
      try {
        final dir = await getExternalStorageDirectory();
        if (dir != null) {
          final sub = Directory('${dir.path}/CFC_Bills');
          if (!await sub.exists()) {
            await sub.create(recursive: true);
          }
          targetDir = sub;
        }
      } catch (_) {}
    }

    // 4. Fallback to getApplicationDocumentsDirectory()
    if (targetDir == null) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final sub = Directory('${dir.path}/CFC_Bills');
        if (!await sub.exists()) {
          await sub.create(recursive: true);
        }
        targetDir = sub;
      } catch (_) {}
    }

    if (targetDir != null) {
      final file = File('${targetDir.path}/$filename');
      await file.writeAsBytes(pdfBytes, flush: true);
      debugPrint('[ReceiptPrinter] PDF successfully saved to: ${file.path}');
      return file;
    }

    return null;
  }

  /// Builds a PDF Document for the customer receipt
  static pw.Document buildBillPdf(Bill bill, {String restaurantName = 'CFC FOOD COURT'}) {
    final printerService = PrinterService();
    final pdf = pw.Document();
    final is58mm = printerService.is58mm;
    final pageFormat = printerService.pageFormat;

    // Group items by shop
    final Map<String, List<dynamic>> shopGroups = {};
    for (final item in bill.items) {
      final shopTitle = item.shopName ?? 'Shop';
      shopGroups.putIfAbsent(shopTitle, () => []).add(item);
    }

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.all(is58mm ? 6 : 12),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Center(
                child: pw.Text(
                  restaurantName,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'Multi-Shop Food Court & Dining',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Bill No:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  pw.Text(bill.displayBillNumber, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Bill Version:', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text('Version ${bill.currentVersion}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                ],
              ),
              if (bill.orderNumber != null)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Order No:', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(bill.orderNumber!, style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Order Type:', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text(bill.orderType ?? 'Dine In', style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              if (bill.tableDisplay != null && bill.tableDisplay!.isNotEmpty)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Table:', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(bill.tableDisplay!, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  ],
                ),
              if (bill.customerName != null && bill.customerName!.trim().isNotEmpty)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Customer:', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(bill.customerName!.trim(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  ],
                ),
              if (bill.customerPhone != null && bill.customerPhone!.trim().isNotEmpty)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Phone:', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(bill.customerPhone!.trim(), style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              if (bill.deliveryAddress != null && bill.deliveryAddress!.trim().isNotEmpty)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Address:', style: const pw.TextStyle(fontSize: 8)),
                    pw.Expanded(
                      child: pw.Text(
                        bill.deliveryAddress!.trim(),
                        textAlign: pw.TextAlign.right,
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                    ),
                  ],
                ),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 0.8),

              // Items Grouped by Shop
              ...shopGroups.entries.map((group) {
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(vertical: 3),
                      child: pw.Text(
                        group.key.toUpperCase(),
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.blueGrey800),
                      ),
                    ),
                    ...group.value.map((item) {
                      return pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 2),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Expanded(
                              flex: 6,
                              child: pw.Text(
                                '${item.productName} × ${item.quantity}',
                                style: const pw.TextStyle(fontSize: 9),
                              ),
                            ),
                            pw.Expanded(
                              flex: 3,
                              child: pw.Text(
                                Formatters.printCurrency(item.subtotal),
                                textAlign: pw.TextAlign.right,
                                style: const pw.TextStyle(fontSize: 9),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    pw.SizedBox(height: 4),
                  ],
                );
              }),

              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Subtotal:', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text(Formatters.printCurrency(bill.subtotal), style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              if (bill.discount > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Discount:', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('- ${Formatters.printCurrency(bill.discount)}', style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              if (bill.tax > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Tax / GST:', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('+ ${Formatters.printCurrency(bill.tax)}', style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              if (bill.parcelCharge > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Parcel / Packing:', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('+ ${Formatters.printCurrency(bill.parcelCharge)}', style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL AMOUNT:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                  pw.Text(Formatters.printCurrency(bill.totalAmount), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                ],
              ),
              pw.SizedBox(height: 4),
              if (bill.isPaid) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Payment Status:', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('PAID', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.green900)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Payment Method:', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(bill.paymentMethod, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  ],
                ),
                if (bill.paymentMethod.toUpperCase() == 'SPLIT' && bill.hasSplitDetails) ...[
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('  > Cash:', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text(Formatters.printCurrency(bill.splitCashAmount), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('  > GPay / UPI:', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text(Formatters.printCurrency(bill.splitGPayAmount), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                    ],
                  ),
                ],
              ] else ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Payment Status:', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(
                      bill.isPartiallyPaid ? 'PARTIALLY PAID' : 'PAYMENT PENDING',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.red900),
                    ),
                  ],
                ),
                if (bill.paidAmount > 0)
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Paid Amount:', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text(Formatters.printCurrency(bill.paidAmount), style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Amount Due:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                    pw.Text(Formatters.printCurrency(bill.remainingAmount), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.red900)),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text(
                    '*** PLEASE PAY AT PAYMENT COUNTER ***',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.red800),
                  ),
                ),
              ],
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Date & Time:', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(Formatters.formatDateTime(bill.printedAt ?? bill.createdAt), style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text(
                  '*** THANK YOU! VISIT AGAIN ***',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                ),
              ),
              pw.SizedBox(height: 10),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  /// Prints bill to thermal printer if connected; otherwise saves PDF directly to local storage
  static Future<PrintResult> printBill(Bill bill, {String restaurantName = 'CFC FOOD COURT'}) async {
    final printerService = PrinterService();

    // 1. If printer is ready & connected, attempt direct print
    if (printerService.isReadyToPrint) {
      if (printerService.isBluetooth) {
        final directSuccess = await printerService.printBill(bill, restaurantName: restaurantName);
        if (directSuccess) {
          return const PrintResult(
            success: true,
            printedToThermal: true,
            message: 'Receipt printed directly to thermal printer.',
          );
        }
      } else if (printerService.isCable && printerService.selectedSystemPrinter != null) {
        try {
          final pdf = buildBillPdf(bill, restaurantName: restaurantName);
          final bytes = await pdf.save();
          final directSuccess = await Printing.directPrintPdf(
            printer: printerService.selectedSystemPrinter!,
            onLayout: (_) async => bytes,
            name: 'Bill_${bill.displayBillNumber}.pdf',
          );
          if (directSuccess) {
            return const PrintResult(
              success: true,
              printedToThermal: true,
              message: 'Receipt sent directly to cable printer.',
            );
          }
        } catch (_) {}
      }
    }

    // 2. If printer is NOT connected (or direct print did not succeed):
    // Save that order as a PDF directly to local storage!
    try {
      final pdf = buildBillPdf(bill, restaurantName: restaurantName);
      final bytes = await pdf.save();
      final file = await saveBillPdfToStorage(bytes, 'Bill_${bill.displayBillNumber}.pdf');

      if (file != null) {
        return PrintResult(
          success: true,
          printedToThermal: false,
          savedPdfPath: file.path,
          message: 'Printer not connected. Bill saved as PDF to Downloads (CFC_Bills/Bill_${bill.displayBillNumber}.pdf).',
        );
      }
    } catch (e) {
      debugPrint('[ReceiptPrinter] Failed to save bill PDF to storage: $e');
    }

    return const PrintResult(
      success: false,
      printedToThermal: false,
      message: 'Printer not connected and unable to save PDF to local storage.',
    );
  }

  /// Generates Kitchen Order Ticket (KOT)
  static Future<void> printKot({
    required String orderNumber,
    required String orderType,
    String? tableDisplay,
    String? customerName,
    required List<OrderItem> items,
  }) async {
    final pdf = pw.Document();
    final printerService = PrinterService();
    final is58mm = printerService.is58mm;
    final pageFormat = printerService.pageFormat;

    final Map<String, List<OrderItem>> shopGroups = {};
    for (final item in items) {
      final shopTitle = item.shopName ?? 'Shop';
      shopGroups.putIfAbsent(shopTitle, () => []).add(item);
    }

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.all(is58mm ? 6 : 12),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Center(
                child: pw.Text(
                  'KITCHEN ORDER TICKET (KOT)',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Order:', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text(orderNumber, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Type:', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text(orderType, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                ],
              ),
              if (tableDisplay != null && tableDisplay.isNotEmpty)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Table:', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text(tableDisplay, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                  ],
                ),
              if (customerName != null)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Customer:', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text(customerName, style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Time:', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(Formatters.formatTime(DateTime.now()), style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 1),

              ...shopGroups.entries.map((group) {
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.Container(
                      color: PdfColors.grey200,
                      padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                      child: pw.Text(
                        '>>> ${group.key.toUpperCase()} <<<',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                      ),
                    ),
                    ...group.value.map((item) {
                      return pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 3),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Expanded(
                                  child: pw.Text(
                                    item.productName,
                                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                                  ),
                                ),
                                pw.Text(
                                  'QTY: ${item.quantity}',
                                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
                                ),
                              ],
                            ),
                            if (item.notes != null && item.notes!.isNotEmpty)
                              pw.Text(
                                'Note: "${item.notes}"',
                                style: const pw.TextStyle(fontSize: 9, color: PdfColors.red900),
                              ),
                          ],
                        ),
                      );
                    }),
                    pw.SizedBox(height: 6),
                  ],
                );
              }),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
            ],
          );
        },
      ),
    );

    await _outputPdf(pdf, 'KOT_$orderNumber.pdf');
  }

  /// Generates Daily Sales & Revenue Summary Report for 80mm thermal printer
  static Future<void> printDailyReport({
    required DateTime startDate,
    required DateTime endDate,
    required double totalSales,
    required int totalBills,
    required double dineInSales,
    required double takeAwaySales,
    required double deliverySales,
    required Map<String, double> paymentTotals,
    required List<dynamic> shopSales,
    String restaurantName = 'CFC FOOD COURT',
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(12),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Center(
                child: pw.Text(
                  restaurantName,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'DAILY SALES & REVENUE SUMMARY',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'Period: ${Formatters.formatDate(startDate)}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 4),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total Bills:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  pw.Text('$totalBills', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total Sales:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                  pw.Text(Formatters.printCurrency(totalSales), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 0.8),
              pw.Text('Order Types:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('  Dine In:', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text(Formatters.printCurrency(dineInSales), style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('  Take Away:', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text(Formatters.printCurrency(takeAwaySales), style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('  Delivery:', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text(Formatters.printCurrency(deliverySales), style: const pw.TextStyle(fontSize: 9)),
                ],
              ),

              pw.SizedBox(height: 6),
              pw.Divider(thickness: 0.8),
              pw.Text('Payment Breakdown:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
              ...paymentTotals.entries.map((e) {
                return pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('  ${e.key}:', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(Formatters.printCurrency(e.value), style: const pw.TextStyle(fontSize: 9)),
                  ],
                );
              }),

              pw.SizedBox(height: 8),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
              pw.Center(
                child: pw.Text(
                  'Printed: ${Formatters.formatDateTime(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                ),
              ),
            ],
          );
        },
      ),
    );

    await _outputPdf(pdf, 'Daily_Summary_${Formatters.formatDate(startDate)}.pdf');
  }

  static Future<void> _outputPdf(pw.Document pdf, String filename) async {
    final printerService = PrinterService();
    final selectedPrinter = printerService.selectedPrinter;
    if (selectedPrinter != null) {
      try {
        final directDone = await Printing.directPrintPdf(
          printer: selectedPrinter,
          onLayout: (format) async => pdf.save(),
          name: filename,
        );
        if (directDone) return;
      } catch (_) {}
    }
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      format: printerService.pageFormat,
      name: filename,
    );
  }
}
