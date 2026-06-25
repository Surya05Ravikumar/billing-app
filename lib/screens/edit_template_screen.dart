import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../utils/app_store.dart';
import '../utils/theme.dart';
import '../widgets/shared.dart';

class EditTemplateScreen extends StatefulWidget {
  final GarmentCategory? existing;
  const EditTemplateScreen({super.key, this.existing});

  @override
  State<EditTemplateScreen> createState() => _EditTemplateScreenState();
}

class _EditTemplateScreenState extends State<EditTemplateScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _priceCtrl;
  late List<TextEditingController> _fieldCtrls;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _priceCtrl = TextEditingController(
        text: widget.existing != null
            ? (widget.existing!.basePrice?.toString() ?? '')
            : '150.0');
    _fieldCtrls = widget.existing != null
        ? widget.existing!.measurementFields
            .map((f) => TextEditingController(text: f))
            .toList()
        : [TextEditingController()];
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    for (final c in _fieldCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _addField() {
    setState(() => _fieldCtrls.add(TextEditingController()));
  }

  void _removeField(int index) {
    if (_fieldCtrls.isEmpty) return;
    setState(() {
      _fieldCtrls[index].dispose();
      _fieldCtrls.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final store = context.read<AppStore>();
    final fields = _fieldCtrls
        .map((c) => c.text.trim())
        .where((f) => f.isNotEmpty)
        .toList();

    final double? basePrice = double.tryParse(_priceCtrl.text.trim());

    if (widget.existing != null) {
      widget.existing!.name = _nameCtrl.text.trim();
      widget.existing!.measurementFields = fields;
      widget.existing!.basePrice = basePrice;
      await store.updateCategory(widget.existing!);
    } else {
      await store.addCategory(_nameCtrl.text.trim(), fields, basePrice: basePrice);
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Category?'),
        content: const Text('This will not affect existing orders.'),
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
    if (confirm == true && mounted) {
      context.read<AppStore>().deleteCategory(widget.existing!.id);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing != null ? 'Edit Category' : 'New Category'),
        actions: [
          if (widget.existing != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(
                label: 'Category Name',
                controller: _nameCtrl,
                hint: 'e.g. Blouse, Chudi...',
                validator: (v) => v!.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Base Price (₹) (Optional)',
                controller: _priceCtrl,
                keyboardType: TextInputType.number,
                hint: 'e.g. 350',
              ),
              const SizedBox(height: 24),
              const SectionLabel('MEASUREMENT FIELDS'),
              const SizedBox(height: 12),
              ..._fieldCtrls.asMap().entries.map((entry) {
                final i = entry.key;
                final ctrl = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text('${i + 1}',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.accent)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: ctrl,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Field name (e.g. Chest)',
                            hintStyle: const TextStyle(
                                fontSize: 13, color: AppTheme.textLight),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppTheme.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                  color: AppTheme.accent, width: 1.5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _removeField(i),
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: _addField,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Field'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accent,
                  side: BorderSide(color: AppTheme.accent.withOpacity(0.4)),
                  minimumSize: const Size.fromHeight(45),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50)),
            child: Text(
                widget.existing != null ? 'Update Category' : 'Save Category'),
          ),
        ),
      ),
    );
  }
}
