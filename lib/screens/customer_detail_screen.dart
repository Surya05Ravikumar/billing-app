// lib/screens/customer_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../utils/app_store.dart';
import '../utils/theme.dart';
import '../widgets/shared.dart';
import 'orders_list_screen.dart';
import 'invoice_preview_screen.dart';

class CustomerDetailScreen extends StatefulWidget {
  final Customer customer;
  const CustomerDetailScreen({super.key, required this.customer});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  late Customer _currentCustomer;

  @override
  void initState() {
    super.initState();
    _currentCustomer = widget.customer;
  }

  void _showEditProfile() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileSheet(
        customer: _currentCustomer,
        onSaved: (updated) {
          setState(() {
            _currentCustomer = updated;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    
    // Refresh customer from store if updated elsewhere
    final refreshed = store.customers.firstWhere(
      (c) => c.id == _currentCustomer.id,
      orElse: () => _currentCustomer,
    );
    _currentCustomer = refreshed;

    final customerOrders = store.orders
        .where((o) => o.customerId == _currentCustomer.id)
        .toList();
    
    // Sort chronological: most recent first
    customerOrders.sort((a, b) => b.orderDate.compareTo(a.orderDate));

    // Stats calculations
    final totalOrders = customerOrders.length;
    final totalPaid = customerOrders.fold<double>(
      0.0,
      (sum, o) => sum + (o.isPaid ? o.totalAmount : (o.advanceAmount ?? 0.0)),
    );
    final totalDue = customerOrders.fold<double>(
      0.0,
      (sum, o) => sum + (o.isPaid ? 0.0 : o.pendingAmount),
    );

    // Compute latest measurements per category
    final Map<String, List<MeasurementField>> latestMeasurements = {};
    for (final cat in store.categories) {
      for (final order in customerOrders) {
        final matchingItem = order.items.where((item) => item.categoryId == cat.id).firstOrNull;
        if (matchingItem != null && matchingItem.measurements.isNotEmpty) {
          latestMeasurements[cat.name] = matchingItem.measurements;
          break;
        }
      }
    }

    final fmt = NumberFormat('#,##0.00', 'en_IN');

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Customer Profile'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: _showEditProfile,
            tooltip: 'Edit Profile',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header Panel
            _buildProfileHeader(refreshed),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Financial Stats Cards
                  _buildStatsSection(totalOrders, totalPaid, totalDue, fmt),
                  const SizedBox(height: 24),

                  // Latest Measurements section
                  _buildMeasurementsSection(latestMeasurements, store.categories),
                  const SizedBox(height: 24),

                  // Complete Order History Timeline
                  _buildOrderHistorySection(customerOrders, fmt),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(Customer customer) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppTheme.border, width: 1),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppTheme.primary.withOpacity(0.08),
            child: Text(
              customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: AppTheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            customer.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.phone_android_outlined, size: 14, color: AppTheme.textLight),
              const SizedBox(width: 4),
              Text(
                customer.phone,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppTheme.textMid,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (customer.address != null && customer.address!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.accent),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      customer.address!,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppTheme.textMid,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsSection(int totalOrders, double totalPaid, double totalDue, NumberFormat fmt) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: 'Orders Count',
            value: '$totalOrders',
            icon: Icons.receipt_long_outlined,
            color: AppTheme.info,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            title: 'Total Paid',
            value: '₹${fmt.format(totalPaid)}',
            icon: Icons.check_circle_outlined,
            color: AppTheme.success,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            title: 'Balance Due',
            value: '₹${fmt.format(totalDue)}',
            icon: Icons.pending_actions_outlined,
            color: AppTheme.accent,
          ),
        ),
      ],
    );
  }

  Widget _buildMeasurementsSection(
    Map<String, List<MeasurementField>> latestMeasurements,
    List<GarmentCategory> categories,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'LATEST SAVED MEASUREMENTS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppTheme.textMid,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        if (latestMeasurements.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Row(
              children: [
                Icon(Icons.straighten_outlined, color: AppTheme.textLight),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No measurements recorded yet. Creating orders will save measurements automatically.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMid),
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: latestMeasurements.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final catName = latestMeasurements.keys.elementAt(index);
              final fields = latestMeasurements[catName]!;
              return _MeasurementCard(categoryName: catName, fields: fields);
            },
          ),
      ],
    );
  }

  Widget _buildOrderHistorySection(List<Order> orders, NumberFormat fmt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ORDER HISTORY',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppTheme.textMid,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        if (orders.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Center(
              child: Column(
                children: [
                  Icon(Icons.history_toggle_off_outlined, color: AppTheme.textLight, size: 36),
                  SizedBox(height: 8),
                  Text('No past orders found', style: TextStyle(color: AppTheme.textMid, fontSize: 13)),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final o = orders[index];
              return Container(
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OrderDetailScreen(orderId: o.id),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '#${o.invoiceNo ?? "1001"}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              StatusBadge(o.status),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      o.items.map((i) => i.customName ?? i.categoryName).join(', '),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textDark,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Delivery due: ${DateFormat('dd MMM yyyy').format(o.deliveryDate)}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: AppTheme.textLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '₹${fmt.format(o.totalAmount)}',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  if (o.isPaid)
                                    const Text('Paid', style: TextStyle(fontSize: 13, color: AppTheme.success, fontWeight: FontWeight.bold))
                                  else
                                    Text('₹${fmt.format(o.pendingAmount)} due', style: const TextStyle(fontSize: 13, color: AppTheme.accent, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: const Icon(Icons.receipt_outlined, size: 14, color: AppTheme.accent),
                                label: const Text(
                                  'View Receipt',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.accent,
                                  ),
                                ),
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => InvoicePreviewScreen(order: o),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.textDark,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textLight,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _MeasurementCard extends StatefulWidget {
  final String categoryName;
  final List<MeasurementField> fields;

  const _MeasurementCard({
    required this.categoryName,
    required this.fields,
  });

  @override
  State<_MeasurementCard> createState() => _MeasurementCardState();
}

class _MeasurementCardState extends State<_MeasurementCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final validFields = widget.fields.where((f) => f.value != null && f.value!.isNotEmpty).toList();
    
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          ListTile(
            onTap: () => setState(() => _expanded = !_expanded),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.straighten, size: 18, color: AppTheme.accent),
            ),
            title: Text(
              widget.categoryName,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textDark),
            ),
            subtitle: Text(
              '${validFields.length} values saved',
              style: const TextStyle(fontSize: 14, color: AppTheme.textLight),
            ),
            trailing: Icon(
              _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 20,
              color: AppTheme.textLight,
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: validFields.isEmpty
                  ? const Text('All values are empty', style: TextStyle(fontSize: 14, color: AppTheme.textLight))
                  : GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 2.2,
                      ),
                      itemCount: validFields.length,
                      itemBuilder: (context, index) {
                        final f = validFields[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                f.name,
                                style: const TextStyle(fontSize: 12, color: AppTheme.textLight),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${f.value} in',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textDark,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  final Customer customer;
  final void Function(Customer) onSaved;

  const _EditProfileSheet({
    required this.customer,
    required this.onSaved,
  });

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addressCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.customer.name);
    _phoneCtrl = TextEditingController(text: widget.customer.phone);
    _addressCtrl = TextEditingController(text: widget.customer.address ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final store = context.read<AppStore>();

    final updated = Customer(
      id: widget.customer.id,
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      createdAt: widget.customer.createdAt,
    );

    await store.updateCustomer(updated);
    widget.onSaved(updated);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Edit Customer Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textDark),
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Full Name',
                controller: _nameCtrl,
                validator: (v) => v!.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Phone Number',
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                validator: (v) => v!.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Address Details',
                controller: _addressCtrl,
                maxLines: 2,
                hint: 'House name, Street, Landmark...',
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                child: const Text('Save Profile Details'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
