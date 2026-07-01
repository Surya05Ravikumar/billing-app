// lib/screens/orders_list_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../utils/app_store.dart';
import '../utils/theme.dart';
import '../widgets/shared.dart';
import 'create_order_screen.dart';
import 'invoice_preview_screen.dart';

class OrdersListScreen extends StatefulWidget {
  const OrdersListScreen({super.key});

  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen> {
  String _query = '';
  OrderStatus? _filterStatus;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();

    var orders = store.orders.where((o) {
      final q = _query.toLowerCase();
      final matchQ = q.isEmpty ||
          o.customerName.toLowerCase().contains(q) ||
          o.customerPhone.contains(q);
      final matchStatus = _filterStatus == null || o.status == _filterStatus;
      return matchQ && matchStatus;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final order = await Navigator.push<Order?>(
                context,
                MaterialPageRoute(builder: (_) => const CreateOrderScreen()),
              );
              if (order != null && !order.isPaid && context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InvoicePreviewScreen(order: order),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search + Filter
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Column(
              children: [
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  style: const TextStyle(color: AppTheme.textDark, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search by name or phone...',
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
                      _FilterChip(
                        label: 'All',
                        selected: _filterStatus == null,
                        onSelected: (_) => setState(() => _filterStatus = null),
                      ),
                      ...OrderStatus.values.map((s) => _FilterChip(
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

          // Orders
          Expanded(
            child: orders.isEmpty
                ? EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: _query.isNotEmpty || _filterStatus != null
                        ? 'No orders found'
                        : 'No orders yet',
                    subtitle: 'Create your first order to get started',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _OrderCard(order: orders[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final void Function(bool) onSelected;

  const _FilterChip({required this.label, required this.selected, required this.onSelected});

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

class _OrderCard extends StatelessWidget {
  final Order order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'en_IN');

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order.id)),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order.customerName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppTheme.textDark)),
                      const SizedBox(height: 2),
                      Text(order.customerPhone,
                          style: const TextStyle(fontSize: 12, color: AppTheme.textMid)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₹${fmt.format(order.totalAmount)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: AppTheme.textDark)),
                    const SizedBox(height: 4),
                    StatusBadge(order.status),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                _InfoChip(
                  icon: Icons.checkroom_outlined,
                  text: '${order.items.length} item${order.items.length != 1 ? 's' : ''}',
                ),
                const SizedBox(width: 8),
                _InfoChip(
                  icon: Icons.local_shipping_outlined,
                  text: 'Due ${DateFormat('dd MMM').format(order.deliveryDate)}',
                ),
                const Spacer(),
                if (order.isPaid)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 12, color: AppTheme.success),
                        SizedBox(width: 4),
                        Text('Paid',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.success)),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('₹${fmt.format(order.pendingAmount)} due',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.accent)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppTheme.textLight),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, color: AppTheme.textMid)),
      ],
    );
  }
}

