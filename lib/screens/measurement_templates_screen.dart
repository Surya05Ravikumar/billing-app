// lib/screens/measurement_templates_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../utils/app_store.dart';
import '../utils/theme.dart';
import '../widgets/shared.dart';
import 'edit_template_screen.dart';

class MeasurementTemplatesScreen extends StatelessWidget {
  const MeasurementTemplatesScreen({super.key});

  void _navigateToEdit(BuildContext context, [GarmentCategory? existing]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditTemplateScreen(existing: existing),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Measurement Templates'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _navigateToEdit(context),
          ),
        ],
      ),
      body: store.categories.isEmpty
          ? EmptyState(
              icon: Icons.straighten_outlined,
              title: 'No templates',
              subtitle: 'Add garment categories with measurement fields',
              action: ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Category'),
                onPressed: () => _navigateToEdit(context),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.info.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.info.withOpacity(0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: AppTheme.info),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'These templates auto-load measurement fields when creating orders.',
                          style: TextStyle(fontSize: 12, color: AppTheme.info),
                        ),
                      ),
                    ],
                  ),
                ),
                ...store.categories.map((cat) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _CategoryCard(
                        category: cat,
                        onEdit: () => _navigateToEdit(context, cat),
                      ),
                    )),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _navigateToEdit(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add New Category'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accent,
                    side: const BorderSide(color: AppTheme.accent, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
    );
  }
}

class _CategoryCard extends StatefulWidget {
  final GarmentCategory category;
  final VoidCallback onEdit;

  const _CategoryCard({required this.category, required this.onEdit});

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cat = widget.category;
    return Container(
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
              child: const Icon(Icons.checkroom_outlined,
                  size: 20, color: AppTheme.primary),
            ),
            title: Text(cat.name,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15)),
            subtitle: Text(
                '${cat.measurementFields.length} field${cat.measurementFields.length != 1 ? 's' : ''}${cat.basePrice != null ? '  ·  Base Price: ₹${cat.basePrice}' : ''}',
                style: const TextStyle(fontSize: 12, color: AppTheme.textMid)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      size: 18, color: AppTheme.textMid),
                  onPressed: widget.onEdit,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36),
                ),
                IconButton(
                  icon: Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 20,
                    color: AppTheme.textLight,
                  ),
                  onPressed: () => setState(() => _expanded = !_expanded),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36),
                ),
              ],
            ),
          ),
          if (_expanded && cat.measurementFields.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: cat.measurementFields
                    .map((f) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.straighten,
                                  size: 12, color: AppTheme.textLight),
                              const SizedBox(width: 5),
                              Text(f,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.textDark)),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
