// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../utils/app_store.dart';
import '../utils/theme.dart';
import '../widgets/shared.dart';
import 'create_order_screen.dart';
import 'orders_list_screen.dart';
import 'customers_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = [
    const _DashboardTab(),
    const OrdersListScreen(),
    const CustomersScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: Colors.white,
        selectedItemColor: AppTheme.accent,
        unselectedItemColor: AppTheme.textMid,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        elevation: 8,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Customers',
          ),
        ],
      ),
    );
  }
}

// ---- Tab 0: Dashboard Tab ----
class _DashboardTab extends StatelessWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final fmt = NumberFormat('#,##0.00', 'en_IN');
    final today = DateFormat('EEEE, dd MMM').format(DateTime.now());

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textDark,
        elevation: 0,
        shape: const Border(
          bottom: BorderSide(color: AppTheme.border, width: 1),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.content_cut, color: AppTheme.accent, size: 16),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Bhuvana Tailoring',
                  style: TextStyle(
                    color: AppTheme.textDark,
                    fontSize: 18,
                    fontFamily: 'serif',
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  today,
                  style: const TextStyle(
                    color: AppTheme.textMid,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppTheme.textDark, size: 22),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats Grid with 1.7 ratio to compress empty space inside cards
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.7, // Flatten stats cards perfectly
              children: [
                StatCard(
                  label: "Today's Orders",
                  value: store.todayOrdersCount.toString(),
                  color: AppTheme.accent,
                  icon: Icons.receipt_long_outlined,
                ),
                StatCard(
                  label: 'Pending Deliveries',
                  value: store.pendingDeliveries.toString(),
                  color: AppTheme.warning,
                  icon: Icons.local_shipping_outlined,
                ),
                StatCard(
                  label: 'Completed',
                  value: store.completedOrders.toString(),
                  color: AppTheme.success,
                  icon: Icons.check_circle_outline,
                ),
                StatCard(
                  label: 'Pending Payments',
                  value: '₹${fmt.format(store.totalPendingPayments)}',
                  color: AppTheme.info,
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Filter upcoming due orders (delivery date between today and 1 week from now, and not delivered)
            SectionLabel(
              'UPCOMING DUE (1 WEEK)',
              trailing: store.orders.isNotEmpty
                  ? TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const OrdersListScreen()),
                        );
                      },
                      child: const Text('See all'),
                    )
                  : null,
            ),
            const SizedBox(height: 12),

            () {
              final now = DateTime.now();
              final todayStart = DateTime(now.year, now.month, now.day);
              final oneWeekLater = todayStart.add(const Duration(days: 7));

              final upcomingOrders = store.orders.where((o) {
                final dDate = DateTime(o.deliveryDate.year, o.deliveryDate.month, o.deliveryDate.day);
                return !dDate.isBefore(todayStart) &&
                       !dDate.isAfter(oneWeekLater) &&
                       o.status != OrderStatus.delivered;
              }).toList();

              if (upcomingOrders.isEmpty) {
                return EmptyState(
                  icon: Icons.assignment_outlined,
                  title: 'No upcoming deliveries',
                  subtitle: 'No orders due for delivery in the next 7 days.',
                  action: ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New Order'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CreateOrderScreen()),
                    ),
                  ),
                );
              } else {
                return Column(
                  children: upcomingOrders.map((order) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _RecentOrderCard(order: order),
                      )).toList(),
                );
              }
            }(),

            const SizedBox(height: 50),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateOrderScreen()),
        ),
        backgroundColor: AppTheme.accent,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'New Order',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
    );
  }
}

class _RecentOrderCard extends StatelessWidget {
  final Order order;
  const _RecentOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'en_IN');
    final dateStr = DateFormat('dd MMM').format(order.deliveryDate);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderDetailScreen(orderId: order.id),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Icon(Icons.content_cut, size: 18, color: AppTheme.accent),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.customerName,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textDark),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "${order.items.length} item${order.items.length != 1 ? 's' : ''} · Due $dateStr",
                    style: const TextStyle(fontSize: 15, color: AppTheme.textMid),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${fmt.format(order.totalAmount)}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppTheme.textDark),
                ),
                const SizedBox(height: 4),
                StatusBadge(order.status),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
