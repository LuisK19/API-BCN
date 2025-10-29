const express = require('express');
const { login, forgotPassword, verifyOtp, resetPassword } = require('../controllers/authController');
const { apiKeyMiddleware } = require('../middlewares/authMiddleware');

const router = express.Router();


// Endpoints de autenticación y OTP
router.post('/login', apiKeyMiddleware, login);
router.post('/forgot-password', apiKeyMiddleware, forgotPassword);
router.post('/verify-otp', apiKeyMiddleware, verifyOtp);
router.post('/reset-password', apiKeyMiddleware, resetPassword);

module.exports = router;