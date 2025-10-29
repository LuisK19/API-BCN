const dotenv = require('dotenv');
dotenv.config();

const express = require('express');
const cors = require('cors');
const authRoutes = require('./routes/auth');
const usersRoutes = require('./routes/users');
const accountsRoutes = require('./routes/accounts');
const cardsRoutes = require('./routes/cards');
const transfersRoutes = require('./routes/transfers');
const errorMiddleware = require('./middlewares/errorMiddleware');

const ENV = process.env.NODE_ENV === 'production' ? 'PROD' : 'DEV';
const PORT = process.env.PORT || 3000;

const app = express();

// Configuración CORS según entorno
app.use(cors({
  origin: ENV === 'PROD'
    ? ['https://tudominio.com']
    : ['http://localhost:3000', 'http://localhost:5173'],
  credentials: true
}));

app.use(express.json());

// Rutas

app.use('/api/v1/auth', authRoutes);
app.use('/api/v1/users', usersRoutes);

app.use('/api/v1/accounts', accountsRoutes);
app.use('/api/v1/cards', cardsRoutes);
app.use('/api/v1/transfers', transfersRoutes);

// Endpoint de salud
app.get('/api/v1/health', (req, res) => {
  res.json({
    status: 'OK',
    message: 'API del Banco funcionando',
    environment: ENV,
    timestamp: new Date().toISOString()
  });
});

// Endpoint de información de entorno
app.get('/api/v1/environment', (req, res) => {
  res.json({
    environment: ENV,
    database: {
      host: process.env[`${ENV}_DB_HOST`],
      port: process.env[`${ENV}_DB_PORT`],
      name: process.env[`${ENV}_DB_NAME`]
    },
    timestamp: new Date().toISOString()
  });
});

// Error handling middleware
app.use(errorMiddleware);

// Ruta no encontrada
app.use((req, res) => {
  res.status(404).json({ error: 'Ruta no encontrada' });
});

app.listen(PORT, () => {
  console.log(`Servidor corriendo en puerto ${PORT}`);
  console.log(`Entorno: ${ENV}`);
  console.log(`Base de datos: ${process.env[`${ENV}_DB_HOST`]}:${process.env[`${ENV}_DB_PORT`]}/${process.env[`${ENV}_DB_NAME`]}`);
});