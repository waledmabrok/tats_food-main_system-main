import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/order.dart';
import '../constants/app_strings.dart';
import '../database/database_helper.dart';

class PrintingService {
  PrintingService._();
  static final PrintingService instance = PrintingService._();

  /// عرض ورق الطباعة الموحّد لكل الإيصالات
  static const double _receiptWidthMm = 70;

  pw.Font? _arabicFont;
  pw.Font? _arabicFontBold;
  pw.MemoryImage? _logo;
  bool _logoLoadAttempted = false;

  Future<void> _initFonts() async {
    _arabicFont ??= pw.Font.ttf(
      await rootBundle.load('assets/fonts/Amiri-Regular.ttf'),
    );

    _arabicFontBold ??= pw.Font.ttf(
      await rootBundle.load('assets/fonts/Amiri-Bold.ttf'),
    );
  }

  /// تحميل اللوجو مرة واحدة فقط
  Future<void> _initLogo() async {
    if (_logoLoadAttempted) return;

    _logoLoadAttempted = true;

    try {
      final bytes = await rootBundle.load('assets/images/logo.png');
      _logo = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {
      _logo = null;
    }
  }

  String _formatDate(DateTime date) {
    int h = date.hour;
    final ampm = h >= 12 ? 'م' : 'ص';

    if (h > 12) h -= 12;
    if (h == 0) h = 12;

    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${h.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} $ampm';
  }

  /// تنسيق السعر
  String _formatPrice(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  pw.Widget _buildLogo({double size = 56}) {
    if (_logo == null) return pw.SizedBox();

    return pw.Center(
      child: pw.Container(
        width: size,
        height: size,
        margin: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Image(_logo!, fit: pw.BoxFit.contain),
      ),
    );
  }

  // ================================================================
  // جدول فاتورة العميل
  // الصنف | الكمية | السعر | الإجمالي
  // ================================================================

  pw.Widget _buildCustomerItemsTable(Order order) {
    final headerStyle = pw.TextStyle(font: _arabicFontBold, fontSize: 9);

    final cellStyle = pw.TextStyle(font: _arabicFont, fontSize: 9);

    final cellBoldStyle = pw.TextStyle(font: _arabicFontBold, fontSize: 9);

    return pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(
          color: const PdfColor(0.35, 0.35, 0.35),
          width: 0.8,
        ),
      ),
      child: pw.Table(
        // مهم: حدود كل الخلايا
        border: pw.TableBorder.all(
          color: const PdfColor(0.45, 0.45, 0.45),
          width: 0.6,
        ),

        // توزيع الأعمدة
        columnWidths: const {
          0: pw.FlexColumnWidth(4.2), // الصنف
          1: pw.FlexColumnWidth(1.5), // الكمية
          2: pw.FlexColumnWidth(2.0), // السعر
          3: pw.FlexColumnWidth(2.2), // الإجمالي
        },

        children: [
          // ==========================================================
          // Header
          // ==========================================================
          pw.TableRow(
            decoration: const pw.BoxDecoration(
              color: PdfColor(0.93, 0.93, 0.93),
            ),
            children: [
              pw.Container(
                alignment: pw.Alignment.center,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 3,
                  vertical: 6,
                ),
                child: pw.Text(
                  'الإجمالي',
                  style: headerStyle,
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Container(
                alignment: pw.Alignment.center,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 3,
                  vertical: 6,
                ),
                child: pw.Text(
                  'السعر',
                  style: headerStyle,
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Container(
                alignment: pw.Alignment.center,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 3,
                  vertical: 6,
                ),
                child: pw.Text(
                  'الكمية',
                  style: headerStyle,
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Container(
                alignment: pw.Alignment.center,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 6,
                ),
                child: pw.Text(
                  'الصنف',
                  style: headerStyle,
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ],
          ),

          // ==========================================================
          // Items
          // ==========================================================
          ...order.items.map(
            (item) => pw.TableRow(
              children: [
                // الإجمالي
                pw.Container(
                  alignment: pw.Alignment.center,
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 3,
                    vertical: 7,
                  ),
                  child: pw.Text(
                    _formatPrice(item.totalPrice),
                    style: cellBoldStyle,
                    textAlign: pw.TextAlign.center,
                  ),
                ),

                // السعر
                pw.Container(
                  alignment: pw.Alignment.center,
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 3,
                    vertical: 7,
                  ),
                  child: pw.Text(
                    _formatPrice(item.unitPrice),
                    style: cellStyle,
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                // الكمية
                pw.Container(
                  alignment: pw.Alignment.center,
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 3,
                    vertical: 7,
                  ),
                  child: pw.Text(
                    item.quantity.toInt().toString(),
                    style: cellStyle,
                    textAlign: pw.TextAlign.center,
                  ),
                ),

                // الصنف
                pw.Container(
                  alignment: pw.Alignment.centerRight,
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 7,
                  ),
                  child: pw.Text(
                    item.productName,
                    style: cellBoldStyle,
                    textAlign: pw.TextAlign.right,
                    softWrap: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // جدول المطبخ
  // ================================================================

  pw.Widget _buildKitchenItemsTable(Order order) {
    final headerStyle = pw.TextStyle(font: _arabicFontBold, fontSize: 12);

    final cellStyle = pw.TextStyle(font: _arabicFontBold, fontSize: 13);

    return pw.Table(
      border: pw.TableBorder.all(
        color: const PdfColor(0.6, 0.6, 0.6),
        width: 0.6,
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(4),
        1: pw.FixedColumnWidth(36),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColor(0.92, 0.92, 0.92)),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                vertical: 5,
                horizontal: 4,
              ),
              child: pw.Text('الصنف', style: headerStyle),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 5),
              child: pw.Text(
                'كمية',
                style: headerStyle,
                textAlign: pw.TextAlign.center,
              ),
            ),
          ],
        ),
        ...order.items.map(
          (item) => pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 4,
                ),
                child: pw.Text(item.productName, style: cellStyle),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 6),
                child: pw.Text(
                  item.quantity.toInt().toString(),
                  style: cellStyle,
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ================================================================
  // فاتورة العميل
  // ================================================================

  Future<void> printCustomerReceipt(Order order) async {
    await _initFonts();
    await _initLogo();

    final restaurantNameRaw = await DatabaseHelper.instance.getSetting(
      'restaurant_name',
    );

    final restaurantName =
        (restaurantNameRaw != null && restaurantNameRaw.trim().isNotEmpty)
            ? restaurantNameRaw.trim()
            : AppStrings.appName;
    final customer = order.customerId == null
        ? null
        : await DatabaseHelper.instance.getCustomerById(order.customerId!);

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          _receiptWidthMm * PdfPageFormat.mm,
          double.infinity,
        ),
        margin: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                _buildLogo(),

                // اسم المطعم
                pw.Center(
                  child: pw.Text(
                    restaurantName,
                    style: pw.TextStyle(font: _arabicFontBold, fontSize: 20),
                    textAlign: pw.TextAlign.center,
                  ),
                ),

                pw.SizedBox(height: 2),

                pw.Center(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: pw.BoxDecoration(
                      color: const PdfColor(0.9, 0.9, 0.9),
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(4),
                      ),
                    ),
                    child: pw.Text(
                      'فاتورة ضريبية مبسطة',
                      style: pw.TextStyle(font: _arabicFont, fontSize: 9),
                    ),
                  ),
                ),

                pw.SizedBox(height: 8),

                pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),

                pw.SizedBox(height: 4),

                // رقم الطلب
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'رقم الطلب:',
                      style: pw.TextStyle(font: _arabicFont, fontSize: 10),
                    ),
                    pw.Text(
                      '#${order.orderNumber}',
                      style: pw.TextStyle(font: _arabicFontBold, fontSize: 11),
                    ),
                  ],
                ),

                pw.SizedBox(height: 2),

                // التاريخ
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'التاريخ:',
                      style: pw.TextStyle(font: _arabicFont, fontSize: 10),
                    ),
                    pw.Text(
                      _formatDate(order.createdAt),
                      style: pw.TextStyle(font: _arabicFont, fontSize: 10),
                    ),
                  ],
                ),

                pw.SizedBox(height: 8),

                if (order.orderType == OrderType.delivery &&
                    customer != null) ...[
                  pw.Text(
                    'العميل: ${customer['name']}',
                    style: pw.TextStyle(font: _arabicFontBold, fontSize: 10),
                    textAlign: pw.TextAlign.right,
                  ),
                  pw.Text(
                    'الهاتف: ${customer['phone']}  •  العنوان: ${customer['address'] ?? order.deliveryAddress ?? '—'}',
                    style: pw.TextStyle(font: _arabicFont, fontSize: 9),
                    textAlign: pw.TextAlign.right,
                  ),
                  pw.SizedBox(height: 6),
                ],

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'نوع الطلب:',
                      style: pw.TextStyle(font: _arabicFont, fontSize: 10),
                    ),
                    pw.Text(
                      order.orderType.label,
                      style: pw.TextStyle(font: _arabicFontBold, fontSize: 10),
                    ),
                  ],
                ),
                if (order.orderType == OrderType.delivery &&
                    order.deliveryAddress != null) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'بيانات التوصيل: ${order.deliveryAddress}',
                    style: pw.TextStyle(font: _arabicFont, fontSize: 10),
                    textAlign: pw.TextAlign.right,
                  ),
                ],

                pw.SizedBox(height: 6),

                // ==================================================
                // جدول الأصناف
                // ==================================================
                _buildCustomerItemsTable(order),

                pw.SizedBox(height: 7),

                pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),

                pw.SizedBox(height: 6),

                // ==================================================
                // الإجماليات
                // ==================================================
                if (order.discountAmount > 0) ...[
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'المجموع:',
                        style: pw.TextStyle(font: _arabicFont, fontSize: 10),
                      ),
                      pw.Text(
                        _formatPrice(order.subtotal),
                        style: pw.TextStyle(font: _arabicFont, fontSize: 10),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 2),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'الخصم:',
                        style: pw.TextStyle(font: _arabicFont, fontSize: 10),
                      ),
                      pw.Text(
                        '- ${_formatPrice(order.discountAmount)}',
                        style: pw.TextStyle(font: _arabicFont, fontSize: 10),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                ],

                // الإجمالي النهائي
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 4,
                  ),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(
                      color: const PdfColor(0.8, 0.8, 0.8),
                      width: 1,
                    ),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(4),
                    ),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'الإجمالي المطلوب:',
                        style: pw.TextStyle(
                          font: _arabicFontBold,
                          fontSize: 13,
                        ),
                      ),
                      pw.Text(
                        '${_formatPrice(order.finalAmount)} EGP',
                        style: pw.TextStyle(
                          font: _arabicFontBold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 6),

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'المدفوع:',
                      style: pw.TextStyle(font: _arabicFont, fontSize: 10),
                    ),
                    pw.Text(
                      _formatPrice(order.paidAmount),
                      style: pw.TextStyle(font: _arabicFont, fontSize: 10),
                    ),
                  ],
                ),

                if (order.changeAmount > 0) ...[
                  pw.SizedBox(height: 2),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'الباقي:',
                        style: pw.TextStyle(font: _arabicFont, fontSize: 10),
                      ),
                      pw.Text(
                        _formatPrice(order.changeAmount),
                        style: pw.TextStyle(font: _arabicFont, fontSize: 10),
                      ),
                    ],
                  ),
                ],

                pw.SizedBox(height: 12),

                pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),

                pw.SizedBox(height: 8),

                pw.Center(
                  child: pw.Text(
                    'Thank You',
                    style: pw.TextStyle(font: _arabicFontBold, fontSize: 13),
                  ),
                ),

                pw.SizedBox(height: 2),

                pw.Center(
                  child: pw.Text(
                    'شكراً لزيارتكم! نتمنى رؤيتكم قريباً',
                    style: pw.TextStyle(font: _arabicFont, fontSize: 10),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Receipt_${order.orderNumber}',
    );
  }

  // ================================================================
  // ورقة المطبخ
  // ================================================================

  Future<void> printKitchenTicket(Order order) async {
    await _initFonts();
    await _initLogo();

    final restaurantNameRaw = await DatabaseHelper.instance.getSetting(
      'restaurant_name',
    );

    final restaurantName =
        (restaurantNameRaw != null && restaurantNameRaw.trim().isNotEmpty)
            ? restaurantNameRaw.trim()
            : AppStrings.appName;

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          _receiptWidthMm * PdfPageFormat.mm,
          double.infinity,
        ),
        margin: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                _buildLogo(size: 44),

                pw.Center(
                  child: pw.Text(
                    restaurantName,
                    style: pw.TextStyle(font: _arabicFontBold, fontSize: 14),
                  ),
                ),

                pw.SizedBox(height: 2),

                pw.Center(
                  child: pw.Text(
                    'ورقة تجهيز - المطبخ',
                    style: pw.TextStyle(font: _arabicFontBold, fontSize: 14),
                  ),
                ),

                pw.SizedBox(height: 6),

                pw.Divider(thickness: 2),

                pw.SizedBox(height: 4),

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'رقم الطلب:',
                      style: pw.TextStyle(font: _arabicFontBold, fontSize: 14),
                    ),
                    pw.Text(
                      '#${order.orderNumber}',
                      style: pw.TextStyle(font: _arabicFontBold, fontSize: 16),
                    ),
                  ],
                ),

                pw.SizedBox(height: 2),

                pw.Text(
                  'الوقت: ${_formatDate(order.createdAt)}',
                  style: pw.TextStyle(font: _arabicFont, fontSize: 10),
                ),

                pw.SizedBox(height: 4),
                pw.Text(
                  'نوع الطلب: ${order.orderType.label}',
                  style: pw.TextStyle(font: _arabicFontBold, fontSize: 12),
                ),
                if (order.orderType == OrderType.delivery &&
                    order.deliveryAddress != null)
                  pw.Text(
                    'العنوان: ${order.deliveryAddress}',
                    style: pw.TextStyle(font: _arabicFontBold, fontSize: 12),
                  ),

                pw.SizedBox(height: 6),

                pw.Divider(thickness: 2),

                pw.SizedBox(height: 4),

                // جدول المطبخ
                _buildKitchenItemsTable(order),

                if (order.notes != null && order.notes!.isNotEmpty) ...[
                  pw.SizedBox(height: 6),
                  pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'ملاحظات:',
                    style: pw.TextStyle(font: _arabicFontBold, fontSize: 12),
                  ),
                  pw.Text(
                    order.notes!,
                    style: pw.TextStyle(font: _arabicFont, fontSize: 12),
                  ),
                ],

                pw.SizedBox(height: 10),

                pw.Center(
                  child: pw.Text(
                    '-- يرجى تجهيز الطلب --',
                    style: pw.TextStyle(font: _arabicFont, fontSize: 12),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Kitchen_${order.orderNumber}',
    );
  }

  Future<void> printShiftClosingReport({
    required String userName,
    required Map<String, dynamic> result,
  }) async {
    await _initFonts();
    await _initLogo();
    final pdf = pw.Document();
    final totalSales = (result['total_sales'] as num).toDouble();
    final expenses = (result['expenses_total'] as num).toDouble();
    final expected = (result['expected_drawer_cash'] as num).toDouble();
    final actual = (result['actual_closing_cash'] as num).toDouble();
    final difference = (result['difference'] as num).toDouble();
    final orders = result['orders_count'] as int;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          _receiptWidthMm * PdfPageFormat.mm,
          double.infinity,
        ),
        margin: const pw.EdgeInsets.all(10),
        build: (_) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _buildLogo(size: 44),
              pw.Center(
                child: pw.Text(
                  'تقرير إقفال الشيفت',
                  style: pw.TextStyle(font: _arabicFontBold, fontSize: 16),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text('المسؤول: $userName',
                  style: pw.TextStyle(font: _arabicFont, fontSize: 11)),
              pw.Text('التاريخ: ${_formatDate(DateTime.now())}',
                  style: pw.TextStyle(font: _arabicFont, fontSize: 11)),
              pw.Divider(),
              _shiftRow('عدد الطلبات', orders.toString()),
              _shiftRow('إجمالي المبيعات',
                  '${_formatPrice(totalSales)} ${AppStrings.currency}'),
              _shiftRow('إجمالي المصروفات',
                  '${_formatPrice(expenses)} ${AppStrings.currency}'),
              _shiftRow('النقد المتوقع',
                  '${_formatPrice(expected)} ${AppStrings.currency}'),
              _shiftRow('النقد الفعلي',
                  '${_formatPrice(actual)} ${AppStrings.currency}'),
              pw.Divider(),
              _shiftRow(
                difference == 0 ? 'النتيجة' : 'العجز / الزيادة',
                difference == 0
                    ? 'الدرج مطابق'
                    : '${_formatPrice(difference.abs())} ${AppStrings.currency} ${difference > 0 ? 'زيادة' : 'عجز'}',
              ),
            ],
          ),
        ),
      ),
    );
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Shift_Closing_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  pw.Widget _shiftRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: _arabicFont, fontSize: 11)),
          pw.Text(value,
              style: pw.TextStyle(font: _arabicFontBold, fontSize: 11)),
        ],
      ),
    );
  }
}
