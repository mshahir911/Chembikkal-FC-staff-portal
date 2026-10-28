import 'dart:convert';
import '../../data/models/bill.dart';
import 'formatters.dart';

enum EscPosAlign { left, center, right }
enum EscPosSize { normal, doubleHeight, doubleWidth, large }

class EscPosBuilder {
  final bool is58mm;
  final List<int> _bytes = [];

  EscPosBuilder({this.is58mm = false});

  int get maxChars => is58mm ? 32 : 48;

  List<int> get bytes => List.unmodifiable(_bytes);

  /// ESC @ - Initialize printer
  EscPosBuilder init() {
    _bytes.addAll([0x1B, 0x40]);
    return this;
  }

  /// Align text
  EscPosBuilder align(EscPosAlign alignment) {
    int val = 0;
    if (alignment == EscPosAlign.center) val = 1;
    if (alignment == EscPosAlign.right) val = 2;
    _bytes.addAll([0x1B, 0x61, val]);
    return this;
  }

  /// Set bold
  EscPosBuilder bold(bool enable) {
    _bytes.addAll([0x1B, 0x45, enable ? 1 : 0]);
    return this;
  }

  /// Set text size
  EscPosBuilder size(EscPosSize s) {
    int val = 0;
    switch (s) {
      case EscPosSize.doubleHeight:
        val = 0x01; // Height x2
        break;
      case EscPosSize.doubleWidth:
        val = 0x10; // Width x2
        break;
      case EscPosSize.large:
        val = 0x11; // Width x2 + Height x2
        break;
      case EscPosSize.normal:
        val = 0x00;
        break;
    }
    _bytes.addAll([0x1D, 0x21, val]);
    return this;
  }

  /// Print a line of text
  EscPosBuilder text(
    String content, {
    EscPosAlign alignment = EscPosAlign.left,
    bool isBold = false,
    EscPosSize textSize = EscPosSize.normal,
  }) {
    align(alignment);
    bold(isBold);
    size(textSize);
    _bytes.addAll(latin1.encode(content));
    _bytes.add(0x0A); // Line feed
    // Reset to defaults
    size(EscPosSize.normal);
    bold(false);
    align(EscPosAlign.left);
    return this;
  }

  /// Print a single horizontal divider
  EscPosBuilder hr({String ch = '-'}) {
    final line = ch * maxChars;
    text(line, alignment: EscPosAlign.center);
    return this;
  }

  /// Print double divider
  EscPosBuilder doubleHr() {
    return hr(ch: '=');
  }

  /// Print two columns (Left and Right aligned on the same line)
  EscPosBuilder row2(
    String left,
    String right, {
    bool isBold = false,
    EscPosSize textSize = EscPosSize.normal,
  }) {
    final effectiveWidth = (textSize == EscPosSize.doubleWidth || textSize == EscPosSize.large)
        ? (maxChars ~/ 2)
        : maxChars;

    final leftLen = left.length;
    final rightLen = right.length;

    String combined;
    if (leftLen + rightLen >= effectiveWidth) {
      final availableLeft = effectiveWidth - rightLen - 1;
      final truncatedLeft = availableLeft > 0 ? left.substring(0, availableLeft) : left;
      final spaces = effectiveWidth - (truncatedLeft.length + rightLen);
      combined = '$truncatedLeft${' ' * (spaces > 0 ? spaces : 1)}$right';
    } else {
      final spaces = effectiveWidth - (leftLen + rightLen);
      combined = '$left${' ' * spaces}$right';
    }

    text(combined, alignment: EscPosAlign.left, isBold: isBold, textSize: textSize);
    return this;
  }

  /// Print three columns (Item, Qty, Amount)
  EscPosBuilder row3(String col1, String col2, String col3, {bool isHeader = false}) {
    final qtyWidth = is58mm ? 4 : 6;
    final amtWidth = is58mm ? 9 : 12;
    final itemWidth = maxChars - qtyWidth - amtWidth;

    // Truncate or pad
    String itemStr = col1;
    if (itemStr.length > itemWidth) {
      itemStr = itemStr.substring(0, itemWidth);
    } else {
      itemStr = itemStr.padRight(itemWidth);
    }

    String qtyStr = col2.padLeft(qtyWidth);
    String amtStr = col3.padLeft(amtWidth);

    text('$itemStr$qtyStr$amtStr', alignment: EscPosAlign.left, isBold: isHeader);
    return this;
  }

  /// Feed N lines
  EscPosBuilder feed(int n) {
    for (int i = 0; i < n; i++) {
      _bytes.add(0x0A);
    }
    return this;
  }

  /// Cut paper
  EscPosBuilder cut() {
    feed(3);
    // GS V 66 0 - Partial cut with feed
    _bytes.addAll([0x1D, 0x56, 0x42, 0x00]);
    return this;
  }

  /// Kick cash drawer (optional pin 2 / pin 5)
  EscPosBuilder openDrawer() {
    _bytes.addAll([0x1B, 0x70, 0x00, 0x32, 0xFA]);
    return this;
  }

  // --------------------------------------------------------------------------
  // High-Level Receipt Templates
  // --------------------------------------------------------------------------

