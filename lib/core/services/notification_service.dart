import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NewOrderEvent {
  final String orderId;
  final String orderNumber;
  final String customerName;
  final double totalAmount;

  NewOrderEvent({
    required this.orderId,
    required this.orderNumber,
    required this.customerName,
    required this.totalAmount,
  });

  String get displayIdentifier {
    final parts = orderNumber.split('-');
    if (parts.length >= 3) {
      return '#${parts.last}';
    }
    return '#$orderNumber';
  }
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  final StreamController<NewOrderEvent> _newOrderController = StreamController<NewOrderEvent>.broadcast();
  Stream<NewOrderEvent> get onNewOrder => _newOrderController.stream;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
        macOS: darwinInit,
      );

      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (details) {
          // Handle tap on notification
        },
      );

      // Create notification channel for Android
      final androidPlatform = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlatform != null) {
        await androidPlatform.requestNotificationsPermission();
        const channel = AndroidNotificationChannel(
          'cfc_delivery_channel',
          'Delivery Orders',
          description: 'Notifications for new delivery orders',
          importance: Importance.max,
          enableVibration: true,
          playSound: true,
        );
        await androidPlatform.createNotificationChannel(channel);
      }

      _initialized = true;
    } catch (e) {
      // Don't crash app if notification initialization fails
    }
  }

  Future<void> showNewOrderNotification({
    required String orderId,
    required String orderNumber,
    required String customerName,
    required double totalAmount,
  }) async {
    // 1. Trigger haptic and audio feedback
    try {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}

    // 2. Broadcast to in-app listeners
    final event = NewOrderEvent(
      orderId: orderId,
      orderNumber: orderNumber,
      customerName: customerName,
      totalAmount: totalAmount,
    );
    _newOrderController.add(event);

    // 3. Trigger system status bar notification
    try {
      const androidDetails = AndroidNotificationDetails(
        'cfc_delivery_channel',
        'Delivery Orders',
        channelDescription: 'Notifications for new delivery orders',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'New Order',
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      final notifId = orderId.hashCode & 0x7FFFFFFF;
      final bodyText = 'Order #$orderNumber • ${customerName.isNotEmpty ? customerName : "Customer"} • ₹${totalAmount.toInt()}';

      await _notificationsPlugin.show(
        id: notifId,
        title: 'New Order',
        body: bodyText,
        notificationDetails: notificationDetails,
        payload: orderId,
      );
    } catch (_) {}
  }
}