// ---- Order Detail Screen ----
class OrderDetailScreen extends StatelessWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final order = store.orders.where((o) => o.id == orderId).firstOrNull;

    if (order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order')),
        body: const Center(child: Text('Order not found')),
      );
    }

    final fmt = NumberFormat('#,##0.00', 'en_IN');

    return Scaffold(
      appBar: AppBar(
        title: Text(order.customerName),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => CreateOrderScreen(existingOrder: order),
              ),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'delete') {
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
                if (confirm == true && context.mounted) {
                  store.deleteOrder(order.id);
                  Navigator.pop(context);
                }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'delete', child: Text('Delete Order')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(order.customerName,
                              style: const TextStyle(
                                  color: AppTheme.textDark,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18)),
                          Text(order.customerPhone,
                              style: const TextStyle(
                                  color: AppTheme.textMid,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                    StatusBadge(order.status),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _DetailStat('Order Date',
                        DateFormat('dd MMM yyyy').format(order.orderDate), AppTheme.textDark),
                    const SizedBox(width: 20),
                    _DetailStat('Delivery',
                        DateFormat('dd MMM yyyy').format(order.deliveryDate), AppTheme.accent),
                    const SizedBox(width: 20),
                    _DetailStat('Total',
                        '₹${fmt.format(order.totalAmount)}', AppTheme.textDark),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Update Status
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('UPDATE STATUS'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: OrderStatus.values.map((s) {
                    final isSelected = order.status == s;
                    final color = statusColor(s);
                    return GestureDetector(
                      onTap: () {
                        final updated = Order(
                          id: order.id,
                          invoiceNo: order.invoiceNo,
                          customerId: order.customerId,
                          customerName: order.customerName,
                          customerPhone: order.customerPhone,
                          orderDate: order.orderDate,
                          deliveryDate: order.deliveryDate,
                          items: order.items,
                          status: s,
                          isPaid: order.isPaid,
                          advanceAmount: order.advanceAmount,
                        );
                        store.updateOrder(updated);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? color : color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: color.withOpacity(0.3)),
                        ),
                        child: Text('${s.emoji} ${s.label}',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : color)),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Items
          const SectionLabel('GARMENT ITEMS'),
          const SizedBox(height: 10),
          ...order.items.map((item) => _ItemDetailCard(item: item)),

          const SizedBox(height: 14),

          // Payment
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              children: [
                const SectionLabel('PAYMENT'),
                const SizedBox(height: 14),
                _PayRow('Total Amount', '₹${fmt.format(order.totalAmount)}', bold: true),
                if (order.advanceAmount != null) ...[
                  const SizedBox(height: 8),
                  _PayRow('Advance Paid', '₹${fmt.format(order.advanceAmount!)}',
                      color: AppTheme.success),
                  const SizedBox(height: 8),
                  _PayRow('Balance Due', '₹${fmt.format(order.pendingAmount)}',
                      color: AppTheme.accent, bold: true),
                ],
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Mark as fully paid',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    Switch.adaptive(
                      value: order.isPaid,
                      activeColor: AppTheme.success,
                      onChanged: (v) {
                        final updated = Order(
                          id: order.id,
                          invoiceNo: order.invoiceNo,
                          customerId: order.customerId,
                          customerName: order.customerName,
                          customerPhone: order.customerPhone,
                          orderDate: order.orderDate,
                          deliveryDate: order.deliveryDate,
                          items: order.items,
                          status: order.status,
                          isPaid: v,
                          advanceAmount: v ? order.totalAmount : 0.0,
                        );
                        store.updateOrder(updated);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Share Invoice / Receipt
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InvoicePreviewScreen(order: order),
              ),
            ),
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('Share Invoice / Receipt'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _DetailStat extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  const _DetailStat(this.label, this.value, this.valueColor);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10,
                color: AppTheme.textMid,
                letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                color: valueColor, fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _PayRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool bold;

  const _PayRow(this.label, this.value, {this.color, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 14,
                color: AppTheme.textMid,
                fontWeight: bold ? FontWeight.w600 : FontWeight.w400)),
        Text(value,
            style: TextStyle(
                fontSize: bold ? 16 : 14,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: color ?? AppTheme.textDark)),
      ],
    );
  }
}

class _ItemDetailCard extends StatefulWidget {
  final OrderItem item;
  const _ItemDetailCard({required this.item});

  @override
  State<_ItemDetailCard> createState() => _ItemDetailCardState();
}

class _ItemDetailCardState extends State<_ItemDetailCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'en_IN');
    final item = widget.item;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.checkroom_outlined, size: 18, color: AppTheme.primary),
            ),
            title: Text(item.displayName,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            subtitle: Text(
                'Qty: ${item.quantity} × ₹${fmt.format(item.price)}  =  ₹${fmt.format(item.total)}',
                style: const TextStyle(fontSize: 12, color: AppTheme.textMid)),
            trailing: IconButton(
              icon: Icon(
                  _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: AppTheme.textLight),
              onPressed: () => setState(() => _expanded = !_expanded),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.measurements.isNotEmpty) ...[
                    const Text('Measurements',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textMid,
                            letterSpacing: 0.5)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: item.measurements
                          .where((m) => m.value != null && m.value!.isNotEmpty)
                          .map((m) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(m.name,
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color: AppTheme.textLight)),
                                    Text('${m.value}" in',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textDark)),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                  if (item.notes != null && item.notes!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Notes',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textMid,
                            letterSpacing: 0.5)),
                    const SizedBox(height: 6),
                    Text(item.notes!,
                        style: const TextStyle(fontSize: 13, color: AppTheme.textDark)),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
