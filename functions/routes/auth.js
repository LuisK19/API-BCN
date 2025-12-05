/* eslint-disable new-cap */
const express = require("express");
const {login, forgotPassword, verifyOtp, resetPassword, register} = require("../controllers/authController");
const {apiKeyMiddleware} = require("../middlewares/authMiddleware");

const router = express.Router();

// Endpoints de autenticación y OTP
router.post("/login", apiKeyMiddleware, login);
router.post("/register", apiKeyMiddleware, register);
router.post("/forgot-password", apiKeyMiddleware, forgotPassword);
router.post("/verify-otp", apiKeyMiddleware, verifyOtp);
router.post("/reset-password", apiKeyMiddleware, resetPassword);

module.exports = router;
