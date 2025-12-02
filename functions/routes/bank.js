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

module.exports = router;
