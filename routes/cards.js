const express = require('express');
const router = express.Router();
const cardController = require('../controllers/cardController');
const { authenticateToken } = require('../middlewares/authMiddleware');

// Todas las rutas requieren autenticación
router.use(authenticateToken);

// @route   GET /api/v1/cards
// @desc    Obtener tarjetas del usuario
// @access  Private
router.get('/', cardController.getUserCards);

module.exports = router;
