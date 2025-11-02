/* eslint-disable new-cap */

const express = require("express");
const router = express.Router();
const auditController = require("../controllers/auditController");
const jwtMiddleware = require("../middlewares/authMiddleware").jwtMiddleware;

/**
 * GET /api/v1/audit/:userId
 * Consultar historial de auditoría de un usuario
 * Requiere autenticación JWT
 * Solo el propio usuario o un admin pueden consultar
 */
router.get("/:userId", jwtMiddleware, auditController.listAuditByUser);

module.exports = router;
