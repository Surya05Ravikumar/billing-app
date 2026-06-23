// lib/utils/app_store.dart

import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';

const _uuid = Uuid();

class AppStore extends ChangeNotifier {
  List<Order> _orders = [];
  List<Customer> _customers = [];
  List<GarmentCategory> _categories = [];

  List<Order> get orders => List.unmodifiable(_orders);
  List<Customer> get customers => List.unmodifiable(_customers);
  List<GarmentCategory> get categories => List.unmodifiable(_categories);
  
  String _gpayLink = '';
  String get gpayLink => _gpayLink;

  String _gpayNumber = '';
  String get gpayNumber => _gpayNumber;

  String _sheetsUrl = '';
  String get sheetsUrl => _sheetsUrl;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  String _syncStatus = '';
  String get syncStatus => _syncStatus;

  // MongoDB configuration
  String _mongodbUrl = 'https://billing-app-tllw.onrender.com/api';
  String get mongodbUrl => _mongodbUrl;

  bool _isMongodbEnabled = false;
  bool get isMongodbEnabled => _isMongodbEnabled;

  String _mongodbSyncStatus = '';
  String get mongodbSyncStatus => _mongodbSyncStatus;

  bool _isMongodbSyncing = false;
  bool get isMongodbSyncing => _isMongodbSyncing;

  // Offline Sync Queue variables
  List<SyncTask> _syncQueue = [];
  List<SyncTask> get syncQueue => List.unmodifiable(_syncQueue);
  Timer? _syncTimer;
  bool _isProcessingQueue = false;
  bool get isProcessingQueue => _isProcessingQueue;

  // Dashboard stats
  int get todayOrdersCount {
    final today = DateTime.now();
    return _orders
        .where((o) =>
            o.orderDate.year == today.year &&
            o.orderDate.month == today.month &&
            o.orderDate.day == today.day)
        .length;
  }

  int get pendingDeliveries =>
      _orders.where((o) => o.status != OrderStatus.delivered).length;

  int get completedOrders =>
      _orders.where((o) => o.status == OrderStatus.completed || o.status == OrderStatus.delivered).length;

  double get totalPendingPayments => _orders
      .where((o) => !o.isPaid)
      .fold(0.0, (sum, o) => sum + o.pendingAmount);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _gpayLink = prefs.getString('gpayLink') ?? '';
    _gpayNumber = prefs.getString('gpayNumber') ?? '';
    _sheetsUrl = prefs.getString('sheetsUrl') ?? '';
    _syncStatus = _sheetsUrl.isNotEmpty ? 'Sync pending (offline)' : '';

    _mongodbUrl = prefs.getString('mongodbUrl') ?? 'https://billing-app-tllw.onrender.com/api';
    // Remove the override that forces it back to render
    _isMongodbEnabled = prefs.getBool('isMongodbEnabled') ?? false;
    
    // Load offline sync queue
    final queueJson = prefs.getString('syncQueue');
    if (queueJson != null) {
      final list = jsonDecode(queueJson) as List;
      _syncQueue = list.map((e) => SyncTask.fromJson(e)).toList();
    }
    
    _mongodbSyncStatus = _isMongodbEnabled 
        ? (_syncQueue.isEmpty ? 'Connected (Synced)' : 'Sync pending (${_syncQueue.length} offline)')
        : '';

    startSyncTimer();

    final ordersJson = prefs.getString('orders');
    if (ordersJson != null) {
      final list = jsonDecode(ordersJson) as List;
      _orders = list.map((e) => Order.fromJson(e)).toList();

      // Enforce strictly unique invoice numbers
      final updatedLegacy = _ensureStrictlyUniqueInvoiceNumbers();
      if (updatedLegacy) {
        await _save();
      }
    }

    final customersJson = prefs.getString('customers');
    if (customersJson != null) {
      final list = jsonDecode(customersJson) as List;
      _customers = list.map((e) => Customer.fromJson(e)).toList();
    }

