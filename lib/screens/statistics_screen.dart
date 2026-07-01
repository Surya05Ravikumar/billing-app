import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../utils/app_store.dart';
import '../utils/theme.dart';
import '../widgets/shared.dart';
import 'orders_list_screen.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final fmt = NumberFormat('#,##0.00', 'en_IN');

    // Revenue calculations
    final double totalRevenue = store.orders.fold(
        0.0,
        (sum, o) =>
            sum + (o.isPaid ? o.totalAmount : (o.advanceAmount ?? 0.0)));
    final double totalPendingPayments = store.totalPendingPayments;
    final int totalOrders = store.orders.length;
    final double avgOrderValue = totalOrders == 0
        ? 0.0
        : (store.orders.fold(0.0, (sum, o) => sum + o.totalAmount) / totalOrders);

    // Status breakdown counts
    final int pendingCount = store.orders.where((o) => o.status == OrderStatus.pending).length;
    final int inProgressCount = store.orders.where((o) => o.status == OrderStatus.inProgress).length;
    final int completedCount = store.orders.where((o) => o.status == OrderStatus.completed).length;
    final int deliveredCount = store.orders.where((o) => o.status == OrderStatus.delivered).length;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Statistics'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textDark,
        elevation: 0,
        shape: const Border(
          bottom: BorderSide(color: AppTheme.border, width: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Overview Stat Cards
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _StatItemCard(
                  label: 'Total Revenue',
                  value: '₹${fmt.format(totalRevenue)}',
                  color: AppTheme.success,
                  icon: Icons.currency_rupee,
                ),
                _StatItemCard(
                  label: 'Pending Payments',
                  value: '₹${fmt.format(totalPendingPayments)}',
                  color: AppTheme.warning,
                  icon: Icons.account_balance_wallet_outlined,
                ),
                _StatItemCard(
                  label: 'Total Orders',
                  value: totalOrders.toString(),
                  color: AppTheme.info,
                  icon: Icons.shopping_bag_outlined,
                ),
                _StatItemCard(
                  label: 'Avg Order Value',
                  value: '₹${fmt.format(avgOrderValue)}',
                  color: Colors.purple,
                  icon: Icons.analytics_outlined,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 2. Order Status Chart/Breakdown Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Order Status Breakdown',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _StatusProgressBar(
                    label: 'Pending Orders',
                    count: pendingCount,
                    total: totalOrders,
                    color: AppTheme.accent,
                  ),
                  const SizedBox(height: 12),
                  _StatusProgressBar(
                    label: 'In Progress',
                    count: inProgressCount,
                    total: totalOrders,
                    color: AppTheme.info,
                  ),
                  const SizedBox(height: 12),
                  _StatusProgressBar(
                    label: 'Completed (Ready)',
                    count: completedCount,
                    total: totalOrders,
                    color: AppTheme.warning,
                  ),
                  const SizedBox(height: 12),
                  _StatusProgressBar(
                    label: 'Delivered',
                    count: deliveredCount,
                    total: totalOrders,
                    color: AppTheme.success,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 3. Upcoming due list
            const SectionLabel(
              'UPCOMING DUE (1 WEEK)',
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
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        'No orders due this week.',
                        style: TextStyle(color: AppTheme.textMid, fontSize: 13),
                      ),
                    ),
                  ),
                );
              } else {
                return Column(
                  children: upcomingOrders.map((order) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _StatRecentOrderCard(order: order),
                      )).toList(),
                );
              }
            }(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _StatItemCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatItemCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMid, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _StatusProgressBar extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;

  const _StatusProgressBar({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final double ratio = total == 0 ? 0.0 : count / total;
    final percentStr = (ratio * 100).toStringAsFixed(0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppTheme.textMid, fontWeight: FontWeight.w500),
            ),
            Text(
              '$count ($percentStr%)',
              style: const TextStyle(fontSize: 12, color: AppTheme.textDark, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            backgroundColor: AppTheme.border,
            color: color,
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}

class _StatRecentOrderCard extends StatelessWidget {
  final Order order;
  const _StatRecentOrderCard({required this.order});

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
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Icon(Icons.content_cut, size: 16, color: AppTheme.accent),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.customerName,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textDark),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "${order.items.length} item${order.items.length != 1 ? 's' : ''} · Due $dateStr",
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMid),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${fmt.format(order.totalAmount)}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.textDark),
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
