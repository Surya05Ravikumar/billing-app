// lib/screens/invoice_preview_screen.dart

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../utils/app_store.dart';
import '../utils/theme.dart';

class InvoicePreviewScreen extends StatefulWidget {
  final Order order;
  const InvoicePreviewScreen({super.key, required this.order});

  @override
  State<InvoicePreviewScreen> createState() => _InvoicePreviewScreenState();
}

class _InvoicePreviewScreenState extends State<InvoicePreviewScreen> {
  final GlobalKey _boundaryKey = GlobalKey();
  bool _isSharing = false;

  Future<void> _shareAsImage() async {
    setState(() => _isSharing = true);

    try {
      final store = Provider.of<AppStore>(context, listen: false);
      final gpayLink = store.gpayLink;
      final gpayNumber = store.gpayNumber;

      final buffer = StringBuffer();
      if (gpayLink.isNotEmpty) {
        buffer.writeln('Pay Now: $gpayLink');
      }
      if (gpayNumber.isNotEmpty) {
        buffer.writeln('Google Pay Number: $gpayNumber');
      }
      final shareText = buffer.toString().trim();

      // 1. Capture the repaint boundary as a high-resolution image
      final RenderRepaintBoundary boundary =
          _boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData == null) throw Exception('Failed to generate image bytes.');
      
      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // 2. Write to a temporary file
      final tempDir = await getTemporaryDirectory();
      final invoiceNum = widget.order.invoiceNo ?? '1001';
      final filePath = '${tempDir.path}/invoice_$invoiceNum.png';
      
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);

