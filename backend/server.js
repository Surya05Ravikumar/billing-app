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

// Customer Schema
const CustomerSchema = new mongoose.Schema({
  id: { type: String, required: true, unique: true }, // custom UUID from Flutter
  name: { type: String, required: true },
  phone: { type: String, required: true },
  address: String,
  createdAt: { type: Date, default: Date.now }
});
const Customer = mongoose.model('Customer', CustomerSchema, 'customer_datas');

// GarmentCategory Schema
const GarmentCategorySchema = new mongoose.Schema({
  id: { type: String, required: true, unique: true }, // custom UUID from Flutter
  name: { type: String, required: true },
  measurementFields: [String],
  basePrice: Number
});
const GarmentCategory = mongoose.model('GarmentCategory', GarmentCategorySchema, 'measurements');

// Order Item Nested Schema
const OrderItemSchema = new mongoose.Schema({
  id: { type: String, required: true },
  categoryId: { type: String, required: true },
  categoryName: { type: String, required: true },
  measurements: [{
    name: { type: String, required: true },
    value: String
  }],
  quantity: { type: Number, required: true, default: 1 },
  price: { type: Number, required: true },
  notes: String,
  imageUrl: String,
  customName: String
});

// Order Schema
const OrderSchema = new mongoose.Schema({
  id: { type: String, required: true, unique: true }, // custom UUID from Flutter
  invoiceNo: String,
  customerId: { type: String, required: true },
  customerName: { type: String, required: true },
  customerPhone: { type: String, required: true },
  orderDate: { type: Date, required: true },
  deliveryDate: { type: Date, required: true },
  items: [OrderItemSchema],
  status: { type: Number, required: true, default: 0 }, // 0=pending, 1=inProgress, 2=completed, 3=delivered
  isPaid: { type: Boolean, required: true, default: false },
  advanceAmount: Number,
  totalAmount: Number
});
const Order = mongoose.model('Order', OrderSchema, 'orders');

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
    const newCustomer = new Customer(req.body);
    await newCustomer.save();
    res.status(201).json(newCustomer);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.put('/api/customers/:id', async (req, res) => {
  try {
    const updated = await Customer.findOneAndUpdate(
      { id: req.params.id },
      req.body,
      { new: true, runValidators: true }
    );
    if (!updated) return res.status(404).json({ error: 'Customer not found' });
    res.json(updated);
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
    const newCategory = new GarmentCategory(req.body);
    await newCategory.save();
    res.status(201).json(newCategory);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.put('/api/categories/:id', async (req, res) => {
  try {
    const updated = await GarmentCategory.findOneAndUpdate(
      { id: req.params.id },
      req.body,
      { new: true, runValidators: true }
    );
    if (!updated) return res.status(404).json({ error: 'Category not found' });
    res.json(updated);
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
    res.json(orders);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/orders', async (req, res) => {
  try {
    const newOrder = new Order(req.body);
    await newOrder.save();
    res.status(201).json(newOrder);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.put('/api/orders/:id', async (req, res) => {
  try {
    const updated = await Order.findOneAndUpdate(
      { id: req.params.id },
      req.body,
      { new: true, runValidators: true }
    );
    if (!updated) return res.status(404).json({ error: 'Order not found' });
    res.json(updated);
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

// 4. Bulk Sync Endpoints (matches Google Sheets bulk structure for easy integration)
app.post('/api/sync', async (req, res) => {
  try {
    const { customers, categories, orders } = req.body;

    // We can do an upsert operation for each entity to ensure everything is saved and updated
    if (customers && Array.isArray(customers)) {
      for (const cust of customers) {
        await Customer.findOneAndUpdate({ id: cust.id }, cust, { upsert: true, new: true });
      }
    }

    if (categories && Array.isArray(categories)) {
      for (const cat of categories) {
        await GarmentCategory.findOneAndUpdate({ id: cat.id }, cat, { upsert: true, new: true });
      }
    }

    if (orders && Array.isArray(orders)) {
      for (const ord of orders) {
        await Order.findOneAndUpdate({ id: ord.id }, ord, { upsert: true, new: true });
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
    const orders = await Order.find().sort({ orderDate: -1 });

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

// Seeding function to populate the database with default structures and records if empty
async function seedDatabase() {
  try {
    // 1. Check if Categories / Measurements are empty, seed default measurements
    const categoryCount = await GarmentCategory.countDocuments();
    let seededCategories = [];
    if (categoryCount === 0) {
      console.log('Seeding default measurements/categories...');
      const defaultCategories = [
        {
          id: 'cat-1-blouse',
          name: 'Blouse',
          measurementFields: ['Chest', 'Waist', 'Hip', 'Sleeve Length', 'Shoulder', 'Back Length', 'Front Length', 'Neck'],
          basePrice: 350.0
        },
        {
          id: 'cat-2-chudi',
          name: 'Chudi / Salwar',
          measurementFields: ['Chest', 'Waist', 'Hip', 'Shoulder', 'Sleeve Length', 'Kurta Length', 'Pant Length', 'Seat'],
          basePrice: 450.0
        },
        {
          id: 'cat-3-saree-falls',
          name: 'Saree Falls',
          measurementFields: ['Length', 'Width'],
          basePrice: 80.0
        },
        {
          id: 'cat-4-skirt',
          name: 'Skirt',
          measurementFields: ['Waist', 'Hip', 'Length'],
          basePrice: 200.0
        },
        {
          id: 'cat-5-shirt',
          name: 'Shirt',
          measurementFields: ['Chest', 'Waist', 'Shoulder', 'Sleeve Length', 'Collar', 'Length'],
          basePrice: 300.0
        }
      ];
      seededCategories = await GarmentCategory.insertMany(defaultCategories);
      console.log(`Seeded ${seededCategories.length} garment category templates.`);
    } else {
      seededCategories = await GarmentCategory.find();
    }

    // 2. Check if Customers are empty, seed default customers
    const customerCount = await Customer.countDocuments();
    let seededCustomers = [];
    if (customerCount === 0) {
      console.log('Seeding sample customers...');
      const defaultCustomers = [
        {
          id: 'cust-1-ramesh',
          name: 'Ramesh Kumar',
          phone: '9876543210',
          address: '123 Main Street, Chennai',
          createdAt: new Date()
        },
        {
          id: 'cust-2-priya',
          name: 'Priya Sharma',
          phone: '9812345678',
          address: '45 G.N. Road, Chennai',
          createdAt: new Date()
        }
      ];
      seededCustomers = await Customer.insertMany(defaultCustomers);
      console.log(`Seeded ${seededCustomers.length} sample customers.`);
    } else {
      seededCustomers = await Customer.find();
    }

    // 3. Check if Orders are empty, seed default orders
    const orderCount = await Order.countDocuments();
    if (orderCount === 0 && seededCustomers.length >= 2 && seededCategories.length >= 5) {
      console.log('Seeding sample orders...');
      
      const ramesh = seededCustomers.find(c => c.id === 'cust-1-ramesh') || seededCustomers[0];
      const priya = seededCustomers.find(c => c.id === 'cust-2-priya') || seededCustomers[1];
      const shirt = seededCategories.find(c => c.name === 'Shirt') || seededCategories[4];
      const blouse = seededCategories.find(c => c.name === 'Blouse') || seededCategories[0];

      const defaultOrders = [
        {
          id: 'order-1-ramesh-shirt',
          invoiceNo: '1001',
          customerId: ramesh.id,
          customerName: ramesh.name,
          customerPhone: ramesh.phone,
          orderDate: new Date(Date.now() - 3 * 24 * 60 * 60 * 1000), // 3 days ago
          deliveryDate: new Date(Date.now() + 5 * 24 * 60 * 60 * 1000), // in 5 days
          items: [
            {
              id: 'item-1',
              categoryId: shirt.id,
              categoryName: shirt.name,
              measurements: [
                { name: 'Chest', value: '40' },
                { name: 'Waist', value: '38' },
                { name: 'Shoulder', value: '18' },
                { name: 'Sleeve Length', value: '25' },
                { name: 'Collar', value: '15' },
                { name: 'Length', value: '29' }
              ],
              quantity: 2,
              price: 300.0,
              notes: 'Stitch double pockets'
            }
          ],
          status: 0, // Pending
          isPaid: false,
          advanceAmount: 200.0,
          totalAmount: 600.0
        },
        {
          id: 'order-2-priya-blouse',
          invoiceNo: '1002',
          customerId: priya.id,
          customerName: priya.name,
          customerPhone: priya.phone,
          orderDate: new Date(Date.now() - 5 * 24 * 60 * 60 * 1000), // 5 days ago
          deliveryDate: new Date(Date.now() - 1 * 24 * 60 * 60 * 1000), // 1 day ago (completed/delivered)
          items: [
            {
              id: 'item-2',
              categoryId: blouse.id,
              categoryName: blouse.name,
              measurements: [
                { name: 'Chest', value: '36' },
                { name: 'Waist', value: '30' },
                { name: 'Hip', value: '38' },
                { name: 'Sleeve Length', value: '12' },
                { name: 'Shoulder', value: '14' },
                { name: 'Back Length', value: '15' },
                { name: 'Front Length', value: '14' },
                { name: 'Neck', value: '7' }
              ],
              quantity: 1,
              price: 350.0,
              notes: 'Designer neck pattern'
            }
          ],
          status: 3, // Delivered
          isPaid: true,
          advanceAmount: 350.0,
          totalAmount: 350.0
        }
      ];
      const seededOrders = await Order.insertMany(defaultOrders);
      console.log(`Seeded ${seededOrders.length} sample orders.`);
    }
  } catch (err) {
    console.error('Error seeding database:', err.message);
  }
}
