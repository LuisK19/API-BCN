const jwt = require('jsonwebtoken');
const db = require('../config/database');

const bcrypt = require('bcrypt');

// LOGIN: Usa SP y valida API Key
const login = async (req, res, next) => {
  const { usernameOrEmail, password } = req.body;
  const apiKey = req.headers['x-api-key'];
  if (!usernameOrEmail || !password) {
    return res.status(422).json({
      error: {
        code: 'VALIDATION_ERROR',
        message: 'Username/email and password are required',
        timestamp: new Date().toISOString(),
        path: req.path
      }
    });
  }
  try {
    // Buscar todas las API Keys activas
    const allKeysResult = await db.query('SELECT * FROM apiKey WHERE activa = true');
    let validApiKey = null;
    for (const keyRow of allKeysResult.rows) {
      if (await bcrypt.compare(apiKey, keyRow.clave_hash)) {
        validApiKey = keyRow;
        break;
      }
    }
    if (!validApiKey) {
      return res.status(401).json({
        error: {
          code: 'UNAUTHORIZED',
          message: 'API Key inválida o inactiva',
          timestamp: new Date().toISOString(),
          path: req.path
        }
      });
    }
    // Buscar usuario con SP
    const userResult = await db.query(
      'SELECT * FROM sp_auth_user_get_by_username_or_email($1)',
      [usernameOrEmail]
    );
    const user = userResult.rows[0];
    console.log(user);
    if (!user) {
      return res.status(401).json({
        error: {
          code: 'UNAUTHORIZED',
          message: 'Credenciales inválidas',
          timestamp: new Date().toISOString(),
          path: req.path
        }
      });
    }
    // Validar contraseña (bcrypt)
    console.log('Hash de la contraseña:', user.contrasena_hash);
    console.log('Contraseña ingresada:', password);
    const validPassword = await bcrypt.compare(password, user.contrasena_hash);
    console.log('Contraseña válida:', validPassword);

    if (!validPassword) {
      return res.status(401).json({
        error: {
          code: 'UNAUTHORIZED',
          message: 'Credenciales inválidas',
          timestamp: new Date().toISOString(),
          path: req.path
        }
      });
    }
    // Generar JWT
    const token = jwt.sign(
      { id: user.user_id, username: user.usuario, role: user.rol_nombre },
      process.env.JWT_SECRET,
      { expiresIn: '1h' }
    );
    res.status(200).json({
      token,
      user: {
        id: user.user_id,
        username: user.usuario,
        email: user.correo,
        role: user.rol_nombre,
        estado: user.estado,
        nombre_completo: user.nombre_completo
      }
    });
  } catch (error) {
    next(error);
  }
};

// FORGOT PASSWORD: Genera OTP
const forgotPassword = async (req, res, next) => {
  const { usernameOrEmail, proposito } = req.body;
  if (!usernameOrEmail || !proposito) {
    return res.status(422).json({ error: { code: 'VALIDATION_ERROR', message: 'Username/email y propósito requeridos', timestamp: new Date().toISOString(), path: req.path } });
  }
  try {
    // Buscar usuario
    const userResult = await db.query('SELECT * FROM sp_auth_user_get_by_username_or_email($1)', [usernameOrEmail]);
    const user = userResult.rows[0];
    if (!user) {
      return res.status(404).json({ error: { code: 'NOT_FOUND', message: 'Usuario no encontrado', timestamp: new Date().toISOString(), path: req.path } });
    }
    // Generar código OTP (hash simple)
    const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
    const otpHash = await bcrypt.hash(otpCode, 10);
    // Crear OTP con SP
    const otpResult = await db.query('SELECT * FROM sp_otp_create($1, $2, $3, $4)', [user.user_id, proposito, 300, otpHash]);
    const otp_id = otpResult.rows[0]?.id || otpResult.rows[0]?.sp_otp_create;
    res.status(201).json({ otp_id, otp_code: otpCode, message: 'OTP generado. (En producción se enviaría por email/SMS)' });
  } catch (error) {
    next(error);
  }
};

