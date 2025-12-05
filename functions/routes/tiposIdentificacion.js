/* eslint-disable new-cap */
const express = require("express");
const {getTiposIdentificacion} = require("../controllers/tiposIdentificacionController");

const router = express.Router();

// Obtener todos los tipos de identificación (endpoint público)
router.get("/", getTiposIdentificacion);

module.exports = router;
