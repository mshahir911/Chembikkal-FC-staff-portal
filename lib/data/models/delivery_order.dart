import 'bill.dart';
import 'order.dart';

class DeliveryItemInfo {
  final String productName;
  final int quantity;
  final double unitPrice;
  final double subtotal;
  final String? shopName;
  final String? shopId;

  DeliveryItemInfo({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    this.shopName,
    this.shopId,
  });
}

class DeliveryOrder {
  final String id;
  final String orderId;
  final String orderNumber;
  final String? billNumber;
  final String? billId;
  final String status;
  final bool isDelivered;
  final bool isPaid;
  final double totalAmount;
  final double paidAmount;
  final double amountToCollect;
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final String? deliveryNotes;
  final List<DeliveryItemInfo> items;
  final DateTime createdAt;
  final DateTime? completedAt;
  final OrderModel? rawOrder;
  final Bill? rawBill;

  DeliveryOrder({
    required this.id,
    required this.orderId,
    required this.orderNumber,
    this.billNumber,
    this.billId,
    required this.status,
    required this.isDelivered,
    required this.isPaid,
    required this.totalAmount,
    required this.paidAmount,
    required this.amountToCollect,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
    this.deliveryNotes,
    this.items = const [],
    required this.createdAt,
    this.completedAt,
    this.rawOrder,
    this.rawBill,
  });

  String? get displayBillNumber {
    if (billNumber == null || billNumber!.isEmpty) return null;
    final trimmed = billNumber!.trim();
    if (RegExp(r'^\d+$').hasMatch(trimmed)) {
      return trimmed.padLeft(3, '0');
    }
    final match = RegExp(r'-(\d+)$').firstMatch(trimmed);
    if (match != null) {
      final n = int.tryParse(match.group(1)!);
      if (n != null) {
        return n.toString().padLeft(3, '0');
      }
    }
    return trimmed;
  }

  /// Official Bill Number (e.g. '075') matching POS and receipts, falling back to sequential order number
  String get billOrOrderNumber {
    final bNum = displayBillNumber;
    if (bNum != null && bNum.isNotEmpty) {
      return bNum;
    }
    final match = RegExp(r'-(\d+)$').firstMatch(orderNumber.trim());
    if (match != null) {
      final n = int.tryParse(match.group(1)!);
      if (n != null) {
        return n.toString().padLeft(3, '0');
      }
    }
    return orderNumber;
  }

  /// Clean display identifier e.g. '#075'
  String get displayIdentifier => '#$billOrOrderNumber';

  factory DeliveryOrder.fromOrder(OrderModel order, {Bill? bill}) {

    final isPaidVal = bill != null && (bill.isPaid || bill.paymentStatus == 'PAID');
    final total = bill?.totalAmount ?? order.totalAmount;
    final paid = bill?.paidAmount ?? 0.0;
    final toCollect = isPaidVal ? 0.0 : (bill?.remainingAmount ?? (total - paid).clamp(0.0, double.infinity));

    List<DeliveryItemInfo> itemInfos = [];
    if (order.items.isNotEmpty) {
      itemInfos = order.items
          .map((i) => DeliveryItemInfo(
                productName: i.productName,
                quantity: i.quantity,
                unitPrice: i.unitPrice,
                subtotal: i.subtotal,
                shopName: i.shopName,
                shopId: i.shopId,
              ))
          .toList();
    } else if (bill != null && bill.items.isNotEmpty) {
      itemInfos = bill.items
          .map((i) => DeliveryItemInfo(
                productName: i.productName,
                quantity: i.quantity,
                unitPrice: i.unitPrice,
                subtotal: i.subtotal,
                shopName: i.shopName,
                shopId: i.shopId,
              ))
          .toList();
    }

    final notes = order.deliveryNotes ?? bill?.deliveryNotes ?? '';
    final isDeliveredVal = order.status == 'DELIVERED' || notes.contains('[DELIVERED]');

    return DeliveryOrder(
      id: order.id,
      orderId: order.id,
      orderNumber: order.orderNumber,
      billNumber: bill?.billNumber,
      billId: bill?.id,
      status: order.status,
      isDelivered: isDeliveredVal,
      isPaid: isPaidVal,
      totalAmount: total,
      paidAmount: paid,
      amountToCollect: toCollect,
      customerName: order.customerName ?? bill?.customerName ?? 'Customer',
      customerPhone: order.customerPhone ?? bill?.customerPhone ?? '',
      deliveryAddress: order.deliveryAddress ?? bill?.deliveryAddress ?? 'No address provided',
      deliveryNotes: order.deliveryNotes ?? bill?.deliveryNotes,
      items: itemInfos,
      createdAt: order.createdAt,
      completedAt: order.completedAt,
      rawOrder: order,
      rawBill: bill,
    );
  }