  /// Build standard customer bill
  static List<int> buildBillTicket(
    Bill bill, {
    required bool is58mm,
    String restaurantName = 'CFC FOOD COURT',
  }) {
    final builder = EscPosBuilder(is58mm: is58mm);
    builder.init();

    // 1. Restaurant Header
    builder.text(
      restaurantName,
      alignment: EscPosAlign.center,
      isBold: true,
      textSize: is58mm ? EscPosSize.doubleHeight : EscPosSize.large,
    );
    builder.text('Chembikkal Food Court & Dining', alignment: EscPosAlign.center);
    builder.doubleHr();

    // 2. Bill Meta
    builder.row2('Bill: #${bill.displayBillNumber}', Formatters.formatTime(bill.printedAt ?? bill.createdAt), isBold: true);
    if (bill.orderNumber != null) {
      builder.row2('Order: #${bill.orderNumber}', bill.orderType ?? 'Dine In');
    }
    if (bill.currentVersion > 1) {
      builder.row2('Bill Revision:', 'v${bill.currentVersion}', isBold: true);
    }
    if (bill.tableDisplay != null && bill.tableDisplay!.isNotEmpty && bill.tableDisplay != 'N/A') {
      builder.row2('Dining Table:', bill.tableDisplay!, isBold: true);
    }
    if (bill.customerName != null && bill.customerName!.trim().isNotEmpty) {
      builder.row2('Customer:', bill.customerName!.trim());
    }
    if (bill.customerPhone != null && bill.customerPhone!.trim().isNotEmpty) {
      builder.row2('Phone:', bill.customerPhone!.trim());
    }
    if (bill.deliveryAddress != null && bill.deliveryAddress!.trim().isNotEmpty) {
      builder.text('Address: ${bill.deliveryAddress!.trim()}');
    }

    builder.hr();

    // 3. Items Table Header
    builder.row3('ITEM', 'QTY', 'AMOUNT', isHeader: true);
    builder.hr(ch: '-');

    // 4. Items List (grouped or listed)
    for (final item in bill.items) {
      builder.row3(
        item.productName,
        '${item.quantity}',
        'Rs.${item.subtotal.toStringAsFixed(2)}',
      );
    }

    builder.hr(ch: '-');

    // 5. Financial Summary
    builder.row2('Subtotal:', 'Rs.${bill.subtotal.toStringAsFixed(2)}');
    if (bill.discount > 0) {
      builder.row2('Discount:', '-Rs.${bill.discount.toStringAsFixed(2)}');
    }
    if (bill.tax > 0) {
      builder.row2('Tax / GST:', '+Rs.${bill.tax.toStringAsFixed(2)}');
    }

    builder.doubleHr();

    // 6. Net Total
    builder.row2(
      'NET TOTAL:',
      'Rs.${bill.totalAmount.toStringAsFixed(2)}',
      isBold: true,
      textSize: is58mm ? EscPosSize.doubleHeight : EscPosSize.large,
    );

    builder.doubleHr();

    // 7. Payment Status
    if (bill.isPaid) {
      builder.text('PAID BY ${bill.paymentMethod.toUpperCase()}', alignment: EscPosAlign.center, isBold: true);
      if (bill.paymentMethod.toUpperCase() == 'SPLIT' && bill.hasSplitDetails) {
        builder.text('Cash Paid: Rs.${bill.splitCashAmount.toStringAsFixed(2)}', alignment: EscPosAlign.center);
        builder.text('GPay Paid: Rs.${bill.splitGPayAmount.toStringAsFixed(2)}', alignment: EscPosAlign.center);
      }
    } else if (bill.isPartiallyPaid) {
      builder.text('PARTIALLY PAID: Rs.${bill.paidAmount.toStringAsFixed(2)}', alignment: EscPosAlign.center, isBold: true);
      builder.text('BALANCE DUE: Rs.${(bill.totalAmount - bill.paidAmount).toStringAsFixed(2)}', alignment: EscPosAlign.center, isBold: true);
    } else {
      builder.text('*** PAYMENT PENDING ***', alignment: EscPosAlign.center, isBold: true);
    }

    builder.feed(1);
    builder.text('Date: ${Formatters.formatDate(bill.createdAt)}', alignment: EscPosAlign.center);
    builder.text('*** THANK YOU! VISIT AGAIN ***', alignment: EscPosAlign.center);
    builder.cut();

    return builder.bytes;
  }

  /// Build ESC/POS Diagnostic Test Slip
  static List<int> buildTestTicket({
    required bool is58mm,
    required String printerName,
    required String connectionType,
  }) {
    final builder = EscPosBuilder(is58mm: is58mm);
    builder.init();

    builder.text(
      'CHEMBIKKAL FOOD COURT',
      alignment: EscPosAlign.center,
      isBold: true,
      textSize: is58mm ? EscPosSize.doubleHeight : EscPosSize.large,
    );
    builder.text('Thermal Printer Diagnostic Slip', alignment: EscPosAlign.center);
    builder.doubleHr();

    builder.row2('Printer Type:', connectionType, isBold: true);
    builder.row2('Device Name:', printerName);
    builder.row2('Roll Width:', is58mm ? '58 mm (2-inch)' : '80 mm (3-inch)');
    builder.row2('Protocol:', 'ESC/POS Direct Stream');
    builder.row2('Timestamp:', Formatters.formatDateTime(DateTime.now()));
    builder.hr();

    builder.text(
      'PRINTER CONNECTION OK',
      alignment: EscPosAlign.center,
      isBold: true,
      textSize: EscPosSize.doubleHeight,
    );
    builder.text('Thermal print head verified successfully.', alignment: EscPosAlign.center);
    builder.hr();
    builder.text('*** END OF DIAGNOSTIC TEST ***', alignment: EscPosAlign.center);
    builder.cut();

    return builder.bytes;
  }
}
