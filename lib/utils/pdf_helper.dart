import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../models/models.dart';
import 'app_store.dart';

class PdfHelper {
  static Future<pw.Document> generateDocument(Order order, AppStore store) async {
    final pdf = pw.Document();
    
    // Load asset logo
    final ByteData logoData = await rootBundle.load('assets/images/logo.png');
    final Uint8List logoBytes = logoData.buffer.asUint8List();
    final logoImage = pw.MemoryImage(logoBytes);

    // Load Roboto Font for rupee symbol and other texts
    final ByteData fontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final robotoFont = pw.Font.ttf(fontData);

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
                            pw.Padding(padding: const pw.EdgeInsets.all(12), child: pw.Text(item.displayName, maxLines: 2, style: const pw.TextStyle(fontSize: 12))),
                            pw.Padding(padding: const pw.EdgeInsets.all(12), child: pw.Text('${item.quantity}', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 12))),
                            pw.Padding(padding: const pw.EdgeInsets.all(12), child: pw.Text('₹ ${fmt.format(item.price)}', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 12, font: robotoFont))),
                            pw.Padding(padding: const pw.EdgeInsets.all(12), child: pw.Text('₹ ${fmt.format(item.total)}', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 12, font: robotoFont))),
                          ],
                        );
                      }),
                    ],
                  ),
                  
                  // Totals Section
                  pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border(
                        left: pw.BorderSide(color: PdfColor.fromHex('#D4AF37')),
                        right: pw.BorderSide(color: PdfColor.fromHex('#D4AF37')),
                        bottom: pw.BorderSide(color: PdfColor.fromHex('#D4AF37')),
                      ),
                    ),
                    padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    child: pw.Column(
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.end,
                          children: [
                            pw.Text('GRAND TOTAL', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, letterSpacing: 1.2)),
                            pw.SizedBox(width: 30),
                            pw.Container(
                              width: 100,
                              alignment: pw.Alignment.centerRight,
                              child: pw.Text('₹ ${fmt.format(order.totalAmount)}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, font: robotoFont)),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 4),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.end,
                          children: [
                            pw.Text('ADVANCE PAID', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#666666'))),
                            pw.SizedBox(width: 30),
                            pw.Container(
                              width: 100,
                              alignment: pw.Alignment.centerRight,
                              child: pw.Text('₹ ${fmt.format(order.isPaid ? order.totalAmount : (order.advanceAmount ?? 0.0))}', style: pw.TextStyle(fontSize: 11, font: robotoFont)),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 4),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.end,
                          children: [
                            pw.Text('BALANCE DUE', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#D4AF37'))),
                            pw.SizedBox(width: 30),
                            pw.Container(
                              width: 100,
                              alignment: pw.Alignment.centerRight,
                              child: pw.Text('₹ ${fmt.format(order.isPaid ? 0.0 : order.pendingAmount)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, font: robotoFont, color: PdfColor.fromHex('#D4AF37'))),
                            ),
                          ],
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

    return pdf;
  }

  static Future<void> printInvoice(BuildContext context, Order order, AppStore store) async {
    try {
      final pdf = await generateDocument(order, store);
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Invoice_${order.invoiceNo ?? "1001"}.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to print PDF: $e'),
            backgroundColor: const Color(0xFFE94560),
          ),
        );
      }
    }
  }

  static Future<void> shareInvoice(BuildContext context, Order order, AppStore store, {VoidCallback? onStartShare, VoidCallback? onEndShare}) async {
    if (onStartShare != null) onStartShare();
    try {
      final pdf = await generateDocument(order, store);
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
      final invoiceNum = order.invoiceNo ?? '1001';

      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/invoice_$invoiceNum.pdf';
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      bool directShared = false;
      if (Platform.isAndroid) {
        const channel = MethodChannel('com.example.billing_app/whatsapp_share');
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share PDF: $e'),
            backgroundColor: const Color(0xFFE94560),
          ),
        );
      }
    } finally {
      if (onEndShare != null) onEndShare();
    }
  }
}
