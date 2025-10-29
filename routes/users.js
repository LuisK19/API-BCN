const express = require('express');
const router = express.Router();
const userController = require('../controllers/userController');
const { jwtMiddleware } = require('../middlewares/authMiddleware');

// Crear usuario (admin o cliente)
router.post('/', jwtMiddleware, userController.createUser);

// Consultar usuario por identificación (admin o dueño)
router.get('/:identification', jwtMiddleware, userController.getUserByIdentification);

// Obtener todos los usuarios (admin)
router.get('/', jwtMiddleware, userController.getAllUsers);

// Actualizar usuario (solo admin)
router.put('/:id', jwtMiddleware, userController.updateUser);
// Eliminar usuario (solo admin)
router.delete('/:id', jwtMiddleware, userController.deleteUser);

module.exports = router;
