import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/offline_sync_service.dart';
import '../../core/services/printer_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/pos_provider.dart';
import 'active_orders_screen.dart';
import 'bill_history_screen.dart';
import 'payment_counter_screen.dart';
import 'pos_screen.dart';
import 'printer_settings_screen.dart';

class MainLayoutScreen extends StatefulWidget {
  const MainLayoutScreen({super.key});

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  int _currentTabIndex = 0;

  void _switchToTab(int index) {
    setState(() => _currentTabIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosProvider>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;

        return Scaffold(
          backgroundColor: AppTheme.background,
          // Compact top header (separate for mobile vs desktop)
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(isMobile ? 54 : 64),
            child: isMobile
                ? _buildMobileHeader(context, pos)
                : _buildDesktopHeader(context, pos),
          ),
          // IndexedStack preserves active state of all views (cart, forms, filters)
          body: IndexedStack(
            index: _currentTabIndex,
            children: [
              const PosScreen(),
              ActiveOrdersScreen(onSwitchToPos: () => _switchToTab(0)),
              PaymentCounterScreen(onSwitchToPos: () => _switchToTab(0)),
              const BillHistoryScreen(),
            ],
          ),
          // Bottom Navigation Bar only shown on Mobile
          bottomNavigationBar: isMobile ? _buildMobileBottomNav(pos) : null,
        );
      },
    );
  }

  // --------------------------------------------------------------------------
  // Mobile Header matching Image 2 POSWare style
  // --------------------------------------------------------------------------
  Widget _buildMobileHeader(BuildContext context, PosProvider pos) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0x0E000000), width: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Logo & Title: Red receipt icon + CFC POS
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primaryBorder.withAlpha(120), width: 0.8),
                    ),
                    child: const Icon(Icons.receipt_long_rounded, color: AppTheme.primary, size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'CFC POS',
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),

              // Status Badges & Quick Action
              Row(
                children: [
                  // Active Order Pill (if any)
                  if (pos.currentActiveOrderNumber != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primaryBorder, width: 0.8),
                      ),
                      child: Text(
                        '#${pos.currentActiveOrderNumber}',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary),
                      ),
                    ),

                  // Offline Sync Queue indicator
                  Consumer<OfflineSyncService>(
                    builder: (context, syncSvc, _) {
                      if (!syncSvc.hasPendingItems) return const SizedBox.shrink();
                      return Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade300, width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 8,
                              height: 8,
                              child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.orange.shade800),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${syncSvc.pendingCount} queued',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade900,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // Supabase Live/Offline pill
                  Consumer<OfflineSyncService>(
                    builder: (context, syncSvc, _) {
                      final isOnline = syncSvc.isOnline;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: isOnline ? AppTheme.cashGreenBg : Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isOnline ? AppTheme.cashGreen.withAlpha(80) : Colors.amber.shade300,
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                              size: 12,
                              color: isOnline ? AppTheme.cashGreen : Colors.amber.shade900,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isOnline ? 'Online' : 'Offline (Local)',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isOnline ? AppTheme.cashGreen : Colors.amber.shade900,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(width: 6),

                  // Top Right Printer Status Badge (Indicator + Tap to Configure)
                  const _PrinterStatusHeaderBadge(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Desktop Header
  // --------------------------------------------------------------------------
  Widget _buildDesktopHeader(BuildContext context, PosProvider pos) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.surfaceBorder, width: 0.9)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Brand / Logo
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.primaryBorder, width: 0.8),
                  ),
                  child: const Icon(Icons.receipt_long_rounded, color: AppTheme.primary, size: 20),
                ),
                const SizedBox(width: 10),
                const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CFC RESTAURANT POS',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      '5 Shops Unified Food Court',
                      style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(width: 28),

            // Center Navigation Tabs
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDesktopNavTab(0, 'POS Terminal', Icons.point_of_sale_rounded),
                    const SizedBox(width: 6),
                    _buildDesktopNavTab(
                      1,
                      'Active Orders',
                      Icons.receipt_long_rounded,
                      badgeCount: pos.activeOrders.length,
                    ),
                    const SizedBox(width: 6),
                    _buildDesktopNavTab(
                      2,
                      'Payments',
                      Icons.payment_rounded,
                      badgeCount: pos.unpaidBills.length,
                    ),
                    const SizedBox(width: 6),
                    _buildDesktopNavTab(3, 'Daily Sales', Icons.storefront_rounded),
                  ],
                ),
              ),
            ),

            // Right Status & Clock
            Row(
              children: [
                // Offline Sync Queue indicator
                Consumer<OfflineSyncService>(
                  builder: (context, syncSvc, _) {
                    if (!syncSvc.hasPendingItems) return const SizedBox.shrink();
                    return Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.orange.shade300, width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange.shade800),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Offline Queue: ${syncSvc.pendingCount} syncing',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade900,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // Online/Offline Supabase indicator
                Consumer<OfflineSyncService>(
                  builder: (context, syncSvc, _) {
                    final isOnline = syncSvc.isOnline;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isOnline ? AppTheme.cashGreenBg : Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isOnline ? AppTheme.cashGreen.withAlpha(80) : Colors.amber.shade300,
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                            size: 14,
                            color: isOnline ? AppTheme.cashGreen : Colors.amber.shade900,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isOnline ? 'Online' : 'Offline (Local Mode)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isOnline ? AppTheme.cashGreen : Colors.amber.shade900,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(width: 14),

                // Isolated Live Clock (does not rebuild parent)
                const _LiveClockWidget(),

                const SizedBox(width: 14),

                // Top Right Printer Status Badge
                const _PrinterStatusHeaderBadge(isCompact: false),
              ],
            ),
          ],
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

  // --------------------------------------------------------------------------
  // Mobile Thumb-Friendly Bottom Navigation Bar (~56px)
  // --------------------------------------------------------------------------
  Widget _buildMobileBottomNav(PosProvider pos) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0x0E000000), width: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 18,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(
            children: [
              _buildBottomNavItem(
                index: 0,
                label: 'POS',
                icon: Icons.point_of_sale_rounded,
              ),
              _buildBottomNavItem(
                index: 1,
                label: 'Orders',
                icon: Icons.receipt_long_rounded,
                badgeCount: pos.activeOrders.length,
              ),
              _buildBottomNavItem(
                index: 2,
                label: 'Payments',
                icon: Icons.payment_rounded,
                badgeCount: pos.unpaidBills.length,
              ),
              _buildBottomNavItem(
                index: 3,
                label: 'Daily Sales',
                icon: Icons.storefront_rounded,
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
          splashColor: AppTheme.primaryLight,
          highlightColor: Colors.transparent,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.symmetric(
                      horizontal: isSelected ? 12 : 6,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primaryLight : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: AnimatedScale(
                      scale: isSelected ? 1.06 : 1.0,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        icon,
                        size: 20,
                        color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  if (badgeCount != null && badgeCount > 0)
                    Positioned(
                      top: -2,
                      right: isSelected ? 4 : -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withAlpha(80),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                        alignment: Alignment.center,
                        child: Text(
                          '$badgeCount',
                          style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  letterSpacing: -0.1,
                  color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveClockWidget extends StatefulWidget {
  const _LiveClockWidget();

  @override
  State<_LiveClockWidget> createState() => _LiveClockWidgetState();
}

class _LiveClockWidgetState extends State<_LiveClockWidget> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          Formatters.formatTime(_now),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
        ),
        Text(
          Formatters.formatDate(_now),
          style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}

class _PrinterStatusHeaderBadge extends StatelessWidget {
  final bool isCompact;

  const _PrinterStatusHeaderBadge({this.isCompact = false});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PrinterService(),
      builder: (context, _) {
        final printerSvc = PrinterService();
        final isConnected = printerSvc.isReadyToPrint;

        final Color bgColor = isConnected ? AppTheme.cashGreenBg : Colors.amber.shade50;
        final Color borderColor = isConnected ? AppTheme.cashGreen.withAlpha(80) : Colors.amber.shade400;
        final Color textColor = isConnected ? AppTheme.cashGreen : Colors.amber.shade900;
        final IconData icon = isConnected ? Icons.print_rounded : Icons.print_disabled_rounded;
        final String label = isConnected ? 'Connected' : 'Disconnected';

        return InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()),
            );
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 13, color: textColor),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
