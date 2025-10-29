const express = require('express');
const router = express.Router();
const transferController = require('../controllers/transferController');
const { authenticateToken } = require('../middlewares/authMiddleware');

// Todas las rutas requieren autenticación
router.use(authenticateToken);

// @route   POST /api/v1/transfers/internal
// @desc    Realizar transferencia interna
// @access  Private
router.post('/internal', transferController.internalTransfer);

module.exports = router;
