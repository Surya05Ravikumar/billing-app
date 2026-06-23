// lib/screens/backup_restore_screen.dart

import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../utils/app_store.dart';
import '../utils/theme.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  bool _isLoading = false;
  String _statusMessage = '';
  late TextEditingController _sheetsController;

  @override
  void initState() {
    super.initState();
    final store = Provider.of<AppStore>(context, listen: false);
    _sheetsController = TextEditingController(text: store.sheetsUrl);
  }

  @override
  void dispose() {
    _sheetsController.dispose();
    super.dispose();
  }

  Future<void> _exportBackup() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Preparing your backup...';
    });

    try {
      final store = Provider.of<AppStore>(context, listen: false);
      final jsonBackup = store.exportBackup();

      if (kIsWeb) {
        // Fallback for Web if needed, but this is targeting mobile
        final bytes = utf8.encode(jsonBackup);
        await Share.shareXFiles(
          [
            XFile.fromData(
              Uint8List.fromList(bytes),
              mimeType: 'application/json',
              name: 'tailor_billing_backup.json',
            )
          ],
          subject: 'Tailor Billing App Data Backup',
        );
      } else {
        final tempDir = await getTemporaryDirectory();
        final dateStr = DateTime.now().toIso8601String().split('T').first.replaceAll('-', '');
        final timeStr = DateTime.now().hour.toString().padLeft(2, '0') +
            DateTime.now().minute.toString().padLeft(2, '0');
        final filePath = '${tempDir.path}/tailor_backup_${dateStr}_$timeStr.json';

        final file = File(filePath);
        await file.writeAsString(jsonBackup);

        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'application/json')],
          subject: 'Tailor Billing App Data Backup',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup shared successfully!'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export backup: $e'),
            backgroundColor: AppTheme.accent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = '';
        });
      }
    }
  }

  Future<void> _importBackup() async {
    final store = Provider.of<AppStore>(context, listen: false);

    // 1. Confirm destructive restore action with a modal
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 28),
            SizedBox(width: 8),
            Text('Overwrite All Data?'),
          ],
        ),
        content: const Text(
          'This action will replace all current orders, customers, and templates with the data in the backup file.\n\nThis cannot be undone! Are you sure you want to proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMid)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Overwrite'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Reading backup file...';
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() {
          _isLoading = false;
          _statusMessage = '';
        });
        return;
      }

      final file = result.files.first;
      String content = '';

      if (kIsWeb || file.bytes != null) {
        content = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        content = await File(file.path!).readAsString();
      }

      setState(() {
        _statusMessage = 'Restoring and saving data...';
      });

      final success = await store.importBackup(content);

      if (mounted) {
        if (success) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: AppTheme.success, size: 28),
                  SizedBox(width: 8),
                  Text('Restore Completed'),
                ],
              ),
              content: const Text(
                'Your database was restored successfully! All orders, customers, and customized templates are up to date.',
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx); // pop dialog
                    Navigator.pop(context); // pop screen back to settings
                  },
                  child: const Text('Perfect'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid backup file. Schema validation failed.'),
              backgroundColor: AppTheme.accent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: AppTheme.accent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Backup & Restore'),
        elevation: 0,
        shape: const Border(
          bottom: BorderSide(color: AppTheme.border, width: 1),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  const Text(
                    'DATABASE SUMMARY',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMid,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildStatsSection(store),
                  const SizedBox(height: 24),
                  const Text(
                    'OFFLINE DATA BACKUP (JSON FILE)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMid,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildBackupCard(),
                  const SizedBox(height: 12),
                  _buildRestoreCard(),
                  const SizedBox(height: 24),
                  const Text(
                    'CLOUD DATA BACKUP (GOOGLE SHEETS)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMid,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildGoogleSheetsCloudCard(context, store),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
          if (_isLoading) _buildLoaderOverlay(),
        ],
      ),
    );
  }

  Widget _buildStatsSection(AppStore store) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          _buildStatRow(Icons.receipt_long, 'Orders & Bills', '${store.orders.length} items'),
          const Divider(height: 24),
          _buildStatRow(Icons.people, 'Customers', '${store.customers.length} people'),
          const Divider(height: 24),
          _buildStatRow(Icons.straighten, 'Measurement Templates', '${store.categories.length} categories'),
        ],
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primary, size: 20),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.textDark,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.textMid,
          ),
        ),
      ],
    );
  }

  Widget _buildBackupCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.drive_folder_upload, color: AppTheme.success, size: 22),
              ),
              const SizedBox(width: 12),
              const Text(
                'Data Backup',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Export all your orders, customer directories, and customized templates into a single secure file. You can save it to your phone storage, Google Drive, send it via email, or share it on WhatsApp.',
            style: TextStyle(fontSize: 13, color: AppTheme.textMid, height: 1.5),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _exportBackup,
              icon: const Icon(Icons.share, size: 18),
              label: const Text('Export & Share Backup'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestoreCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.restore, color: AppTheme.accent, size: 22),
              ),
              const SizedBox(width: 12),
              const Text(
                'Restore Data',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.accent.withOpacity(0.12)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: AppTheme.accent, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'WARNING: Restoring a backup file will permanently overwrite and replace all current app data.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.accent,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Select a previously exported `.json` file from your device files or downloaded backups to load all registers.',
            style: TextStyle(fontSize: 13, color: AppTheme.textMid, height: 1.5),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.accent),
                foregroundColor: AppTheme.accent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _importBackup,
              icon: const Icon(Icons.file_open, size: 18),
              label: const Text(
                'Select & Restore Backup',
                style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoaderOverlay() {
    return Container(
      color: AppTheme.primary.withOpacity(0.7),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppTheme.accent),
              const SizedBox(height: 20),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildGoogleSheetsCloudCard(BuildContext context, AppStore store) {
    _sheetsController.selection = TextSelection.fromPosition(TextPosition(offset: _sheetsController.text.length));

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
                  color: AppTheme.info.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.cloud_sync_outlined,
                  color: AppTheme.info,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Google Sheets Integration',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      store.syncStatus.isNotEmpty
                          ? 'Status: ${store.syncStatus}'
                          : 'Enter your Apps Script Web App URL',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: store.syncStatus.contains('successful')
                            ? Colors.green
                            : store.syncStatus.contains('pending') || store.syncStatus.contains('Fetching')
                                ? AppTheme.warning
                                : store.syncStatus.contains('failed')
                                    ? Colors.red
                                    : AppTheme.textMid,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _sheetsController,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'https://script.google.com/macros/s/.../exec',
              hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textLight),
              labelText: 'Paste Web App URL',
              labelStyle: const TextStyle(fontSize: 13, color: AppTheme.textMid),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.check, color: Colors.green),
                onPressed: () {
                  store.updateSheetsUrl(_sheetsController.text);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Sync URL saved successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
              ),
            ),
            onFieldSubmitted: (val) {
              store.updateSheetsUrl(val);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Sync URL saved successfully!'),
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
                  onPressed: store.isSyncing || store.sheetsUrl.isEmpty
                      ? null
                      : () async {
                          setState(() {
                            _isLoading = true;
                            _statusMessage = 'Syncing data to Google Sheets...';
                          });
                          await store.syncWithGoogleSheets();
                          setState(() {
                            _isLoading = false;
                            _statusMessage = '';
                          });
                        },
                  icon: const Icon(Icons.cloud_upload_outlined, size: 16, color: Colors.white),
                  label: const Text('Upload (Sync)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: store.isSyncing || store.sheetsUrl.isEmpty
                      ? null
                      : () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 28),
                                  SizedBox(width: 8),
                                  Text('Overwrite Local Data?'),
                                ],
                              ),
                              content: const Text(
                                'This will replace all current app data with the data from your Google Sheet.\n\nAre you sure you want to proceed?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel', style: TextStyle(color: AppTheme.textMid)),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Yes, Overwrite'),
                                ),
                              ],
                            ),
                          );

                          if (confirm != true) return;

                          setState(() {
                            _isLoading = true;
                            _statusMessage = 'Downloading data from Google Sheets...';
                          });
                          final success = await store.pullFromGoogleSheets();
                          setState(() {
                            _isLoading = false;
                            _statusMessage = '';
                          });
                          
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(success
                                    ? 'Data successfully restored from Google Sheets!'
                                    : 'Failed to restore data from Google Sheets.'),
                                backgroundColor: success ? Colors.green : Colors.red,
                              ),
                            );
                          }
                        },
                  icon: const Icon(Icons.cloud_download_outlined, size: 16, color: AppTheme.accent),
                  label: const Text('Download (Restore)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.accent)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accent,
                    side: const BorderSide(color: AppTheme.accent),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