  factory DeliveryOrder.fromBill(Bill bill, {OrderModel? order}) {
    final isPaidVal = bill.isPaid || bill.paymentStatus == 'PAID';
    final total = bill.totalAmount;
    final paid = bill.paidAmount;
    final toCollect = isPaidVal ? 0.0 : bill.remainingAmount;

    List<DeliveryItemInfo> itemInfos = [];
    if (order != null && order.items.isNotEmpty) {
      itemInfos = order.items
          .map((i) => DeliveryItemInfo(
                productName: i.productName,
                quantity: i.quantity,
                unitPrice: i.unitPrice,
                subtotal: i.subtotal,
                shopName: i.shopName,
                shopId: i.shopId,
              ))
          .toList();
    } else if (bill.items.isNotEmpty) {
      itemInfos = bill.items
          .map((i) => DeliveryItemInfo(
                productName: i.productName,
                quantity: i.quantity,
                unitPrice: i.unitPrice,
                subtotal: i.subtotal,
                shopName: i.shopName,
                shopId: i.shopId,
              ))
          .toList();
    }

    final notes = bill.deliveryNotes ?? order?.deliveryNotes ?? '';
    final isDeliveredVal = (order != null && order.status == 'DELIVERED') ||
        bill.status == 'DELIVERED' ||
        notes.contains('[DELIVERED]');

    return DeliveryOrder(
      id: bill.orderId.isNotEmpty ? bill.orderId : bill.id,
      orderId: bill.orderId,
      orderNumber: bill.orderNumber ?? order?.orderNumber ?? bill.billNumber,
      billNumber: bill.billNumber,
      billId: bill.id,
      status: order?.status ?? bill.status,
      isDelivered: isDeliveredVal,
      isPaid: isPaidVal,
      totalAmount: total,
      paidAmount: paid,
      amountToCollect: toCollect,
      customerName: bill.customerName ?? order?.customerName ?? 'Customer',
      customerPhone: bill.customerPhone ?? order?.customerPhone ?? '',
      deliveryAddress: bill.deliveryAddress ?? order?.deliveryAddress ?? 'No address provided',
      deliveryNotes: bill.deliveryNotes ?? order?.deliveryNotes,
      items: itemInfos,
      createdAt: bill.createdAt,
      completedAt: order?.completedAt,
      rawOrder: order,
      rawBill: bill,
    );
  }

  Bill? get bill => rawBill;
  OrderModel? get order => rawOrder;

  Set<String> get pickupShops {
    final Set<String> shops = {};
    for (final i in items) {
      if (i.shopName != null && i.shopName!.trim().isNotEmpty) {
        shops.add(i.shopName!.trim());
      }
    }
    return shops;
  }

  DeliveryOrder withResolvedShopNames(Map<String, String> shopsLookup) {
    if (shopsLookup.isEmpty) return this;
    final updatedItems = items.map((i) {
      if ((i.shopName == null || i.shopName!.isEmpty) && i.shopId != null && shopsLookup.containsKey(i.shopId)) {
        return DeliveryItemInfo(
          productName: i.productName,
          quantity: i.quantity,
          unitPrice: i.unitPrice,
          subtotal: i.subtotal,
          shopName: shopsLookup[i.shopId],
          shopId: i.shopId,
        );
      }
      return i;
    }).toList();

    return DeliveryOrder(
      id: id,
      orderId: orderId,
      orderNumber: orderNumber,
      billNumber: billNumber,
      billId: billId,
      status: status,
      isDelivered: isDelivered,
      isPaid: isPaid,
      totalAmount: totalAmount,
      paidAmount: paidAmount,
      amountToCollect: amountToCollect,
      customerName: customerName,
      customerPhone: customerPhone,
      deliveryAddress: deliveryAddress,
      deliveryNotes: deliveryNotes,
      items: updatedItems,
      createdAt: createdAt,
      completedAt: completedAt,
      rawOrder: rawOrder,
      rawBill: rawBill,
    );
  }
}