// VERIFY OTP: Verifica y consume OTP
const verifyOtp = async (req, res, next) => {
  const { usernameOrEmail, proposito, otpCode } = req.body;
  if (!usernameOrEmail || !proposito || !otpCode) {
    return res.status(422).json({ error: { code: 'VALIDATION_ERROR', message: 'Datos requeridos', timestamp: new Date().toISOString(), path: req.path } });
  }
  try {
    // Buscar usuario
    const userResult = await db.query('SELECT * FROM sp_auth_user_get_by_username_or_email($1)', [usernameOrEmail]);
    const user = userResult.rows[0];
    if (!user) {
      return res.status(404).json({ error: { code: 'NOT_FOUND', message: 'Usuario no encontrado', timestamp: new Date().toISOString(), path: req.path } });
    }
    // Buscar OTP válido en la base
    const otpDbResult = await db.query(
      'SELECT * FROM Otps WHERE usuario_id = $1 AND proposito = $2 AND fecha_consumido IS NULL AND fecha_expiracion > NOW() ORDER BY fecha_creacion DESC LIMIT 1',
      [user.user_id, proposito]
    );
    const otpDb = otpDbResult.rows[0];
    if (!otpDb) {
      return res.status(400).json({ error: { code: 'INVALID_OTP', message: 'OTP inválido o expirado', timestamp: new Date().toISOString(), path: req.path } });
    }
    // Comparar el código plano con el hash guardado
    const valid = await bcrypt.compare(otpCode, otpDb.codigo_hash);
    if (!valid) {
      return res.status(400).json({ error: { code: 'INVALID_OTP', message: 'OTP inválido o expirado', timestamp: new Date().toISOString(), path: req.path } });
    }
    // Consumir el OTP (marcar como usado)
    await db.query('UPDATE Otps SET fecha_consumido = NOW() WHERE id = $1', [otpDb.id]);
    res.status(200).json({ success: true, otp_id: otpDb.id, message: 'OTP verificado y consumido' });
  } catch (error) {
    next(error);
  }
};

// RESET PASSWORD: Verifica OTP y cambia contraseña
const resetPassword = async (req, res, next) => {
  const { usernameOrEmail, proposito, otpCode, newPassword } = req.body;
  if (!usernameOrEmail || !proposito || !otpCode || !newPassword) {
    return res.status(422).json({ error: { code: 'VALIDATION_ERROR', message: 'Datos requeridos', timestamp: new Date().toISOString(), path: req.path } });
  }
  try {
    // Buscar usuario
    const userResult = await db.query('SELECT * FROM sp_auth_user_get_by_username_or_email($1)', [usernameOrEmail]);
    console.log('userResult:', userResult);
    const user = userResult.rows[0];
    console.log('user:', user);
    if (!user) {
      return res.status(404).json({ error: { code: 'NOT_FOUND', message: 'Usuario no encontrado', timestamp: new Date().toISOString(), path: req.path } });
    }
    // Buscar OTP válido en la base
    const otpDbResult = await db.query(
      'SELECT * FROM Otps WHERE usuario_id = $1 AND proposito = $2 AND fecha_consumido IS NULL AND fecha_expiracion > NOW() ORDER BY fecha_creacion DESC LIMIT 1',
      [user.user_id, proposito]
    );
    const otpDb = otpDbResult.rows[0];
    if (!otpDb) {
      return res.status(400).json({ error: { code: 'INVALID_OTP', message: 'OTP inválido o expirado', timestamp: new Date().toISOString(), path: req.path } });
    }
    // Comparar el código plano con el hash guardado
    const valid = await bcrypt.compare(otpCode, otpDb.codigo_hash);
    if (!valid) {
      return res.status(400).json({ error: { code: 'INVALID_OTP', message: 'OTP inválido o expirado', timestamp: new Date().toISOString(), path: req.path } });
    }
    // Cambiar contraseña usando el SP real
    console.log('OTP verificado, cambiando contraseña para usuario:', user.user_id);
    console.log('Nueva contraseña:', newPassword);
    const newHash = await bcrypt.hash(newPassword, 12);
    console.log('Nuevo hash de contraseña:', newHash);
    const changeResult = await db.query('SELECT * FROM sp_users_change_password($1, $2)', [user.user_id, newHash]);
    const success = changeResult.rows[0]?.success;
    if (!success) {
      return res.status(400).json({ error: { code: 'CHANGE_PASSWORD_FAILED', message: 'No se pudo cambiar la contraseña', timestamp: new Date().toISOString(), path: req.path } });
    }
  // Consumir el OTP (marcar como usado) solo si el cambio fue exitoso
  await db.query('UPDATE Otps SET fecha_consumido = NOW() WHERE id = $1', [otpDb.id]);
    res.status(200).json({ success: true, message: 'Contraseña cambiada exitosamente' });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  login,
  forgotPassword,
  verifyOtp,
  resetPassword
};