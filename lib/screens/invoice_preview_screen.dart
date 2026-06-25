import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/models.dart';
import '../utils/app_store.dart';
import '../utils/theme.dart';

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
    if (widget.autoShare) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _shareAsPdf();
      });
    }
  }

  Future<void> _shareAsPdf() async {
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

      final pdf = pw.Document();
      final ByteData logoData = await rootBundle.load('assets/images/logo.png');
      final Uint8List logoBytes = logoData.buffer.asUint8List();
      final logoImage = pw.MemoryImage(logoBytes);

      final ByteData fontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      final robotoFont = pw.Font.ttf(fontData);

      final order = widget.order;
      final fmt = NumberFormat('#,##0.00', 'en_IN');
      final invoiceNum = order.invoiceNo ?? '1001';
      final date = DateFormat('dd/MM/yyyy').format(order.orderDate);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Stack(
              children: [
                // Watermark
                pw.Positioned.fill(
                  child: pw.Center(
                    child: pw.Opacity(
                      opacity: 0.15,
                      child: pw.Image(logoImage, width: 350, height: 350),
                    ),
                  ),
                ),
                
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Header
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Image(logoImage, width: 100, height: 100),
                        pw.SizedBox(width: 20),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'BHUVANA DESIGNERS',
                                style: pw.TextStyle(
                                  fontSize: 32,
                                  color: PdfColor.fromHex('#D4AF37'),
                                  fontWeight: pw.FontWeight.bold,
                                  font: pw.Font.timesBold(),
                                ),
                              ),
                              pw.SizedBox(height: 10),
                              pw.Text(
                                'LKC Nagar, 2nd Street, old municipality office opposite',
                                style: pw.TextStyle(
                                  fontSize: 14,
                                  color: PdfColor.fromHex('#D4AF37'),
                                  font: pw.Font.times(),
                                ),
                              ),
                              pw.Text(
                                'vellakovil - 638111.',
                                style: pw.TextStyle(
                                  fontSize: 14,
                                  color: PdfColor.fromHex('#D4AF37'),
                                  font: pw.Font.times(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 40),
                    
                    // Billing Info
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('BILLED TO :', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                            pw.SizedBox(height: 8),
                            pw.Text(order.customerName, style: const pw.TextStyle(fontSize: 12)),
                          ],
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('INVOICE ID :', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                            pw.SizedBox(height: 8),
                            pw.Text('#$invoiceNum', style: const pw.TextStyle(fontSize: 12)),
                          ],
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('INVOICE DATE :', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                            pw.SizedBox(height: 8),
                            pw.Text(date, style: const pw.TextStyle(fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 40),
                    
                    // Table Header & Items
                    pw.Table(
                      border: pw.TableBorder(
                        top: pw.BorderSide(color: PdfColor.fromHex('#D4AF37')),
                        left: pw.BorderSide(color: PdfColor.fromHex('#D4AF37')),
                        right: pw.BorderSide(color: PdfColor.fromHex('#D4AF37')),
                        bottom: pw.BorderSide(color: PdfColor.fromHex('#D4AF37')),
                        verticalInside: pw.BorderSide(color: PdfColor.fromHex('#D4AF37')),
                      ),
                      columnWidths: {
                        0: const pw.FlexColumnWidth(1),
                        1: const pw.FlexColumnWidth(4),
                        2: const pw.FlexColumnWidth(1.2),
                        3: const pw.FlexColumnWidth(2),
                        4: const pw.FlexColumnWidth(2),
                      },
                      children: [
                        // Header Row
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: PdfColor.fromHex('#FFF9C4')), // Light yellow/gold
                          children: [
                            pw.Padding(padding: const pw.EdgeInsets.all(12), child: pw.Text('NO', style: pw.TextStyle(color: PdfColor.fromHex('#D4AF37'), fontWeight: pw.FontWeight.bold, fontSize: 10))),
                            pw.Padding(padding: const pw.EdgeInsets.all(12), child: pw.Text('DESCRIPTION', style: pw.TextStyle(color: PdfColor.fromHex('#D4AF37'), fontWeight: pw.FontWeight.bold, fontSize: 10))),
                            pw.Padding(padding: const pw.EdgeInsets.all(12), child: pw.Text('QTY', textAlign: pw.TextAlign.center, style: pw.TextStyle(color: PdfColor.fromHex('#D4AF37'), fontWeight: pw.FontWeight.bold, fontSize: 10))),
                            pw.Padding(padding: const pw.EdgeInsets.all(12), child: pw.Text('PRICE', textAlign: pw.TextAlign.center, style: pw.TextStyle(color: PdfColor.fromHex('#D4AF37'), fontWeight: pw.FontWeight.bold, fontSize: 10))),
                            pw.Padding(padding: const pw.EdgeInsets.all(12), child: pw.Text('SUBTOTAL', textAlign: pw.TextAlign.right, style: pw.TextStyle(color: PdfColor.fromHex('#D4AF37'), fontWeight: pw.FontWeight.bold, fontSize: 10))),
                          ],
                        ),
                        // Items
                        ...List.generate(order.items.length, (index) {
                          final item = order.items[index];
                          return pw.TableRow(
                            verticalAlignment: pw.TableCellVerticalAlignment.middle,
                            children: [
                              pw.Padding(padding: const pw.EdgeInsets.all(12), child: pw.Text('${index + 1}', style: const pw.TextStyle(fontSize: 12))),
                              pw.Padding(padding: const pw.EdgeInsets.all(12), child: pw.Text(item.customName ?? item.categoryName, maxLines: 2, style: const pw.TextStyle(fontSize: 12))),
                              pw.Padding(padding: const pw.EdgeInsets.all(12), child: pw.Text('${item.quantity}', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 12))),
                              pw.Padding(padding: const pw.EdgeInsets.all(12), child: pw.Text('₹ ${fmt.format(item.price)}', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 12, font: robotoFont))),
                              pw.Padding(padding: const pw.EdgeInsets.all(12), child: pw.Text('₹ ${fmt.format(item.total)}', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 12, font: robotoFont))),
                            ],
                          );
                        }),
                      ],
                    ),
                    
                    // Grand Total Row
                    pw.Container(
                      decoration: pw.BoxDecoration(
                        border: pw.Border(
                          left: pw.BorderSide(color: PdfColor.fromHex('#D4AF37')),
                          right: pw.BorderSide(color: PdfColor.fromHex('#D4AF37')),
                          bottom: pw.BorderSide(color: PdfColor.fromHex('#D4AF37')),
                        ),
                      ),
                      padding: const pw.EdgeInsets.all(12),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.end,
                        children: [
                          pw.Text('GRAND TOTAL', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, letterSpacing: 1.2)),
                          pw.SizedBox(width: 30),
                          pw.Container(
                            width: 100, // Approximate width of SUBTOTAL column to align text
                            alignment: pw.Alignment.centerRight,
                            child: pw.Text('₹ ${fmt.format(order.totalAmount)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, font: robotoFont)),
                          ),
                        ],
                      ),
                    ),
                    
                    pw.Spacer(),
                    
                    // Footer
                    pw.Center(
                      child: pw.Column(
                        children: [
                          pw.Text(
                            'Thank you!',
                            style: pw.TextStyle(
                              fontSize: 32,
                              color: PdfColor.fromHex('#D4AF37'),
                              font: pw.Font.timesBoldItalic(),
                            ),
                          ),
                          pw.SizedBox(height: 10),
                          pw.Text(
                            'Stitched with love and care',
                            style: pw.TextStyle(
                              fontSize: 16,
                              color: PdfColor.fromHex('#D4AF37'),
                              font: pw.Font.times(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 40),
                    
                    // Social Handles
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        // We could add images for icons, but since we may not have them we can just write it or leave placeholder text.
                        pw.Text('Instagram: @bhuvana_designers_vellakovil', style: const pw.TextStyle(fontSize: 12)),
                        pw.SizedBox(width: 20),
                        pw.Text('WhatsApp: 9994979201', style: const pw.TextStyle(fontSize: 12)),
                      ],
                    ),
                    pw.SizedBox(height: 20),
                  ],
                ),
              ],
            );
          },
        ),
      );

      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/invoice_$invoiceNum.pdf';
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      bool directShared = false;
      if (Platform.isAndroid) {
        final channel = const MethodChannel('com.example.billing_app/whatsapp_share');
        try {
          await channel.invokeMethod('shareToWhatsApp', {
            'phone': order.customerPhone,
            'filePath': file.path,
          });
          directShared = true;
        } catch (e) {
          debugPrint('MethodChannel direct WhatsApp share failed: $e');
        }
      }

      if (!directShared) {
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'application/pdf')],
          text: shareText.isNotEmpty ? shareText : null,
        );
      }
      
      await store.markReminderSent(order.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share PDF: $e'),
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
    buffer.writeln('Thank you for choosing Bhuvana Designers!');
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
                                              Expanded(flex: 4, child: Text(item.customName ?? item.categoryName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
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
                                // Grand Total
                                Container(
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      left: BorderSide(color: Color(0xFFD4AF37)),
                                      right: BorderSide(color: Color(0xFFD4AF37)),
                                      bottom: BorderSide(color: Color(0xFFD4AF37)),
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      const Text('GRAND TOTAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                                      const SizedBox(width: 20),
                                      Container(
                                        width: 80,
                                        alignment: Alignment.centerRight,
                                        child: Text('₹ ${fmt.format(order.totalAmount)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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
