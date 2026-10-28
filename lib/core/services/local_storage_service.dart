import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../../data/models/bill.dart';
import '../../data/models/dining_table.dart';
import '../../data/models/order.dart';
import '../../data/models/product.dart';
import '../../data/models/shop.dart';

/// LocalStorageService handles zero-latency offline persistence for CFC POS.
/// Guarantees that the app is 100% functional with full menu, tables, billing,
/// and orders even when completely offline or during network dropouts.
class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  bool _isInitialized = false;
  Directory? _docsDir;

  List<Shop> _cachedShops = [];
  List<Product> _cachedProducts = [];
  List<DiningTable> _cachedTables = [];
  List<Bill> _cachedBills = [];
  List<OrderModel> _cachedOrders = [];

  List<Shop> getShops() => List.unmodifiable(_cachedShops);
  List<Product> getProducts() => List.unmodifiable(_cachedProducts);
  List<DiningTable> getTables() => List.unmodifiable(_cachedTables);
  List<Bill> getBills() => List.unmodifiable(_cachedBills);
  List<OrderModel> getOrders() => List.unmodifiable(_cachedOrders);

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      _docsDir = await getApplicationDocumentsDirectory();
      await Future.wait([
        _loadShopsFromDisk(),
        _loadProductsFromDisk(),
        _loadTablesFromDisk(),
        _loadBillsFromDisk(),
        _loadOrdersFromDisk(),
      ]);

      // Seed fallback catalog if disk cache was completely empty
      if (_cachedShops.isEmpty) {
        _cachedShops = _getSeedShops();
        _saveShopsToDisk();
      }
      if (_cachedProducts.isEmpty) {
        _cachedProducts = _getSeedProducts();
        _saveProductsToDisk();
      }
      if (_cachedTables.isEmpty) {
        _cachedTables = _getSeedTables();
        _saveTablesToDisk();
      }

      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) debugPrint('[LocalStorageService] Init error: $e');
      // Ensure seed data is always available in memory even if disk IO fails
      if (_cachedShops.isEmpty) _cachedShops = _getSeedShops();
      if (_cachedProducts.isEmpty) _cachedProducts = _getSeedProducts();
      if (_cachedTables.isEmpty) _cachedTables = _getSeedTables();
      _isInitialized = true;
    }
  }

  File _getFile(String filename) => File('${_docsDir!.path}/$filename');

  // --------------------------------------------------------------------------
  // Shops
  // --------------------------------------------------------------------------
  Future<void> _loadShopsFromDisk() async {
    try {
      final file = _getFile('cfc_cache_shops.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> list = jsonDecode(content);
        _cachedShops = list.map((j) => Shop.fromJson(j as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
  }

  Future<void> saveShops(List<Shop> shops) async {
    if (shops.isEmpty) return;
    _cachedShops = List.from(shops);
    await _saveShopsToDisk();
  }

  Future<void> _saveShopsToDisk() async {
    try {
      if (_docsDir == null) return;
      final file = _getFile('cfc_cache_shops.json');
      await file.writeAsString(jsonEncode(_cachedShops.map((s) => s.toJson()).toList()));
    } catch (_) {}
  }

  // --------------------------------------------------------------------------
  // Products
  // --------------------------------------------------------------------------
  Future<void> _loadProductsFromDisk() async {
    try {
      final file = _getFile('cfc_cache_products.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> list = jsonDecode(content);
        _cachedProducts = list.map((j) => Product.fromJson(j as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
  }

  Future<void> saveProducts(List<Product> products) async {
    if (products.isEmpty) return;
    _cachedProducts = List.from(products);
    await _saveProductsToDisk();
  }

  Future<void> _saveProductsToDisk() async {
    try {
      if (_docsDir == null) return;
      final file = _getFile('cfc_cache_products.json');
      await file.writeAsString(jsonEncode(_cachedProducts.map((p) => p.toJson()).toList()));
    } catch (_) {}
  }

  // --------------------------------------------------------------------------
  // Dining Tables
  // --------------------------------------------------------------------------
  Future<void> _loadTablesFromDisk() async {
    try {
      final file = _getFile('cfc_cache_tables.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> list = jsonDecode(content);
        _cachedTables = list.map((j) => DiningTable.fromJson(j as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
  }

  Future<void> saveTables(List<DiningTable> tables) async {
    if (tables.isEmpty) return;
    _cachedTables = List.from(tables);
    await _saveTablesToDisk();
  }

  Future<void> _saveTablesToDisk() async {
    try {
      if (_docsDir == null) return;
      final file = _getFile('cfc_cache_tables.json');
      await file.writeAsString(jsonEncode(_cachedTables.map((t) => t.toJson()).toList()));
    } catch (_) {}
  }

  // --------------------------------------------------------------------------
  // Bills (Historical & Today's bills)
  // --------------------------------------------------------------------------
  Future<void> _loadBillsFromDisk() async {
    try {
      final file = _getFile('cfc_cache_bills.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> list = jsonDecode(content);
        _cachedBills = list.map((j) => Bill.fromJson(j as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
  }

  Future<void> saveBills(List<Bill> bills) async {
    _cachedBills = List.from(bills);
    await _saveBillsToDisk();
  }

  Future<void> upsertBill(Bill bill) async {
    final idx = _cachedBills.indexWhere((b) => b.id == bill.id || b.billNumber == bill.billNumber);
    if (idx >= 0) {
      _cachedBills[idx] = bill;
    } else {
      _cachedBills.insert(0, bill);
    }
    await _saveBillsToDisk();
  }

  Future<void> _saveBillsToDisk() async {
    try {
      if (_docsDir == null) return;
      final file = _getFile('cfc_cache_bills.json');
      // Limit to latest 300 bills on disk for optimal mobile performance
      final toStore = _cachedBills.take(300).map((b) => b.toJson()).toList();
      await file.writeAsString(jsonEncode(toStore));
    } catch (_) {}
  }

  // --------------------------------------------------------------------------
  // Active Orders
  // --------------------------------------------------------------------------
  Future<void> _loadOrdersFromDisk() async {
    try {
      final file = _getFile('cfc_cache_orders.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> list = jsonDecode(content);
        _cachedOrders = list.map((j) => OrderModel.fromJson(j as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
  }

  Future<void> saveOrders(List<OrderModel> orders) async {
    _cachedOrders = List.from(orders);
    await _saveOrdersToDisk();
  }

  Future<void> upsertOrder(OrderModel order) async {
    final idx = _cachedOrders.indexWhere((o) => o.id == order.id);
    if (idx >= 0) {
      _cachedOrders[idx] = order;
    } else {
      _cachedOrders.insert(0, order);
    }
    await _saveOrdersToDisk();
  }

  Future<void> removeOrder(String orderId) async {
    _cachedOrders.removeWhere((o) => o.id == orderId);
    await _saveOrdersToDisk();
  }

  Future<void> deleteOrder(String orderId) => removeOrder(orderId);

  Future<void> _saveOrdersToDisk() async {
    try {
      if (_docsDir == null) return;
      final file = _getFile('cfc_cache_orders.json');
      await file.writeAsString(jsonEncode(_cachedOrders.map((o) => o.toJson()).toList()));
    } catch (_) {}
  }

  // --------------------------------------------------------------------------
  // Embedded Seed Data for First-Install Instant Offline Readiness
  // --------------------------------------------------------------------------
  List<Shop> _getSeedShops() {
    final now = DateTime.now();
    return [
      Shop(id: '11111111-1111-1111-1111-111111111101', name: 'Thejaj', code: 'THEJAJ', description: 'Authentic Shawarma & Shawaya Specialists', status: 'ACTIVE', displayOrder: 1, createdAt: now),
      Shop(id: '11111111-1111-1111-1111-111111111102', name: 'Fruvia', code: 'FRUVIA', description: 'Fresh Juices, Coolers & Thick Shakes', status: 'ACTIVE', displayOrder: 2, createdAt: now),
      Shop(id: '11111111-1111-1111-1111-111111111103', name: 'Chai Latte', code: 'CHAI-LATTE', description: 'Freshly Brewed Tea, Coffee & Hot Evening Snacks', status: 'ACTIVE', displayOrder: 3, createdAt: now),
      Shop(id: '11111111-1111-1111-1111-111111111104', name: 'Smoocho', code: 'SMOOCHO', description: 'Kunafa Bowls, Flavour Storm Cakes, Signature Desserts & Milk Specials', status: 'ACTIVE', displayOrder: 4, createdAt: now),
    ];
  }

  List<DiningTable> _getSeedTables() {
    return List.generate(10, (i) => DiningTable(
      id: 'table_${i + 1}',
      tableNumber: i + 1,
      tableName: 'Table ${i + 1}',
      capacity: (i == 3 || i == 7) ? 6 : (i == 9 ? 8 : (i % 2 == 0 ? 2 : 4)),
      status: 'AVAILABLE',
      isActive: true,
    ));
  }

  List<Product> _getSeedProducts() {
    return [
      // Thejaj
      Product(id: '22e97e85-9331-4781-9cd1-986b9c574212', shopId: '11111111-1111-1111-1111-111111111101', name: 'Shawaya (Full)', category: 'Shawaya', price: 550.0),
      Product(id: '7b0356d0-cfce-4f8e-ac2b-391ec9c066e4', shopId: '11111111-1111-1111-1111-111111111101', name: 'Shawaya (Half)', category: 'Shawaya', price: 300.0),
      Product(id: '749fb1d3-4b31-4441-a348-25c5e70c4759', shopId: '11111111-1111-1111-1111-111111111101', name: 'Shawaya (Quarter)', category: 'Shawaya', price: 150.0),
      Product(id: '0615c62a-021f-4d75-94a0-72d67a751536', shopId: '11111111-1111-1111-1111-111111111101', name: 'Rumali Roll Shawarma', category: 'Shawarma', price: 130.0),
      Product(id: 'fd551307-bf43-4578-a081-0c6b177fc5ec', shopId: '11111111-1111-1111-1111-111111111101', name: 'Rumali Plate Shawarma', category: 'Shawarma', price: 150.0),
      Product(id: 'kuboos_roll', shopId: '11111111-1111-1111-1111-111111111101', name: 'Kuboos Roll Shawarma', category: 'Shawarma', price: 100.0),

      // Fruvia
      Product(id: 'avocado_shake', shopId: '11111111-1111-1111-1111-111111111102', name: 'Avocado Shake', category: 'Shakes', price: 110.0),
      Product(id: 'avocado_juice', shopId: '11111111-1111-1111-1111-111111111102', name: 'Avocado Juice', category: 'Juice', price: 80.0),
      Product(id: 'chikku_juice', shopId: '11111111-1111-1111-1111-111111111102', name: 'Chikku Juice', category: 'Juice', price: 80.0),
      Product(id: 'chikku_shake', shopId: '11111111-1111-1111-1111-111111111102', name: 'Chikku Shake', category: 'Shakes', price: 110.0),
      Product(id: 'a918cde7-3a5e-4481-aef3-3f09157d8c5c', shopId: '11111111-1111-1111-1111-111111111102', name: 'Watermelon Juice', category: 'Juice', price: 80.0),
      Product(id: '66f521fa-2393-4807-b951-4a419fbe27b9', shopId: '11111111-1111-1111-1111-111111111102', name: 'Snickers Shake', category: 'Shakes', price: 110.0),
      Product(id: 'e001d91d-89cf-40ea-b97e-7f5fc2a3f05c', shopId: '11111111-1111-1111-1111-111111111102', name: 'Tender Coconut Juice', category: 'Juice', price: 80.0),
      Product(id: '92b3eb53-90bc-46e7-8a96-5c71136e35d1', shopId: '11111111-1111-1111-1111-111111111102', name: 'Tender Coconut Shake', category: 'Shakes', price: 110.0),

      // Chai Latte
      Product(id: 'chicken_kabab', shopId: '11111111-1111-1111-1111-111111111103', name: 'Chicken Kabab', category: 'Snacks', price: 35.0),
      Product(id: 'boost', shopId: '11111111-1111-1111-1111-111111111103', name: 'Boost', category: 'Hot Drinks', price: 25.0),
      Product(id: 'b2797f53-f347-4b26-a735-9ccb91278dd7', shopId: '11111111-1111-1111-1111-111111111103', name: 'Tea', category: 'Hot Drinks', price: 15.0),
      Product(id: 'f388d155-0582-400c-a7b4-ce1e8ba8e79b', shopId: '11111111-1111-1111-1111-111111111103', name: 'Samoosa', category: 'Snacks', price: 15.0),
      Product(id: '137042db-f2ca-4127-ab77-9521ef642ca7', shopId: '11111111-1111-1111-1111-111111111103', name: 'Ullivada', category: 'Snacks', price: 15.0),
      Product(id: 'bd8e8028-0ef6-4b68-9be1-f42bf86f0e40', shopId: '11111111-1111-1111-1111-111111111103', name: 'Thurakkalappam', category: 'Snacks', price: 25.0),

      // Smoocho
      Product(id: 'aseerathul_pistachio', shopId: '11111111-1111-1111-1111-111111111104', name: 'Aseerathul Pistachio', category: 'Smoocho Signature', price: 150.0),
      Product(id: 'aseerathul_kinder', shopId: '11111111-1111-1111-1111-111111111104', name: 'Aseerathul Kinder', category: 'Smoocho Signature', price: 150.0),
      Product(id: 'aseerathul_hazelnut', shopId: '11111111-1111-1111-1111-111111111104', name: 'Aseerathul Hazelnut', category: 'Smoocho Signature', price: 150.0),
      Product(id: 'aseerathul_coffee', shopId: '11111111-1111-1111-1111-111111111104', name: 'Aseerathul Coffee', category: 'Smoocho Signature', price: 150.0),
      Product(id: '86e64203-3dfd-4aa3-bd95-02bdd4ecd487', shopId: '11111111-1111-1111-1111-111111111104', name: 'Pista Kunafa', category: 'Kunafa Bowls', price: 279.0),
      Product(id: 'eea3e1df-204d-481a-a789-ce6660894f8d', shopId: '11111111-1111-1111-1111-111111111104', name: 'Pista Biscoff Kunafa', category: 'Kunafa Bowls', price: 279.0),
      Product(id: '923a8c68-a066-4665-a33b-30cb74736959', shopId: '11111111-1111-1111-1111-111111111104', name: 'White Chocolate Kunafa', category: 'Kunafa Bowls', price: 249.0),
      Product(id: '0da85e03-832d-41a8-890d-2b5516e245f1', shopId: '11111111-1111-1111-1111-111111111104', name: 'Salankatia Pistachio', category: 'Salankatia', price: 349.0),
      Product(id: 'e7cd474b-55d3-41e2-9685-0918311c050e', shopId: '11111111-1111-1111-1111-111111111104', name: 'Salankatia Biscoff', category: 'Salankatia', price: 349.0),
      Product(id: '57f76071-1a6a-4245-8009-544f43f63b36', shopId: '11111111-1111-1111-1111-111111111104', name: 'Salankatia Hazelnut', category: 'Salankatia', price: 349.0),
      Product(id: '286e6a9c-184f-47a7-bced-f20a77a95bbc', shopId: '11111111-1111-1111-1111-111111111104', name: 'Smoocho Bueno', category: 'Smoocho Signature', price: 199.0),
      Product(id: '0b6fd2ab-bd7f-4c97-af99-425fa7f2c720', shopId: '11111111-1111-1111-1111-111111111104', name: 'Vietnamese Iced Coffee', category: 'Crafted to Refresh', price: 99.0),
    ];
  }
}
