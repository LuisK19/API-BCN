const express = require("express");
// eslint-disable-next-line new-cap
const router = express.Router();
const accountsController = require("../controllers/accountsController");
const {jwtMiddleware} = require("../middlewares/authMiddleware");

// Crear cuenta bancaria
router.post("/", jwtMiddleware, accountsController.createAccount);
// Listar cuentas de usuario
router.get("/", jwtMiddleware, accountsController.listAccounts);
// Consultar detalle de cuenta
router.get("/:accountid", jwtMiddleware, accountsController.getAccountDetail);
// Cambiar estado de cuenta
router.post("/:accountid/status", jwtMiddleware, accountsController.setAccountStatus);

module.exports = router;
