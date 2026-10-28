import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/delivery_order.dart';
import '../../../providers/delivery_provider.dart';
import '../../widgets/bill_receipt_dialog.dart';
import '../../widgets/delivery_payment_dialog.dart';

class DeliveryHomeScreen extends StatefulWidget {
  const DeliveryHomeScreen({super.key});

  @override
  State<DeliveryHomeScreen> createState() => _DeliveryHomeScreenState();
}

class _DeliveryHomeScreenState extends State<DeliveryHomeScreen> {
  int _currentTabIndex = 0; // 0 = Deliveries, 1 = Collections, 2 = History
  String _activeSearchQuery = '';
  String _activeFilter = 'ALL'; // 'ALL', 'DUE', 'PAID'
  String _historySearchQuery = '';

  late Timer _clockTimer;
  StreamSubscription<NewOrderEvent>? _newOrderSubscription;
  DateTime _currentTime = DateTime.now();
  DateTime _lastShiftCutoff = _computeShiftCutoff(DateTime.now());

  static DateTime _computeShiftCutoff(DateTime dt) {
    return dt.hour < 3
        ? DateTime(dt.year, dt.month, dt.day - 1, 3, 0, 0)
        : DateTime(dt.year, dt.month, dt.day, 3, 0, 0);
  }

  @override
  void initState() {
    super.initState();
    _newOrderSubscription = NotificationService.instance.onNewOrder.listen((event) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(40),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delivery_dining_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'New Order Received! 🔔',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${event.displayIdentifier} • ${event.customerName.isNotEmpty ? event.customerName : "Customer"} • ₹${event.totalAmount.toInt()}',
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(12),
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'VIEW',
              textColor: Colors.white,
              onPressed: () {
                _switchToTab(0);
              },
            ),
          ),
        );
      }
    });

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        final now = DateTime.now();
        setState(() => _currentTime = now);
        final currentCutoff = _computeShiftCutoff(now);
        if (currentCutoff != _lastShiftCutoff) {
          _lastShiftCutoff = currentCutoff;
          context.read<DeliveryProvider>().loadDeliveries();
        }
      }
    });
  }

  @override
  void dispose() {
    _newOrderSubscription?.cancel();
    _clockTimer.cancel();
    super.dispose();
  }

  void _switchToTab(int index) {
    setState(() => _currentTabIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeliveryProvider>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;

        return Scaffold(
          backgroundColor: AppTheme.background,
          // Header matching POS app
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(isMobile ? 54 : 64),
            child: isMobile
                ? _buildMobileHeader(context, provider)
                : _buildDesktopHeader(context, provider),
          ),
          // IndexedStack preserves state of search queries and lists
          body: IndexedStack(
            index: _currentTabIndex,
            children: [
              _buildDeliveriesTab(context, provider, isMobile),
              _buildCollectionsTab(context, provider, isMobile),
              _buildHistoryTab(context, provider, isMobile),
            ],
          ),
          // Bottom Navigation Bar only shown on Mobile matching POS
          bottomNavigationBar: isMobile ? _buildMobileBottomNav(provider) : null,
        );
      },
    );
  }

  // ==========================================================================
  // 1. HEADERS (Mobile & Desktop) matching POS App exactly
  // ==========================================================================

  Widget _buildMobileHeader(BuildContext context, DeliveryProvider provider) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.cardBorder, width: 1)),
        boxShadow: AppTheme.shadowSoft,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Logo & Title: Moped icon + CFC DELIVERY
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: AppTheme.shadowSoft,
                    ),
                    child: const Icon(
                      Icons.delivery_dining_rounded,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CFC DELIVERY',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'Doorstep Partner',
                        style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),

              // Status Badges & Quick Action
              Row(
                children: [
                  // Active Deliveries Counter Pill (if any)
                  if (provider.activeDeliveries.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.primaryBorder, width: 0.8),
                        boxShadow: AppTheme.shadowSoft,
                      ),
                      child: Text(
                        '${provider.activeDeliveries.length} Pending',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),

                  // Supabase Live pill matching POS style
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: provider.errorMessage == null ? AppTheme.cashGreenBg : Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: provider.errorMessage == null ? AppTheme.cashGreen.withAlpha(80) : Colors.amber.shade300,
                        width: 0.8,
                      ),
                      boxShadow: AppTheme.shadowSoft,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          provider.errorMessage == null ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                          size: 12,
                          color: provider.errorMessage == null ? AppTheme.cashGreen : Colors.amber.shade900,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          provider.errorMessage == null ? 'Online' : 'Offline',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: provider.errorMessage == null ? AppTheme.cashGreen : Colors.amber.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Refresh Button
                  IconButton(
                    icon: provider.isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                          )
                        : const Icon(Icons.refresh_rounded, size: 22, color: AppTheme.textPrimary),
                    tooltip: 'Refresh Deliveries',
                    onPressed: provider.isLoading ? null : () => provider.loadDeliveries(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopHeader(BuildContext context, DeliveryProvider provider) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.surfaceBorder, width: 0.9)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              // Logo & App Name
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.primaryBorder, width: 0.8),
                    ),
                    child: const Icon(
                      Icons.delivery_dining_rounded,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CFC RESTAURANT DELIVERY',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'Doorstep Deliveries & Collections',
                        style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 28),

              // Center Navigation Tabs (POS Style)
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildDesktopNavTab(
                        0,
                        'Active Deliveries',
                        Icons.two_wheeler_rounded,
                        badgeCount: provider.activeDeliveries.length,
                      ),
                      const SizedBox(width: 6),
                      _buildDesktopNavTab(
                        1,
                        'Shift Collections',
                        Icons.payments_rounded,
                        badgeCount: provider.activeDeliveries.where((d) => !d.isPaid).length,
                      ),
                      const SizedBox(width: 6),
                      _buildDesktopNavTab(
                        2,
                        'Delivered History',
                        Icons.history_rounded,
                        badgeCount: provider.completedDeliveries.length,
                      ),
                    ],
                  ),
                ),
              ),

              // Right Status & Clock
              Row(
                children: [
                  // Online Supabase indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.cashGreenBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.cashGreen.withAlpha(80), width: 0.8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_done_rounded, size: 14, color: AppTheme.cashGreen),
                        SizedBox(width: 6),
                        Text(
                          'Live Supabase',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.cashGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Live Clock
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        Formatters.formatTime(_currentTime),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
                      ),
                      Text(
                        Formatters.formatDate(_currentTime),
                        style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),

                  IconButton(
                    icon: provider.isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                          )
                        : const Icon(Icons.refresh_rounded, size: 22, color: AppTheme.textPrimary),
                    tooltip: 'Refresh Deliveries',
                    onPressed: provider.isLoading ? null : () => provider.loadDeliveries(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopNavTab(int index, String label, IconData icon, {int? badgeCount}) {
    final isSelected = _currentTabIndex == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _switchToTab(index),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryLight : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected ? Border.all(color: AppTheme.primary, width: 1.2) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                ),
              ),
              if (badgeCount != null && badgeCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // 2. MOBILE BOTTOM NAVIGATION BAR matching POS App
  // ==========================================================================

  Widget _buildMobileBottomNav(DeliveryProvider provider) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.cardBorder, width: 1)),
        boxShadow: AppTheme.shadowSoft,
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              _buildBottomNavItem(
                index: 0,
                label: 'Deliveries',
                icon: Icons.two_wheeler_rounded,
                badgeCount: provider.activeDeliveries.length,
              ),
              _buildBottomNavItem(
                index: 1,
                label: 'Collections',
                icon: Icons.payments_rounded,
              ),
              _buildBottomNavItem(
                index: 2,
                label: 'History',
                icon: Icons.history_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({
    required int index,
    required String label,
    required IconData icon,
    int? badgeCount,
  }) {
    final isSelected = _currentTabIndex == index;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _switchToTab(index),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryLight : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedScale(
                        scale: isSelected ? 1.08 : 1.0,
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutBack,
                        child: Icon(
                          icon,
                          size: 20,
                          color: isSelected ? AppTheme.primary : AppTheme.textMuted,
                        ),
                      ),
                      if (badgeCount != null && badgeCount > 0)
                        Positioned(
                          top: -6,
                          right: -10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: AppTheme.shadowGlow,
                            ),
                            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                            alignment: Alignment.center,
                            child: Text(
                              '$badgeCount',
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // 3. TAB 0: ACTIVE DELIVERIES SCREEN (matches Active Orders & Payment Counter)
  // ==========================================================================

  Widget _buildDeliveriesTab(BuildContext context, DeliveryProvider provider, bool isMobile) {
    var deliveries = provider.activeDeliveries;

    // Apply Filter
    if (_activeFilter == 'DUE') {
      deliveries = deliveries.where((d) => !d.isPaid).toList();
    } else if (_activeFilter == 'PAID') {
      deliveries = deliveries.where((d) => d.isPaid).toList();
    }

    // Apply Search
    if (_activeSearchQuery.isNotEmpty) {
      deliveries = deliveries.where((d) {
        final oNum = d.orderNumber.toLowerCase();
        final bNum = (d.billNumber ?? '').toLowerCase();
        final dispNum = d.billOrOrderNumber.toLowerCase();
        final dispId = d.displayIdentifier.toLowerCase();
        final name = d.customerName.toLowerCase();
        final phone = d.customerPhone.toLowerCase();
        final addr = d.deliveryAddress.toLowerCase();
        return oNum.contains(_activeSearchQuery) ||
            bNum.contains(_activeSearchQuery) ||
            dispNum.contains(_activeSearchQuery) ||
            dispId.contains(_activeSearchQuery) ||
            name.contains(_activeSearchQuery) ||
            phone.contains(_activeSearchQuery) ||
            addr.contains(_activeSearchQuery);
      }).toList();
    }

    final unpaidCount = provider.activeDeliveries.where((d) => !d.isPaid).length;
    final paidCount = provider.activeDeliveries.where((d) => d.isPaid).length;

    return RefreshIndicator(
      onRefresh: () => provider.loadDeliveries(),
      color: AppTheme.primary,
      backgroundColor: AppTheme.surface,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar: Title & Refresh (POS Style)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Active Deliveries',
                  style: TextStyle(
                    fontSize: isMobile ? 20 : 24,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${provider.activeDeliveries.length} orders pending doorstep handover & collection',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Modern Capsule Search Bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.cardBorder),
                boxShadow: AppTheme.shadowSoft,
              ),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search order #, customer phone, name or address...',
                  hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppTheme.primary),
                  suffixIcon: _activeSearchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18, color: AppTheme.textMuted),
                          onPressed: () => setState(() => _activeSearchQuery = ''),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.transparent,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                onChanged: (val) => setState(() => _activeSearchQuery = val.trim().toLowerCase()),
              ),
            ),
            const SizedBox(height: 10),

            // Filter Chips (POS Style)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('ALL', 'All (${provider.activeDeliveries.length})'),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'DUE',
                    'Payment Due ($unpaidCount)',
                    isAlert: unpaidCount > 0,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'PAID',
                    'Prepaid at Counter ($paidCount)',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Deliveries List
            Expanded(
              child: deliveries.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: const BoxDecoration(
                              color: AppTheme.primaryLight,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.moped_rounded,
                              size: 44,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _activeSearchQuery.isNotEmpty
                                ? 'No deliveries matching "$_activeSearchQuery"'
                                : 'No Active Deliveries',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'When POS staff saves a delivery order, it appears here instantly.',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                      padding: const EdgeInsets.only(top: 4, bottom: 40),
                      itemCount: deliveries.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final delivery = deliveries[index];
                        return _buildDeliveryCard(context, provider, delivery, isMobile);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, {bool isAlert = false}) {
    final isSelected = _activeFilter == key;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _activeFilter = key),
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primary
                : (isAlert ? AppTheme.primaryLight : AppTheme.surfaceLight),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primary
                  : (isAlert ? AppTheme.primaryBorder : Colors.transparent),
              width: 1,
            ),
            boxShadow: isSelected ? AppTheme.shadowGlow : AppTheme.shadowSoft,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected
                  ? Colors.white
                  : (isAlert ? AppTheme.primary : AppTheme.textSecondary),
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // DELIVERY CARD (Matches POS Payment Counter Bill Card Style)
  // ==========================================================================

  Widget _buildDeliveryCard(
    BuildContext context,
    DeliveryProvider provider,
    DeliveryOrder delivery,
    bool isMobile,
  ) {
    final isPaid = delivery.isPaid;
    final toCollect = delivery.amountToCollect;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPaid ? AppTheme.cashGreen.withAlpha(60) : AppTheme.cardBorder,
          width: 1,
        ),
        boxShadow: AppTheme.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Row: Order #, Tags, Status Badge & Time
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        delivery.displayIdentifier,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primaryBorder, width: 0.8),
                      ),
                      child: const Text(
                        'DELIVERY',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppTheme.primary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Status Badge & Time
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPaid ? AppTheme.cashGreenBg : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isPaid ? AppTheme.cashGreen.withAlpha(80) : const Color(0xFFFECACA),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      isPaid ? 'PREPAID' : 'DUE: ${Formatters.currency(toCollect)}',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: isPaid ? AppTheme.cashGreen : const Color(0xFFDC2626),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    Formatters.formatTime(delivery.createdAt),
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ],
          ),
          if (delivery.displayBillNumber != null) ...[
            const SizedBox(height: 2),
            Text(
              'Bill #${delivery.displayBillNumber}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
            ),
          ],
          const SizedBox(height: 8),

          // 2. Customer Name & Contact Actions
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      delivery.customerName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (delivery.customerPhone.isNotEmpty)
                      Text(
                        delivery.customerPhone,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                  ],
                ),
              ),

              // Action Buttons: Call & Chat
              if (delivery.customerPhone.isNotEmpty) ...[
                InkWell(
                  onTap: () => _makePhoneCall(delivery.customerPhone),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.cashGreenBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.cashGreen.withAlpha(80), width: 0.8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.call_rounded, size: 13, color: AppTheme.cashGreen),
                        SizedBox(width: 4),
                        Text(
                          'Call',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cashGreen),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => _openWhatsApp(delivery.customerPhone, delivery.billOrOrderNumber),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF16A34A), width: 0.8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_rounded, size: 13, color: Color(0xFF15803D)),
                        SizedBox(width: 4),
                        Text(
                          'Chat',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // 3. Address Card with Google Maps & Copy
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.surfaceBorder, width: 0.8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFFE11D48)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        delivery.deliveryAddress,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
                if (delivery.deliveryNotes != null && delivery.deliveryNotes!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 22),
                    child: Text(
                      'Note: ${delivery.deliveryNotes}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    InkWell(
                      onTap: () => _copyAddress(context, delivery.deliveryAddress),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        child: Row(
                          children: [
                            Icon(Icons.copy_rounded, size: 13, color: AppTheme.textSecondary),
                            SizedBox(width: 4),
                            Text('Copy', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _openGoogleMaps(delivery.deliveryAddress),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.primaryBorder, width: 0.8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.navigation_rounded, size: 13, color: AppTheme.primary),
                            SizedBox(width: 4),
                            Text('Google Maps', style: TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 4. Items List (POS Preview)
          if (delivery.items.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.surfaceBorder, width: 0.8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ORDER ITEMS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        '${delivery.items.length} item(s)',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (delivery.pickupShops.isNotEmpty) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.primaryBorder, width: 0.8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.storefront_rounded, size: 14, color: AppTheme.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'COLLECT PARCEL: ${delivery.pickupShops.join(' • ')}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primary,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  ...delivery.items.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${item.quantity}x ${item.productName}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                                  ),
                                ),
                                Text(
                                  Formatters.currency(item.subtotal),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                                ),
                              ],
                            ),
                            if (item.shopName != null && item.shopName!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 1),
                                child: Text(
                                  'Counter: ${item.shopName}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      )),
                ],
              ),
            ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1),
          ),

          // 5. Financial Totals & Action Buttons (POS Style)
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              // Amounts
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'TOTAL: ${Formatters.currency(delivery.totalAmount)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  if (!isPaid && toCollect > 0)
                    Text(
                      'Due at Door: ${Formatters.currency(toCollect)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    )
                  else
                    const Text(
                      'Prepaid at Counter ✓',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.cashGreen,
                      ),
                    ),
                ],
              ),

              // Action Buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [

                  // Main Action Button (POS Payment Counter Style)
                  if (isPaid)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.cashGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.check_circle_rounded, size: 16),
                      label: const Text(
                        'HANDOVER',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, letterSpacing: 0.3),
                      ),
                      onPressed: () => _confirmDeliveryHandover(context, provider, delivery),
                    )
                  else
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.payment_rounded, size: 16),
                      label: Text(
                        'COLLECT ${Formatters.currency(toCollect)}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, letterSpacing: 0.3),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => DeliveryPaymentDialog(
                            delivery: delivery,
                            onConfirm: ({required paymentMethod, cashAmount, gpayAmount}) {
                              return provider.completeDelivery(
                                delivery: delivery,
                                paymentMethod: paymentMethod,
                                cashAmount: cashAmount,
                                gpayAmount: gpayAmount,
                              );
                            },
                          ),
                        );
                      },
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // 4. TAB 1: SHIFT COLLECTIONS & CASH RECONCILIATION SCREEN
  // ==========================================================================

  Widget _buildCollectionsTab(BuildContext context, DeliveryProvider provider, bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Shift Collections & Cash',
                style: TextStyle(
                  fontSize: isMobile ? 20 : 24,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Doorstep cash in hand & UPI reconciliation',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // KPI Summary Cards Grid (POS Metric Style)
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 600;

              return GridView.count(
                crossAxisCount: isSmall ? 2 : 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: isSmall ? 1.35 : 2.1,
                children: [
                  _buildMetricCard(
                    title: 'Cash in Hand',
                    value: Formatters.currency(provider.totalCashCollectedToday),
                    icon: Icons.payments_rounded,
                    color: AppTheme.cashGreen,
                    bgColor: AppTheme.cashGreenBg,
                    subtitle: 'Physical cash to turn in',
                  ),
                  _buildMetricCard(
                    title: 'GPay / UPI',
                    value: Formatters.currency(provider.totalGpayCollectedToday),
                    icon: Icons.qr_code_2_rounded,
                    color: AppTheme.upiBlue,
                    bgColor: AppTheme.upiBlueBg,
                    subtitle: 'Direct online payments',
                  ),
                  _buildMetricCard(
                    title: 'Total Shift Volume',
                    value: Formatters.currency(provider.totalCollectedToday),
                    icon: Icons.account_balance_wallet_rounded,
                    color: AppTheme.primary,
                    bgColor: AppTheme.primaryLight,
                    subtitle: 'All door collections',
                  ),
                  _buildMetricCard(
                    title: 'Delivered Today',
                    value: '${provider.completedCountToday} Orders',
                    icon: Icons.task_alt_rounded,
                    color: const Color(0xFFD97706),
                    bgColor: const Color(0xFFFEF3C7),
                    subtitle: 'Successful handovers',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),

          // Business Day Cycle Notice
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.surfaceBorder, width: 0.9),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.schedule_rounded, color: AppTheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Shift Cycle: 3:00 AM Daily Reset',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Collections and delivery metrics automatically reset at 3:00 AM daily for the new business day.',
                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withAlpha(40), width: 1.0),
        boxShadow: AppTheme.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 15, color: color),
              ),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 9.5, color: AppTheme.textMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // 5. TAB 2: DELIVERED HISTORY SCREEN (Matches Bill History Screen)
  // ==========================================================================

  Widget _buildHistoryTab(BuildContext context, DeliveryProvider provider, bool isMobile) {
    final historyList = provider.completedDeliveries;

    var filteredList = historyList;
    if (_historySearchQuery.isNotEmpty) {
      filteredList = filteredList.where((d) {
        final oNum = d.orderNumber.toLowerCase();
        final bNum = (d.billNumber ?? '').toLowerCase();
        final dispNum = d.billOrOrderNumber.toLowerCase();
        final dispId = d.displayIdentifier.toLowerCase();
        final name = d.customerName.toLowerCase();
        final phone = d.customerPhone.toLowerCase();
        final addr = d.deliveryAddress.toLowerCase();
        return oNum.contains(_historySearchQuery) ||
            bNum.contains(_historySearchQuery) ||
            dispNum.contains(_historySearchQuery) ||
            dispId.contains(_historySearchQuery) ||
            name.contains(_historySearchQuery) ||
            phone.contains(_historySearchQuery) ||
            addr.contains(_historySearchQuery);
      }).toList();
    }

    return Padding(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Delivered History',
                style: TextStyle(
                  fontSize: isMobile ? 20 : 24,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${historyList.length} delivered orders today (since 3:00 AM)',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Modern Capsule Search Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.cardBorder),
              boxShadow: AppTheme.shadowSoft,
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search delivered orders by customer, phone, or address...',
                hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppTheme.primary),
                suffixIcon: _historySearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18, color: AppTheme.textMuted),
                        onPressed: () => setState(() => _historySearchQuery = ''),
                      )
                    : null,
                filled: true,
                fillColor: Colors.transparent,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
              onChanged: (val) => setState(() => _historySearchQuery = val.trim().toLowerCase()),
            ),
          ),
          const SizedBox(height: 12),

          // History List
          Expanded(
            child: filteredList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: AppTheme.primaryLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.history_toggle_off_rounded, size: 36, color: AppTheme.primary),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No delivered orders today',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Delivery history resets daily at 3:00 AM.\nToday\'s completed deliveries will show here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    padding: const EdgeInsets.only(top: 4, bottom: 40),
                    itemCount: filteredList.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = filteredList[index];
                      return _buildHistoryCard(context, item);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, DeliveryOrder delivery) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder, width: 1),
        boxShadow: AppTheme.shadowCard,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.cashGreenBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.task_alt_rounded, color: AppTheme.cashGreen, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      delivery.displayIdentifier,
                      style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.textPrimary, fontSize: 14),
                    ),
                    Text(
                      Formatters.currency(delivery.totalAmount),
                      style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.cashGreen, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: AppTheme.cashGreenBg,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'DELIVERED',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.cashGreen),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${delivery.customerName} • ${delivery.customerPhone}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  delivery.deliveryAddress,
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (delivery.bill != null)
            IconButton(
              icon: const Icon(Icons.receipt_long_rounded, size: 20, color: AppTheme.primary),
              tooltip: 'View Receipt',
              visualDensity: VisualDensity.compact,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => BillReceiptDialog(bill: delivery.bill!),
                );
              },
            ),
        ],
      ),
    );
  }

  // ==========================================================================
  // 6. ACTIONS & HELPERS
  // ==========================================================================

  Future<void> _confirmDeliveryHandover(
    BuildContext context,
    DeliveryProvider provider,
    DeliveryOrder delivery,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, color: AppTheme.cashGreen),
            SizedBox(width: 8),
            Text('Complete Delivery', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          ],
        ),
        content: Text(
          'Confirm handover of Bill ${delivery.displayIdentifier} to ${delivery.customerName}?\n\nPayment was already completed at counter (₹0 to collect).',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cashGreen),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Handover', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final ok = await provider.completeDelivery(
        delivery: delivery,
        paymentMethod: delivery.bill?.paymentMethod ?? 'GPAY',
      );
      if (ok) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Bill ${delivery.displayIdentifier} marked as delivered!'),
            backgroundColor: AppTheme.cashGreen,
          ),
        );
      }
    }
  }

  Future<void> _makePhoneCall(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String phone, String orderNum) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final normalized = clean.startsWith('91') ? clean : '91$clean';
    final text = Uri.encodeComponent('Hello, I am arriving with your Chembikkal Food Court order #$orderNum.');
    final uri = Uri.parse('https://wa.me/$normalized?text=$text');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openGoogleMaps(String address) async {
    final encoded = Uri.encodeComponent(address);
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encoded');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _copyAddress(BuildContext context, String address) {
    Clipboard.setData(ClipboardData(text: address));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Delivery address copied to clipboard!'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