      // 3. Share the file via WhatsApp / native OS sheet
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: shareText.isNotEmpty ? shareText : null,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share image: $e'),
            backgroundColor: AppTheme.accent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  void _shareAsText() {
    final store = Provider.of<AppStore>(context, listen: false);
    final gpayLink = store.gpayLink;
    final order = widget.order;
    final fmt = NumberFormat('#,##0.00', 'en_IN');
    final invoiceNum = order.invoiceNo ?? '1001';

    final totalPaid = order.isPaid ? order.totalAmount : (order.advanceAmount ?? 0.0);
    final balanceDue = order.isPaid ? 0.0 : order.pendingAmount;

    final buffer = StringBuffer();
    buffer.writeln('----------------------------------------');
    buffer.writeln('          BHUVANA TAILORING             ');
    buffer.writeln('----------------------------------------');
    buffer.writeln('Invoice No: #$invoiceNum');
    buffer.writeln('----------------------------------------');
    buffer.writeln('Customer: ${order.customerName}');
    buffer.writeln('Phone: ${order.customerPhone}');
    buffer.writeln('----------------------------------------');
    buffer.writeln('ITEMS:');
    
    for (int i = 0; i < order.items.length; i++) {
      final item = order.items[i];
      buffer.writeln('${i + 1}. ${item.customName ?? item.categoryName} (Qty: ${item.quantity})');
      buffer.writeln('   Price: ₹${fmt.format(item.price)} | Total: ₹${fmt.format(item.total)}');
    }
    
    buffer.writeln('----------------------------------------');
    buffer.writeln('SUMMARY:');
    buffer.writeln('Total Amount: ₹${fmt.format(order.totalAmount)}');
    buffer.writeln('Total Paid:   ₹${fmt.format(totalPaid)}');
    buffer.writeln('Balance Due:  ₹${fmt.format(balanceDue)}');
    buffer.writeln('----------------------------------------');
    if (gpayLink.isNotEmpty || store.gpayNumber.isNotEmpty) {
      if (gpayLink.isNotEmpty) {
        buffer.writeln('Pay Now: $gpayLink');
      }
      if (store.gpayNumber.isNotEmpty) {
        buffer.writeln('Google Pay Number: ${store.gpayNumber}');
      }
      buffer.writeln('----------------------------------------');
    }
    buffer.writeln('Thank you for choosing Bhuvana Tailoring!');
    buffer.writeln('----------------------------------------');

    Share.share(buffer.toString(), subject: 'Invoice #$invoiceNum');
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final order = widget.order;
    final fmt = NumberFormat('#,##0.00', 'en_IN');
    final invoiceNum = order.invoiceNo ?? '1001';

    final totalPaid = order.isPaid ? order.totalAmount : (order.advanceAmount ?? 0.0);
    final balanceDue = order.isPaid ? 0.0 : order.pendingAmount;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Invoice Receipt'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: RepaintBoundary(
                  key: _boundaryKey,
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 420),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Shop Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/images/logo.png',
                              height: 48,
                              width: 48,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'BHUVANA TAILORING',
                                    style: TextStyle(
                                      fontFamily: 'serif',
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: AppTheme.textDark,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Professional Blouse & Ladies Dress Stitching Studio',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.textMid,
                                      letterSpacing: 0.1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildDashedLine(),
                        const SizedBox(height: 16),

                        // Bill Metadata (Strictly Invoice No, Customer, and Phone)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('INVOICE NO',
                                    style: TextStyle(fontSize: 12, color: AppTheme.textLight, fontWeight: FontWeight.bold)),
                                Text('#$invoiceNum',
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('CUSTOMER NAME',
                                    style: TextStyle(fontSize: 12, color: AppTheme.textLight, fontWeight: FontWeight.bold)),
                                Text(order.customerName,
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text('CONTACT PHONE',
                            style: TextStyle(fontSize: 12, color: AppTheme.textLight, fontWeight: FontWeight.bold)),
                        Text(order.customerPhone,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
                        
                        const SizedBox(height: 20),
                        _buildDashedLine(),
                        const SizedBox(height: 16),

                        // Item Table Header
                        const Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text('GARMENT ITEM',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textMid)),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text('QTY',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textMid)),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text('PRICE',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textMid)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Divider(height: 1),
                        const SizedBox(height: 8),

                        // Items list (Strictly no individual measurements)
                        ...order.items.map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          item.customName ?? item.categoryName,
                                          style: const TextStyle(
                                              fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textDark),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          '${item.quantity}',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 15, color: AppTheme.textDark),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          '₹${fmt.format(item.price)}',
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(
                                              fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textDark),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            )),

                        const SizedBox(height: 12),
                        _buildDashedLine(),
                        const SizedBox(height: 16),

                        // Payment Summary block (Total, Paid, and Balance)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Amount:',
                                style: TextStyle(fontSize: 15, color: AppTheme.textMid, fontWeight: FontWeight.w500)),
                            Text('₹${fmt.format(order.totalAmount)}',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Paid:',
                                style: TextStyle(fontSize: 15, color: AppTheme.success, fontWeight: FontWeight.w500)),
                            Text('₹${fmt.format(totalPaid)}',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.success)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Balance Due:',
                                style: TextStyle(fontSize: 15, color: AppTheme.accent, fontWeight: FontWeight.w700)),
                            Text('₹${fmt.format(balanceDue)}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.accent)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildDashedLine(),
                        const SizedBox(height: 16),
                        
                        // Payment Info (Interactive Clickable)
                        if (store.gpayLink.isNotEmpty || store.gpayNumber.isNotEmpty) ...[
                          const Text(
                            'PAYMENT METHOD',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textLight,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (store.gpayLink.isNotEmpty)
                            InkWell(
                              onTap: () async {
                                final link = store.gpayLink.trim();
                                if (link.isNotEmpty) {
                                  final messenger = ScaffoldMessenger.of(context);
                                  String finalUriStr = link;
                                  
                                  if (link.contains('@') && !link.startsWith('upi://')) {
                                    finalUriStr = 'upi://pay?pa=$link&pn=Bhuvana%20Tailoring&tn=Invoice%20$invoiceNum&am=${balanceDue.toStringAsFixed(2)}&cu=INR';
                                  } else if (link.startsWith('upi://')) {
                                    // Append amount if not present
                                    if (!link.contains('&am=')) {
                                      finalUriStr = '$link&am=${balanceDue.toStringAsFixed(2)}';
                                    }
                                  }
                                  
                                  final uri = Uri.tryParse(finalUriStr);
                                  if (uri != null) {
                                    try {
                                      final launched = await launchUrl(
                                        uri,
                                        mode: LaunchMode.externalApplication,
                                      );
                                      if (!launched) {
                                        messenger.showSnackBar(
                                          const SnackBar(
                                            content: Text('Could not launch GPay. Use GPay number below.'),
                                            backgroundColor: AppTheme.accent,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text('Error: $e. GPay number is provided below.'),
                                          backgroundColor: AppTheme.accent,
                                        ),
                                      );
                                    }
                                  }
                                }
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green.withOpacity(0.2)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.payment, size: 18, color: Colors.green),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Pay Now via GPay / UPI',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green,
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            store.gpayLink.contains('pa=')
                                                ? Uri.parse(store.gpayLink).queryParameters['pa'] ?? 'Tap to redirect'
                                                : 'Tap to pay directly',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: AppTheme.textMid,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.green),
                                  ],
                                ),
                              ),
                            ),
                          if (store.gpayLink.isNotEmpty && store.gpayNumber.isNotEmpty)
                            const SizedBox(height: 8),
                          if (store.gpayNumber.isNotEmpty)
                            InkWell(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: store.gpayNumber));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Google Pay number copied to clipboard!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.phone_android, size: 18, color: AppTheme.primary),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Google Pay Phone Number',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.primary,
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            store.gpayNumber,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.textDark,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.copy, size: 14, color: AppTheme.primary),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          _buildDashedLine(),
                          const SizedBox(height: 16),
                        ],

                        // Center Shop Thank You Footer (Disclaimer text removed)
                        const Center(
                          child: Column(
                            children: [
                              Text(
                                'Thank you for choosing Bhuvana Tailoring!',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textDark),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Stitched with love & care.',
                                style: TextStyle(fontSize: 12, color: AppTheme.textLight, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Action Buttons panel at the bottom
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textDark,
                      side: const BorderSide(color: AppTheme.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _shareAsText,
                    icon: const Icon(Icons.notes, size: 18),
                    label: const Text('Share as Text'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366), // WhatsApp Green
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isSharing ? null : _shareAsImage,
                    icon: _isSharing 
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.share, size: 18),
                    label: const Text('WhatsApp (Image)'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashedLine() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 5.0;
        const dashHeight = 1.0;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return const SizedBox(
              width: dashWidth,
              height: dashHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(color: AppTheme.border),
              ),
            );
          }),
        );
      },
    );
  }
}
