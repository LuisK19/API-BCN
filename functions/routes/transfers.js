const express = require("express");
// eslint-disable-next-line new-cap
const router = express.Router();
const transfersController = require("../controllers/transfersController");
const {jwtMiddleware} = require("../middlewares/authMiddleware");

// Transferencia interna (entre cuentas del mismo banco)
router.post("/internal", jwtMiddleware, transfersController.createInternalTransfer);

// Transferencia interbancaria (via WebSocket)
router.post("/interbank", jwtMiddleware, transfersController.createInterbankTransfer);

module.exports = router;