    final categoriesJson = prefs.getString('categories');
    if (categoriesJson != null) {
      final list = jsonDecode(categoriesJson) as List;
      _categories = list.map((e) => GarmentCategory.fromJson(e)).toList();
      
      bool updatedCategories = false;
      for (final cat in _categories) {
        if (cat.basePrice == null) {
          switch (cat.name.trim().toLowerCase()) {
            case 'blouse':
              cat.basePrice = 350.0;
              break;
            case 'chudi / salwar':
            case 'chudi':
            case 'salwar':
              cat.basePrice = 450.0;
              break;
            case 'saree falls':
              cat.basePrice = 80.0;
              break;
            case 'skirt':
              cat.basePrice = 200.0;
              break;
            case 'shirt':
              cat.basePrice = 300.0;
              break;
            default:
              cat.basePrice = 150.0;
          }
          updatedCategories = true;
        }
      }
      if (updatedCategories) {
        await _save();
      }
    } else {
      _categories = _defaultCategories();
      await _save();
    }

    notifyListeners();

    // Auto-recovery: If local database is empty but a sheets URL is present, trigger cloud restore
    if (_orders.isEmpty && _sheetsUrl.isNotEmpty) {
      pullFromGoogleSheets();
    } else if (_orders.isEmpty && _isMongodbEnabled) {
      pullFromMongoDB();
    }
  }

  bool _ensureStrictlyUniqueInvoiceNumbers() {
    final Map<String, List<Order>> invoiceMap = {};
    for (final order in _orders) {
      final inv = order.invoiceNo?.trim() ?? '';
      if (inv.isNotEmpty) {
        invoiceMap.putIfAbsent(inv, () => []).add(order);
      }
    }

    int nextInvoiceNum = 1000;
    for (final inv in invoiceMap.keys) {
      final val = int.tryParse(inv);
      if (val != null && val > nextInvoiceNum) {
        nextInvoiceNum = val;
      }
    }
    nextInvoiceNum += 1;

    final Set<String> usedInvoices = {};
    for (final order in _orders) {
      final inv = order.invoiceNo?.trim() ?? '';
      final val = int.tryParse(inv);
      if (inv.isNotEmpty && val != null && val >= 1001) {
        if (!usedInvoices.contains(inv) && invoiceMap[inv]!.length == 1) {
          usedInvoices.add(inv);
        }
      }
    }

    bool changed = false;
    for (final order in _orders) {
      final inv = order.invoiceNo?.trim() ?? '';
      final val = int.tryParse(inv);
      
      bool needsReassignment = false;
      if (inv.isEmpty || val == null || val < 1001) {
        needsReassignment = true;
      } else if (invoiceMap[inv]!.length > 1) {
        if (!usedInvoices.contains(inv)) {
          usedInvoices.add(inv);
        } else {
          needsReassignment = true;
        }
      }

      if (needsReassignment) {
        order.invoiceNo = nextInvoiceNum.toString();
        usedInvoices.add(order.invoiceNo!);
        nextInvoiceNum++;
        changed = true;
      }
    }
    return changed;
  }

  Future<void> _save() async {
    _ensureStrictlyUniqueInvoiceNumbers(); // Enforce strict uniqueness on every save!
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'orders', jsonEncode(_orders.map((o) => o.toJson()).toList()));
    await prefs.setString(
        'customers', jsonEncode(_customers.map((c) => c.toJson()).toList()));
    await prefs.setString('categories',
        jsonEncode(_categories.map((c) => c.toJson()).toList()));
    
    syncWithGoogleSheets();
  }

  // Orders
  Future<void> addOrder(Order order) async {
    int maxInvoice = 1000;
    for (final o in _orders) {
      if (o.invoiceNo != null && o.invoiceNo!.isNotEmpty) {
        final val = int.tryParse(o.invoiceNo!);
        if (val != null && val > maxInvoice) {
          maxInvoice = val;
        }
      }
    }
    order.invoiceNo = (maxInvoice + 1).toString();
    _orders.insert(0, order);
    _updateCustomerMeasurementsLocally(order);
    await _save();
    
    if (_isMongodbEnabled) {
      try {
        final url = '$_mongodbUrl/orders';
        final response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(order.toJson()),
        ).timeout(const Duration(seconds: 5));
        
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(response.body);
          if (decoded['invoiceNo'] != null) {
            order.invoiceNo = decoded['invoiceNo'].toString();
            await _save();
          }
        } else {
          _addToQueue(SyncTask(action: 'POST', endpoint: 'orders', id: order.id, data: order.toJson()));
        }
      } catch (_) {
        _addToQueue(SyncTask(action: 'POST', endpoint: 'orders', id: order.id, data: order.toJson()));
      }
    }
    notifyListeners();
  }

  /// Updates the local Customer object's measurements map from order items.
  /// This ensures auto-fill works even before a full MongoDB sync.
  void _updateCustomerMeasurementsLocally(Order order) {
    final custIdx = _customers.indexWhere((c) => c.id == order.customerId);
    if (custIdx == -1) return;
    final customer = _customers[custIdx];
    for (final item in order.items) {
      if (item.measurements.isNotEmpty) {
        final filledMeasurements = item.measurements
            .where((m) => m.value != null && m.value!.isNotEmpty)
            .toList();
        if (filledMeasurements.isNotEmpty) {
          customer.indivvidualmeasurement[item.categoryName.toLowerCase()] = filledMeasurements
              .map((m) => MeasurementField(name: m.name, value: m.value))
              .toList();
        }
      }
    }
    // No notifyListeners here — caller does it
  }

  Future<void> updateOrder(Order order) async {
    final idx = _orders.indexWhere((o) => o.id == order.id);
    if (idx != -1) {
      _orders[idx] = order;
      _updateCustomerMeasurementsLocally(order);
      await _save();
      if (_isMongodbEnabled) {
        _apiPut('orders', order.id, order.toJson());
      }
      notifyListeners();
    }
  }

  Future<void> deleteOrder(String id) async {
    _orders.removeWhere((o) => o.id == id);
    await _save();
    if (_isMongodbEnabled) {
      _apiDelete('orders', id);
    }
    notifyListeners();
  }

  // Customers
  Future<Customer> addCustomer(String name, String phone) async {
    final customer = Customer(
      id: _uuid.v4(),
      name: name,
      phone: phone,
      createdAt: DateTime.now(),
    );
    _customers.add(customer);
    await _save();
    
    if (_isMongodbEnabled) {
      try {
        final url = '$_mongodbUrl/customers';
        final response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(customer.toJson()),
        ).timeout(const Duration(seconds: 5));
        
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(response.body);
          if (decoded['customerId'] != null) {
            customer.customerId = decoded['customerId'].toString();
            await _save();
          }
        } else {
          _addToQueue(SyncTask(action: 'POST', endpoint: 'customers', id: customer.id, data: customer.toJson()));
        }
      } catch (_) {
        _addToQueue(SyncTask(action: 'POST', endpoint: 'customers', id: customer.id, data: customer.toJson()));
      }
    }
    notifyListeners();
    return customer;
  }

  Future<void> updateCustomer(Customer customer) async {
    final idx = _customers.indexWhere((c) => c.id == customer.id);
    if (idx != -1) {
      _customers[idx] = customer;
      await _save();
      if (_isMongodbEnabled) {
        _apiPut('customers', customer.id, customer.toJson());
      }
      notifyListeners();
    }
  }

  Future<void> deleteCustomer(String id) async {
    _customers.removeWhere((c) => c.id == id);
    await _save();
    if (_isMongodbEnabled) {
      _apiDelete('customers', id);
    }
    notifyListeners();
  }

  // Categories
  Future<void> addCategory(String name, List<String> fields, {double? basePrice}) async {
    final cat = GarmentCategory(
      id: _uuid.v4(),
      name: name,
      measurementFields: fields,
      basePrice: basePrice ?? 150.0,
    );
    _categories.add(cat);
    await _save();
    if (_isMongodbEnabled) {
      _apiPost('categories', cat.toJson());
    }
    notifyListeners();
  }

  Future<void> updateCategory(GarmentCategory cat) async {
    final idx = _categories.indexWhere((c) => c.id == cat.id);
    if (idx != -1) {
      _categories[idx] = cat;
      await _save();
      if (_isMongodbEnabled) {
        _apiPut('categories', cat.id, cat.toJson());
      }
      notifyListeners();
    }
  }

  Future<void> deleteCategory(String id) async {
    _categories.removeWhere((c) => c.id == id);
    await _save();
    if (_isMongodbEnabled) {
      _apiDelete('categories', id);
    }
    notifyListeners();
  }

  String generateId() => _uuid.v4();

  Future<void> updateGpayLink(String link) async {
    _gpayLink = link.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gpayLink', _gpayLink);
    notifyListeners();
  }

  Future<void> updateGpayNumber(String number) async {
    _gpayNumber = number.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gpayNumber', _gpayNumber);
    notifyListeners();
  }

  Future<void> updateSheetsUrl(String url) async {
    _sheetsUrl = url.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sheetsUrl', _sheetsUrl);
    notifyListeners();
    await syncWithGoogleSheets();
  }

  Future<void> syncWithGoogleSheets() async {
    if (_sheetsUrl.isEmpty || _isSyncing) return;

    if (_sheetsUrl.contains('docs.google.com/spreadsheets')) {
      _syncStatus = 'Sync failed: spreadsheet link pasted. Need deployed Web App URL!';
      notifyListeners();
      return;
    }

    _isSyncing = true;
    _syncStatus = 'Syncing...';
    notifyListeners();

    try {
      final Map<String, dynamic> payload = {
        'orders': _orders.map((o) => o.toJson()).toList(),
        'customers': _customers.map((c) => c.toJson()).toList(),
        'categories': _categories.map((c) => c.toJson()).toList(),
      };

      final response = await _postWithRedirects(
        _sheetsUrl,
        {'Content-Type': 'application/json'},
        jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true) {
          _syncStatus = 'Sync successful!';
        } else {
          _syncStatus = 'Sync failed: ${decoded['error']}';
        }
      } else {
        _syncStatus = 'Sync failed (server error: ${response.statusCode})';
      }
    } catch (e) {
      _syncStatus = 'Sync pending (offline)';
      if (kDebugMode) {
        print('Sync error: $e');
      }
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  String? _getHeader(Map<String, String> headers, String name) {
    name = name.toLowerCase();
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == name) {
        return entry.value;
      }
    }
    return null;
  }

  Future<bool> pullFromGoogleSheets() async {
    if (_sheetsUrl.isEmpty || _isSyncing) return false;

    if (_sheetsUrl.contains('docs.google.com/spreadsheets')) {
      _syncStatus = 'Sync failed: spreadsheet link pasted. Need deployed Web App URL!';
      notifyListeners();
      return false;
    }

    _isSyncing = true;
    _syncStatus = 'Fetching from Cloud...';
    notifyListeners();

    try {
      final response = await _getWithRedirects(
        _sheetsUrl,
        {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true) {
          final customersData = decoded['customers'] as List?;
          final categoriesData = decoded['categories'] as List?;
          final ordersData = decoded['orders'] as List?;

          // Map and import Customers
          if (customersData != null && customersData.isNotEmpty) {
            _customers = customersData.map((e) => Customer.fromJson(e)).toList();
          }
          // Map and import Categories
          if (categoriesData != null && categoriesData.isNotEmpty) {
            _categories = categoriesData.map((e) => GarmentCategory.fromJson(e)).toList();
          }
          // Map and import Orders
          if (ordersData != null && ordersData.isNotEmpty) {
            _orders = ordersData.map((e) => Order.fromJson(e)).toList();
          }

          // Enforce strict uniqueness and sequential IDs
          _ensureStrictlyUniqueInvoiceNumbers();

          // Save the freshly imported data locally
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
              'orders', jsonEncode(_orders.map((o) => o.toJson()).toList()));
          await prefs.setString(
              'customers', jsonEncode(_customers.map((c) => c.toJson()).toList()));
          await prefs.setString('categories',
              jsonEncode(_categories.map((c) => c.toJson()).toList()));

          _syncStatus = 'Import successful!';
          notifyListeners();
          return true;
        } else {
          _syncStatus = 'Import failed: ${decoded['error']}';
        }
      } else {
        _syncStatus = 'Import failed (server error: ${response.statusCode})';
      }
    } catch (e) {
      _syncStatus = 'Import failed (offline or script error)';
      if (kDebugMode) {
        print('Import error: $e');
      }
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
    return false;
  }

  Future<http.Response> _getWithRedirects(String url, Map<String, String> headers) async {
    final client = http.Client();
    var currentUri = Uri.parse(url);
    
    var request = http.Request('GET', currentUri)
      ..followRedirects = false;
    
    headers.forEach((key, val) {
      request.headers[key] = val;
    });

    var streamedResponse = await client.send(request).timeout(const Duration(seconds: 15));
    var response = await http.Response.fromStream(streamedResponse);

    for (int i = 0; i < 5; i++) {
      if (response.statusCode == 301 || response.statusCode == 302 || response.statusCode == 303 || response.statusCode == 307 || response.statusCode == 308) {
        final location = _getHeader(response.headers, 'location');
        if (location == null) {
          return response;
        }
        
        currentUri = currentUri.resolve(location);
        
        final getRequest = http.Request('GET', currentUri)
          ..followRedirects = false;
        
        headers.forEach((key, val) {
          getRequest.headers[key] = val;
        });

        streamedResponse = await client.send(getRequest).timeout(const Duration(seconds: 15));
        response = await http.Response.fromStream(streamedResponse);
        continue;
      }
      break;
    }
    
    client.close();
    return response;
  }

  Future<http.Response> _postWithRedirects(String url, Map<String, String> headers, String body) async {
    final client = http.Client();
    var currentUri = Uri.parse(url);
    
    // First request is a POST request
    final request = http.Request('POST', currentUri)
      ..followRedirects = false
      ..body = body;
    
    headers.forEach((key, val) {
      request.headers[key] = val;
    });

    var streamedResponse = await client.send(request).timeout(const Duration(seconds: 15));
    var response = await http.Response.fromStream(streamedResponse);

    // Follow redirect with GET request (required for Google Apps Script Web App)
    for (int i = 0; i < 5; i++) {
      if (response.statusCode == 301 || response.statusCode == 302 || response.statusCode == 303 || response.statusCode == 307 || response.statusCode == 308) {
        final location = _getHeader(response.headers, 'location');
        if (location == null) {
          return response;
        }
        
        currentUri = currentUri.resolve(location);
        
        // Google redirects should be followed with a GET request
        final getRequest = http.Request('GET', currentUri)
          ..followRedirects = false;
        
        // Copy headers except Content-Type
        headers.forEach((key, val) {
          if (key.toLowerCase() != 'content-type') {
            getRequest.headers[key] = val;
          }
        });

        streamedResponse = await client.send(getRequest).timeout(const Duration(seconds: 15));
        response = await http.Response.fromStream(streamedResponse);
        continue;
      }
      break;
    }
    
    client.close();
    return response;
  }

  List<GarmentCategory> _defaultCategories() => [
        GarmentCategory(
          id: _uuid.v4(),
          name: 'Blouse',
          measurementFields: ['Chest', 'Waist', 'Hip', 'Sleeve Length', 'Shoulder', 'Back Length', 'Front Length', 'Neck'],
          basePrice: 350.0,
        ),
        GarmentCategory(
          id: _uuid.v4(),
          name: 'Chudi / Salwar',
          measurementFields: ['Chest', 'Waist', 'Hip', 'Shoulder', 'Sleeve Length', 'Kurta Length', 'Pant Length', 'Seat'],
          basePrice: 450.0,
        ),
        GarmentCategory(
          id: _uuid.v4(),
          name: 'Saree Falls',
          measurementFields: ['Length', 'Width'],
          basePrice: 80.0,
        ),
        GarmentCategory(
          id: _uuid.v4(),
          name: 'Skirt',
          measurementFields: ['Waist', 'Hip', 'Length'],
          basePrice: 200.0,
        ),
        GarmentCategory(
          id: _uuid.v4(),
          name: 'Shirt',
          measurementFields: ['Chest', 'Waist', 'Shoulder', 'Sleeve Length', 'Collar', 'Length'],
          basePrice: 300.0,
        ),
      ];

  // Export all data as a backup JSON string
  String exportBackup() {
    final Map<String, dynamic> backupData = {
      'backupVersion': 1,
      'backupDate': DateTime.now().toIso8601String(),
      'orders': _orders.map((o) => o.toJson()).toList(),
      'customers': _customers.map((c) => c.toJson()).toList(),
      'categories': _categories.map((c) => c.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(backupData);
  }

  // Restore data from a backup JSON string
  Future<bool> importBackup(String backupJson) async {
    try {
      final decoded = jsonDecode(backupJson);
      if (decoded is! Map<String, dynamic>) return false;

      // Validate basic structure
      if (!decoded.containsKey('orders') ||
          !decoded.containsKey('customers') ||
          !decoded.containsKey('categories')) {
        return false;
      }

      final ordersData = decoded['orders'] as List;
      final customersData = decoded['customers'] as List;
      final categoriesData = decoded['categories'] as List;

      // Map data to models
      final importedOrders = ordersData.map((e) => Order.fromJson(e)).toList();
      final importedCustomers = customersData.map((e) => Customer.fromJson(e)).toList();
      final importedCategories = categoriesData.map((e) => GarmentCategory.fromJson(e)).toList();

      // If mapping succeeds, overwrite and persist
      _orders = importedOrders;
      _customers = importedCustomers;
      _categories = importedCategories;

      await _save();
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Backup import failed: $e');
      }
      return false;
    }
  }

  // --- MongoDB Operations ---

  Future<void> updateMongodbUrl(String url) async {
    _mongodbUrl = url.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mongodbUrl', _mongodbUrl);
    notifyListeners();
  }

  Future<void> toggleMongodbEnabled(bool enabled) async {
    _isMongodbEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isMongodbEnabled', _isMongodbEnabled);
    if (_isMongodbEnabled) {
      _mongodbSyncStatus = _syncQueue.isEmpty ? 'Connected (Synced)' : 'Sync pending (${_syncQueue.length} offline)';
      startSyncTimer();
      _processSyncQueue();
    } else {
      _mongodbSyncStatus = '';
      _syncTimer?.cancel();
    }
    notifyListeners();
  }

  Future<void> syncWithMongoDB() async {
    if (_mongodbUrl.isEmpty || _isMongodbSyncing) return;

    _isMongodbSyncing = true;
    _mongodbSyncStatus = 'Syncing...';
    notifyListeners();

    try {
      final Map<String, dynamic> payload = {
        'orders': _orders.map((o) => o.toJson()).toList(),
        'customers': _customers.map((c) => c.toJson()).toList(),
        'categories': _categories.map((c) => c.toJson()).toList(),
      };

      final response = await http.post(
        Uri.parse('$_mongodbUrl/sync'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true) {
          _mongodbSyncStatus = 'Sync successful!';
        } else {
          _mongodbSyncStatus = 'Sync failed: ${decoded['error']}';
        }
      } else {
        _mongodbSyncStatus = 'Sync failed (server error: ${response.statusCode})';
      }
    } catch (e) {
      _mongodbSyncStatus = 'Sync pending (offline)';
      if (kDebugMode) {
        print('MongoDB Sync error: $e');
      }
    } finally {
      _isMongodbSyncing = false;
      notifyListeners();
    }
  }

  Future<bool> pullFromMongoDB() async {
    if (_mongodbUrl.isEmpty || _isMongodbSyncing) return false;

    _isMongodbSyncing = true;
    _mongodbSyncStatus = 'Fetching from Cloud...';
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('$_mongodbUrl/sync'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true) {
          final customersData = decoded['customers'] as List?;
          final categoriesData = decoded['categories'] as List?;
          final ordersData = decoded['orders'] as List?;

          if (customersData != null && customersData.isNotEmpty) {
            _customers = customersData.map((e) => Customer.fromJson(e)).toList();
          }
          if (categoriesData != null && categoriesData.isNotEmpty) {
            _categories = categoriesData.map((e) => GarmentCategory.fromJson(e)).toList();
          }
          if (ordersData != null && ordersData.isNotEmpty) {
            _orders = ordersData.map((e) => Order.fromJson(e)).toList();
          }

          _ensureStrictlyUniqueInvoiceNumbers();

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
              'orders', jsonEncode(_orders.map((o) => o.toJson()).toList()));
          await prefs.setString(
              'customers', jsonEncode(_customers.map((c) => c.toJson()).toList()));
          await prefs.setString('categories',
              jsonEncode(_categories.map((c) => c.toJson()).toList()));

          _mongodbSyncStatus = 'Import successful!';
          notifyListeners();
          return true;
        } else {
          _mongodbSyncStatus = 'Import failed: ${decoded['error']}';
        }
      } else {
        _mongodbSyncStatus = 'Import failed (server error: ${response.statusCode})';
      }
    } catch (e) {
      _mongodbSyncStatus = 'Import failed (offline or server error)';
      if (kDebugMode) {
        print('MongoDB Import error: $e');
      }
    } finally {
      _isMongodbSyncing = false;
      notifyListeners();
    }
    return false;
  }

  // --- REST HTTP Helpers ---

  Future<void> _apiPost(String endpoint, Map<String, dynamic> body) async {
    if (!_isMongodbEnabled) return;
    final id = body['id'] ?? '';
    try {
      final url = '$_mongodbUrl/$endpoint';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 4));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        _processSyncQueue();
        return;
      }
    } catch (_) {}
    _addToQueue(SyncTask(action: 'POST', endpoint: endpoint, id: id, data: body));
  }

  Future<void> _apiPut(String endpoint, String id, Map<String, dynamic> body) async {
    if (!_isMongodbEnabled) return;
    try {
      final url = '$_mongodbUrl/$endpoint/$id';
      final response = await http.put(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 4));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        _processSyncQueue();
        return;
      }
    } catch (_) {}
    _addToQueue(SyncTask(action: 'PUT', endpoint: endpoint, id: id, data: body));
  }

  Future<void> _apiDelete(String endpoint, String id) async {
    if (!_isMongodbEnabled) return;
    try {
      final url = '$_mongodbUrl/$endpoint/$id';
      final response = await http.delete(
        Uri.parse(url),
      ).timeout(const Duration(seconds: 4));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        _processSyncQueue();
        return;
      }
    } catch (_) {}
    _addToQueue(SyncTask(action: 'DELETE', endpoint: endpoint, id: id));
  }

  // --- Offline Sync Queue Helpers ---

  void _addToQueue(SyncTask task) {
    final existingIndex = _syncQueue.indexWhere((t) => t.id == task.id && t.endpoint == task.endpoint);
    if (existingIndex != -1) {
      final existingTask = _syncQueue[existingIndex];
      if (existingTask.action == 'POST' && task.action == 'PUT') {
        _syncQueue[existingIndex] = SyncTask(action: 'POST', endpoint: task.endpoint, id: task.id, data: task.data);
      } else if (existingTask.action == 'POST' && task.action == 'DELETE') {
        _syncQueue.removeAt(existingIndex);
      } else if (existingTask.action == 'PUT' && task.action == 'DELETE') {
        _syncQueue[existingIndex] = task;
      } else {
        _syncQueue[existingIndex] = task;
      }
    } else {
      _syncQueue.add(task);
    }
    _saveQueue();
    _mongodbSyncStatus = 'Sync pending (${_syncQueue.length} offline)';
    notifyListeners();
  }

  Future<void> _saveQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('syncQueue', jsonEncode(_syncQueue.map((e) => e.toJson()).toList()));
  }

  void startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (_isMongodbEnabled && _syncQueue.isNotEmpty) {
        _processSyncQueue();
      }
    });
  }

  Future<void> _processSyncQueue() async {
    if (_syncQueue.isEmpty || _isProcessingQueue || !_isMongodbEnabled) return;
    _isProcessingQueue = true;
    notifyListeners();

    List<SyncTask> successfullySynced = [];
    try {
      for (final task in List<SyncTask>.from(_syncQueue)) {
        bool success = false;
        try {
          if (task.action == 'POST') {
            final url = '$_mongodbUrl/${task.endpoint}';
            final res = await http.post(
              Uri.parse(url),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(task.data),
            ).timeout(const Duration(seconds: 4));
            success = res.statusCode >= 200 && res.statusCode < 300;
          } else if (task.action == 'PUT') {
            final url = '$_mongodbUrl/${task.endpoint}/${task.id}';
            final res = await http.put(
              Uri.parse(url),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(task.data),
            ).timeout(const Duration(seconds: 4));
            success = res.statusCode >= 200 && res.statusCode < 300;
          } else if (task.action == 'DELETE') {
            final url = '$_mongodbUrl/${task.endpoint}/${task.id}';
            final res = await http.delete(Uri.parse(url)).timeout(const Duration(seconds: 4));
            success = res.statusCode >= 200 && res.statusCode < 300;
          }
        } catch (_) {
          success = false;
        }

        if (success) {
          successfullySynced.add(task);
        } else {
          break;
        }
      }

      if (successfullySynced.isNotEmpty) {
        _syncQueue.removeWhere((t) => successfullySynced.contains(t));
        await _saveQueue();
        _mongodbSyncStatus = _syncQueue.isEmpty ? 'Connected (Synced)' : 'Sync pending (${_syncQueue.length} offline)';
      }
    } finally {
      _isProcessingQueue = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }
}

// Model class to represent offline pending tasks
class SyncTask {
  final String action; // 'POST' | 'PUT' | 'DELETE'
  final String endpoint; // 'orders' | 'customers' | 'categories'
  final String id;
  final Map<String, dynamic>? data;

  SyncTask({required this.action, required this.endpoint, required this.id, this.data});

  Map<String, dynamic> toJson() => {
    'action': action,
    'endpoint': endpoint,
    'id': id,
    'data': data,
  };

  factory SyncTask.fromJson(Map<String, dynamic> json) => SyncTask(
    action: json['action'],
    endpoint: json['endpoint'],
    id: json['id'],
    data: json['data'] != null ? Map<String, dynamic>.from(json['data']) : null,
  );
}
