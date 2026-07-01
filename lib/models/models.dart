// lib/models/models.dart



class Customer {
  final String id;
  String? customerId;
  String name;
  String phone;
  DateTime createdAt;
  // categoryName -> list of measurements (synced from MongoDB embedded measurements map)
  Map<String, List<MeasurementField>> indivvidualmeasurement;

  Customer({
    required this.id,
    this.customerId,
    required this.name,
    required this.phone,
    required this.createdAt,
    Map<String, List<MeasurementField>>? indivvidualmeasurement,
  }) : indivvidualmeasurement = indivvidualmeasurement ?? {};

  Map<String, dynamic> toJson() => {
        'id': id,
        'customerId': customerId,
        'name': name,
        'phone': phone,
        'createdAt': createdAt.toIso8601String(),
        // Serialize measurements as { categoryName: { fieldName: value } }
        'indivvidualmeasurement': indivvidualmeasurement.isEmpty
            ? null
            : indivvidualmeasurement.map((catName, fields) => MapEntry(
                catName,
                Map.fromEntries(
                  fields
                      .where((f) => f.value != null && f.value!.isNotEmpty)
                      .map((f) => MapEntry(f.name, f.value)),
                ),
              )),
      };

  factory Customer.fromJson(Map<String, dynamic> j) {
    Map<String, List<MeasurementField>> measurementsMap = {};
    
    // Fallback for older local data format
    if (j['measurements'] != null && j['measurements'] is Map) {
      final raw = j['measurements'] as Map;
      raw.forEach((catId, fields) {
        if (fields is Map) {
          final fieldList = fields.entries
              .map((e) => MeasurementField(
                    name: e.key.toString(),
                    value: e.value?.toString(),
                  ))
              .toList();
          measurementsMap[catId.toString()] = fieldList;
        }
      });
    }

    // New format
    if (j['indivvidualmeasurement'] != null && j['indivvidualmeasurement'] is Map) {
      final raw = j['indivvidualmeasurement'] as Map;
      raw.forEach((catName, fields) {
        if (fields is Map) {
          final fieldList = fields.entries
              .map((e) => MeasurementField(
                    name: e.key.toString(),
                    value: e.value?.toString(),
                  ))
              .toList();
          measurementsMap[catName.toString()] = fieldList;
        }
      });
    }
    return Customer(
      id: j['id'],
      customerId: j['customerId'],
      name: j['name'],
      phone: j['phone'],
      createdAt: DateTime.parse(j['createdAt']),
      indivvidualmeasurement: measurementsMap,
    );
  }
}

class MeasurementField {
  String name;
  String? value;

  MeasurementField({required this.name, this.value});

  MeasurementField copyWith({String? name, String? value}) =>
      MeasurementField(name: name ?? this.name, value: value ?? this.value);

  Map<String, dynamic> toJson() => {'name': name, 'value': value};
  factory MeasurementField.fromJson(Map<String, dynamic> j) =>
      MeasurementField(name: j['name'], value: j['value']);
}

class GarmentCategory {
  final String id;
  String name;
  List<String> measurementFields;
  double? basePrice;

  GarmentCategory({
    required this.id,
    required this.name,
    required this.measurementFields,
    this.basePrice,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'measurementFields': measurementFields,
        'basePrice': basePrice,
      };

  factory GarmentCategory.fromJson(Map<String, dynamic> j) => GarmentCategory(
        id: j['id'],
        name: j['name'],
        measurementFields: List<String>.from(j['measurementFields']),
        basePrice: j['basePrice'] != null ? (j['basePrice'] as num).toDouble() : null,
      );
}

class OrderItem {
  final String id;
  String categoryId;
  String categoryName;
  List<MeasurementField> measurements;
  int quantity;
  double price;
  String? notes;
  String? imageUrl;
  String? customName;

  OrderItem({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.measurements,
    required this.quantity,
    required this.price,
    this.notes,
    this.imageUrl,
    this.customName,
  });

  double get total => price * quantity;

  String get displayName => (customName != null && customName!.trim().isNotEmpty) ? customName!.trim() : categoryName;

  Map<String, dynamic> toJson() => {
        'id': id,
        'categoryId': categoryId,
        'categoryName': categoryName,
        'measurements': measurements.map((m) => m.toJson()).toList(),
        'quantity': quantity,
        'price': price,
        'notes': notes,
        'imageUrl': imageUrl,
        'customName': customName,
      };

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
        id: j['id'],
        categoryId: j['categoryId'],
        categoryName: j['categoryName'],
        measurements: (j['measurements'] as List)
            .map((m) => MeasurementField.fromJson(m))
            .toList(),
        quantity: j['quantity'],
        price: (j['price'] as num).toDouble(),
        notes: j['notes'],
        imageUrl: j['imageUrl'],
        customName: j['customName'],
      );
}

enum OrderStatus { pending, inProgress, completed, delivered }

extension OrderStatusExt on OrderStatus {
  String get label {
    switch (this) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.inProgress:
        return 'In Progress';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.delivered:
        return 'Delivered';
    }
  }

  String get emoji {
    switch (this) {
      case OrderStatus.pending:
        return '🕐';
      case OrderStatus.inProgress:
        return '✂️';
      case OrderStatus.completed:
        return '✅';
      case OrderStatus.delivered:
        return '📦';
    }
  }
}

class Order {
  final String id;
  String? invoiceNo;
  String customerId;
  String customerName;
  String customerPhone;
  DateTime orderDate;
  DateTime deliveryDate;
  List<OrderItem> items;
  OrderStatus status;
  bool isPaid;
  double? advanceAmount;
  DateTime? lastReminderSentAt;

  Order({
    required this.id,
    this.invoiceNo,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.orderDate,
    required this.deliveryDate,
    required this.items,
    this.status = OrderStatus.pending,
    this.isPaid = false,
    this.advanceAmount,
    this.lastReminderSentAt,
  });

  double get totalAmount => items.fold(0, (sum, i) => sum + i.total);
  double get pendingAmount => isPaid ? 0.0 : totalAmount - (advanceAmount ?? 0);

  Map<String, dynamic> toJson() => {
        'id': id,
        'invoiceNo': invoiceNo,
        'customerId': customerId,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'orderDate': orderDate.toIso8601String(),
        'deliveryDate': deliveryDate.toIso8601String(),
        'items': items.map((i) => i.toJson()).toList(),
        'status': status.index,
        'isPaid': isPaid,
        'advanceAmount': advanceAmount,
        'totalAmount': totalAmount,
        'lastReminderSentAt': lastReminderSentAt?.toIso8601String(),
      };

  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id: j['id'],
        invoiceNo: j['invoiceNo'],
        customerId: j['customerId'],
        customerName: j['customerName'],
        customerPhone: j['customerPhone'],
        orderDate: DateTime.parse(j['orderDate']),
        deliveryDate: DateTime.parse(j['deliveryDate']),
        items: (j['items'] as List).map((i) => OrderItem.fromJson(i)).toList(),
        status: OrderStatus.values[j['status']],
        isPaid: j['isPaid'],
        advanceAmount: j['advanceAmount'] != null
            ? (j['advanceAmount'] as num).toDouble()
            : null,
        lastReminderSentAt: j['lastReminderSentAt'] != null
            ? DateTime.parse(j['lastReminderSentAt'])
            : null,
      );
}
