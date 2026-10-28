import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/bill.dart';
import '../data/models/delivery_order.dart';
import '../data/models/order.dart';
import '../core/services/notification_service.dart';
import '../core/services/offline_sync_service.dart';

class DeliveryProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<DeliveryOrder> _activeDeliveries = [];
  List<DeliveryOrder> _completedDeliveries = [];
  bool _isLoading = false;
  String? _errorMessage;

  final Set<String> _knownDeliveryIds = {};
  bool _isFirstLoad = true;

  double _totalCashCollectedToday = 0.0;
  double _totalGpayCollectedToday = 0.0;

  RealtimeChannel? _ordersSubscription;
  RealtimeChannel? _billsSubscription;
  Timer? _cutoffCheckTimer;
  DateTime _lastCutoff = _computeCutoff();

  static DateTime _computeCutoff() {
    final now = DateTime.now();
    return now.hour < 3
        ? DateTime(now.year, now.month, now.day - 1, 3, 0, 0)
        : DateTime(now.year, now.month, now.day, 3, 0, 0);
  }

  List<DeliveryOrder> get activeDeliveries => _activeDeliveries;
  List<DeliveryOrder> get completedDeliveries => _completedDeliveries;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  double get totalCashCollectedToday => _totalCashCollectedToday;
  double get totalGpayCollectedToday => _totalGpayCollectedToday;
  double get totalCollectedToday => _totalCashCollectedToday + _totalGpayCollectedToday;
  int get completedCountToday => _completedDeliveries.length;

  DeliveryProvider() {
    loadDeliveries();
    _setupRealtime();
    _cutoffCheckTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      final currentCutoff = _computeCutoff();
      if (currentCutoff != _lastCutoff) {
        _lastCutoff = currentCutoff;
        loadDeliveries();
      }
    });
  }

  void _setupRealtime() {
    try {
      _ordersSubscription = _supabase
          .channel('public:delivery_orders')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'orders',
            callback: (payload) {
              loadDeliveries();
            },
          )
          .subscribe();

      _billsSubscription = _supabase
          .channel('public:delivery_bills')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'bills',
            callback: (payload) {
              loadDeliveries();
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Realtime setup error: $e');
    }
  }

  Future<void> loadDeliveries() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 0. Fetch shops lookup map for fast, reliable shop name resolution
      final Map<String, String> shopsLookup = {};
      try {
        final shopsResp = await _supabase.from('shops').select('id, name');
        for (final s in (shopsResp as List)) {
          final sId = s['id']?.toString() ?? '';
          final sName = s['name']?.toString() ?? '';
          if (sId.isNotEmpty && sName.isNotEmpty) {
            shopsLookup[sId] = sName;
          }
        }
      } catch (_) {}

      // 1. Fetch delivery orders from database with joined shops
      final ordersResp = await _supabase
          .from('orders')
          .select('*, order_items(*, shops(name))')
          .eq('order_type', 'DELIVERY')
          .order('created_at', ascending: false)
          .limit(80);

      final allOrdersList = (ordersResp as List)
          .map((json) => OrderModel.fromJson(json))
          .toList();
      final orderIds = allOrdersList.map((o) => o.id).toList();

      // 2. Fetch associated bills with payments and items with joined shops
      Map<String, Bill> billsMap = {};
      if (orderIds.isNotEmpty) {
        try {
          final billsResp = await _supabase
              .from('bills')
              .select('*, payments(*), bill_items(*, shops(name))')
              .inFilter('order_id', orderIds);
          for (final b in (billsResp as List)) {
            final bill = Bill.fromJson(b);
            billsMap[bill.orderId] = bill;
          }
        } catch (_) {}
      }

      // Also fetch any recent bills with order_type DELIVERY directly
      try {
        final recentDeliveryBillsResp = await _supabase
            .from('bills')
            .select('*, payments(*), bill_items(*, shops(name)), orders(*)')
            .order('created_at', ascending: false)
            .limit(40);

        for (final b in (recentDeliveryBillsResp as List)) {
          final order = b['orders'] as Map<String, dynamic>?;
          final billMap = Map<String, dynamic>.from(b);
          if (order != null) {
            billMap['order_number'] = order['order_number'];
            billMap['order_type'] = order['order_type'];
            billMap['customer_name'] = order['customer_name'];
            billMap['customer_phone'] = order['customer_phone'];
            billMap['delivery_address'] = order['delivery_address'];
            billMap['delivery_notes'] = order['delivery_notes'];
          }
          final bill = Bill.fromJson(billMap);
          final key = bill.orderId.isNotEmpty ? bill.orderId : bill.id;
          if (!billsMap.containsKey(key)) {
            billsMap[key] = bill;
          }
        }
      } catch (_) {}

      final Map<String, DeliveryOrder> activeMap = {};
      final Map<String, DeliveryOrder> completedMap = {};

      // 3:00 AM daily cutoff: delivery history and collections reset daily at 3:00 AM
      final shiftCutoff = _computeCutoff();
      _lastCutoff = shiftCutoff;

      for (final order in allOrdersList) {
        if (order.status == 'CANCELLED') continue;
        final bill = billsMap[order.id];
        final rawDeliveryOrder = DeliveryOrder.fromOrder(order, bill: bill);
        final deliveryOrder = rawDeliveryOrder.withResolvedShopNames(shopsLookup);
        if (deliveryOrder.isDelivered) {
          DateTime compTime = (deliveryOrder.completedAt ?? deliveryOrder.createdAt).toLocal();
          if (bill != null && bill.isPaid) {
            final billTime = bill.createdAt.toLocal();
            if (billTime.isAfter(compTime)) {
              compTime = billTime;
            }
          }
          // Only show today's deliveries completed on or after 3:00 AM
          if (!compTime.isBefore(shiftCutoff)) {
            completedMap[order.id] = deliveryOrder;
          }
        } else {
          activeMap[order.id] = deliveryOrder;
        }
      }

      // Check any delivery bills not yet covered by orders
      for (final bill in billsMap.values) {
        final isDelivery = (bill.orderType?.toLowerCase() == 'delivery') ||
            (bill.deliveryAddress != null && bill.deliveryAddress!.trim().isNotEmpty);
        if (isDelivery && !bill.isCancelled) {
          final key = bill.orderId.isNotEmpty ? bill.orderId : bill.id;
          if (!activeMap.containsKey(key) && !completedMap.containsKey(key)) {
            final rawDeliveryOrder = DeliveryOrder.fromBill(bill);
            final deliveryOrder = rawDeliveryOrder.withResolvedShopNames(shopsLookup);
            if (deliveryOrder.isDelivered) {
              final compTime = (deliveryOrder.completedAt ?? deliveryOrder.createdAt).toLocal();
              // Only show today's deliveries completed on or after 3:00 AM
              if (!compTime.isBefore(shiftCutoff)) {
                completedMap[key] = deliveryOrder;
              }
            } else {
              activeMap[key] = deliveryOrder;
            }
          }
        }
      }

      _activeDeliveries = activeMap.values.toList();
      _activeDeliveries.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Trigger "New Order" notification for newly arrived deliveries
      if (_isFirstLoad) {
        _isFirstLoad = false;
        _knownDeliveryIds.addAll(activeMap.keys);
      } else {
        for (final entry in activeMap.entries) {
          if (!_knownDeliveryIds.contains(entry.key)) {
            _knownDeliveryIds.add(entry.key);
            final newOrder = entry.value;
            NotificationService.instance.showNewOrderNotification(
              orderId: newOrder.id,
              orderNumber: newOrder.orderNumber,
              customerName: newOrder.customerName,
              totalAmount: newOrder.totalAmount,
            );
          }
        }
      }

      _completedDeliveries = completedMap.values.toList();
      _completedDeliveries.sort((a, b) =>
          (b.completedAt ?? b.createdAt).compareTo(a.completedAt ?? a.createdAt));

      // Calculate shift collections for today's deliveries
      double cashSum = 0.0;
      double gpaySum = 0.0;

      for (final del in _completedDeliveries) {
        final bill = del.bill;
        if (bill != null && bill.payments.isNotEmpty) {
          for (final p in bill.payments) {
            final method = p.paymentMethod.toUpperCase();
            if (method == 'CASH') {
              cashSum += p.amount;
            } else {
              gpaySum += p.amount;
            }
          }
        } else {
          final method = (bill?.paymentMethod ?? '').toUpperCase();
          if (method == 'CASH') {
            cashSum += del.totalAmount;
          } else {
            gpaySum += del.totalAmount;
          }
        }
      }

      _totalCashCollectedToday = cashSum;
      _totalGpayCollectedToday = gpaySum;
    } catch (e) {
      _errorMessage = 'Failed to load delivery orders: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> completeDelivery({
    required DeliveryOrder delivery,
    required String paymentMethod,
    double? cashAmount,
    double? gpayAmount,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final orderId = delivery.orderId;
      var bill = delivery.bill;

      // 1. If not yet paid, ensure bill exists and record payment
      if (!delivery.isPaid && delivery.amountToCollect > 0) {
        if (bill == null && delivery.billId != null) {
          final bResp = await _supabase
              .from('bills')
              .select('id, total_amount, paid_amount, status, payment_status')
              .eq('id', delivery.billId!)
              .maybeSingle();
          if (bResp != null) {
            bill = Bill.fromJson(bResp);
          }
        }

        if (bill == null && orderId.isNotEmpty) {
          final bResp = await _supabase
              .from('bills')
              .select('id, total_amount, paid_amount, status, payment_status')
              .eq('order_id', orderId)
              .maybeSingle();

          if (bResp != null) {
            bill = Bill.fromJson(bResp);
          } else {
            String bNum;
            try {
              final numResp = await _supabase.rpc('generate_bill_number').timeout(const Duration(seconds: 4));
              bNum = numResp as String;
            } catch (_) {
              bNum = await OfflineSyncService().generateOfflineBillNumber();
            }
            final newBillResp = await _supabase.from('bills').insert({
              'bill_number': bNum,
              'order_id': orderId,
              'subtotal': delivery.totalAmount,
              'discount': 0.0,
              'tax': 0.0,
              'total_amount': delivery.totalAmount,
              'paid_amount': 0.0,
              'current_version': 1,
              'status': 'PRINTED',
              'payment_method': 'CASH',
              'payment_status': 'UNPAID',
            }).select().single();
            bill = Bill.fromJson(newBillResp);
          }
        }

        List<Map<String, dynamic>> payments = [];
        if (paymentMethod == 'CASH') {
          payments = [{'method': 'CASH', 'amount': delivery.amountToCollect}];
        } else if (paymentMethod == 'GPAY') {
          payments = [{'method': 'GPAY', 'amount': delivery.amountToCollect}];
        } else if (paymentMethod == 'SPLIT') {
          if ((cashAmount ?? 0) > 0) payments.add({'method': 'CASH', 'amount': cashAmount});
          if ((gpayAmount ?? 0) > 0) payments.add({'method': 'GPAY', 'amount': gpayAmount});
        }

        if (bill != null) {
          try {
            await _supabase.rpc('record_bill_payment_transaction', params: {
              'p_bill_id': bill.id,
              'p_payments': payments,
            });
          } catch (_) {
            for (final p in payments) {
              await _supabase.from('payments').insert({
                'bill_id': bill.id,
                'payment_method': (p['method'] as String? ?? 'CASH').toUpperCase(),
                'amount': p['amount'],
                'status': 'COMPLETED',
              });
            }
          }
        }
      }

      // 2. Mark order completed & append [DELIVERED] to notes
      final currentNotes = delivery.deliveryNotes ?? '';
      final updatedNotes = currentNotes.contains('[DELIVERED]')
          ? currentNotes
          : (currentNotes.isEmpty ? '[DELIVERED]' : '$currentNotes [DELIVERED]');

      if (orderId.isNotEmpty) {
        try {
          await _supabase.from('orders').update({
            'status': 'COMPLETED',
            'delivery_notes': updatedNotes,
            'completed_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', orderId);
        } catch (_) {}
      }

      // Also ensure bill payment status is marked PAID
      final effectiveBillId = bill?.id ?? delivery.billId;
      if (effectiveBillId != null) {
        try {
          await _supabase.from('bills').update({
            'status': 'PAID',
            'payment_status': 'PAID',
            'paid_amount': delivery.totalAmount,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', effectiveBillId);
        } catch (_) {}
      }

      await loadDeliveries();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to complete delivery: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _ordersSubscription?.unsubscribe();
    _billsSubscription?.unsubscribe();
    _cutoffCheckTimer?.cancel();
    super.dispose();
  }
}
