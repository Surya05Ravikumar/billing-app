import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../utils/app_store.dart';
import '../utils/theme.dart';
import '../utils/pdf_helper.dart';

class InvoicePreviewScreen extends StatefulWidget {
  final Order order;
  final bool autoShare;
  const InvoicePreviewScreen({super.key, required this.order, this.autoShare = false});

  @override
  State<InvoicePreviewScreen> createState() => _InvoicePreviewScreenState();
}

class _InvoicePreviewScreenState extends State<InvoicePreviewScreen> {
  final GlobalKey _boundaryKey = GlobalKey();
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _shareAsPdf() async {
    final store = Provider.of<AppStore>(context, listen: false);
    await PdfHelper.shareInvoice(
      context,
      widget.order,
      store,
      onStartShare: () => setState(() => _isSharing = true),
      onEndShare: () => setState(() => _isSharing = false),
    );
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
    buffer.writeln('          BHUVANA DESIGNERS             ');
    buffer.writeln('----------------------------------------');
    buffer.writeln('Invoice No: #$invoiceNum');
    buffer.writeln('----------------------------------------');
    buffer.writeln('Customer: ${order.customerName}');
    buffer.writeln('Phone: ${order.customerPhone}');
    buffer.writeln('----------------------------------------');
    buffer.writeln('ITEMS:');
    
    for (int i = 0; i < order.items.length; i++) {
      final item = order.items[i];
      buffer.writeln('${i + 1}. ${item.displayName} (Qty: ${item.quantity})');
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
    buffer.writeln('Thank you for choosing Bhuvana Designers!');
    buffer.writeln('----------------------------------------');

    Share.share(buffer.toString(), subject: 'Invoice #$invoiceNum');
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final fmt = NumberFormat('#,##0.00', 'en_IN');
    final invoiceNum = order.invoiceNo ?? '1001';


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
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/images/logo.png',
                              height: 60,
                              width: 60,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'BHUVANA DESIGNERS',
                                    style: TextStyle(
                                      fontFamily: 'serif',
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFD4AF37),
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'LKC Nagar, 2nd Street, old municipality office opposite',
                                    style: TextStyle(
                                      fontFamily: 'serif',
                                      fontSize: 10,
                                      color: Color(0xFFD4AF37),
                                    ),
                                  ),
                                  Text(
                                    'vellakovil - 638111.',
                                    style: TextStyle(
                                      fontFamily: 'serif',
                                      fontSize: 10,
                                      color: Color(0xFFD4AF37),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Bill Metadata
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('BILLED TO :',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(order.customerName,
                                    style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('INVOICE ID :',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text('#$invoiceNum',
                                    style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('INVOICE DATE :',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(DateFormat('dd/MM/yyyy').format(order.orderDate),
                                    style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 24),

                        // Table
                        Stack(
                          children: [
                            Positioned.fill(
                              child: Center(
                                child: Opacity(
                                  opacity: 0.15,
                                  child: Image.asset(
                                    'assets/images/logo.png',
                                    width: 250,
                                    height: 250,
                                  ),
                                ),
                              ),
                            ),
                            Column(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: const Color(0xFFD4AF37), width: 1),
                                  ),
                                  child: Column(
                                    children: [
                                      // Header
                                      Container(
                                        color: const Color(0xFFFFF9C4),
                                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                        child: const Row(
                                          children: [
                                            Expanded(flex: 1, child: Text('NO', style: TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold, fontSize: 10))),
                                            Expanded(flex: 4, child: Text('DESCRIPTION', style: TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold, fontSize: 10))),
                                            Expanded(flex: 1, child: Text('QTY', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold, fontSize: 10))),
                                            Expanded(flex: 2, child: Text('PRICE', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold, fontSize: 10))),
                                            Expanded(flex: 2, child: Text('SUBTOTAL', textAlign: TextAlign.right, style: TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold, fontSize: 10))),
                                          ],
                                        ),
                                      ),
                                      const Divider(color: Color(0xFFD4AF37), height: 1, thickness: 1),
                                      
                                      // Items
                                      ...List.generate(order.items.length, (index) {
                                        final item = order.items[index];
                                        return Container(
                                          decoration: BoxDecoration(
                                            border: Border(
                                              bottom: BorderSide(
                                                color: index == order.items.length - 1 ? Colors.transparent : const Color(0xFFD4AF37).withOpacity(0.3),
                                              ),
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(flex: 1, child: Text('${index + 1}', style: const TextStyle(fontSize: 12))),
                                              Expanded(flex: 4, child: Text(item.displayName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                                              Expanded(flex: 1, child: Text('${item.quantity}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
                                              Expanded(flex: 2, child: Text('₹ ${fmt.format(item.price)}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
                                              Expanded(flex: 2, child: Text('₹ ${fmt.format(item.total)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))),
                                            ],
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                                // Totals Section
                                Container(
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      left: BorderSide(color: Color(0xFFD4AF37)),
                                      right: BorderSide(color: Color(0xFFD4AF37)),
                                      bottom: BorderSide(color: Color(0xFFD4AF37)),
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          const Text('GRAND TOTAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                                          const SizedBox(width: 20),
                                          Container(
                                            width: 80,
                                            alignment: Alignment.centerRight,
                                            child: Text('₹ ${fmt.format(order.totalAmount)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          const Text('ADVANCE PAID', style: TextStyle(fontSize: 9, color: AppTheme.textLight)),
                                          const SizedBox(width: 20),
                                          Container(
                                            width: 80,
                                            alignment: Alignment.centerRight,
                                            child: Text('₹ ${fmt.format(order.isPaid ? order.totalAmount : (order.advanceAmount ?? 0.0))}', style: const TextStyle(fontSize: 11)),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          const Text('BALANCE DUE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD4AF37))),
                                          const SizedBox(width: 20),
                                          Container(
                                            width: 80,
                                            alignment: Alignment.centerRight,
                                            child: Text('₹ ${fmt.format(order.isPaid ? 0.0 : order.pendingAmount)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFD4AF37))),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 30),
                        
                        // Footer
                        const Center(
                          child: Column(
                            children: [
                              Text(
                                    'Thank you!',
                                    style: TextStyle(
                                      fontFamily: 'serif',
                                      fontStyle: FontStyle.italic,
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFD4AF37),
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Stitched with love and care',
                                    style: TextStyle(
                                      fontFamily: 'serif',
                                      fontSize: 14,
                                      color: Color(0xFFD4AF37),
                                    ),
                                  ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 30),
                        
                        // Social Handles
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt_outlined, size: 14, color: Colors.purple),
                            SizedBox(width: 4),
                            Text('bhuvana_designers_vellakovil', style: TextStyle(fontSize: 10)),
                            SizedBox(width: 16),
                            Icon(Icons.message, size: 14, color: Colors.green),
                            SizedBox(width: 4),
                            Text('9994979201', style: TextStyle(fontSize: 10)),
                          ],
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
                    onPressed: _isSharing ? null : _shareAsPdf,
                    icon: _isSharing 
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.picture_as_pdf, size: 18),
                    label: const Text('WhatsApp (PDF)'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
