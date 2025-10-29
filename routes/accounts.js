const express = require('express');
const router = express.Router();
const accountController = require('../controllers/accountController');
const { authenticateToken } = require('../middlewares/authMiddleware');

// Todas las rutas requieren autenticación
router.use(authenticateToken);

// @route   GET /api/v1/accounts
// @desc    Obtener cuentas del usuario
// @access  Private
router.get('/', accountController.getUserAccounts);

// @route   GET /api/v1/accounts/:id
// @desc    Obtener detalle de cuenta específica
// @access  Private
router.get('/:id', accountController.getAccountById);

// @route   GET /api/v1/accounts/:id/movements
// @desc    Obtener movimientos de cuenta
// @access  Private
router.get('/:id/movements', accountController.getAccountMovements);

module.exports = router;
