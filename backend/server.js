// backend/server.js
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 5000;

// Middleware
app.use(cors());
app.use(express.json({ limit: '50mb' })); // Support larger payloads for sync
app.use(express.urlencoded({ limit: '50mb', extended: true }));

// MongoDB Connection
const mongoURI = process.env.MONGODB_URI;
console.log('Connecting to MongoDB at:', mongoURI.replace(/\/\/.*@/, '//<credentials>@')); // Hide credentials in logs

mongoose.connect(mongoURI)
  .then(async () => {
    console.log('Successfully connected to MongoDB Atlas.');
    await seedDatabase();
  })
  .catch(err => {
    console.error('MongoDB connection error:', err.message);
    console.log('Please check your MONGODB_URI in the backend/.env file and ensure network access is enabled.');
  });

// --- Mongoose Schemas & Models ---

// 1. Counter Schema (for unique sequential ID generation)
const CounterSchema = new mongoose.Schema({
  _id: { type: String, required: true }, // e.g. "ORDER_2026", "CUSTOMER"
  year: { type: Number },
  sequence: { type: Number, required: true, default: 0 }
});
const Counter = mongoose.model('Counter', CounterSchema, 'counters');

// Helper to generate next sequential customer ID
async function getNextCustomerId() {
  const counter = await Counter.findOneAndUpdate(
    { _id: 'CUSTOMER' },
    { $inc: { sequence: 1 } },
    { new: true, upsert: true }
  );
  return 'CUST' + String(counter.sequence).padStart(4, '0');
}

// Helper to generate next sequential bill number for a given year
async function getNextBillNo(year) {
  const yy = String(year).substring(2); // e.g. "26" for 2026
  const counterId = `ORDER_${year}`;
  const counter = await Counter.findOneAndUpdate(
    { _id: counterId },
    { $inc: { sequence: 1 }, year: year },
    { new: true, upsert: true }
  );
  return yy + String(counter.sequence).padStart(4, '0');
}

// 2. Customer Schema (customerDatas)
const CustomerSchema = new mongoose.Schema({
  id: { type: String, required: true, unique: true }, // Flutter UUID
  customerId: { type: String, unique: true }, // e.g. CUST0001
  name: { type: String, required: true },
  phone: { type: String, required: true },
  indivvidualmeasurement: { type: Map, of: mongoose.Schema.Types.Mixed, default: {} }, // maps category name -> measurements object
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now }
}, { timestamps: true });

// Transform database format to match Flutter app expectations
CustomerSchema.set('toJSON', {
  transform: (doc, ret) => {
    return ret;
  }
});
const Customer = mongoose.model('Customer', CustomerSchema, 'customerDatas');

// 3. GarmentCategory Schema (garmentCategories)
const MeasurementFieldSchema = new mongoose.Schema({
  key: { type: String, required: true },
  label: { type: String, required: true },
  unit: { type: String, default: 'inch' }
}, { _id: false });

const GarmentCategorySchema = new mongoose.Schema({
  id: { type: String, required: true, unique: true }, // Flutter UUID
  name: { type: String, required: true },
  price: { type: Number, required: true, default: 0 },
  measurementFields: [MeasurementFieldSchema],
  isActive: { type: Boolean, default: true },
  createdAt: { type: Date, default: Date.now }
});

// Transform database format to match Flutter app expectations
GarmentCategorySchema.set('toJSON', {
  transform: (doc, ret) => {
    ret.basePrice = ret.price; // Map price to basePrice for app
    // Map list of objects back to list of strings (using label) for app
    ret.measurementFields = (ret.measurementFields || []).map(f => {
      if (f && typeof f === 'object' && f.label) {
        return f.label;
      }
      return f;
    });
    return ret;
  }
});
const GarmentCategory = mongoose.model('GarmentCategory', GarmentCategorySchema, 'garmentCategories');

// 4. Order Schema (orders)
const OrderItemSchema = new mongoose.Schema({
  garmentCategoryId: { type: mongoose.Schema.Types.ObjectId, ref: 'GarmentCategory', required: true },
  garmentName: { type: String, required: true },
  quantity: { type: Number, required: true, default: 1 },
  unitPrice: { type: Number, required: true, default: 0 },
  amount: { type: Number, required: true, default: 0 },
  measurements: { type: Map, of: mongoose.Schema.Types.Mixed }
}, { _id: false });

