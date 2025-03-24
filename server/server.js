require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const Product = require('./models/product');

const app = express();
const PORT = process.env.PORT || 5000;

// Middleware
app.use(cors());
app.use(express.json());

// MongoDB Connection
mongoose.connect(process.env.MONGODB_URI, {
  serverSelectionTimeoutMS: 5000,
  socketTimeoutMS: 45000,
  retryWrites: true,
  w: 'majority',
  maxPoolSize: 10,
  minPoolSize: 5,
  connectTimeoutMS: 10000,
  family: 4
}).then(() => {
  console.log('Connected to MongoDB');
}).catch((err) => {
  if (err.name === 'MongooseServerSelectionError') {
    console.error('MongoDB connection error: Unable to reach the database server');
    console.error('Please check your network connection and MongoDB URI');
    console.error('Detailed error:', err.message);
  } else if (err.name === 'MongooseError') {
    console.error('MongoDB connection error: Invalid connection string');
    console.error('Please check your MongoDB URI format');
  } else {
    console.error('MongoDB connection error:', err.message);
  }
  process.exit(1);
});

// User Schema
const userSchema = new mongoose.Schema({
  nombre: String,
  correo: String,
  password: String,
  rol: String
});

const User = mongoose.model('User', userSchema);



// Authentication Middleware
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ message: 'Authentication token required' });
  }

  // Update JWT secret to use environment variable
  jwt.verify(token, process.env.JWT_SECRET, (err, user) => {
    if (err) {
      return res.status(403).json({ message: 'Invalid or expired token' });
    }
    req.user = user;
    next();
  });
};

// Routes
app.get('/usuarios', authenticateToken, async (req, res) => {
  try {
    const users = await User.find().select('-password');
    res.json(users);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// Add POST route for creating users
app.post('/usuarios', authenticateToken, async (req, res) => {
  try {
    // Check if the user making the request is an admin
    if (req.user.rol !== 'admin') {
      return res.status(403).json({ message: 'Only administrators can create users' });
    }

    const { nombre, correo, password, rol } = req.body;

    // Create a new user with the provided data
    const newUser = new User({
      nombre,
      correo,
      password: await bcrypt.hash(password, 10), // Hash the password
      rol
    });

    // Save the user to the database
    const savedUser = await newUser.save();

    // Return the created user (without password)
    const userResponse = {
      _id: savedUser._id,
      nombre: savedUser.nombre,
      correo: savedUser.correo,
      rol: savedUser.rol
    };

    res.status(201).json(userResponse);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// Login route
app.post('/login', async (req, res) => {
  try {
    const { correo, password } = req.body;
    const user = await User.findOne({ correo });

    if (!user) {
      return res.status(401).json({ message: 'Invalid credentials' });
    }

    const isValidPassword = await bcrypt.compare(password, user.password);
    if (!isValidPassword) {
      return res.status(401).json({ message: 'Invalid credentials' });
    }

    // Update token signing to use environment variable
    const token = jwt.sign(
      { userId: user._id, rol: user.rol },
      process.env.JWT_SECRET,
      { expiresIn: '1h' }
    );

    res.json({ token, rol: user.rol });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});



// Update user route
app.put('/usuarios/:id', authenticateToken, async (req, res) => {
  try {
    // Check if the user making the request is an admin
    if (req.user.rol !== 'admin') {
      return res.status(403).json({ message: 'Only administrators can update users' });
    }

    const { id } = req.params;
    const updateData = req.body;

    // Remove password from updateData if it exists
    if (updateData.password) {
      updateData.password = await bcrypt.hash(updateData.password, 10);
    }

    const updatedUser = await User.findByIdAndUpdate(
      id,
      updateData,
      { new: true, runValidators: true }
    ).select('-password');

    if (!updatedUser) {
      return res.status(404).json({ message: 'User not found' });
    }

    res.json(updatedUser);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// Delete user route
app.delete('/usuarios/:id', authenticateToken, async (req, res) => {
  try {
    // Check if the user making the request is an admin
    if (req.user.rol !== 'admin') {
      return res.status(403).json({ message: 'Only administrators can delete users' });
    }

    const { id } = req.params;
    const deletedUser = await User.findByIdAndDelete(id);

    if (!deletedUser) {
      return res.status(404).json({ message: 'User not found' });
    }

    res.json({ message: 'User deleted successfully' });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// Update the server listen configuration
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server is running on port ${PORT}`);
});

// Product Routes
app.get('/productos', authenticateToken, async (req, res) => {
  try {
    const products = await Product.find();
    res.json(products);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.post('/productos', authenticateToken, async (req, res) => {
  try {
    if (req.user.rol !== 'admin') {
      return res.status(403).json({ message: 'Only administrators can create products' });
    }

    const product = new Product(req.body);
    const savedProduct = await product.save();
    res.status(201).json(savedProduct);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.put('/productos/:id', authenticateToken, async (req, res) => {
  try {
    if (req.user.rol !== 'admin') {
      return res.status(403).json({ message: 'Only administrators can update products' });
    }

    const { id } = req.params;
    const updatedProduct = await Product.findByIdAndUpdate(id, req.body, { new: true });
    
    if (!updatedProduct) {
      return res.status(404).json({ message: 'Product not found' });
    }
    
    res.json(updatedProduct);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.delete('/productos/:id', authenticateToken, async (req, res) => {
  try {
    if (req.user.rol !== 'admin') {
      return res.status(403).json({ message: 'Only administrators can delete products' });
    }

    const { id } = req.params;
    const deletedProduct = await Product.findByIdAndDelete(id);
    
    if (!deletedProduct) {
      return res.status(404).json({ message: 'Product not found' });
    }
    
    res.json({ message: 'Product deleted successfully' });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});