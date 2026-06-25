// lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/theme.dart';
import '../utils/app_store.dart';
import 'measurement_templates_screen.dart';
import 'backup_restore_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _mongodbController;

  @override
  void initState() {
    super.initState();
    // Initialize controller using the store's current URL
    final store = Provider.of<AppStore>(context, listen: false);
    _mongodbController = TextEditingController(text: store.mongodbUrl);
  }

  @override
  void dispose() {
    _mongodbController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Settings'),
        automaticallyImplyLeading: false,
        elevation: 0,
        shape: const Border(
          bottom: BorderSide(color: AppTheme.border, width: 1),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              _buildHeaderCard(),
              const SizedBox(height: 24),
              const Text(
                'DATABASE SYNCHRONIZATION',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMid,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 12),
              _buildMongodbCard(context),
              const SizedBox(height: 24),
              const Text(
                'PREFERENCES & DATA',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMid,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 12),
              _buildSettingsCard(
                context,
                icon: Icons.design_services_outlined,
                iconColor: AppTheme.accent,
                title: 'Measurement Templates',
                subtitle: 'Manage measurement fields & garment templates',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MeasurementTemplatesScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildSettingsCard(
                context,
                icon: Icons.cloud_sync_outlined,
                iconColor: AppTheme.info,
                title: 'Data Backup & Restore',
                subtitle: 'Backup your business data or restore past backups',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BackupRestoreScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primary.withOpacity(0.2), width: 1.5),
                image: const DecorationImage(
                  image: AssetImage('assets/images/logo.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bhuvana Designers',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Manage your workshop & records offline',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMid,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMongodbCard(BuildContext context) {
    final store = Provider.of<AppStore>(context);
    _mongodbController.selection = TextSelection.fromPosition(TextPosition(offset: _mongodbController.text.length));
    const mongoGreen = Color(0xFF47A248);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: mongoGreen.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.storage_outlined,
                  color: mongoGreen,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MongoDB Atlas Integration',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      store.mongodbSyncStatus.isNotEmpty
                          ? 'Status: ${store.mongodbSyncStatus}'
                          : 'Connect app with MongoDB Atlas',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: store.mongodbSyncStatus.contains('successful') || store.mongodbSyncStatus.contains('Connected')
                            ? Colors.green
                            : store.mongodbSyncStatus.contains('Syncing') || store.mongodbSyncStatus.contains('Fetching')
                                ? AppTheme.warning
                                : store.mongodbSyncStatus.contains('failed')
                                    ? Colors.red
                                    : AppTheme.textMid,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: store.isMongodbEnabled,
                activeColor: mongoGreen,
                onChanged: (val) {
                  store.toggleMongodbEnabled(val);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(val ? 'MongoDB integration enabled!' : 'MongoDB integration disabled!'),
                      backgroundColor: val ? Colors.green : Colors.grey,
                    ),
                  );
                },
              ),
            ],
          ),
          if (store.isMongodbEnabled) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _mongodbController,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'https://billing-app-tllw.onrender.com/api',
                hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textLight),
                labelText: 'Paste Backend API URL',
                labelStyle: const TextStyle(fontSize: 13, color: AppTheme.textMid),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: mongoGreen, width: 1.5),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.check, color: Colors.green),
                  onPressed: () {
                    store.updateMongodbUrl(_mongodbController.text);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('MongoDB API URL saved successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                ),
              ),
              onFieldSubmitted: (val) {
                store.updateMongodbUrl(val);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('MongoDB API URL saved successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: store.isMongodbSyncing || store.mongodbUrl.isEmpty
                        ? null
                        : () async {
                            await store.syncWithMongoDB();
                          },
                    icon: store.isMongodbSyncing && store.mongodbSyncStatus.contains('Syncing')
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.cloud_upload_outlined, size: 16, color: Colors.white),
                    label: const Text('Upload (Sync)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mongoGreen,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: store.isMongodbSyncing || store.mongodbUrl.isEmpty
                        ? null
                        : () async {
                            final success = await store.pullFromMongoDB();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(success
                                      ? 'Data successfully restored from MongoDB!'
                                      : 'Failed to restore data from MongoDB.'),
                                  backgroundColor: success ? Colors.green : Colors.red,
                                ),
                              );
                            }
                          },
                    icon: store.isMongodbSyncing && store.mongodbSyncStatus.contains('Fetching')
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: mongoGreen),
                          )
                        : const Icon(Icons.cloud_download_outlined, size: 16, color: mongoGreen),
                    label: const Text('Download (Restore)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: mongoGreen)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: mongoGreen,
                      side: const BorderSide(color: mongoGreen),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSettingsCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMid,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppTheme.textLight,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return const Center(
      child: Column(
        children: [
          Text(
            'Version 1.0.0',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textLight,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Made with ❤️ for Tailors',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textLight,
            ),
          ),
        ],
      ),
    );
  }
}