const OrderSchema = new mongoose.Schema({
  id: { type: String, required: true, unique: true }, // Flutter UUID
  billNo: { type: String, unique: true },
  customerId: { type: mongoose.Schema.Types.ObjectId, ref: 'Customer', required: true },
  items: [OrderItemSchema],
  totalAmount: { type: Number, required: true, default: 0 },
  advanceAmount: { type: Number, default: 0 },
  balanceAmount: { type: Number, default: 0 },
  orderDate: { type: Date, required: true, default: Date.now },
  deliveryDate: { type: Date, required: true },
  status: { type: String, required: true, default: 'Pending' }, // 'Pending', 'In Progress', 'Completed', 'Delivered'
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now }
}, { timestamps: true });

const Order = mongoose.model('Order', OrderSchema, 'orders');

// --- Helper Functions to Map Client Data to DB Models ---

async function saveOrUpdateCustomerFromClient(clientCust) {
  let customerDoc = await Customer.findOne({ id: clientCust.id });
  const phoneVal = clientCust.phone || clientCust.mobile || '0000000000';

  if (customerDoc) {
    customerDoc.name = clientCust.name;
    customerDoc.phone = phoneVal;
    if (clientCust.indivvidualmeasurement) {
      customerDoc.indivvidualmeasurement = clientCust.indivvidualmeasurement;
    }
    customerDoc.updatedAt = new Date();
    await customerDoc.save();
  } else {
    // Generate unique sequential CUSTXXXX id
    const uniqueCustId = await getNextCustomerId();
    customerDoc = new Customer({
      id: clientCust.id,
      customerId: uniqueCustId,
      name: clientCust.name,
      phone: phoneVal,
      indivvidualmeasurement: clientCust.indivvidualmeasurement || {},
      createdAt: clientCust.createdAt ? new Date(clientCust.createdAt) : new Date()
    });
    await customerDoc.save();
  }
  return customerDoc;
}

async function saveOrUpdateCategoryFromClient(clientCat) {
  let categoryDoc = await GarmentCategory.findOne({ id: clientCat.id });
  
  // Map flat string fields to key-label-unit objects
  const fields = (clientCat.measurementFields || []).map(f => {
    if (typeof f === 'string') {
      return {
        key: f.toLowerCase().replace(/\s+/g, '_'),
        label: f,
        unit: 'inch'
      };
    }
    return f;
  });

  const priceVal = clientCat.price || clientCat.basePrice || 0;

  if (categoryDoc) {
    categoryDoc.name = clientCat.name;
    categoryDoc.price = priceVal;
    categoryDoc.measurementFields = fields;
    await categoryDoc.save();
  } else {
    categoryDoc = new GarmentCategory({
      id: clientCat.id,
      name: clientCat.name,
      price: priceVal,
      measurementFields: fields
    });
    await categoryDoc.save();
  }
  return categoryDoc;
}

