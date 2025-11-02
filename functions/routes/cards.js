const express = require("express");
// eslint-disable-next-line new-cap
const router = express.Router();
const cardsController = require("../controllers/cardsController");
const {jwtMiddleware} = require("../middlewares/authMiddleware");

// Crear tarjeta
router.post("/", jwtMiddleware, cardsController.createCard);
// Listar tarjetas de usuario
router.get("/", jwtMiddleware, cardsController.listCards);
// Consultar detalle de tarjeta
router.get("/:cardid", jwtMiddleware, cardsController.getCardDetail);

// Listar movimientos de tarjeta
router.get("/:cardid/movements", jwtMiddleware, cardsController.listCardMovements);
// Agregar movimiento de tarjeta
router.post("/:cardid/movements", jwtMiddleware, cardsController.addCardMovement);
// Generar OTP para ver PIN/CVV
router.post("/:cardid/otp", jwtMiddleware, cardsController.generateOtpForCardDetails);
// Verificar OTP y ver detalles sensibles
router.post("/:cardid/view-details", jwtMiddleware, cardsController.viewCardDetailsWithOtp);

module.exports = router;
