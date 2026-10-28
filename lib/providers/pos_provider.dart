import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/services/local_storage_service.dart';
import '../core/services/offline_sync_service.dart';
import '../core/utils/receipt_printer.dart';
import '../core/utils/uuid_util.dart';
import '../data/models/bill.dart';
import '../data/models/bill_item.dart';
import '../data/models/dining_table.dart';
import '../data/models/order.dart';
import '../data/models/order_item.dart';
import '../data/models/product.dart';
import '../data/models/shop.dart';
import '../data/models/void_refund_request.dart';
import '../data/models/delivery_order.dart';
import '../data/models/payment_record.dart';

enum AppRole {
  posStaff,
  deliveryPartner,
}

class PosProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Real-time and data states
  bool _isLoading = true;
  String? _errorMessage;
  bool _isProcessingBilling = false;

  // App Role: POS Staff vs Delivery Partner
  AppRole _currentRole = AppRole.posStaff;
  AppRole get currentRole => _currentRole;
  void setRole(AppRole role) {
    _currentRole = role;
    if (role == AppRole.deliveryPartner) {
      loadDeliveryOrders();
    }
    notifyListeners();
  }

  List<Shop> _shops = [];
  Shop? _selectedShop;
  List<Product> _allProducts = [];
  List<DiningTable> _tables = [];
  List<OrderModel> _activeOrders = [];
  List<Bill> _recentBills = [];
  List<VoidRefundRequest> _pendingApprovals = [];
  List<DeliveryOrder> _activeDeliveryOrders = [];
  List<DeliveryOrder> _completedDeliveryOrders = [];

  List<DeliveryOrder> get activeDeliveryOrders => _activeDeliveryOrders;
  List<DeliveryOrder> get completedDeliveryOrders => _completedDeliveryOrders;

  // Active bill being edited (for creating Version 2, 3...)
  Bill? _activeBillForEdit;

  // Filtering
  String _productSearchQuery = '';
  String _selectedCategory = 'ALL';

  // Current Order / Cart State
  OrderType _orderType = OrderType.dineIn;
  DiningTable? _selectedTable;
  String? _currentActiveOrderId;
  String? _currentActiveOrderNumber;
  String? _currentActiveSessionId;

  // Delivery Customer Info
  final TextEditingController customerNameController = TextEditingController();
  final TextEditingController customerPhoneController = TextEditingController();
  final TextEditingController deliveryAddressController = TextEditingController();
  final TextEditingController deliveryNotesController = TextEditingController();

  int _paymentEventCount = 0;
  int get paymentEventCount => _paymentEventCount;

  static final Map<String, List<Map<String, dynamic>>> localPaymentsCache = {};

  // Cart Items
  final List<OrderItem> _cart = [];
  double _discount = 0.0;
  double _tax = 0.0;
  double _parcelCharge = 0.0;

  // Realtime subscription
  RealtimeChannel? _tablesChannel;
  RealtimeChannel? _billsChannel;
  RealtimeChannel? _approvalsChannel;

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isProcessingBilling => _isProcessingBilling;

  List<Shop> get shops => _shops;
  Shop? get selectedShop => _selectedShop;
  List<DiningTable> get tables => _tables;
  List<OrderModel> get activeOrders => _activeOrders;
  List<Bill> get recentBills => _recentBills;

  /// Business day cutoff: Daily at 3:00 AM (night shifts past midnight belong to previous calendar day)
  static DateTime computeBusinessDayCutoff() {
    final now = DateTime.now();
    return now.hour < 3
        ? DateTime(now.year, now.month, now.day - 1, 3, 0, 0)
        : DateTime(now.year, now.month, now.day, 3, 0, 0);
  }

  /// Bills belonging strictly to the current business day (on or after 3:00 AM)
  List<Bill> get todayBills {
    final cutoff = computeBusinessDayCutoff();
    return _recentBills.where((b) => !b.createdAt.toLocal().isBefore(cutoff)).toList();
  }

  List<VoidRefundRequest> get pendingApprovals => _pendingApprovals;
  Bill? get activeBillForEdit => _activeBillForEdit;

  List<Bill> get unpaidBills =>
      todayBills.where((b) => b.isUnpaid || b.isPartiallyPaid).toList();
  List<Bill> get paidBills => todayBills.where((b) => b.isPaid).toList();

  OrderType get orderType => _orderType;
  DiningTable? get selectedTable => _selectedTable;
  String? get currentActiveOrderId => _currentActiveOrderId;
  String? get currentActiveOrderNumber => _currentActiveOrderNumber;
  String? get currentActiveSessionId => _currentActiveSessionId;

  List<OrderItem> get cart => List.unmodifiable(_cart);
  double get discount => _discount;
  double get tax => _tax;
  double get parcelCharge => _parcelCharge;

  void setParcelCharge(double charge) {
    _parcelCharge = charge.clamp(0.0, double.infinity);
    notifyListeners();
  }

  String get productSearchQuery => _productSearchQuery;
  String get selectedCategory => _selectedCategory;

  double get subtotal => _cart.fold(0.0, (sum, item) => sum + item.subtotal);
  double get totalAmount =>
      (subtotal - _discount + _tax + (_orderType == OrderType.parcel ? _parcelCharge : 0.0))
          .clamp(0.0, double.infinity);
  int get totalItemCount => _cart.fold(0, (sum, item) => sum + item.quantity);

  // Filtered Products for selected shop and category
  List<Product> get filteredProducts {
    if (_selectedShop == null) return [];
    return _allProducts.where((p) {
      if (p.shopId != _selectedShop!.id) return false;
      if (_selectedCategory != 'ALL' && p.category != _selectedCategory) return false;
      if (_productSearchQuery.isNotEmpty) {
        final q = _productSearchQuery.toLowerCase();
        return p.name.toLowerCase().contains(q) ||
            (p.description != null && p.description!.toLowerCase().contains(q)) ||
            (p.sku != null && p.sku!.toLowerCase().contains(q));
      }
      return true;
    }).toList();
  }

  List<Product> get allProducts => _allProducts;

  List<String> get currentShopCategories {
    if (_selectedShop == null) return ['ALL'];
    final cats = _allProducts
        .where((p) => p.shopId == _selectedShop!.id)
        .map((p) => p.category)
        .toSet()
        .toList();
    cats.sort();
    return ['ALL', ...cats];
  }

  // Grouped cart items by Shop for receipt & clear multi-shop display
  Map<String, List<OrderItem>> get cartByShop {
    final Map<String, List<OrderItem>> grouped = {};
    for (final item in _cart) {
      final name = item.shopName ??
          _shops.firstWhere((s) => s.id == item.shopId, orElse: () => Shop(
                id: item.shopId,
                name: 'Shop',
                code: 'SH',
                status: 'ACTIVE',
                displayOrder: 1,
                createdAt: DateTime.now(),
              )).name;
      grouped.putIfAbsent(name, () => []).add(item);
    }
    return grouped;
  }

  PosProvider() {
    init();
  }

  Future<void> init() async {
    _isLoading = true;
    _errorMessage = null;

    // 1. Immediately hydrate from LocalStorageService (Zero-latency instant display!)
    final local = LocalStorageService();
    final cachedShops = local.getShops();
    final cachedProducts = local.getProducts();
    final cachedTables = local.getTables();
    final cachedBills = local.getBills();
    final cachedOrders = local.getOrders();

    if (cachedShops.isNotEmpty) _shops = List.from(cachedShops);
    if (cachedProducts.isNotEmpty) _allProducts = List.from(cachedProducts);
    if (cachedTables.isNotEmpty) _tables = List.from(cachedTables);
    if (cachedBills.isNotEmpty) _recentBills = List.from(cachedBills);
    if (cachedOrders.isNotEmpty) _activeOrders = List.from(cachedOrders);

    if (_shops.isNotEmpty && _selectedShop == null) {
      _selectedShop = _shops.first;
    }
    if (_tables.isNotEmpty && _selectedTable == null) {
      _selectedTable = _tables.firstWhere((t) => t.isAvailable, orElse: () => _tables.first);
    }

    // Stop loading indicator immediately so UI is completely visible and usable
    _isLoading = false;
    notifyListeners();

    // Hook background sync success callback to refresh in-memory state
    OfflineSyncService().onSyncSuccess = () {
      loadRecentBills();
      loadActiveOrders();
    };

    // 2. Asynchronously refresh remote data from Supabase in background
    _refreshRemoteData();
  }

  Future<void> _refreshRemoteData() async {
    try {
      await Future.wait([
        loadShops(),
        loadProducts(),
        loadTables(),
        loadActiveOrders(),
        loadRecentBills(),
        loadPendingApprovals(),
        loadDeliveryOrders(),
      ]);
      _setupRealtime();
      _errorMessage = null;
      OfflineSyncService().markOnline();
    } catch (_) {
      // Offline fallback: do not wipe cached data, simply mark offline
      OfflineSyncService().markOffline();
    } finally {
      notifyListeners();
    }
  }

  void _setupRealtime() {
    try {
      _tablesChannel = _supabase
          .channel('public:dining_tables')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'dining_tables',
            callback: (payload) {
              loadTables();
              loadActiveOrders();
            },
          )
          .subscribe();

      _billsChannel = _supabase
          .channel('public:bills')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'bills',
            callback: (payload) {
              loadRecentBills();
              loadActiveOrders();
            },
          )
          .subscribe();

      _approvalsChannel = _supabase
          .channel('public:void_refund_requests')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'void_refund_requests',
            callback: (payload) {
              loadPendingApprovals();
              loadRecentBills();
            },
          )
          .subscribe();
    } catch (_) {}
  }

  @override
  void dispose() {
    _tablesChannel?.unsubscribe();
    _billsChannel?.unsubscribe();
    _approvalsChannel?.unsubscribe();
    customerNameController.dispose();
    customerPhoneController.dispose();
    deliveryAddressController.dispose();
    deliveryNotesController.dispose();
    super.dispose();
  }

  // --------------------------------------------------------------------------
  // Data Loaders
  // --------------------------------------------------------------------------
  Future<void> loadShops() async {
    try {
      final response = await _supabase
          .from('shops')
          .select('*')
          .eq('status', 'ACTIVE')
          .order('display_order', ascending: true)
          .timeout(const Duration(seconds: 3));

      final fetched = (response as List).map((json) => Shop.fromJson(json)).toList();
      if (fetched.isNotEmpty) {
        _shops = fetched;
        LocalStorageService().saveShops(_shops);
        if (_selectedShop == null || !_shops.any((s) => s.id == _selectedShop!.id)) {
          _selectedShop = _shops.first;
        }
      }
    } catch (_) {
      // Offline fallback: keep cached shops
      if (_shops.isEmpty) {
        _shops = LocalStorageService().getShops();
        if (_shops.isNotEmpty && _selectedShop == null) {
          _selectedShop = _shops.first;
        }
      }
    }
  }

  Future<void> loadProducts() async {
    try {
      final response = await _supabase
          .from('products')
          .select('*')
          .eq('is_active', true)
          .order('name', ascending: true)
          .timeout(const Duration(seconds: 3));

      final fetched = (response as List).map((json) => Product.fromJson(json)).toList();
      if (fetched.isNotEmpty) {
        _allProducts = fetched;
        LocalStorageService().saveProducts(_allProducts);
      }
    } catch (_) {
      // Offline fallback: keep cached products
      if (_allProducts.isEmpty) {
        _allProducts = LocalStorageService().getProducts();
      }
    }
  }

  Future<void> loadTables() async {
    try {
      final response = await _supabase
          .from('dining_tables')
          .select('*')
          .eq('is_active', true)
          .order('table_number', ascending: true)
          .timeout(const Duration(seconds: 3));

      final List<DiningTable> rawTables =
          (response as List).map((json) => DiningTable.fromJson(json)).toList();

      // Enrich with active session & order info
      try {
        final sessionsResp = await _supabase
            .from('table_sessions')
            .select('id, session_number, status, table_session_tables(table_id, left_at), orders(id, order_number, total_amount, status)')
            .eq('status', 'OPEN')
            .timeout(const Duration(seconds: 3));

        final Map<String, Map<String, dynamic>> tableInfoMap = {};

        for (final sess in sessionsResp as List) {
          final sessId = sess['id'] as String;
          final tstList = sess['table_session_tables'] as List? ?? [];
          final ordersList = sess['orders'] as List? ?? [];
          final openOrder = ordersList.firstWhere(
            (o) => o['status'] == 'OPEN' || o['status'] == 'IN_PROGRESS',
            orElse: () => null,
          );

          final activeTableIds = tstList
              .where((t) => t['left_at'] == null)
              .map((t) => t['table_id'] as String)
              .toList();

          for (final tId in activeTableIds) {
            tableInfoMap[tId] = {
              'session_id': sessId,
              'order_id': openOrder != null ? openOrder['id'] : null,
              'order_number': openOrder != null ? openOrder['order_number'] : null,
              'order_total': openOrder != null ? (openOrder['total_amount'] as num).toDouble() : null,
              'merged_count': activeTableIds.length,
            };
          }
        }

        _tables = rawTables.map((t) {
          final info = tableInfoMap[t.id];
          if (info != null) {
            return t.copyWith(
              activeSessionId: info['session_id'],
              activeOrderId: info['order_id'],
              activeOrderNumber: info['order_number'],
              activeOrderTotal: info['order_total'],
            );
          }
          return t;
        }).toList();
      } catch (_) {
        _tables = rawTables;
      }

      if (_tables.isNotEmpty) {
        LocalStorageService().saveTables(_tables);
      }

      if (_orderType == OrderType.dineIn && _selectedTable == null && _tables.isNotEmpty) {
        _selectedTable = _tables.firstWhere(
          (t) => t.isAvailable,
          orElse: () => _tables.first,
        );
      }

      // Map table names to any currently loaded active orders
      for (int i = 0; i < _activeOrders.length; i++) {
        final o = _activeOrders[i];
        if (o.orderType == OrderType.dineIn && (o.tableDisplay == null || o.tableDisplay!.isEmpty)) {
          final tblName = getTableForOrder(o);
          if (tblName != null) {
            _activeOrders[i] = o.copyWith(tableDisplay: tblName);
          }
        }
      }

      notifyListeners();
    } catch (_) {
      if (_tables.isEmpty) {
        _tables = LocalStorageService().getTables();
      }
    }
  }

  String? getTableForOrder(OrderModel order) {
    if (order.orderType != OrderType.dineIn) return null;

    if (order.tableDisplay != null && order.tableDisplay!.trim().isNotEmpty) {
      return order.tableDisplay;
    }

    // 1. Check if any table in _tables has this order as activeOrderId
    final tablesWithOrder = _tables.where((t) => t.activeOrderId == order.id).toList();
    if (tablesWithOrder.isNotEmpty) {
      return tablesWithOrder.map((t) => t.tableName).join(' + ');
    }

    // 2. Check if any table in _tables has this order's tableSessionId
    if (order.tableSessionId != null) {
      final tablesWithSession = _tables.where((t) => t.activeSessionId == order.tableSessionId).toList();
      if (tablesWithSession.isNotEmpty) {
        return tablesWithSession.map((t) => t.tableName).join(' + ');
      }
    }

    return null;
  }

  Future<void> loadActiveOrders() async {
    try {
      final response = await _supabase
          .from('orders')
          .select('*, order_items(*)')
          .inFilter('status', ['OPEN', 'IN_PROGRESS', 'READY'])
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 3));

      final remoteOrders = (response as List).map((json) {
        final order = OrderModel.fromJson(json);
        if (order.orderType == OrderType.dineIn && (order.tableDisplay == null || order.tableDisplay!.isEmpty)) {
          final tblName = getTableForOrder(order);
          if (tblName != null) {
            return order.copyWith(tableDisplay: tblName);
          }
        }
        return order;
      }).toList();

      // Merge with pending offline orders that haven't synced yet
      final pendingOfflineIds = OfflineSyncService().queue
          .where((item) => item['action'] == 'SAVE_ORDER')
          .map((item) => (item['payload']['order'] as Map)['id'] as String?)
          .whereType<String>()
          .toSet();

      final offlineOrders = _activeOrders.where((o) => pendingOfflineIds.contains(o.id)).toList();
      for (final off in offlineOrders) {
        if (!remoteOrders.any((r) => r.id == off.id)) {
          remoteOrders.add(off);
        }
      }

      _activeOrders = remoteOrders;
      LocalStorageService().saveOrders(_activeOrders);
      notifyListeners();
    } catch (_) {
      if (_activeOrders.isEmpty) {
        _activeOrders = LocalStorageService().getOrders();
      }
    }
  }

  Future<void> loadRecentBills() async {
    try {
      final cutoff = computeBusinessDayCutoff();
      final response = await _supabase
          .from('bills')
          .select('*, bill_items(*), bill_versions(*), payments(*), orders(*)')
          .gte('created_at', cutoff.toUtc().toIso8601String())
          .order('created_at', ascending: false)
          .limit(100)
          .timeout(const Duration(seconds: 3));

      final remoteBills = (response as List).map((json) {
        final order = json['orders'] as Map<String, dynamic>?;
        final billMap = Map<String, dynamic>.from(json);
        if (order != null) {
          billMap['order_number'] = order['order_number'];
          billMap['order_type'] = order['order_type'];
          billMap['customer_name'] = order['customer_name'];
          billMap['customer_phone'] = order['customer_phone'];
          billMap['delivery_address'] = order['delivery_address'];
          billMap['delivery_notes'] = order['delivery_notes'];
        }
        return Bill.fromJson(billMap);
      }).toList();

      // Merge with any local bills in local storage
      final remoteBillIds = remoteBills.map((b) => b.id).toSet();
      final localBills = LocalStorageService().getBills();
      for (final lb in localBills) {
        if (!remoteBillIds.contains(lb.id) && lb.createdAt.isAfter(cutoff)) {
          remoteBills.add(lb);
        }
      }

      remoteBills.sort((a, b) => (b.printedAt ?? b.createdAt).compareTo(a.printedAt ?? a.createdAt));

      _recentBills = remoteBills;
      LocalStorageService().saveBills(_recentBills);
      notifyListeners();
    } catch (_) {
      if (_recentBills.isEmpty) {
        _recentBills = LocalStorageService().getBills();
        notifyListeners();
      }
    }
  }

  Future<void> loadPendingApprovals() async {
    try {
      List<dynamic> requests = [];
      try {
        final response = await _supabase
            .from('void_refund_requests')
            .select('*, bills(bill_number, total_amount)')
            .order('requested_at', ascending: false)
            .limit(50);
        requests = List<dynamic>.from(response);
      } catch (_) {}

      // Also include bills with VOID_PENDING / REFUND_PENDING status that
      // may not have a void_refund_requests row yet (fallback)
      try {
        final pendingBills = await _supabase
            .from('bills')
            .select('id, bill_number, total_amount, status, created_at, updated_at')
            .inFilter('status', ['VOID_PENDING', 'REFUND_PENDING'])
            .order('updated_at', ascending: false);

        final existingBillIds = requests.map((r) => r['bill_id']).toSet();
        for (final b in (pendingBills as List)) {
          if (!existingBillIds.contains(b['id'])) {
            existingBillIds.add(b['id']);
            requests.add({
              'id': b['id'],
              'bill_id': b['id'],
              'request_type': b['status'] == 'VOID_PENDING' ? 'VOID' : 'REFUND',
              'reason': b['status'] == 'VOID_PENDING' ? 'Void requested from counter' : 'Refund requested from counter',
              'status': 'PENDING',
              'requested_at': b['updated_at'] ?? b['created_at'],
              'bills': {
                'bill_number': b['bill_number'],
                'total_amount': b['total_amount'],
              }
            });
          }
        }
      } catch (_) {}

      _pendingApprovals = requests.map((json) {
        final bill = json['bills'] as Map<String, dynamic>?;
        final map = Map<String, dynamic>.from(json);
        if (bill != null) {
          map['bill_number'] = bill['bill_number'];
          map['total_amount'] = bill['total_amount'];
        }
        return VoidRefundRequest.fromJson(map);
      }).toList();
      notifyListeners();
    } catch (_) {
      _pendingApprovals = [];
    }
  }

  // --------------------------------------------------------------------------
  // Delivery Orders Management
  // --------------------------------------------------------------------------
  Future<void> loadDeliveryOrders() async {
    try {
      // 1. Fetch delivery orders from database
      final ordersResp = await _supabase
          .from('orders')
          .select('*, order_items(*)')
          .eq('order_type', 'DELIVERY')
          .order('created_at', ascending: false)
          .limit(60);

      final allOrdersList = (ordersResp as List).map((json) => OrderModel.fromJson(json)).toList();
      final orderIds = allOrdersList.map((o) => o.id).toList();

      Map<String, Bill> billsMap = {};
      if (orderIds.isNotEmpty) {
        try {
          final billsResp = await _supabase
              .from('bills')
              .select('*, payments(*), bill_items(*)')
              .inFilter('order_id', orderIds);
          for (final b in (billsResp as List)) {
            final bill = Bill.fromJson(b);
            billsMap[bill.orderId] = bill;
          }
        } catch (_) {}
      }

      // Merge with _recentBills in memory
      for (final b in _recentBills) {
        if (b.orderId.isNotEmpty && !billsMap.containsKey(b.orderId)) {
          billsMap[b.orderId] = b;
        }
      }

      final Map<String, DeliveryOrder> activeMap = {};
      final Map<String, DeliveryOrder> completedMap = {};

      for (final order in allOrdersList) {
        if (order.status == 'CANCELLED') continue;
        final bill = billsMap[order.id];
        final deliveryOrder = DeliveryOrder.fromOrder(order, bill: bill);
        if (deliveryOrder.isDelivered) {
          completedMap[order.id] = deliveryOrder;
        } else {
          activeMap[order.id] = deliveryOrder;
        }
      }

      // Also merge any delivery bills from _recentBills
      for (final bill in _recentBills) {
        final isDelivery = (bill.orderType?.toLowerCase() == 'delivery') ||
            (bill.deliveryAddress != null && bill.deliveryAddress!.trim().isNotEmpty);
        if (isDelivery && !bill.isCancelled) {
          final key = bill.orderId.isNotEmpty ? bill.orderId : bill.id;
          if (!activeMap.containsKey(key) && !completedMap.containsKey(key)) {
            final deliveryOrder = DeliveryOrder.fromBill(bill);
            if (deliveryOrder.isDelivered) {
              completedMap[key] = deliveryOrder;
            } else {
              activeMap[key] = deliveryOrder;
            }
          }
        }
      }

      _activeDeliveryOrders = activeMap.values.toList();
      _activeDeliveryOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      _completedDeliveryOrders = completedMap.values.toList();
      _completedDeliveryOrders.sort((a, b) => (b.completedAt ?? b.createdAt).compareTo(a.completedAt ?? a.createdAt));

      notifyListeners();
    } catch (e) {
      // Fallback: build from _activeOrders and _recentBills
      final Map<String, DeliveryOrder> activeMap = {};
      final Map<String, DeliveryOrder> completedMap = {};

      for (final o in _activeOrders) {
        if (o.orderType == OrderType.delivery && o.status != 'CANCELLED') {
          final bill = _recentBills.cast<Bill?>().firstWhere(
            (b) => b?.orderId == o.id,
            orElse: () => null,
          );
          final deliveryOrder = DeliveryOrder.fromOrder(o, bill: bill);
          if (deliveryOrder.isDelivered) {
            completedMap[o.id] = deliveryOrder;
          } else {
            activeMap[o.id] = deliveryOrder;
          }
        }
      }

      for (final bill in _recentBills) {
        final isDelivery = (bill.orderType?.toLowerCase() == 'delivery') ||
            (bill.deliveryAddress != null && bill.deliveryAddress!.trim().isNotEmpty);
        if (isDelivery && !bill.isCancelled) {
          final key = bill.orderId.isNotEmpty ? bill.orderId : bill.id;
          if (!activeMap.containsKey(key) && !completedMap.containsKey(key)) {
            final deliveryOrder = DeliveryOrder.fromBill(bill);
            if (deliveryOrder.isDelivered) {
              completedMap[key] = deliveryOrder;
            } else {
              activeMap[key] = deliveryOrder;
            }
          }
        }
      }

      _activeDeliveryOrders = activeMap.values.toList();
      _activeDeliveryOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      _completedDeliveryOrders = completedMap.values.toList();
      _completedDeliveryOrders.sort((a, b) => (b.completedAt ?? b.createdAt).compareTo(a.completedAt ?? a.createdAt));

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
            // Generate bill if missing
            final numResp = await _supabase.rpc('generate_bill_number');
            final bNum = numResp as String? ?? 'BILL-${DateTime.now().millisecondsSinceEpoch}';
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
          await recordPayment(billId: bill.id, payments: payments);
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

      // 3. Refresh state across all screens
      await Future.wait([
        loadDeliveryOrders(),
        loadRecentBills(),
        loadActiveOrders(),
      ]);

      return true;
    } catch (e) {
      _errorMessage = 'Failed to complete delivery: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --------------------------------------------------------------------------
  // Navigation & Filtering
  // --------------------------------------------------------------------------
  void selectShop(Shop shop) {
    _selectedShop = shop;
    _selectedCategory = 'ALL';
    notifyListeners();
  }

  void selectCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _productSearchQuery = query;
    notifyListeners();
  }

  void setOrderType(OrderType type) {
    if (_orderType == type) return;
    _orderType = type;
    if (_orderType == OrderType.parcel && _parcelCharge == 0.0) {
      _parcelCharge = 10.0;
    }
    if (_orderType != OrderType.dineIn) {
      _selectedTable = null;
      // Cart items and active order ID are preserved so switching from Dine-In to Parcel/Takeaway does not clear the cart!
    } else {
      if (_selectedTable == null && _tables.isNotEmpty) {
        _selectedTable = _tables.firstWhere(
          (t) => t.isAvailable,
          orElse: () => _tables.first,
        );
      }
    }
    notifyListeners();
  }

  // --------------------------------------------------------------------------
  // Table Selection & Dine-In Management
  // --------------------------------------------------------------------------
  Future<void> selectTable(DiningTable? table) async {
    _orderType = OrderType.dineIn;

    if (table == null) {
      _selectedTable = null;
      notifyListeners();
      return;
    }

    // If clicking the same table that is already loaded and active, nothing to do
    if (_selectedTable?.id == table.id &&
        _currentActiveOrderId != null &&
        table.activeOrderId == _currentActiveOrderId) {
      return;
    }

    // If clicked table is occupied and has an active order, and our current cart is empty,
    // load that table's existing active order into cart.
    if ((table.isOccupied || table.isMerged) && table.activeOrderId != null && _cart.isEmpty) {
      _selectedTable = table;
      await reopenOrderById(table.activeOrderId!);
      _selectedTable = table;
    } else {
      // Assign this table to current order and KEEP the cart intact!
      _selectedTable = table;
      notifyListeners();
    }
  }

  Future<void> reopenOrderById(String orderId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final response = await _supabase
          .from('orders')
          .select('*, order_items(*)')
          .eq('id', orderId)
          .single();

      final order = OrderModel.fromJson(response);
      _currentActiveOrderId = order.id;
      _currentActiveOrderNumber = order.orderNumber;
      _currentActiveSessionId = order.tableSessionId;
      _orderType = order.orderType;
      _parcelCharge = order.parcelCharge;

      customerNameController.text = order.customerName ?? '';
      customerPhoneController.text = order.customerPhone ?? '';
      deliveryAddressController.text = order.deliveryAddress ?? '';
      deliveryNotesController.text = order.orderType == OrderType.parcel
          ? OrderModel.parseParcelNotes(order.deliveryNotes).cleanNotes
          : (order.deliveryNotes ?? '');

      _cart.clear();
      for (final item in order.items) {
        _cart.add(item);
      }
      _discount = order.discount;
      _tax = order.tax;

      // Find matching table if dine in
      if (order.tableSessionId != null && order.orderType == OrderType.dineIn) {
        final table = _tables.firstWhere(
          (t) => t.activeSessionId == order.tableSessionId || t.activeOrderId == order.id,
          orElse: () => _selectedTable ?? (_tables.isNotEmpty ? _tables.first : null)!,
        );
        _selectedTable = table;
      } else {
        _selectedTable = null;
      }
    } catch (e) {
      _errorMessage = 'Could not reopen order: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --------------------------------------------------------------------------
  // Multi-Shop Cart Operations
  // --------------------------------------------------------------------------
  void addToCart(Product product, {String? notes}) {
    final existingIndex = _cart.indexWhere(
      (item) => item.productId == product.id && item.notes == notes,
    );

    if (existingIndex >= 0) {
      _cart[existingIndex].quantity += 1;
      _cart[existingIndex].subtotal = _cart[existingIndex].quantity * _cart[existingIndex].unitPrice;
    } else {
      final shop = _shops.firstWhere(
        (s) => s.id == product.shopId,
        orElse: () => Shop(
          id: product.shopId,
          name: 'Shop',
          code: 'SH',
          status: 'ACTIVE',
          displayOrder: 1,
          createdAt: DateTime.now(),
        ),
      );

      _cart.add(OrderItem(
        shopId: product.shopId,
        shopName: shop.name,
        productId: product.id,
        productName: product.name,
        quantity: 1,
        unitPrice: product.price,
        subtotal: product.price,
        notes: notes,
      ));
    }
    notifyListeners();
  }

  bool canDecreaseQuantity(int index) {
    if (index < 0 || index >= _cart.length) return false;
    final item = _cart[index];
    return item.quantity > item.minQuantity;
  }

  bool canRemoveItem(int index) {
    if (index < 0 || index >= _cart.length) return false;
    return _cart[index].minQuantity == 0;
  }

  void updateItemQuantity(int index, int delta) {
    if (index < 0 || index >= _cart.length) return;
    final item = _cart[index];

    // Enforce immutability: Cannot decrease below locked baseline
    if (delta < 0 && item.quantity <= item.minQuantity) {
      return;
    }

    final newQty = item.quantity + delta;

    if (newQty <= 0) {
      if (item.minQuantity > 0) return; // Cannot delete locked item
      _cart.removeAt(index);
    } else {
      item.quantity = newQty;
      item.subtotal = newQty * item.unitPrice;
    }
    notifyListeners();
  }

  void updateItemNotes(int index, String notes) {
    if (index < 0 || index >= _cart.length) return;
    _cart[index].notes = notes.trim().isEmpty ? null : notes.trim();
    notifyListeners();
  }

  void setDiscount(double value) {
    _discount = value.clamp(0.0, subtotal);
    notifyListeners();
  }

  void setTax(double value) {
    _tax = value.clamp(0.0, double.infinity);
    notifyListeners();
  }

  void _clearCartInternal() {
    _cart.clear();
    _discount = 0.0;
    _tax = 0.0;
    _parcelCharge = 0.0;
    customerNameController.clear();
    customerPhoneController.clear();
    deliveryAddressController.clear();
    deliveryNotesController.clear();
  }

  void clearCustomerDetails() {
    customerNameController.clear();
    customerPhoneController.clear();
    notifyListeners();
  }

  void clearCart() {
    _clearCartInternal();
    _currentActiveOrderId = null;
    _currentActiveOrderNumber = null;
    _selectedTable = null;
    notifyListeners();
  }

  // --------------------------------------------------------------------------
  // Save / Keep Active Order
  // --------------------------------------------------------------------------
  Future<bool> saveOrder({bool resetCart = true}) async {
    if (_cart.isEmpty) {
      _errorMessage = 'Cannot save an empty order.';
      notifyListeners();
      return false;
    }

    if (_orderType == OrderType.dineIn && _selectedTable == null) {
      _errorMessage = 'Please select a table for Dine-In order.';
      notifyListeners();
      return false;
    }

    final phone = customerPhoneController.text.trim();
    if (phone.isNotEmpty && !RegExp(r'^\d{10}$').hasMatch(phone)) {
      _errorMessage = 'Customer Phone must be exactly 10 digits.';
      notifyListeners();
      return false;
    }

    if (_orderType == OrderType.delivery) {
      if (customerNameController.text.trim().isEmpty) {
        _errorMessage = 'Customer Name is required for Delivery orders.';
        notifyListeners();
        return false;
      }
      if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
        _errorMessage = 'Customer Phone must be exactly 10 digits for Delivery orders.';
        notifyListeners();
        return false;
      }
      if (deliveryAddressController.text.trim().isEmpty) {
        _errorMessage = 'Delivery Address / Location is required for Delivery orders.';
        notifyListeners();
        return false;
      }
    }

    try {
      _isLoading = true;
      notifyListeners();

      String orderId = '';
      String orderNumber = '';

      final effectiveNotes = _orderType == OrderType.parcel
          ? OrderModel.formatParcelNotes(_parcelCharge, deliveryNotesController.text)
          : (deliveryNotesController.text.trim().isEmpty ? null : deliveryNotesController.text.trim());

      bool remoteSuccess = false;
      if (OfflineSyncService().isOnline) {
        try {
          if (_currentActiveOrderId != null) {
            // Update existing order
            orderId = _currentActiveOrderId!;
            orderNumber = _currentActiveOrderNumber!;

            await _supabase.from('orders').update({
              'subtotal': subtotal,
              'discount': _discount,
              'tax': _tax,
              'total_amount': totalAmount,
              'customer_name': customerNameController.text.trim().isEmpty ? null : customerNameController.text.trim(),
              'customer_phone': customerPhoneController.text.trim().isEmpty ? null : customerPhoneController.text.trim(),
              'delivery_address': deliveryAddressController.text.trim().isEmpty ? null : deliveryAddressController.text.trim(),
              'delivery_notes': effectiveNotes,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            }).eq('id', orderId).timeout(const Duration(seconds: 3));

            // Replace order items
            await _supabase.from('order_items').delete().eq('order_id', orderId).timeout(const Duration(seconds: 3));
          } else {
            // Create new order
            if (_orderType == OrderType.dineIn) {
              // Atomic procedure to create session and open order
              final rpcResp = await _supabase.rpc('create_dine_in_session', params: {
                'p_table_id': _selectedTable!.id,
                'p_guest_count': _selectedTable!.capacity,
              }).timeout(const Duration(seconds: 3));

              orderId = rpcResp['order_id'] as String;
              orderNumber = rpcResp['order_number'] as String;
              _currentActiveSessionId = rpcResp['session_id'] as String;

              // Update customer details on newly created dine-in order if provided
              if (customerNameController.text.trim().isNotEmpty ||
                  customerPhoneController.text.trim().isNotEmpty) {
                try {
                  await _supabase.from('orders').update({
                    'customer_name': customerNameController.text.trim().isEmpty
                        ? null
                        : customerNameController.text.trim(),
                    'customer_phone': customerPhoneController.text.trim().isEmpty
                        ? null
                        : customerPhoneController.text.trim(),
                  }).eq('id', orderId).timeout(const Duration(seconds: 2));
                } catch (_) {}
              }
            } else {
              // Walkin, Parcel, or Delivery
              final numResp = await _supabase.rpc('generate_order_number').timeout(const Duration(seconds: 3));
              orderNumber = numResp as String;

              final orderInsert = await _supabase.from('orders').insert({
                'order_number': orderNumber,
                'order_type': _orderType.dbValue,
                'status': 'OPEN',
                'customer_name': customerNameController.text.trim().isEmpty ? null : customerNameController.text.trim(),
                'customer_phone': customerPhoneController.text.trim().isEmpty ? null : customerPhoneController.text.trim(),
                'delivery_address': deliveryAddressController.text.trim().isEmpty ? null : deliveryAddressController.text.trim(),
                'delivery_notes': effectiveNotes,
                'subtotal': subtotal,
                'discount': _discount,
                'tax': _tax,
                'total_amount': totalAmount,
              }).select('id').single().timeout(const Duration(seconds: 3));

              orderId = orderInsert['id'] as String;
            }

            _currentActiveOrderId = orderId;
            _currentActiveOrderNumber = orderNumber;
          }

          // Customer Data Collection: Record/Upsert to customers table
          try {
            await _supabase.from('customers').upsert({
              'phone': customerPhoneController.text.trim(),
              'name': customerNameController.text.trim(),
              'last_order_at': DateTime.now().toUtc().toIso8601String(),
            }, onConflict: 'phone').timeout(const Duration(seconds: 2));
          } catch (_) {}

          // Insert Order Items
          final itemsToInsert = _cart.map((item) => {
            'order_id': orderId,
            'shop_id': item.shopId,
            'product_id': item.productId,
            'product_name': item.productName,
            'quantity': item.quantity,
            'unit_price': item.unitPrice,
            'subtotal': item.subtotal,
            'notes': item.notes,
          }).toList();

          await _supabase.from('order_items').insert(itemsToInsert).timeout(const Duration(seconds: 3));

          // Persist latest subtotal, tax, discount, total_amount, and customer details to orders table
          await _supabase.from('orders').update({
            'subtotal': subtotal,
            'discount': _discount,
            'tax': _tax,
            'total_amount': totalAmount,
            'customer_name': customerNameController.text.trim().isEmpty ? null : customerNameController.text.trim(),
            'customer_phone': customerPhoneController.text.trim().isEmpty ? null : customerPhoneController.text.trim(),
            'delivery_address': deliveryAddressController.text.trim().isEmpty ? null : deliveryAddressController.text.trim(),
            'delivery_notes': effectiveNotes,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', orderId).timeout(const Duration(seconds: 2));

          // If a bill already exists for this order, ensure bills table is kept strictly synchronized with totalAmount
          try {
            await _supabase.from('bills').update({
              'subtotal': subtotal,
              'discount': _discount,
              'tax': _tax,
              'total_amount': totalAmount,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            }).eq('order_id', orderId).timeout(const Duration(seconds: 2));
          } catch (_) {}

          // If delivery order, automatically generate bill so Payment Counter and Delivery Boy see it immediately
          if (_orderType == OrderType.delivery) {
            try {
              await _supabase.rpc('print_bill_transaction', params: {
                'p_order_id': orderId,
                'p_discount': _discount,
                'p_tax': _tax,
              }).timeout(const Duration(seconds: 3));
              await _supabase.from('bills').update({'total_amount': totalAmount}).eq('order_id', orderId);
            } catch (_) {
              try {
                final exists = await _supabase.from('bills').select('id').eq('order_id', orderId).maybeSingle();
                if (exists == null) {
                  final bNum = await OfflineSyncService().generateOfflineBillNumber();
                  await _supabase.from('bills').insert({
                    'bill_number': bNum,
                    'order_id': orderId,
                    'subtotal': subtotal,
                    'discount': _discount,
                    'tax': _tax,
                    'total_amount': totalAmount,
                    'paid_amount': 0.0,
                    'current_version': 1,
                    'status': 'PRINTED',
                    'payment_method': 'PENDING',
                    'payment_status': 'UNPAID',
                  });
                }
              } catch (_) {}
            }
          }

          remoteSuccess = true;
        } catch (netErr) {
          OfflineSyncService().markOffline();
          debugPrint('[PosProvider] Remote Supabase save failed/timed out: $netErr. Falling back to offline queue.');
        }
      }

      if (!remoteSuccess) {
        // Generate offline order number & queue locally with standard UUID
        orderNumber = await OfflineSyncService().generateOfflineOrderNumber();
        orderId = UuidUtil.newUuid();

        _currentActiveOrderId = orderId;
        _currentActiveOrderNumber = orderNumber;

        final cutoff = computeBusinessDayCutoff();
        final bizDateStr = '${cutoff.year}-${cutoff.month.toString().padLeft(2, '0')}-${cutoff.day.toString().padLeft(2, '0')}';
        final nowIso = DateTime.now().toUtc().toIso8601String();

        final orderData = {
          'id': orderId,
          'order_number': orderNumber,
          'order_type': _orderType.dbValue,
          'status': 'OPEN',
          'business_date': bizDateStr,
          'customer_name': customerNameController.text.trim().isEmpty ? null : customerNameController.text.trim(),
          'customer_phone': customerPhoneController.text.trim().isEmpty ? null : customerPhoneController.text.trim(),
          'delivery_address': deliveryAddressController.text.trim().isEmpty ? null : deliveryAddressController.text.trim(),
          'delivery_notes': effectiveNotes,
          'subtotal': subtotal,
          'discount': _discount,
          'tax': _tax,
          'total_amount': totalAmount,
          'created_at': nowIso,
          'updated_at': nowIso,
        };

        final itemsToInsert = _cart.map((item) => {
          'id': UuidUtil.newUuid(),
          'order_id': orderId,
          'shop_id': item.shopId,
          'product_id': item.productId,
          'product_name': item.productName,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
          'subtotal': item.subtotal,
          'notes': item.notes,
        }).toList();

        await OfflineSyncService().enqueue('SAVE_ORDER', {
          'order': orderData,
          'items': itemsToInsert,
        });

        // Add to in-memory active orders immediately
        final localOrder = OrderModel(
          id: orderId,
          orderNumber: orderNumber,
          orderType: _orderType,
          status: 'OPEN',
          customerName: customerNameController.text.trim().isEmpty ? null : customerNameController.text.trim(),
          customerPhone: customerPhoneController.text.trim().isEmpty ? null : customerPhoneController.text.trim(),
          deliveryAddress: deliveryAddressController.text.trim().isEmpty ? null : deliveryAddressController.text.trim(),
          deliveryNotes: effectiveNotes,
          subtotal: subtotal,
          discount: _discount,
          tax: _tax,
          totalAmount: totalAmount,
          createdAt: DateTime.now(),
          items: List.from(_cart),
          tableDisplay: _orderType == OrderType.dineIn ? _selectedTable?.tableName : null,
        );
        _activeOrders.removeWhere((o) => o.id == orderId);
        _activeOrders.insert(0, localOrder);
        LocalStorageService().upsertOrder(localOrder);
      } else {
        // Also persist online saved order to local disk cache
        final savedOrder = OrderModel(
          id: orderId,
          orderNumber: orderNumber,
          orderType: _orderType,
          status: 'OPEN',
          customerName: customerNameController.text.trim().isEmpty ? null : customerNameController.text.trim(),
          customerPhone: customerPhoneController.text.trim().isEmpty ? null : customerPhoneController.text.trim(),
          deliveryAddress: deliveryAddressController.text.trim().isEmpty ? null : deliveryAddressController.text.trim(),
          deliveryNotes: effectiveNotes,
          subtotal: subtotal,
          discount: _discount,
          tax: _tax,
          totalAmount: totalAmount,
          createdAt: DateTime.now(),
          items: List.from(_cart),
          tableDisplay: _orderType == OrderType.dineIn ? _selectedTable?.tableName : null,
        );
        LocalStorageService().upsertOrder(savedOrder);
      }

      // Trigger data refreshes in background so saveOrder returns immediately
      loadTables();
      loadActiveOrders();
      loadRecentBills();
      loadDeliveryOrders();

      // Reset cart and active order so the POS terminal is fresh and ready for the next order
      if (resetCart) {
        _clearCartInternal();
        _currentActiveOrderId = null;
        _currentActiveOrderNumber = null;
        _currentActiveSessionId = null;
        _selectedTable = null;
      }

      return true;
    } catch (e) {
      _errorMessage = 'Failed to save order: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --------------------------------------------------------------------------
  // Print Bill (First Print: Version 1 / Unpaid; Edit: Version 2, 3...)
  // --------------------------------------------------------------------------
  Future<Bill?> printBill() async {
    if (_isProcessingBilling) return null;
    if (_cart.isEmpty) {
      _errorMessage = 'Cannot print bill with empty cart.';
      notifyListeners();
      return null;
    }

    if (_orderType == OrderType.dineIn && _selectedTable == null) {
      _errorMessage = 'Please select a table for Dine-In order.';
      notifyListeners();
      return null;
    }

    final phone = customerPhoneController.text.trim();
    if (phone.isNotEmpty && !RegExp(r'^\d{10}$').hasMatch(phone)) {
      _errorMessage = 'Customer Phone must be exactly 10 digits.';
      notifyListeners();
      return null;
    }

    _isProcessingBilling = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Snapshot cart state before saving or billing
      final cartSnapshot = List<OrderItem>.from(_cart);
      final double snapshotSubtotal = subtotal;
      final double snapshotTotal = totalAmount;
      final double snapshotDiscount = _discount;
      final double snapshotTax = _tax;
      final double snapshotParcelCharge = _parcelCharge;
      final DiningTable? snapshotTable = _selectedTable;
      final OrderType snapshotOrderType = _orderType;
      final String? custName = customerNameController.text.trim().isNotEmpty
          ? customerNameController.text.trim()
          : null;
      final String? custPhone = customerPhoneController.text.trim().isNotEmpty
          ? customerPhoneController.text.trim()
          : null;
      final String? delivAddress = deliveryAddressController.text.trim().isNotEmpty
          ? deliveryAddressController.text.trim()
          : null;

      // 1. Ensure order is saved in database first WITHOUT resetting cart
      if (_currentActiveOrderId == null) {
        final saved = await saveOrder(resetCart: false);
        if (!saved || _currentActiveOrderId == null) {
          throw Exception('Failed to initialize order before billing.');
        }
      } else {
        await saveOrder(resetCart: false);
      }

      String billId = '';
      String billNumber = '';
      int versionNumber = 1;
      double currentSubtotal = snapshotSubtotal;
      double currentTotal = snapshotTotal;
      String currentStatus = 'PRINTED';
      double paidAmt = 0.0;
      final effectiveNotes = snapshotOrderType == OrderType.parcel
          ? OrderModel.formatParcelNotes(snapshotParcelCharge, deliveryNotesController.text)
          : (deliveryNotesController.text.trim().isEmpty ? null : deliveryNotesController.text.trim());

      bool isOfflineBill = !OfflineSyncService().isOnline || _currentActiveOrderId!.startsWith('OFFLINE_');

      // Check if we are updating an existing printed bill (Version 2+)
      if (_activeBillForEdit != null) {
        billId = _activeBillForEdit!.id;
        billNumber = _activeBillForEdit!.billNumber;
        versionNumber = _activeBillForEdit!.currentVersion + 1;
        paidAmt = _activeBillForEdit!.paidAmount;

        if (!isOfflineBill) {
          try {
            final resp = await _supabase.rpc('update_bill_version_transaction', params: {
              'p_bill_id': billId,
              'p_discount': snapshotDiscount,
              'p_tax': snapshotTax,
              'p_print_reason': 'Items updated',
            }).timeout(const Duration(seconds: 3));
            if (resp != null) {
              billId = resp['bill_id'] as String? ?? billId;
              billNumber = resp['bill_number'] as String? ?? billNumber;
              versionNumber = (resp['version_number'] as num?)?.toInt() ?? versionNumber;
              currentTotal = (resp['total_amount'] as num?)?.toDouble() ?? currentTotal;
              currentStatus = resp['status'] as String? ?? 'PRINTED';
              paidAmt = (resp['paid_amount'] as num?)?.toDouble() ?? paidAmt;
            }
          } catch (_) {
            isOfflineBill = true;
          }
        }
      } else {
        // Initial Print (Version 1)
        if (!isOfflineBill) {
          try {
            final response = await _supabase.rpc('print_bill_transaction', params: {
              'p_order_id': _currentActiveOrderId,
              'p_discount': snapshotDiscount,
              'p_tax': snapshotTax,
            }).timeout(const Duration(seconds: 3));

            billId = response['bill_id'] as String;
            billNumber = response['bill_number'] as String;
            if (billNumber.length > 3 || billNumber.contains('-')) {
              try {
                final cutoff = PosProvider.computeBusinessDayCutoff();
                final bizDateStr = '${cutoff.year}-${cutoff.month.toString().padLeft(2, '0')}-${cutoff.day.toString().padLeft(2, '0')}';
                final billsCountResp = await _supabase
                    .from('bills')
                    .select('id')
                    .gte('created_at', cutoff.toUtc().toIso8601String());
                final count = (billsCountResp as List).length;
                final cleanNum = count.toString().padLeft(3, '0');
                billNumber = cleanNum;
                await _supabase.from('bills').update({
                  'bill_number': cleanNum,
                  'business_date': bizDateStr,
                }).eq('id', billId);
              } catch (_) {
                billNumber = await OfflineSyncService().generateOfflineBillNumber();
                try {
                  await _supabase.from('bills').update({'bill_number': billNumber}).eq('id', billId);
                } catch (_) {}
              }
            }
            versionNumber = (response['version_number'] as num?)?.toInt() ?? 1;
            currentTotal = (response['total_amount'] as num?)?.toDouble() ?? currentTotal;
            currentStatus = response['status'] as String? ?? 'PRINTED';

            if ((snapshotTotal - currentTotal).abs() > 0.001 || snapshotOrderType == OrderType.parcel || snapshotOrderType == OrderType.delivery) {
              currentTotal = snapshotTotal;
              try {
                await _supabase.from('bills').update({'total_amount': currentTotal}).eq('id', billId);
                await _supabase.from('bill_versions').update({'total_amount': currentTotal}).eq('bill_id', billId).eq('version_number', versionNumber);
              } catch (_) {}
            }
          } catch (_) {
            isOfflineBill = true;
          }
        }

        if (isOfflineBill) {
          billId = UuidUtil.newUuid();
          billNumber = await OfflineSyncService().generateOfflineBillNumber();
          versionNumber = 1;
          currentTotal = snapshotTotal;
          currentStatus = 'PRINTED';
        }
      }

      final cutoff = PosProvider.computeBusinessDayCutoff();
      final bizDateStr = '${cutoff.year}-${cutoff.month.toString().padLeft(2, '0')}-${cutoff.day.toString().padLeft(2, '0')}';
      final nowTime = DateTime.now();

      final billObj = Bill(
        id: billId,
        billNumber: billNumber,
        currentVersion: versionNumber,
        orderId: _currentActiveOrderId!,
        orderNumber: _currentActiveOrderNumber,
        orderType: snapshotOrderType.displayName,
        subtotal: currentSubtotal,
        discount: snapshotDiscount,
        tax: snapshotTax,
        parcelCharge: snapshotParcelCharge,
        totalAmount: currentTotal,
        paidAmount: paidAmt,
        status: currentStatus,
        paymentMethod: 'PENDING',
        paymentStatus: paidAmt >= currentTotal ? 'PAID' : 'UNPAID',
        tableDisplay: snapshotTable?.tableName,
        customerName: custName,
        customerPhone: custPhone,
        deliveryAddress: delivAddress,
        deliveryNotes: effectiveNotes,
        createdAt: nowTime,
        printedAt: nowTime,
        items: cartSnapshot
            .map((i) => BillItem(
                  id: UuidUtil.newUuid(),
                  billId: billId,
                  shopId: i.shopId,
                  shopName: i.shopName,
                  productId: i.productId,
                  productName: i.productName,
                  quantity: i.quantity,
                  unitPrice: i.unitPrice,
                  subtotal: i.subtotal,
                ))
            .toList(),
      );

      // If offline, enqueue to sync service so it pushes seamlessly once reconnected
      if (isOfflineBill) {
        await OfflineSyncService().enqueue('SAVE_BILL', {
          'bill': {
            'id': billObj.id,
            'bill_number': billObj.billNumber,
            'business_date': bizDateStr,
            'order_id': billObj.orderId,
            'subtotal': billObj.subtotal,
            'discount': billObj.discount,
            'tax': billObj.tax,
            'total_amount': billObj.totalAmount,
            'paid_amount': billObj.paidAmount,
            'current_version': billObj.currentVersion,
            'status': billObj.status,
            'payment_status': billObj.paymentStatus,
            'payment_method': billObj.paymentMethod,
            'created_at': billObj.createdAt.toUtc().toIso8601String(),
            'printed_at': billObj.printedAt?.toUtc().toIso8601String(),
          },
          'bill_items': billObj.items.map((i) => {
            'id': i.id,
            'bill_id': billObj.id,
            'shop_id': i.shopId,
            'product_id': i.productId,
            'product_name': i.productName,
            'quantity': i.quantity,
            'unit_price': i.unitPrice,
            'subtotal': i.subtotal,
          }).toList(),
        });
      }

      // Persist to local storage disk cache immediately
      LocalStorageService().upsertBill(billObj);

      // Print thermal bill immediately or save directly to PDF storage
      await printBillReceipt(billObj);

      // Update local in-memory collections so the bill shows immediately in Payments
      _recentBills.removeWhere((b) => b.id == billObj.id);
      _recentBills.insert(0, billObj);
      if (_currentActiveOrderId != null) {
        _activeOrders.removeWhere((o) => o.id == _currentActiveOrderId);
        LocalStorageService().deleteOrder(_currentActiveOrderId!);
      }

      // Reset editing and active order states ONLY AFTER billing is completely done
      _activeBillForEdit = null;
      _clearCartInternal();
      _currentActiveOrderId = null;
      _currentActiveOrderNumber = null;
      _currentActiveSessionId = null;
      _selectedTable = null;

      // Refresh background data
      await Future.wait([
        loadTables(),
        loadActiveOrders(),
        loadRecentBills(),
      ]);

      return billObj;
    } catch (e) {
      _errorMessage = 'Print Bill failed: $e';
      return null;
    } finally {
      _isProcessingBilling = false;
      notifyListeners();
    }
  }

  /// Generates and prints/saves bill directly for an existing active order (from Active Orders screen)
  /// Moves the order to Payments and does not affect the active POS draft cart!
  Future<({Bill? bill, PrintResult result})> printBillForOrder(OrderModel order) async {
    try {
      _isLoading = true;
      notifyListeners();

      // If order passed has empty items, refresh from database first to be certain
      var effectiveOrder = order;
      if (effectiveOrder.items.isEmpty) {
        try {
          final fresh = await _supabase
              .from('orders')
              .select('*, order_items(*)')
              .eq('id', order.id)
              .single();
          final freshOrder = OrderModel.fromJson(fresh);
          if (freshOrder.items.isNotEmpty) {
            effectiveOrder = freshOrder;
          }
        } catch (_) {}
      }

      final double ordSubtotal = effectiveOrder.subtotal > 0
          ? effectiveOrder.subtotal
          : effectiveOrder.items.fold(0.0, (sum, i) => sum + i.subtotal);
      final double ordTotal = effectiveOrder.totalAmount > 0 ? effectiveOrder.totalAmount : ordSubtotal;

      String billId = '';
      String billNumber = '';
      int versionNumber = 1;
      double currentTotal = ordTotal;
      String currentStatus = 'PRINTED';
      double paidAmt = 0.0;

      bool isOfflineBill = !OfflineSyncService().isOnline || effectiveOrder.id.startsWith('OFFLINE_');

      // Check if bill already exists for this order
      Map<String, dynamic>? existingBill;
      if (!isOfflineBill) {
        try {
          existingBill = await _supabase.from('bills').select('*').eq('order_id', effectiveOrder.id).maybeSingle().timeout(const Duration(seconds: 2));
        } catch (_) {
          isOfflineBill = true;
        }
      }

      if (existingBill != null) {
        billId = existingBill['id'] as String;
        billNumber = existingBill['bill_number'] as String;
        versionNumber = (existingBill['current_version'] as num?)?.toInt() ?? 1;
        currentTotal = (existingBill['total_amount'] as num).toDouble();
        paidAmt = (existingBill['paid_amount'] as num?)?.toDouble() ?? 0.0;

        // Keep bill synchronized with latest order totals
        try {
          await _supabase.from('bills').update({
            'subtotal': ordSubtotal,
            'discount': effectiveOrder.discount,
            'tax': effectiveOrder.tax,
            'total_amount': ordTotal,
            'status': 'PRINTED',
            'payment_status': paidAmt >= ordTotal ? 'PAID' : 'UNPAID',
            'payment_method': paidAmt >= ordTotal ? (existingBill['payment_method'] ?? 'CASH') : 'PENDING',
            'printed_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', billId).timeout(const Duration(seconds: 2));
        } catch (_) {}
      } else {
        if (!isOfflineBill) {
          try {
            final response = await _supabase.rpc('print_bill_transaction', params: {
              'p_order_id': effectiveOrder.id,
              'p_discount': effectiveOrder.discount,
              'p_tax': effectiveOrder.tax,
            }).timeout(const Duration(seconds: 3));
            billId = response['bill_id'] as String;
            billNumber = response['bill_number'] as String;
            versionNumber = (response['version_number'] as num?)?.toInt() ?? 1;
            currentTotal = (response['total_amount'] as num?)?.toDouble() ?? ordTotal;
            currentStatus = response['status'] as String? ?? 'PRINTED';
            paidAmt = (response['paid_amount'] as num?)?.toDouble() ?? 0.0;
          } catch (_) {
            isOfflineBill = true;
          }
        }

        if (isOfflineBill) {
          billId = UuidUtil.newUuid();
          billNumber = await OfflineSyncService().generateOfflineBillNumber();
          versionNumber = 1;
          currentTotal = ordTotal;
          currentStatus = 'PRINTED';
        }
      }

      final cutoff = PosProvider.computeBusinessDayCutoff();
      final bizDateStr = '${cutoff.year}-${cutoff.month.toString().padLeft(2, '0')}-${cutoff.day.toString().padLeft(2, '0')}';
      final nowTime = DateTime.now();

      // Construct Bill object
      final billObj = Bill(
        id: billId,
        billNumber: billNumber,
        currentVersion: versionNumber,
        orderId: effectiveOrder.id,
        orderNumber: effectiveOrder.orderNumber,
        orderType: effectiveOrder.orderType.displayName,
        subtotal: ordSubtotal,
        discount: effectiveOrder.discount,
        tax: effectiveOrder.tax,
        parcelCharge: effectiveOrder.parcelCharge,
        totalAmount: currentTotal,
        paidAmount: paidAmt,
        status: currentStatus,
        paymentMethod: 'PENDING',
        paymentStatus: paidAmt >= currentTotal ? 'PAID' : 'UNPAID',
        tableDisplay: effectiveOrder.tableDisplay ?? getTableForOrder(effectiveOrder),
        customerName: effectiveOrder.customerName,
        customerPhone: effectiveOrder.customerPhone,
        deliveryAddress: effectiveOrder.deliveryAddress,
        deliveryNotes: effectiveOrder.deliveryNotes,
        createdAt: nowTime,
        printedAt: nowTime,
        items: effectiveOrder.items.map((i) => BillItem(
          id: UuidUtil.newUuid(),
          billId: billId,
          shopId: i.shopId,
          shopName: i.shopName,
          productId: i.productId,
          productName: i.productName,
          quantity: i.quantity,
          unitPrice: i.unitPrice,
          subtotal: i.subtotal,
        )).toList(),
      );

      if (isOfflineBill) {
        await OfflineSyncService().enqueue('SAVE_BILL', {
          'bill': {
            'id': billObj.id,
            'bill_number': billObj.billNumber,
            'business_date': bizDateStr,
            'order_id': billObj.orderId,
            'subtotal': billObj.subtotal,
            'discount': billObj.discount,
            'tax': billObj.tax,
            'total_amount': billObj.totalAmount,
            'paid_amount': billObj.paidAmount,
            'current_version': billObj.currentVersion,
            'status': billObj.status,
            'payment_status': billObj.paymentStatus,
            'payment_method': billObj.paymentMethod,
            'created_at': billObj.createdAt.toUtc().toIso8601String(),
            'printed_at': billObj.printedAt?.toUtc().toIso8601String(),
          },
          'bill_items': billObj.items.map((i) => {
            'id': i.id,
            'bill_id': billObj.id,
            'shop_id': i.shopId,
            'product_id': i.productId,
            'product_name': i.productName,
            'quantity': i.quantity,
            'unit_price': i.unitPrice,
            'subtotal': i.subtotal,
          }).toList(),
        });
      }

      // Persist to local disk cache immediately
      LocalStorageService().upsertBill(billObj);

      // Print to thermal printer if connected, or save PDF to local storage
      final printResult = await ReceiptPrinter.printBill(billObj);

      // Immediately move from active orders to payments in-memory
      _activeOrders.removeWhere((o) => o.id == effectiveOrder.id);
      LocalStorageService().deleteOrder(effectiveOrder.id);
      _recentBills.removeWhere((b) => b.id == billId);
      _recentBills.insert(0, billObj);
      notifyListeners();

      // Trigger background refreshes
      loadTables();
      loadActiveOrders();
      loadRecentBills();

      return (bill: billObj, result: printResult);
    } catch (e) {
      _errorMessage = 'Error printing bill: $e';
      return (
        bill: null,
        result: PrintResult(
          success: false,
          printedToThermal: false,
          message: 'Error printing bill: $e',
        ),
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --------------------------------------------------------------------------
  // Bill Reopening for Edit (Customer adds item -> Version 2, same Bill #)
  // --------------------------------------------------------------------------
  void reopenBillForEdit(Bill bill) {
    _activeBillForEdit = bill;
    _currentActiveOrderId = bill.orderId;
    _currentActiveOrderNumber = bill.orderNumber;

    if (bill.orderType != null) {
      if (bill.orderType!.toUpperCase().contains('PARCEL')) {
        _orderType = OrderType.parcel;
        _parcelCharge = bill.parcelCharge;
      } else if (bill.orderType!.toUpperCase().contains('WALK') ||
          bill.orderType!.toUpperCase().contains('TAKE')) {
        _orderType = OrderType.walkIn;
      } else if (bill.orderType!.toUpperCase().contains('DELIV')) {
        _orderType = OrderType.delivery;
      } else {
        _orderType = OrderType.dineIn;
      }
    }

    customerNameController.text = bill.customerName ?? '';
    customerPhoneController.text = bill.customerPhone ?? '';
    deliveryAddressController.text = bill.deliveryAddress ?? '';
    _discount = bill.discount;
    _tax = bill.tax;

    if (bill.tableDisplay != null && _tables.isNotEmpty) {
      final cleanTable = bill.tableDisplay!.split('+').first.trim().toLowerCase();
      _selectedTable = _tables.firstWhere(
        (t) =>
            t.tableName.toLowerCase() == cleanTable ||
            t.tableNumber.toString() == cleanTable,
        orElse: () => _tables.first,
      );
    }

    _cart.clear();
    for (final item in bill.items) {
      final shop = _shops.firstWhere(
        (s) => s.id == item.shopId,
        orElse: () => Shop(
          id: item.shopId,
          name: item.shopName ?? 'Shop',
          code: 'SH',
          status: 'ACTIVE',
          displayOrder: 1,
          createdAt: DateTime.now(),
        ),
      );

      _cart.add(OrderItem(
        shopId: item.shopId,
        shopName: shop.name,
        productId: item.productId,
        productName: item.productName,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        subtotal: item.subtotal,
        minQuantity: item.quantity, // Locked: cannot be decreased or deleted
      ));
    }

    notifyListeners();
  }

  void cancelBillEdit() {
    _activeBillForEdit = null;
    _clearCartInternal();
    _currentActiveOrderId = null;
    _currentActiveOrderNumber = null;
    _selectedTable = null;
    notifyListeners();
  }

  // --------------------------------------------------------------------------
  // Update Bill Parcel Charge
  // --------------------------------------------------------------------------
  Future<bool> updateBillParcelCharge(String billId, double newParcelCharge) async {
    try {
      Bill? b;
      try {
        b = _recentBills.firstWhere((item) => item.id == billId);
      } catch (_) {}

      double sub = b?.subtotal ?? 0.0;
      double disc = b?.discount ?? 0.0;
      double tx = b?.tax ?? 0.0;
      String? existingNotes = b?.deliveryNotes;
      String orderId = b?.orderId ?? '';

      if (b == null) {
        final bResp = await _supabase.from('bills').select('subtotal, discount, tax, order_id').eq('id', billId).maybeSingle();
        if (bResp != null) {
          sub = (bResp['subtotal'] as num?)?.toDouble() ?? 0.0;
          disc = (bResp['discount'] as num?)?.toDouble() ?? 0.0;
          tx = (bResp['tax'] as num?)?.toDouble() ?? 0.0;
          orderId = bResp['order_id'] as String? ?? '';
        }
      }

      final newTotal = (sub - disc + tx + newParcelCharge).clamp(0.0, double.infinity);
      final newNotes = OrderModel.formatParcelNotes(newParcelCharge, existingNotes ?? '');
      await _supabase.from('bills').update({'total_amount': newTotal}).eq('id', billId);
      if (orderId.isNotEmpty) {
        await _supabase.from('orders').update({
          'total_amount': newTotal,
          'delivery_notes': newNotes,
        }).eq('id', orderId);
      }
      await loadRecentBills();
      return true;
    } catch (_) {
      return false;
    }
  }

  // --------------------------------------------------------------------------
  // Record Payment at Counter (Cash, GPay, Split)
  // --------------------------------------------------------------------------
  Future<bool> recordPayment({
    required String billId,
    required List<Map<String, dynamic>> payments,
  }) async {
    if (payments.isEmpty) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {

    // Compute payment breakdown
    double splitCash = 0.0;
    double splitGPay = 0.0;
    for (final p in payments) {
      final m = (p['payment_method'] ?? p['method'] ?? 'CASH').toString().toUpperCase();
      final a = (p['amount'] as num?)?.toDouble() ?? 0.0;
      if (m == 'CASH') {
        splitCash += a;
      } else {
        splitGPay += a;
      }
    }

    final payMethod = (payments.length > 1 || (splitCash > 0 && splitGPay > 0))
        ? 'SPLIT'
        : (payments.first['method'] ?? payments.first['payment_method'] ?? 'CASH').toString().toUpperCase();

    final splitTag = payMethod == 'SPLIT'
        ? '[SPLIT:CASH=${splitCash.toStringAsFixed(2)},GPAY=${splitGPay.toStringAsFixed(2)}]'
        : null;

    // Cache exact payment breakdown locally so Reports screen and Receipt Dialog reflect it instantly
    localPaymentsCache[billId] = payments.map((p) => {
      'payment_method': (p['payment_method'] ?? p['method'] ?? 'CASH').toString().toUpperCase(),
      'amount': (p['amount'] as num?)?.toDouble() ?? 0.0,
      'status': 'COMPLETED',
    }).toList();

    double totalPaid = 0.0;
    for (final p in payments) {
      totalPaid += (p['amount'] as num?)?.toDouble() ?? 0.0;
    }

    // Immediately resolve local bill from in-memory or disk cache
    Bill? localBill;
    try {
      localBill = _recentBills.firstWhere((b) => b.id == billId);
    } catch (_) {
      try {
        localBill = LocalStorageService().getBills().firstWhere((b) => b.id == billId);
      } catch (_) {}
    }
    String? orderId = localBill?.orderId;

    final newPaymentRecords = payments.map((p) => PaymentRecord(
      id: UuidUtil.newUuid(),
      billId: billId,
      paymentMethod: (p['payment_method'] ?? p['method'] ?? 'CASH').toString().toUpperCase(),
      amount: (p['amount'] as num?)?.toDouble() ?? 0.0,
      status: 'COMPLETED',
      createdAt: DateTime.now(),
    )).toList();

    if (localBill != null) {
      final updatedNotes = (payMethod == 'SPLIT' && splitTag != null)
          ? (() {
              final curr = localBill!.deliveryNotes ?? '';
              final clean = curr.replaceAll(RegExp(r'\[SPLIT:[^\]]+\]', caseSensitive: false), '').trim();
              return clean.isEmpty ? splitTag : '$clean $splitTag';
            })()
          : localBill.deliveryNotes;

      final updatedBill = localBill.copyWith(
        paidAmount: totalPaid,
        status: 'PAID',
        paymentStatus: 'PAID',
        paymentMethod: payMethod,
        deliveryNotes: updatedNotes,
        payments: newPaymentRecords,
      );

      _recentBills.removeWhere((b) => b.id == billId);
      _recentBills.insert(0, updatedBill);
      LocalStorageService().upsertBill(updatedBill);
    }

    bool isOffline = !OfflineSyncService().isOnline || billId.startsWith('OFFLINE_');

    if (!isOffline) {
      try {
        final resp = await _supabase.rpc('record_bill_payment_transaction', params: {
          'p_bill_id': billId,
          'p_payments': payments,
        }).timeout(const Duration(seconds: 3));

        if (resp != null && resp['success'] != true) {
          throw Exception(resp['message'] ?? 'Payment recording failed.');
        }

        if (payMethod == 'SPLIT' && splitTag != null && orderId != null) {
          try {
            final ordResp = await _supabase.from('orders').select('delivery_notes').eq('id', orderId).maybeSingle().timeout(const Duration(seconds: 2));
            final currentNotes = ordResp?['delivery_notes'] as String? ?? '';
            final cleanNotes = currentNotes.replaceAll(RegExp(r'\[SPLIT:[^\]]+\]', caseSensitive: false), '').trim();
            final updatedNotes = cleanNotes.isEmpty ? splitTag : '$cleanNotes $splitTag';
            await _supabase.from('orders').update({
              'status': 'COMPLETED',
              'delivery_notes': updatedNotes,
            }).eq('id', orderId).timeout(const Duration(seconds: 2));
          } catch (_) {}
        }
      } catch (netErr) {
        OfflineSyncService().markOffline();
        isOffline = true;
      }
    }

    if (isOffline) {
      final paymentRows = payments.map((p) => {
        'id': UuidUtil.newUuid(),
        'bill_id': billId,
        'payment_method': (p['payment_method'] ?? p['method'] ?? 'CASH').toString().toUpperCase(),
        'amount': (p['amount'] as num?)?.toDouble() ?? 0.0,
        'status': 'COMPLETED',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      }).toList();

      await OfflineSyncService().enqueue('RECORD_PAYMENT', {
        'bill_id': billId,
        'payments': paymentRows,
        'bill_updates': {
          'paid_amount': totalPaid,
          'status': 'PAID',
          'payment_status': 'PAID',
          'payment_method': payMethod,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        'order_id': orderId,
        'order_notes': splitTag,
      });
    }

    if (orderId != null) {
      _activeOrders.removeWhere((o) => o.id == orderId);
      LocalStorageService().deleteOrder(orderId);
      if (_currentActiveOrderId == orderId) {
        _clearCartInternal();
        _currentActiveOrderId = null;
        _currentActiveOrderNumber = null;
        _currentActiveSessionId = null;
        _selectedTable = null;
      }
    }

    loadTables();
    loadActiveOrders();
    loadRecentBills();

    _paymentEventCount++;
    notifyListeners();

    return true;
    } catch (e) {
      _errorMessage = 'Payment recording failed: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --------------------------------------------------------------------------
  // Void & Refund Request / Approval Workflows
  // --------------------------------------------------------------------------
  Future<bool> requestVoidRefund({
    required String billId,
    required String requestType,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      _errorMessage = 'Please provide a reason for the request.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      try {
        await _supabase.rpc('request_void_or_refund', params: {
          'p_bill_id': billId,
          'p_request_type': requestType,
          'p_reason': reason.trim(),
        });
      } catch (_) {
        final newStatus = requestType == 'VOID' ? 'VOID_PENDING' : 'REFUND_PENDING';
        await _supabase.from('bills').update({
          'status': newStatus,
        }).eq('id', billId);

        await _supabase.from('void_refund_requests').insert({
          'bill_id': billId,
          'request_type': requestType,
          'reason': reason.trim(),
          'status': 'PENDING',
        });
      }

      await Future.wait([
        loadRecentBills(),
        loadPendingApprovals(),
      ]);

      return true;
    } catch (e) {
      _errorMessage = 'Request failed: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> approveVoidRefund({
    required String requestId,
    required bool approve,
    String? notes,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      try {
        await _supabase.rpc('approve_void_or_refund', params: {
          'p_request_id': requestId,
          'p_approve': approve,
          'p_notes': notes,
        });
      } catch (_) {
        final req = await _supabase
            .from('void_refund_requests')
            .select('*')
            .eq('id', requestId)
            .single();
        final billId = req['bill_id'] as String;
        final reqType = req['request_type'] as String;

        if (approve) {
          final newStatus = reqType == 'VOID' ? 'CANCELLED' : 'REFUNDED';
          await _supabase.from('bills').update({
            'status': newStatus,
            'payment_status': newStatus,
          }).eq('id', billId);

          await _supabase.from('void_refund_requests').update({
            'status': 'APPROVED',
            'approved_at': DateTime.now().toUtc().toIso8601String(),
            'notes': notes,
          }).eq('id', requestId);
        } else {
          final revertStatus = reqType == 'VOID' ? 'PRINTED' : 'PAID';
          await _supabase.from('bills').update({
            'status': revertStatus,
          }).eq('id', billId);

          await _supabase.from('void_refund_requests').update({
            'status': 'REJECTED',
            'approved_at': DateTime.now().toUtc().toIso8601String(),
            'notes': notes,
          }).eq('id', requestId);
        }
      }

      await Future.wait([
        loadTables(),
        loadActiveOrders(),
        loadRecentBills(),
        loadPendingApprovals(),
      ]);

      return true;
    } catch (e) {
      _errorMessage = 'Approval failed: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Legacy compatibility helper
  Future<Bill?> completeBill(String paymentMethod) async {
    final bill = await printBill();
    if (bill != null) {
      await recordPayment(
        billId: bill.id,
        payments: [
          {'method': paymentMethod, 'amount': bill.totalAmount},
        ],
      );
    }
    return bill;
  }

  // --------------------------------------------------------------------------
  // Table Merging (Atomic RPC)
  // --------------------------------------------------------------------------
  Future<bool> mergeTables(DiningTable primaryTable, List<DiningTable> secondaryTables) async {
    try {
      _isLoading = true;
      notifyListeners();

      final idsToMerge = secondaryTables.map((t) => t.id).toList();

      await _supabase.rpc('merge_tables', params: {
        'p_primary_table_id': primaryTable.id,
        'p_table_ids_to_merge': idsToMerge,
      });

      await Future.wait([
        loadTables(),
        loadActiveOrders(),
      ]);

      // Reopen primary table's session using fresh state from _tables
      final updatedPrimary = _tables.firstWhere(
        (t) => t.id == primaryTable.id,
        orElse: () => primaryTable,
      );
      await selectTable(updatedPrimary);
      return true;
    } catch (e) {
      _errorMessage = 'Merge failed: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --------------------------------------------------------------------------
  // Table Unmerging (Atomic RPC)
  // --------------------------------------------------------------------------
  Future<bool> unmergeTable(DiningTable table) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _supabase.rpc('unmerge_table', params: {
        'p_table_id': table.id,
      });

      await Future.wait([
        loadTables(),
        loadActiveOrders(),
      ]);

      return true;
    } catch (e) {
      _errorMessage = 'Unmerge failed: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --------------------------------------------------------------------------
  // Table Transfer (Atomic RPC)
  // --------------------------------------------------------------------------
  Future<bool> transferTable(DiningTable fromTable, DiningTable toTable) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _supabase.rpc('transfer_table', params: {
        'p_from_table_id': fromTable.id,
        'p_to_table_id': toTable.id,
      });

      await Future.wait([
        loadTables(),
        loadActiveOrders(),
      ]);

      _selectedTable = toTable;
      return true;
    } catch (e) {
      _errorMessage = 'Transfer failed: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --------------------------------------------------------------------------
  // KOT & Receipt Printing
  // --------------------------------------------------------------------------
  Future<void> printKot() async {
    if (_cart.isEmpty) return;
    await ReceiptPrinter.printKot(
      orderNumber: _currentActiveOrderNumber ?? 'NEW',
      orderType: _orderType.displayName,
      tableDisplay: _selectedTable?.tableName,
      customerName: customerNameController.text.trim().isNotEmpty
          ? customerNameController.text.trim()
          : null,
      items: _cart,
    );
  }

  Future<void> printBillReceipt(Bill bill) async {
    await ReceiptPrinter.printBill(bill);
  }
}