async function saveOrUpdateOrderFromClient(clientOrder) {
  // 1. Resolve Customer ObjectId
  let customerDoc = await Customer.findOne({ id: clientOrder.customerId });
  if (!customerDoc) {
    // Fallback: check by phone
    customerDoc = await Customer.findOne({ phone: clientOrder.customerPhone });
    if (!customerDoc) {
      // Create new customer
      const uniqueCustId = await getNextCustomerId();
      customerDoc = new Customer({
        id: clientOrder.customerId || new mongoose.Types.ObjectId().toString(),
        customerId: uniqueCustId,
        name: clientOrder.customerName || 'Unknown Customer',
        phone: clientOrder.customerPhone || '0000000000',
        createdAt: new Date()
      });
      await customerDoc.save();
    }
  }

  // 2. Resolve items
  const mappedItems = [];
  let measurementsUpdated = false;

  for (const item of clientOrder.items) {
    let categoryDoc = await GarmentCategory.findOne({ id: item.categoryId });
    if (!categoryDoc) {
      categoryDoc = await GarmentCategory.findOne({ name: item.categoryName });
      if (!categoryDoc) {
        categoryDoc = new GarmentCategory({
          id: item.categoryId || new mongoose.Types.ObjectId().toString(),
          name: item.categoryName,
          price: item.price || 0,
          measurementFields: (item.measurements || []).map(m => ({
            key: m.name.toLowerCase().replace(/\s+/g, '_'),
            label: m.name,
            unit: 'inch'
          }))
        });
        await categoryDoc.save();
      }
    }

    // Convert list of measurements [{name, value}] to Map/Object
    const measurementsObj = {};
    if (item.measurements && Array.isArray(item.measurements)) {
      item.measurements.forEach(m => {
        if (m.name && m.value !== undefined && m.value !== null && m.value !== '') {
          measurementsObj[m.name] = parseFloat(m.value) || m.value;
        }
      });
    }

    mappedItems.push({
      garmentCategoryId: categoryDoc._id,
      garmentName: item.categoryName || categoryDoc.name,
      quantity: item.quantity || 1,
      unitPrice: item.price || categoryDoc.price || 0,
      amount: (item.quantity || 1) * (item.price || categoryDoc.price || 0),
      measurements: measurementsObj
    });

    // Save/Update Customer measurements embedded inside customer document
    if (Object.keys(measurementsObj).length > 0) {
      if (!customerDoc.indivvidualmeasurement) {
        customerDoc.indivvidualmeasurement = {};
      }
      const catNameKey = (item.categoryName || categoryDoc.name).toLowerCase();
      if (typeof customerDoc.indivvidualmeasurement.set === 'function') {
        customerDoc.indivvidualmeasurement.set(catNameKey, measurementsObj);
      } else {
        customerDoc.indivvidualmeasurement[catNameKey] = measurementsObj;
      }
      customerDoc.markModified('indivvidualmeasurement');
      measurementsUpdated = true;
    }
  }

  if (measurementsUpdated || customerDoc.isModified('indivvidualmeasurement')) {
    await customerDoc.save();
  }

  // 3. Map status index back to String name
  const statusRevMap = {
    0: 'Pending',
    1: 'In Progress',
    2: 'Completed',
    3: 'Delivered'
  };
  const statusStr = statusRevMap[clientOrder.status] || 'Pending';

  // 4. Generate/resolve billNo
  let billNo = clientOrder.invoiceNo;
  const isLegacy = !billNo || (parseInt(billNo) < 200000);
  if (isLegacy) {
    const orderYear = clientOrder.orderDate ? new Date(clientOrder.orderDate).getFullYear() : new Date().getFullYear();
    billNo = await getNextBillNo(orderYear);
  }

  const total = clientOrder.totalAmount || mappedItems.reduce((sum, i) => sum + i.amount, 0);
  const advance = clientOrder.advanceAmount || 0;
  const balance = total - advance;

  // 5. Save or Update Order
  let orderDoc = await Order.findOne({ id: clientOrder.id });
  if (orderDoc) {
    orderDoc.customerId = customerDoc._id;
    orderDoc.items = mappedItems;
    orderDoc.totalAmount = total;
    orderDoc.advanceAmount = advance;
    orderDoc.balanceAmount = balance;
    orderDoc.orderDate = clientOrder.orderDate ? new Date(clientOrder.orderDate) : orderDoc.orderDate;
    orderDoc.deliveryDate = clientOrder.deliveryDate ? new Date(clientOrder.deliveryDate) : orderDoc.deliveryDate;
    orderDoc.status = statusStr;
    orderDoc.updatedAt = new Date();
    await orderDoc.save();
  } else {
    orderDoc = new Order({
      id: clientOrder.id,
      billNo: billNo,
      customerId: customerDoc._id,
      items: mappedItems,
      totalAmount: total,
      advanceAmount: advance,
      balanceAmount: balance,
      orderDate: clientOrder.orderDate ? new Date(clientOrder.orderDate) : new Date(),
      deliveryDate: clientOrder.deliveryDate ? new Date(clientOrder.deliveryDate) : new Date(),
      status: statusStr
    });
    await orderDoc.save();
  }

  return orderDoc;
}

async function transformOrderToClient(order) {
  let populatedOrder = order;
  if (!order.populated('customerId') || !order.items.every(item => order.populated('items.garmentCategoryId'))) {
    populatedOrder = await Order.findById(order._id)
      .populate('customerId')
      .populate('items.garmentCategoryId');
  }

  const cust = populatedOrder.customerId;
  const itemsMapped = populatedOrder.items.map(item => {
    const cat = item.garmentCategoryId;
    
    // Map DB key-value measurements back to [{name, value}]
    const measurementsArr = [];
    if (item.measurements) {
      item.measurements.forEach((val, key) => {
        measurementsArr.push({ name: key, value: String(val) });
      });
    }

    return {
      id: Math.random().toString(36).substring(2, 9),
      categoryId: cat ? cat.id : '',
      categoryName: item.garmentName,
      measurements: measurementsArr,
      quantity: item.quantity,
      price: item.unitPrice,
      notes: '',
      customName: item.garmentName !== (cat ? cat.name : '') ? item.garmentName : null
    };
  });

  const statusMap = {
    'Pending': 0,
    'In Progress': 1,
    'Completed': 2,
    'Delivered': 3
  };

  return {
    id: populatedOrder.id,
    invoiceNo: populatedOrder.billNo,
    customerId: cust ? cust.id : '',
    customerName: cust ? cust.name : '',
    customerPhone: cust ? cust.phone : '',
    orderDate: populatedOrder.orderDate.toISOString(),
    deliveryDate: populatedOrder.deliveryDate.toISOString(),
    items: itemsMapped,
    status: statusMap[populatedOrder.status] !== undefined ? statusMap[populatedOrder.status] : 0,
    isPaid: (populatedOrder.advanceAmount >= populatedOrder.totalAmount) || (populatedOrder.balanceAmount <= 0),
    advanceAmount: populatedOrder.advanceAmount,
    totalAmount: populatedOrder.totalAmount
  };
}

