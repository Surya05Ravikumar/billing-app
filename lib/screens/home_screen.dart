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
import 'invoice_preview_screen.dart';
import 'statistics_screen.dart';
import '../utils/pdf_helper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;

  final List<Widget> _tabs = [
    const _HomeOrdersTab(),
    const StatisticsScreen(),
    const CustomersScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppStore>().syncAndPull();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<AppStore>().syncAndPull();
    }
  }

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
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics_outlined),
            activeIcon: Icon(Icons.analytics),
            label: 'Statistics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Customers',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

// ---- Tab 0: Home Orders Tab (Redesigned Dashboard) ----
class _HomeOrdersTab extends StatefulWidget {
  const _HomeOrdersTab();

  @override
  State<_HomeOrdersTab> createState() => _HomeOrdersTabState();
}

class _HomeOrdersTabState extends State<_HomeOrdersTab> {
  String _query = '';
  OrderStatus? _filterStatus;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final today = DateFormat('EEEE, dd MMM').format(DateTime.now());

    // Filter and search orders
    final orders = store.orders.where((o) {
      final q = _query.toLowerCase().trim();
      final matchQ = q.isEmpty ||
          o.customerName.toLowerCase().contains(q) ||
          o.customerPhone.contains(q) ||
          (o.invoiceNo ?? '').toLowerCase().contains(q);
      final matchStatus = _filterStatus == null || o.status == _filterStatus;
      return matchQ && matchStatus;
    }).toList();

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
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.accent.withOpacity(0.2), width: 1.5),
                image: const DecorationImage(
                  image: AssetImage('assets/images/logo.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Bhuvana Designers',
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
      ),
      body: Column(
        children: [
          // Search & Filters Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  style: const TextStyle(color: AppTheme.textDark, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search by customer, phone, invoice...',
                    hintStyle: const TextStyle(color: AppTheme.textLight, fontSize: 14),
                    prefixIcon: const Icon(Icons.search, color: AppTheme.textMid, size: 20),
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _HomeFilterChip(
                        label: 'All',
                        selected: _filterStatus == null,
                        onSelected: (_) => setState(() => _filterStatus = null),
                      ),
                      ...OrderStatus.values.map((s) => _HomeFilterChip(
                            label: '${s.emoji} ${s.label}',
                            selected: _filterStatus == s,
                            onSelected: (_) => setState(() =>
                                _filterStatus = _filterStatus == s ? null : s),
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Orders List
          Expanded(
            child: orders.isEmpty
                ? EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: _query.isNotEmpty || _filterStatus != null
                        ? 'No orders found'
                        : 'No orders yet',
                    subtitle: 'Create a new order to get started',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      return _HomeOrderCard(order: orders[index]);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final order = await Navigator.push<Order?>(
            context,
            MaterialPageRoute(builder: (_) => const CreateOrderScreen()),
          );
          if (order != null && context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InvoicePreviewScreen(order: order),
              ),
            );
          }
        },
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

class _HomeFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final void Function(bool) onSelected;

  const _HomeFilterChip({required this.label, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppTheme.textDark)),
        selected: selected,
        onSelected: onSelected,
        backgroundColor: AppTheme.surface,
        selectedColor: AppTheme.accent,
        checkmarkColor: Colors.white,
        side: const BorderSide(color: AppTheme.border),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }
}

// ---- Custom Order Card as requested in Screenshot ----
class _HomeOrderCard extends StatelessWidget {
  final Order order;
  const _HomeOrderCard({required this.order});

  void _print(BuildContext context, AppStore store) async {
    await PdfHelper.printInvoice(context, order, store);
  }

  void _share(BuildContext context, AppStore store) async {
    await PdfHelper.shareInvoice(context, order, store);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final fmt = NumberFormat('#,##0.00', 'en_IN');
    final dateStr = DateFormat('dd MMM, yy').format(order.orderDate);

    final bool isPaid = order.isPaid;
    final String statusText = isPaid ? 'SALE : PAID' : 'SALE : UNPAID';
    final Color badgeBg = isPaid ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0);
    final Color badgeText = isPaid ? const Color(0xFF2E7D32) : const Color(0xFFE65100);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderDetailScreen(orderId: order.id),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.01),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Customer Name & Invoice No
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    order.customerName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '#${order.invoiceNo ?? "1001"}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Row 2: Status Badge & Date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: badgeText,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                Text(
                  dateStr,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Row 3: Total, Balance & Quick Actions
            Row(
              children: [
                // Total
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(fontSize: 12, color: AppTheme.textLight, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹ ${fmt.format(order.totalAmount)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
                // Balance
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Balance',
                        style: TextStyle(fontSize: 12, color: AppTheme.textLight, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹ ${fmt.format(order.isPaid ? 0.0 : order.pendingAmount)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Actions
                IconButton(
                  icon: const Icon(Icons.print_outlined, color: AppTheme.textLight, size: 20),
                  onPressed: () => _print(context, store),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Print Invoice',
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.reply_outlined, color: AppTheme.textLight, size: 20), // curved share arrow
                  onPressed: () => _share(context, store),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Share Invoice',
                ),
                const SizedBox(width: 12),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_outlined, color: AppTheme.textLight, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'More options',
                  onSelected: (val) async {
                    if (val == 'edit') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreateOrderScreen(existingOrder: order),
                        ),
                      );
                    } else if (val == 'delete') {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Delete Order?'),
                          content: const Text('This action cannot be undone.'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel')),
                            TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                                child: const Text('Delete')),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        store.deleteOrder(order.id);
                      }
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit Order')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete Order')),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
