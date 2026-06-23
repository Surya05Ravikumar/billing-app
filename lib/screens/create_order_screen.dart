// lib/screens/create_order_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import '../models/models.dart';
import '../utils/app_store.dart';
import '../utils/theme.dart';
import '../widgets/shared.dart';

const _uuid = Uuid();

class CreateOrderScreen extends StatefulWidget {
  final Order? existingOrder;
  const CreateOrderScreen({super.key, this.existingOrder});

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final _formKey = GlobalKey<FormState>();

  // Customer fields
  Customer? _selectedCustomer;
  final _customerNameCtrl = TextEditingController();
  final _customerPhoneCtrl = TextEditingController();

  // Order fields
  late DateTime _orderDate;
  late DateTime _deliveryDate;
  late List<_OrderItemForm> _itemForms;

  // Payment
  final _advanceCtrl = TextEditingController();
  bool _isPaid = false;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _orderDate = DateTime.now();
    _deliveryDate = DateTime.now().add(const Duration(days: 3));

    if (widget.existingOrder != null) {
      final o = widget.existingOrder!;
      _customerNameCtrl.text = o.customerName;
      _customerPhoneCtrl.text = o.customerPhone;
      _orderDate = o.orderDate;
      _deliveryDate = o.deliveryDate;
      _isPaid = o.isPaid;
      _advanceCtrl.text = o.advanceAmount?.toString() ?? '';
      _itemForms = o.items.map((item) => _OrderItemForm.fromItem(item)).toList();
    } else {
      _itemForms = [_OrderItemForm()];
    }
  }

  @override
  void dispose() {
    _customerNameCtrl.dispose();
    _customerPhoneCtrl.dispose();
    _advanceCtrl.dispose();
    for (final form in _itemForms) {
      form.qtyCtrl.dispose();
      form.priceCtrl.dispose();
      form.notesCtrl.dispose();
      form.customNameCtrl.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDeliveryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deliveryDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.accent),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _deliveryDate = picked);
  }

  Future<void> _selectCustomer() async {
    final store = context.read<AppStore>();
    if (store.customers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No saved customers. Enter details manually.')),
      );
      return;
    }

    final result = await showModalBottomSheet<Customer>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CustomerPickerSheet(customers: store.customers),
    );

    if (result != null) {
      setState(() {
        _selectedCustomer = result;
        _customerNameCtrl.text = result.name;
        _customerPhoneCtrl.text = result.phone;
      });
      _loadPastMeasurementsForActiveItems();
    }
  }

  void _loadPastMeasurementsForActiveItems() {
    final store = context.read<AppStore>();
    final custId = _selectedCustomer?.id;
    final phone = _customerPhoneCtrl.text.trim();

    final customerOrders = store.orders.where((o) =>
        (custId != null && o.customerId == custId) ||
        (phone.isNotEmpty && o.customerPhone == phone)).toList();

    if (customerOrders.isEmpty) return;
    customerOrders.sort((a, b) => b.orderDate.compareTo(a.orderDate));

    setState(() {
      for (final form in _itemForms) {
        if (form.categoryId != null) {
          List<MeasurementField>? previousMeasurements;
          for (final order in customerOrders) {
            final matchingItems = order.items.where((item) => item.categoryId == form.categoryId).toList();
            if (matchingItems.isNotEmpty) {
              previousMeasurements = matchingItems.first.measurements;
              break;
            }
          }

          if (previousMeasurements != null && previousMeasurements.isNotEmpty) {
            form.measurements = previousMeasurements
                .map((m) => MeasurementField(name: m.name, value: m.value))
                .toList();

            // Merge any new fields defined in the template that weren't in the previous order
            final cat = store.categories.firstWhere(
              (c) => c.id == form.categoryId,
              orElse: () => GarmentCategory(id: '', name: '', measurementFields: []),
            );
            if (cat.id.isNotEmpty) {
              for (final fieldName in cat.measurementFields) {
                if (!form.measurements.any((m) => m.name.toLowerCase() == fieldName.toLowerCase())) {
                  form.measurements.add(MeasurementField(name: fieldName));
                }
              }
            }
          }
        }
      }
    });
  }

  Future<void> _pickFromNativeContacts() async {
    try {
      final picker = FlutterContactPicker();
      final contact = await picker.selectContact();
      if (contact != null) {
        final String name = contact.fullName ?? '';
        String phone = '';
        if (contact.phoneNumbers != null && contact.phoneNumbers!.isNotEmpty) {
          phone = contact.phoneNumbers!.first;
        }

        // Clean phone number (remove spaces, hyphens, non-digit chars except +)
        phone = phone.replaceAll(RegExp(r'[^\d+]'), '');

        setState(() {
          _customerNameCtrl.text = name;
          _customerPhoneCtrl.text = phone;
          _selectedCustomer = null; // Reset picked app customer to allow saving/matching
        });
        _loadPastMeasurementsForActiveItems();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick contact: $e'),
            backgroundColor: AppTheme.accent,
          ),
        );
      }
    }
  }

  Future<void> _saveOrder() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    // Validate items
    for (final item in _itemForms) {
      if (item.categoryId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select garment type for all items')),
        );
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final store = context.read<AppStore>();

      // Save customer if new
    Customer customer;
    if (_selectedCustomer != null) {
      customer = _selectedCustomer!;
    } else {
      final nameVal = _customerNameCtrl.text.trim();
      final phoneVal = _customerPhoneCtrl.text.trim();
      final existing = store.customers
          .where((c) => c.phone == phoneVal || c.name.toLowerCase() == nameVal.toLowerCase())
          .toList();
      if (existing.isNotEmpty) {
        customer = existing.first;
      } else {
        customer = await store.addCustomer(nameVal, phoneVal);
      }
    }

    final items = _itemForms.map((f) => f.toOrderItem()).toList();
    final totalAmount = items.fold<double>(0, (sum, i) => sum + i.total);
    final advance = double.tryParse(_advanceCtrl.text) ?? 0.0;
    final isPaidValue = _isPaid || (advance >= totalAmount && totalAmount > 0);

    final order = Order(
      id: widget.existingOrder?.id ?? _uuid.v4(),
      invoiceNo: widget.existingOrder?.invoiceNo,
      customerId: customer.id,
      customerName: customer.name,
      customerPhone: customer.phone,
      orderDate: _orderDate,
      deliveryDate: _deliveryDate,
      items: items,
      status: widget.existingOrder?.status ?? OrderStatus.pending,
      isPaid: isPaidValue,
      advanceAmount: advance,
    );

      if (widget.existingOrder != null) {
        await store.updateOrder(order);
      } else {
        await store.addOrder(order);
      }

      if (mounted) {
        Navigator.pop(context, order);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final totalAmount = _itemForms.fold<double>(
        0, (sum, f) => sum + ((double.tryParse(f.priceCtrl.text) ?? 0) * (int.tryParse(f.qtyCtrl.text) ?? 1)));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingOrder != null ? 'Edit Order' : 'New Order'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveOrder,
            child: _isSaving 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Customer Section
            _SectionCard(
              title: 'Customer',
              child: Column(
                children: [
                  AppTextField(
                    label: 'Customer Name',
                    controller: _customerNameCtrl,
                    validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _selectCustomer,
                          icon: const Icon(Icons.person_search_outlined, size: 16),
                          label: const Text('Pick App Customer'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.accent,
                            side: const BorderSide(color: AppTheme.accent),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickFromNativeContacts,
                          icon: const Icon(Icons.contacts_outlined, size: 16),
                          label: const Text('Import Contact'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.accent,
                            side: const BorderSide(color: AppTheme.accent),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'Phone Number',
                    controller: _customerPhoneCtrl,
                    keyboardType: TextInputType.phone,
                    validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Dates
            _SectionCard(
              title: 'Dates',
              child: Row(
                children: [
                  Expanded(
                    child: _DateField(
                      label: 'Order Date',
                      date: _orderDate,
                      onTap: null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DateField(
                      label: 'Delivery Date',
                      date: _deliveryDate,
                      onTap: _pickDeliveryDate,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Items
            const SectionLabel('GARMENT ITEMS'),
            const SizedBox(height: 10),
            ...List.generate(_itemForms.length, (index) => _ItemFormCard(
              key: ValueKey(_itemForms[index].id),
              form: _itemForms[index],
              index: index,
              categories: store.categories,
              selectedCustomerId: _selectedCustomer?.id,
              customerPhone: _customerPhoneCtrl.text,
              onRemove: _itemForms.length > 1
                  ? () => setState(() {
                      final removed = _itemForms.removeAt(index);
                      removed.qtyCtrl.dispose();
                      removed.priceCtrl.dispose();
                      removed.notesCtrl.dispose();
                      removed.customNameCtrl.dispose();
                    })
                  : null,
              onChanged: () => setState(() {}),
            )),

            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => setState(() => _itemForms.add(_OrderItemForm())),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Another Item'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.accent,
                side: const BorderSide(color: AppTheme.accent, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 14),

            // Payment
            _SectionCard(
              title: 'Payment',
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Amount',
                          style: TextStyle(fontSize: 14, color: AppTheme.textMid)),
                      Text(
                        '₹${NumberFormat('#,##0.00').format(totalAmount)}',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textDark),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'Advance Received (₹)',
                    controller: _advanceCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (val) {
                      final advance = double.tryParse(val) ?? 0.0;
                      if (advance >= totalAmount && totalAmount > 0) {
                        _isPaid = true;
                      } else {
                        _isPaid = false;
                      }
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: _isPaid,
                        onChanged: (v) => setState(() => _isPaid = v!),
                        activeColor: AppTheme.success,
                      ),
                      const Text('Fully Paid', style: TextStyle(fontSize: 14)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isSaving ? null : _saveOrder,
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: _isSaving
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(widget.existingOrder != null ? 'Update Order' : 'Save Order'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ---- Item Form Model ----
class _OrderItemForm {
  final String id;
  String? categoryId;
  String? categoryName;
  List<MeasurementField> measurements = [];
  final qtyCtrl = TextEditingController(text: '1');
  final priceCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  final customNameCtrl = TextEditingController();

  _OrderItemForm() : id = _uuid.v4();

  _OrderItemForm.fromItem(OrderItem item) : id = item.id {
    categoryId = item.categoryId;
    categoryName = item.categoryName;
    measurements = item.measurements.map((m) => MeasurementField(name: m.name, value: m.value)).toList();
    qtyCtrl.text = item.quantity.toString();
    priceCtrl.text = item.price.toString();
    notesCtrl.text = item.notes ?? '';
    customNameCtrl.text = item.customName ?? '';
  }

  OrderItem toOrderItem() => OrderItem(
        id: id,
        categoryId: categoryId!,
        categoryName: categoryName!,
        measurements: measurements,
        quantity: int.tryParse(qtyCtrl.text) ?? 1,
        price: double.tryParse(priceCtrl.text) ?? 0,
        notes: notesCtrl.text.isEmpty ? null : notesCtrl.text,
        customName: customNameCtrl.text.trim().isEmpty ? null : customNameCtrl.text.trim(),
      );
}

// ---- Item Form Card Widget ----
class _ItemFormCard extends StatefulWidget {
  final _OrderItemForm form;
  final int index;
  final List<GarmentCategory> categories;
  final String? selectedCustomerId;
  final String customerPhone;
  final VoidCallback? onRemove;
  final VoidCallback onChanged;

  const _ItemFormCard({
    super.key,
    required this.form,
    required this.index,
    required this.categories,
    required this.selectedCustomerId,
    required this.customerPhone,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  State<_ItemFormCard> createState() => _ItemFormCardState();
}

class _ItemFormCardState extends State<_ItemFormCard> {
  bool _measurementsExpanded = true;

  void _onCategoryChanged(GarmentCategory cat) {
    setState(() {
      widget.form.categoryId = cat.id;
      widget.form.categoryName = cat.name;
      if (cat.basePrice != null) {
        widget.form.priceCtrl.text = cat.basePrice!.toString();
      }
      
      // Auto-load past measurements of this customer for this category
      final store = context.read<AppStore>();
      List<MeasurementField>? previousMeasurements;

      final custId = widget.selectedCustomerId;
      final phone = widget.customerPhone.trim();

      // 1. First: check the customer profile's synced measurements map (from MongoDB)
      if (custId != null) {
        final customerProfile = store.customers.firstWhere(
          (c) => c.id == custId,
          orElse: () => Customer(id: '', name: '', phone: '', createdAt: DateTime.now()),
        );
        if (customerProfile.id.isNotEmpty) {
          if (customerProfile.indivvidualmeasurement.containsKey(cat.name.toLowerCase())) {
            final syncedMeasurements = customerProfile.indivvidualmeasurement[cat.name.toLowerCase()]!;
            if (syncedMeasurements.isNotEmpty) {
              previousMeasurements = syncedMeasurements;
            }
          } else if (customerProfile.indivvidualmeasurement.containsKey(cat.id)) {
            final syncedMeasurements = customerProfile.indivvidualmeasurement[cat.id]!;
            if (syncedMeasurements.isNotEmpty) {
              previousMeasurements = syncedMeasurements;
            }
          }
        }
      }

      // 2. Fallback: search past orders for this customer's measurements for this category
      if (previousMeasurements == null) {
        final customerOrders = store.orders.where((o) =>
            (custId != null && o.customerId == custId) ||
            (phone.isNotEmpty && o.customerPhone == phone)).toList();

        if (customerOrders.isNotEmpty) {
          customerOrders.sort((a, b) => b.orderDate.compareTo(a.orderDate));
          for (final order in customerOrders) {
            final matchingItems = order.items.where((item) => item.categoryId == cat.id).toList();
            if (matchingItems.isNotEmpty) {
              previousMeasurements = matchingItems.first.measurements;
              break;
            }
          }
        }
      }

      if (previousMeasurements != null && previousMeasurements.isNotEmpty) {
        widget.form.measurements = previousMeasurements
            .map((m) => MeasurementField(name: m.name, value: m.value))
            .toList();

        // Merge any new fields defined in the template that weren't in the previous measurements
        for (final fieldName in cat.measurementFields) {
          if (!widget.form.measurements.any((m) => m.name.toLowerCase() == fieldName.toLowerCase())) {
            widget.form.measurements.add(MeasurementField(name: fieldName));
          }
        }
      } else {
        // Fallback to standard fields
        widget.form.measurements = cat.measurementFields
            .map((f) => MeasurementField(name: f))
            .toList();
      }
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.form;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: f.categoryId != null ? AppTheme.accent.withOpacity(0.3) : AppTheme.border,
        ),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Item ${widget.index + 1}',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.accent)),
                ),
                const Spacer(),
                if (widget.onRemove != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.textLight),
                    onPressed: widget.onRemove,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category dropdown
                DropdownButtonFormField<GarmentCategory>(
                  value: widget.categories
                      .where((c) => c.id == f.categoryId)
                      .firstOrNull,
                  hint: const Text('Select Garment Type'),
                  decoration: const InputDecoration(
                    labelText: 'Garment Type',
                    prefixIcon: Icon(Icons.checkroom_outlined, size: 20),
                  ),
                  items: widget.categories
                      .map((cat) => DropdownMenuItem(
                            value: cat,
                            child: Text(cat.name),
                          ))
                      .toList(),
                  onChanged: (cat) {
                    if (cat != null) _onCategoryChanged(cat);
                  },
                ),
                const SizedBox(height: 12),

                AppTextField(
                  label: 'Dress Name (Optional)',
                  controller: f.customNameCtrl,
                  hint: 'e.g. Pink Blouse, Green Blouse',
                  onChanged: (_) => widget.onChanged(),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: 'Qty',
                        controller: f.qtyCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => widget.onChanged(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: AppTextField(
                        label: 'Price (₹)',
                        controller: f.priceCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => widget.onChanged(),
                      ),
                    ),
                  ],
                ),

                // Measurements
                if (f.measurements.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => setState(() => _measurementsExpanded = !_measurementsExpanded),
                    child: Row(
                      children: [
                        const Icon(Icons.straighten, size: 16, color: AppTheme.textMid),
                        const SizedBox(width: 6),
                        const Text('Measurements',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textMid)),
                        const Spacer(),
                        Icon(
                          _measurementsExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 18,
                          color: AppTheme.textLight,
                        ),
                      ],
                    ),
                  ),
                  if (_measurementsExpanded) ...[
                    const SizedBox(height: 10),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 3.2,
                      ),
                      itemCount: f.measurements.length,
                      itemBuilder: (_, i) {
                        final m = f.measurements[i];
                        return _MeasurementField(
                          label: m.name,
                          value: m.value ?? '',
                          onChanged: (v) {
                            setState(() => f.measurements[i] =
                                MeasurementField(name: m.name, value: v));
                          },
                        );
                      },
                    ),
                  ],
                ],

                const SizedBox(height: 12),
                AppTextField(
                  label: 'Customization Notes',
                  controller: f.notesCtrl,
                  maxLines: 2,
                  hint: 'e.g. Button style, embroidery...',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MeasurementField extends StatefulWidget {
  final String label;
  final String value;
  final void Function(String) onChanged;

  const _MeasurementField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_MeasurementField> createState() => _MeasurementFieldState();
}

class _MeasurementFieldState extends State<_MeasurementField> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(fontSize: 13),
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        labelText: widget.label,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
        ),
        suffixText: 'in',
        suffixStyle: const TextStyle(fontSize: 11, color: AppTheme.textLight),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback? onTap;

  const _DateField({required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: onTap != null ? AppTheme.accent.withOpacity(0.4) : AppTheme.border),
        ),
        child: Row(
          children: [
            Icon(
              onTap != null ? Icons.edit_calendar_outlined : Icons.calendar_today_outlined,
              size: 18,
              color: onTap != null ? AppTheme.accent : AppTheme.textLight,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textLight)),
                  Text(DateFormat('dd MMM yyyy').format(date),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMid,
                  letterSpacing: 0.8)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _CustomerPickerSheet extends StatefulWidget {
  final List<Customer> customers;
  const _CustomerPickerSheet({required this.customers});

  @override
  State<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<_CustomerPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.customers
        .where((c) =>
            c.name.toLowerCase().contains(_query.toLowerCase()) ||
            c.phone.contains(_query))
        .toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Customer',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                TextField(
                  autofocus: true,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search name or phone...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final c = filtered[i];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primary.withOpacity(0.1),
                    child: Text(c.name[0].toUpperCase(),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, color: AppTheme.primary)),
                  ),
                  title: Text(c.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(c.phone,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMid)),
                  onTap: () => Navigator.pop(context, c),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
