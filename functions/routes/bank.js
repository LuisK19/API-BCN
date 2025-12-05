/* eslint-disable new-cap */
const express = require("express");
const router = express.Router();
const bankController = require("../controllers/bankController");
const jwtMiddleware = require("../middlewares/authMiddleware").jwtMiddleware;

/**
 * POST /api/v1/bank/validate-account
 * Validar cuenta bancaria por IBAN
 * Requiere autenticación JWT
 */
router.post("/validate-account", bankController.validateAccount);

/**
 * GET /api/v1/bank/ping-central
 * Verificar si el Banco Central está disponible
 */
router.get("/ping-central", bankController.pingCentralBank);

/**
 * GET /api/v1/bank/websocket-status
 * Verificar estado de la conexión WebSocket
 */
router.get("/websocket-status", bankController.checkWebSocketStatus);

module.exports = router;