// --- REST API Routes ---

// Health Check
app.get('/api/health', (req, res) => {
  res.json({
    status: 'online',
    dbState: mongoose.connection.readyState === 1 ? 'connected' : 'disconnected'
  });
});

// 1. Customer Endpoints
app.get('/api/customers', async (req, res) => {
  try {
    const customers = await Customer.find().sort({ createdAt: -1 });
    res.json(customers);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/customers', async (req, res) => {
  try {
    const saved = await saveOrUpdateCustomerFromClient(req.body);
    res.status(201).json(saved);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.put('/api/customers/:id', async (req, res) => {
  try {
    const saved = await saveOrUpdateCustomerFromClient({ ...req.body, id: req.params.id });
    res.json(saved);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.delete('/api/customers/:id', async (req, res) => {
  try {
    const deleted = await Customer.findOneAndDelete({ id: req.params.id });
    if (!deleted) return res.status(404).json({ error: 'Customer not found' });
    res.json({ success: true, message: 'Customer deleted successfully' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// 2. Garment Category Endpoints
app.get('/api/categories', async (req, res) => {
  try {
    const categories = await GarmentCategory.find();
    res.json(categories);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/categories', async (req, res) => {
  try {
    const saved = await saveOrUpdateCategoryFromClient(req.body);
    res.status(201).json(saved);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.put('/api/categories/:id', async (req, res) => {
  try {
    const saved = await saveOrUpdateCategoryFromClient({ ...req.body, id: req.params.id });
    res.json(saved);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.delete('/api/categories/:id', async (req, res) => {
  try {
    const deleted = await GarmentCategory.findOneAndDelete({ id: req.params.id });
    if (!deleted) return res.status(404).json({ error: 'Category not found' });
    res.json({ success: true, message: 'Category deleted successfully' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// 3. Order Endpoints
app.get('/api/orders', async (req, res) => {
  try {
    const orders = await Order.find().sort({ orderDate: -1 });
    const mapped = [];
    for (const order of orders) {
      mapped.push(await transformOrderToClient(order));
    }
    res.json(mapped);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/orders', async (req, res) => {
  try {
    const savedDoc = await saveOrUpdateOrderFromClient(req.body);
    const clientOrder = await transformOrderToClient(savedDoc);
    res.status(201).json(clientOrder);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.put('/api/orders/:id', async (req, res) => {
  try {
    const savedDoc = await saveOrUpdateOrderFromClient({ ...req.body, id: req.params.id });
    const clientOrder = await transformOrderToClient(savedDoc);
    res.json(clientOrder);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.delete('/api/orders/:id', async (req, res) => {
  try {
    const deleted = await Order.findOneAndDelete({ id: req.params.id });
    if (!deleted) return res.status(404).json({ error: 'Order not found' });
    res.json({ success: true, message: 'Order deleted successfully' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// 4. Bulk Sync Endpoints
app.post('/api/sync', async (req, res) => {
  try {
    const { customers, categories, orders } = req.body;

    if (categories && Array.isArray(categories)) {
      for (const cat of categories) {
        await saveOrUpdateCategoryFromClient(cat);
      }
    }

    if (customers && Array.isArray(customers)) {
      for (const cust of customers) {
        await saveOrUpdateCustomerFromClient(cust);
      }
    }

    if (orders && Array.isArray(orders)) {
      for (const ord of orders) {
        await saveOrUpdateOrderFromClient(ord);
      }
    }

    res.json({ success: true, message: 'Sync upload successful' });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.get('/api/sync', async (req, res) => {
  try {
    const customers = await Customer.find();
    const categories = await GarmentCategory.find();
    
    const dbOrders = await Order.find().sort({ orderDate: -1 });
    const orders = [];
    for (const order of dbOrders) {
      orders.push(await transformOrderToClient(order));
    }

    res.json({
      success: true,
      customers,
      categories,
      orders
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// Start Server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server is running on port ${PORT}`);
});

async function seedDatabase() {
  try {
    console.log('Database initialized. Fresh database start (seeding disabled).');
  } catch (err) {
    console.error('Error during database initialization:', err.message);
  }
}
