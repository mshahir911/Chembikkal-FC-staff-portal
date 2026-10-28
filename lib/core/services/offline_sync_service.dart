import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cfc_pos/core/services/local_storage_service.dart';

/// OfflineSyncService manages the resilient, multi-day background sync queue.
/// Preserves exact creation timestamps, customer details, split payments,
/// and items so that historical data is pushed accurately to Supabase and Owner portal.
class OfflineSyncService extends ChangeNotifier {
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._internal();

  static const String _prefQueueKey = 'cfc_offline_sync_queue';
  static const String _prefOrderSeqKey = 'cfc_offline_order_seq';
  static const String _prefBillSeqKey = 'cfc_offline_bill_seq';

  List<Map<String, dynamic>> _queue = [];
  bool _isSyncing = false;
  bool _isOnline = true;
  Timer? _syncTimer;
  Timer? _heartbeatTimer;
  SupabaseClient? _supabaseClient;
  Directory? _docsDir;

  VoidCallback? onSyncSuccess;

  List<Map<String, dynamic>> get queue => List.unmodifiable(_queue);
  int get pendingCount => _queue.length;
  bool get isSyncing => _isSyncing;
  bool get hasPendingItems => _queue.isNotEmpty;
  bool get isOnline => _isOnline;

  Future<void> initialize(SupabaseClient client) async {
    _supabaseClient = client;
    try {
      _docsDir = await getApplicationDocumentsDirectory();
    } catch (_) {}

    await _loadQueue();

    // Start background sync timer every 8 seconds
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      drainQueue();
    });

    // Heartbeat connection checker every 10 seconds
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      checkConnection();
    });

    // Initial connection check & drain
    checkConnection().then((online) {
      if (online) drainQueue();
    });
  }

  void disposeService() {
    _syncTimer?.cancel();
    _heartbeatTimer?.cancel();
  }

  void markOnline() {
    if (!_isOnline) {
      _isOnline = true;
      notifyListeners();
      drainQueue();
    }
  }

  void markOffline() {
    if (_isOnline) {
      _isOnline = false;
      notifyListeners();
    }
  }

  Future<bool> checkConnection() async {
    try {
      final client = _supabaseClient ?? Supabase.instance.client;
      await client.from('shops').select('id').limit(1).timeout(const Duration(milliseconds: 1500));
      if (!_isOnline) {
        _isOnline = true;
        notifyListeners();
        drainQueue();
      }
      return true;
    } catch (_) {
      if (_isOnline) {
        _isOnline = false;
        notifyListeners();
      }
      return false;
    }
  }

  File? _getQueueFile() {
    if (_docsDir == null) return null;
    return File('${_docsDir!.path}/cfc_sync_queue.json');
  }

  Future<void> _loadQueue() async {
    try {
      final file = _getQueueFile();
      if (file != null && await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final List<dynamic> list = jsonDecode(content);
          _queue = list.cast<Map<String, dynamic>>();
          notifyListeners();
          return;
        }
      }

      // Fallback to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefQueueKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> list = jsonDecode(raw);
        _queue = list.cast<Map<String, dynamic>>();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _saveQueue() async {
    try {
      final encoded = jsonEncode(_queue);
      final file = _getQueueFile();
      if (file != null) {
        await file.writeAsString(encoded);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefQueueKey, encoded);
      notifyListeners();
    } catch (_) {}
  }

  Future<String> generateOfflineOrderNumber() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final adjusted = now.subtract(const Duration(hours: 3));
      final dateStr = '${adjusted.year}${adjusted.month.toString().padLeft(2, '0')}${adjusted.day.toString().padLeft(2, '0')}';

      int seq = prefs.getInt(_prefOrderSeqKey) ?? 0;
      final lastDate = prefs.getString('cfc_offline_order_date');
      if (lastDate != dateStr) {
        seq = 0;
        await prefs.setString('cfc_offline_order_date', dateStr);
      }

      // Check highest order number in local storage
      try {
        final localOrders = LocalStorageService().getOrders();
        for (final o in localOrders) {
          final parts = o.orderNumber.split('-');
          if (parts.length >= 3 && parts[1] == dateStr) {
            final n = int.tryParse(parts[2]);
            if (n != null && n > seq) seq = n;
          }
        }
      } catch (_) {}

      seq += 1;
      await prefs.setInt(_prefOrderSeqKey, seq);
      return 'ORD-$dateStr-${seq.toString().padLeft(4, '0')}';
    } catch (_) {
      return 'ORD-${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  Future<String> generateOfflineBillNumber() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final adjusted = now.subtract(const Duration(hours: 3));
      final bizDateStr = '${adjusted.year}-${adjusted.month.toString().padLeft(2, '0')}-${adjusted.day.toString().padLeft(2, '0')}';

      final lastDate = prefs.getString('cfc_offline_bill_biz_date');
      int seq = prefs.getInt(_prefBillSeqKey) ?? 0;
      if (lastDate != bizDateStr) {
        seq = 0;
        await prefs.setString('cfc_offline_bill_biz_date', bizDateStr);
      }

      // Check max bill number in local storage for this business date
      try {
        final localBills = LocalStorageService().getBills();
        for (final b in localBills) {
          final bDate = b.createdAt.subtract(const Duration(hours: 3));
          final bDateStr = '${bDate.year}-${bDate.month.toString().padLeft(2, '0')}-${bDate.day.toString().padLeft(2, '0')}';
          if (bDateStr == bizDateStr) {
            final n = int.tryParse(b.displayBillNumber);
            if (n != null && n > seq) {
              seq = n;
            }
          }
        }
      } catch (_) {}

      seq += 1;
      await prefs.setInt(_prefBillSeqKey, seq);
      return seq.toString().padLeft(3, '0');
    } catch (_) {
      return '001';
    }
  }

  Future<void> enqueue(String action, Map<String, dynamic> payload) async {
    final item = {
      'id': 'SYNC_${DateTime.now().microsecondsSinceEpoch}',
      'action': action,
      'payload': payload,
      'createdAt': DateTime.now().toIso8601String(),
      'retryCount': 0,
    };
    _queue.add(item);
    await _saveQueue();
    // Try immediate drain if online
    if (_isOnline) {
      drainQueue();
    }
  }

  Future<void> drainQueue() async {
    if (_isSyncing || _queue.isEmpty) return;
    final client = _supabaseClient ?? Supabase.instance.client;

    _isSyncing = true;
    notifyListeners();

    final List<Map<String, dynamic>> remaining = [];
    bool networkFailureOccurred = false;

    for (final item in _queue) {
      if (networkFailureOccurred) {
        remaining.add(item);
        continue;
      }

      final action = item['action'] as String;
      final payload = Map<String, dynamic>.from(item['payload'] as Map);

      try {
        await _executeAction(client, action, payload);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[OfflineSyncService] Sync action $action failed: $e');
        }
        item['retryCount'] = ((item['retryCount'] as int?) ?? 0) + 1;
        remaining.add(item);

        final errStr = e.toString().toLowerCase();
        if (errStr.contains('socket') ||
            errStr.contains('timeout') ||
            errStr.contains('failed host lookup') ||
            errStr.contains('connection refused') ||
            errStr.contains('network is unreachable')) {
          markOffline();
          networkFailureOccurred = true;
        }
      }
    }

    _queue = remaining;
    await _saveQueue();

    _isSyncing = false;
    notifyListeners();

    if (!networkFailureOccurred) {
      markOnline();
      onSyncSuccess?.call();
    }
  }

  Future<void> _executeAction(
    SupabaseClient client,
    String action,
    Map<String, dynamic> payload,
  ) async {
    switch (action) {
      case 'SAVE_ORDER':
        final orderData = Map<String, dynamic>.from(payload['order'] as Map);
        final itemsData = (payload['items'] as List).cast<Map<String, dynamic>>();

        // Upsert order preserving exact created_at timestamp
        await client.from('orders').upsert(orderData, onConflict: 'id');

        // Upsert customer if phone present
        final phone = orderData['customer_phone'] as String?;
        final name = orderData['customer_name'] as String?;
        if (phone != null && phone.trim().isNotEmpty) {
          try {
            await client.from('customers').upsert({
              'phone': phone.trim(),
              'name': name?.trim() ?? '',
              'last_order_at': DateTime.now().toUtc().toIso8601String(),
            }, onConflict: 'phone');
          } catch (_) {}
        }

        // Clean up any previously inserted items for this order before re-inserting, to prevent duplicate items
        final orderId = orderData['id'] as String?;
        if (orderId != null) {
          try {
            await client.from('order_items').delete().eq('order_id', orderId);
          } catch (_) {}
        }

        // Insert items
        for (final item in itemsData) {
          try {
            await client.from('order_items').upsert(item, onConflict: 'id');
          } catch (_) {
            await client.from('order_items').insert(item);
          }
        }
        break;

      case 'SAVE_BILL':
        final billData = Map<String, dynamic>.from(payload['bill'] as Map);
        final billItems = (payload['bill_items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final billVersions = (payload['bill_versions'] as List?)?.cast<Map<String, dynamic>>() ?? [];

        // Upsert bill preserving exact created_at, printed_at, bill_number
        try {
          await client.from('bills').upsert(billData, onConflict: 'id');
        } catch (e) {
          final errStr = e.toString().toLowerCase();
          if (errStr.contains('bills_bill_number_business_date_key') ||
              errStr.contains('duplicate key value violates unique constraint') ||
              errStr.contains('bills_bill_number_key')) {
            // Find highest bill number for this business date and assign next sequential
            final bizDate = billData['business_date'] ?? billData['created_at']?.toString().split('T').first;
            try {
              final existingBills = await client
                  .from('bills')
                  .select('bill_number')
                  .eq('business_date', bizDate);
              int maxN = 0;
              for (final row in (existingBills as List)) {
                final n = int.tryParse(row['bill_number']?.toString() ?? '');
                if (n != null && n > maxN) maxN = n;
              }
              billData['bill_number'] = (maxN + 1).toString().padLeft(3, '0');
              await client.from('bills').upsert(billData, onConflict: 'id');
            } catch (_) {
              await client.from('bills').upsert(billData, onConflict: 'id');
            }
          } else {
            rethrow;
          }
        }

        for (final v in billVersions) {
          try {
            await client.from('bill_versions').upsert(v, onConflict: 'id');
          } catch (_) {}
        }

        // Clean up any previously inserted items for this bill before re-inserting, to prevent duplicate items
        final billId = billData['id'] as String?;
        if (billId != null) {
          try {
            await client.from('bill_items').delete().eq('bill_id', billId);
          } catch (_) {}
        }

        for (final bi in billItems) {
          try {
            await client.from('bill_items').upsert(bi, onConflict: 'id');
          } catch (_) {
            await client.from('bill_items').insert(bi);
          }
        }
        break;

      case 'RECORD_PAYMENT':
        final paymentsList = payload['payments'] != null
            ? (payload['payments'] as List).cast<Map<String, dynamic>>()
            : (payload['payment'] != null
                ? [Map<String, dynamic>.from(payload['payment'] as Map)]
                : <Map<String, dynamic>>[]);

        final billId = payload['bill_id'] as String;
        final billUpdates = Map<String, dynamic>.from(payload['bill_updates'] as Map);
        final notesUpdate = payload['order_notes'] as String?;
        final orderId = payload['order_id'] as String?;

        // Pre-clean existing payments for this bill to avoid duplicate payment records
        if (billId.isNotEmpty) {
          try {
            await client.from('payments').delete().eq('bill_id', billId);
          } catch (_) {}
        }

        for (final p in paymentsList) {
          try {
            await client.from('payments').upsert(p, onConflict: 'id');
          } catch (_) {
            await client.from('payments').insert(p);
          }
        }

        await client.from('bills').update(billUpdates).eq('id', billId);

        if (orderId != null) {
          final ordUpdate = <String, dynamic>{'status': 'COMPLETED'};
          if (notesUpdate != null && notesUpdate.isNotEmpty) {
            ordUpdate['delivery_notes'] = notesUpdate;
          }
          try {
            await client.from('orders').update(ordUpdate).eq('id', orderId);
          } catch (_) {}
        }
        break;

      case 'VOID_REFUND':
        final requestData = Map<String, dynamic>.from(payload['request'] as Map);
        await client.from('void_refund_requests').upsert(requestData, onConflict: 'id');
        break;

      default:
        break;
    }
  }
}
