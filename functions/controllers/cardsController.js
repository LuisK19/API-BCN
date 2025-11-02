const db = require("../config/database");
const audit = require("../utils/auditHelper");
const crypto = require("crypto");

// Configuración de encriptación AES para PIN/CVV
const ENCRYPTION_KEY = process.env.ENCRYPTION_KEY || "12345678901234567890123456789012"; // 32 bytes
const ENCRYPTION_IV_LENGTH = 16;

/**
 * Encripta datos sensibles usando AES-256-CBC.
 * @param {string} text - Texto a encriptar (PIN o CVV).
 * @return {string} Texto encriptado en formato "iv:encryptedData".
 */
function encrypt(text) {
  const iv = crypto.randomBytes(ENCRYPTION_IV_LENGTH);
  const cipher = crypto.createCipheriv("aes-256-cbc", Buffer.from(ENCRYPTION_KEY), iv);
  let encrypted = cipher.update(text);
  encrypted = Buffer.concat([encrypted, cipher.final()]);
  return iv.toString("hex") + ":" + encrypted.toString("hex");
}

/**
 * Desencripta datos sensibles previamente encriptados con AES-256-CBC.
 * @param {string} text - Texto encriptado en formato "iv:encryptedData".
 * @return {string} Texto desencriptado (PIN o CVV original).
 */
function decrypt(text) {
  const parts = text.split(":");
  const iv = Buffer.from(parts.shift(), "hex");
  const encryptedText = Buffer.from(parts.join(":"), "hex");
  const decipher = crypto.createDecipheriv("aes-256-cbc", Buffer.from(ENCRYPTION_KEY), iv);
  let decrypted = decipher.update(encryptedText);
  decrypted = Buffer.concat([decrypted, decipher.final()]);
  return decrypted.toString();
}

// Crear tarjeta
const createCard = async (req, res, next) => {
  const user = req.user;
  const {
    tipo,
    numeroEnmascarado,
    fechaExpiracion,
    cvvEncriptado,
    pinEncriptado,
    moneda,
    compania,
    limiteCredito,
    saldoActual,
    categoria,
    tasaInteres,
  } = req.body;

  // Validar campos obligatorios
  if (!tipo || !numeroEnmascarado || !fechaExpiracion || !cvvEncriptado ||
      !pinEncriptado || !moneda || !compania || !limiteCredito) {
    return res.status(422).json({
      error: {
        code: "VALIDATION_ERROR",
        message: "Faltan campos obligatorios: tipo, numeroEnmascarado, fechaExpiracion, " +
                 "cvvEncriptado, pinEncriptado, moneda, compania, limiteCredito",
        timestamp: new Date().toISOString(),
        path: req.path,
      },
    });
  }

  // Validar compañía
  const companiasValidas = ["alipay", "amex", "diners", "discover", "elo", "generic",
    "hiper", "hipercard", "jcb", "maestro", "mastercard", "mir",
    "paypal", "unionpay", "visa"];

  if (!companiasValidas.includes(compania.toLowerCase())) {
    return res.status(422).json({
      error: {
        code: "VALIDATION_ERROR",
        message: `Compañía de tarjeta no válida. Valores permitidos: ${companiasValidas.join(", ")}`,
        timestamp: new Date().toISOString(),
        path: req.path,
      },
    });
  }

  try {
    // Encriptar CVV y PIN con AES antes de enviar al SP
    const cvvEncrypted = encrypt(cvvEncriptado);
    const pinEncrypted = encrypt(pinEncriptado);

    const result = await db.query(
        "SELECT * FROM sp_cards_create($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)",
        [
          user.id, // p_usuario_id
          tipo, // p_tipo (UUID)
          numeroEnmascarado, // p_numero_enmascarado
          fechaExpiracion, // p_fecha_expiracion (MM/YY)
          cvvEncrypted, // p_cvv_encriptado (AES encrypted)
          pinEncrypted, // p_pin_encriptado (AES encrypted)
          moneda, // p_moneda (UUID)
          limiteCredito, // p_limite_credito (DECIMAL)
          saldoActual || 0, // p_saldo_actual (DECIMAL, default 0)
          compania.toLowerCase(), // p_compania (VARCHAR: visa, mastercard, etc.)
          categoria || null, // p_categoria (VARCHAR: gold, platinum, black, blue, saprisa)
          tasaInteres || null, // p_tasa_interes (DECIMAL, default 18.50 en SP)
        ],
    );

    const row = result.rows && result.rows[0] ? result.rows[0] : undefined;
    if (!row || !row.success) {
      return res.status(400).json({
        error: {
          code: "CREATE_FAILED",
          message: row ? row.message : "No se pudo crear la tarjeta",
          timestamp: new Date().toISOString(),
          path: req.path,
        },
      });
    }

    // REGISTRAR EN AUDITORÍA
    try {
      await audit.logCardCreate(user.id, row.card_id, {
        tipo,
        moneda,
        numeroEnmascarado,
        limiteCredito,
        compania,
        categoria: categoria || "blue",
        saldoActual: saldoActual || 0,
      });
    } catch (auditError) {
      console.error("Error registrando auditoría de creación de tarjeta:", auditError.message);
    }

    res.status(201).json({cardId: row.card_id, message: row.message});
  } catch (error) {
    next(error);
  }
};

// Listar tarjetas de usuario
const listCards = async (req, res, next) => {
  const user = req.user;
  const {userId} = req.query; // Admin puede consultar tarjetas de otro usuario

  try {
    // Determinar de quién se consultan las tarjetas
    let targetUserId;
    if (user.role === "admin" && userId) {
      // Admin puede consultar tarjetas de cualquier usuario
      targetUserId = userId;
    } else {
      // Cliente solo puede ver sus propias tarjetas
      targetUserId = user.id;
    }

    const result = await db.query(
        "SELECT * FROM sp_cards_get($1, NULL)",
        [targetUserId],
    );
    res.status(200).json({cards: result.rows});
  } catch (error) {
    next(error);
  }
};

// Consultar detalle de tarjeta
const getCardDetail = async (req, res, next) => {
  const user = req.user;
  const {cardid} = req.params;

  try {
    const result = await db.query(
        "SELECT * FROM sp_cards_get(NULL, $1)",
        [cardid],
    );

    const card = result.rows && result.rows[0] ? result.rows[0] : undefined;
    if (!card) {
      return res.status(404).json({
        error: {
          code: "NOT_FOUND",
          message: "Tarjeta no encontrada",
          timestamp: new Date().toISOString(),
          path: req.path,
        },
      });
    }

    // Validar que el usuario sea dueño o admin
    if (user.role !== "admin" && card.usuario_id !== user.id) {
      return res.status(403).json({
        error: {
          code: "FORBIDDEN",
          message: "No autorizado",
          timestamp: new Date().toISOString(),
          path: req.path,
        },
      });
    }

    res.status(200).json({card});
  } catch (error) {
    next(error);
  }
};

// Listar movimientos de tarjeta
const listCardMovements = async (req, res, next) => {
  const user = req.user;
  const {cardid} = req.params;
  const {fromDate, toDate, type, q, page = 1, pageSize = 10} = req.query;

  try {
    // Verificar que la tarjeta existe y pertenece al usuario
    const cardResult = await db.query(
        "SELECT * FROM sp_cards_get(NULL, $1)",
        [cardid],
    );

    const card = cardResult.rows && cardResult.rows[0] ? cardResult.rows[0] : undefined;
    if (!card) {
      return res.status(404).json({
        error: {
          code: "NOT_FOUND",
          message: "Tarjeta no encontrada",
          timestamp: new Date().toISOString(),
          path: req.path,
        },
      });
    }

    // Validar que el usuario sea dueño o admin
    if (user.role !== "admin" && card.usuario_id !== user.id) {
      return res.status(403).json({
        error: {
          code: "FORBIDDEN",
          message: "No autorizado",
          timestamp: new Date().toISOString(),
          path: req.path,
        },
      });
    }

    // Listar movimientos (el SP detecta automáticamente si es débito o crédito)
    const result = await db.query(
        "SELECT * FROM sp_card_movements_list($1, $2, $3, $4, $5, $6, $7)",
        [cardid, fromDate || null, toDate || null, type || null, q || null, parseInt(page), parseInt(pageSize)],
    );

    const row = result.rows && result.rows[0] ? result.rows[0] : undefined;
    res.status(200).json({
      items: row ? row.items : [],
      total: row ? row.total : 0,
      page: row ? row.page : parseInt(page),
      pageSize: row ? row.page_size : parseInt(pageSize),
    });
  } catch (error) {
    next(error);
  }
};

// Agregar movimiento de tarjeta (compra/pago)
const addCardMovement = async (req, res, next) => {
  const user = req.user;
  const {cardid} = req.params;
  const {
    fecha,
    tipo,
    descripcion,
    moneda,
    monto,
    comerciante,
    ubicacion,
  } = req.body;

  // Validar campos obligatorios
  if (!fecha || !tipo || !descripcion || !moneda || !monto) {
    return res.status(422).json({
      error: {
        code: "VALIDATION_ERROR",
        message: "Faltan campos obligatorios: fecha, tipo, descripcion, moneda, monto",
        timestamp: new Date().toISOString(),
        path: req.path,
      },
    });
  }

  try {
    // Verificar que la tarjeta existe y pertenece al usuario
    const cardResult = await db.query(
        "SELECT * FROM sp_cards_get(NULL, $1)",
        [cardid],
    );

    const card = cardResult.rows && cardResult.rows[0] ? cardResult.rows[0] : undefined;
    if (!card) {
      return res.status(404).json({
        error: {
          code: "NOT_FOUND",
          message: "Tarjeta no encontrada",
          timestamp: new Date().toISOString(),
          path: req.path,
        },
      });
    }

    // Validar que el usuario sea dueño o admin
    if (user.role !== "admin" && card.usuario_id !== user.id) {
      return res.status(403).json({
        error: {
          code: "FORBIDDEN",
          message: "No autorizado",
          timestamp: new Date().toISOString(),
          path: req.path,
        },
      });
    }

    // Agregar movimiento
    const result = await db.query(
        "SELECT * FROM sp_card_movement_add($1, $2, $3, $4, $5, $6, $7, $8)",
        [
          cardid, // p_card_id
          fecha, // p_fecha
          tipo, // p_tipo (UUID: Compra o Pago)
          descripcion, // p_descripcion
          moneda, // p_moneda (UUID)
          parseFloat(monto), // p_monto
          comerciante || null, // p_comerciante
          ubicacion || null, // p_ubicacion
        ],
    );

    const row = result.rows && result.rows[0] ? result.rows[0] : undefined;
    if (!row || !row.success) {
      return res.status(400).json({
        error: {
          code: "OPERATION_FAILED",
          message: row ? row.message : "No se pudo registrar el movimiento",
          timestamp: new Date().toISOString(),
          path: req.path,
        },
      });
    }

    // REGISTRAR EN AUDITORÍA
    try {
      await audit.logCardMovementAdd(user.id, cardid, {
        tipo,
        monto: parseFloat(monto),
        descripcion,
        comerciante: comerciante || null,
        movementId: row.movement_id,
      });
    } catch (auditError) {
      console.error("Error registrando auditoría de movimiento de tarjeta:", auditError.message);
    }

    // Nota: nuevoSaldo para crédito = saldo de tarjeta, para débito = saldo de cuenta
    res.status(201).json({
      movementId: row.movement_id,
      nuevoSaldo: row.nuevo_saldo,
      creditoDisponible: row.credito_disponible,
      message: row.message,
    });
  } catch (error) {
    next(error);
  }
};

// Generar OTP para ver PIN/CVV
const generateOtpForCardDetails = async (req, res, next) => {
  const user = req.user;
  const {cardid} = req.params;

  try {
    // Verificar que la tarjeta existe y pertenece al usuario
    const cardResult = await db.query(
        "SELECT * FROM sp_cards_get(NULL, $1)",
        [cardid],
    );

    const card = cardResult.rows && cardResult.rows[0] ? cardResult.rows[0] : undefined;
    if (!card) {
      return res.status(404).json({
        error: {
          code: "NOT_FOUND",
          message: "Tarjeta no encontrada",
          timestamp: new Date().toISOString(),
          path: req.path,
        },
      });
    }

    // Validar que el usuario sea dueño o admin
    if (user.role !== "admin" && card.usuario_id !== user.id) {
      return res.status(403).json({
        error: {
          code: "FORBIDDEN",
          message: "No autorizado",
          timestamp: new Date().toISOString(),
          path: req.path,
        },
      });
    }

    // Generar código OTP de 6 dígitos
    const crypto = require("crypto");
    const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
    const otpHash = crypto.createHash("sha256").update(otpCode).digest("hex");

    // Guardar OTP en la base de datos (válido por 5 minutos = 300 segundos)
    const result = await db.query(
        "SELECT sp_otp_create($1, $2, $3, $4) as otp_id",
        [user.id, "card_details", 300, otpHash],
    );

    const otpId = result.rows && result.rows[0] ? result.rows[0].otp_id : null;
    if (!otpId) {
      return res.status(500).json({
        error: {
          code: "OTP_GENERATION_FAILED",
          message: "No se pudo generar el código OTP",
          timestamp: new Date().toISOString(),
          path: req.path,
        },
      });
    }

    // En producción, este código se enviaría por SMS/email
    // Para desarrollo, lo devolvemos en la respuesta
    res.status(200).json({
      message: "Código OTP generado exitosamente",
      otpCode: otpCode, // SOLO PARA DESARROLLO - remover en producción
      expiresIn: 300,
      cardId: cardid,
    });
  } catch (error) {
    next(error);
  }
};

// Verificar OTP y mostrar detalles sensibles (PIN/CVV)
const viewCardDetailsWithOtp = async (req, res, next) => {
  const user = req.user;
  const {cardid} = req.params;
  const {otpCode} = req.body;

  // Validar campo obligatorio
  if (!otpCode) {
    return res.status(422).json({
      error: {
        code: "VALIDATION_ERROR",
        message: "Falta campo obligatorio: otpCode",
        timestamp: new Date().toISOString(),
        path: req.path,
      },
    });
  }

  try {
    // Verificar que la tarjeta existe y pertenece al usuario
    const cardResult = await db.query(
        "SELECT * FROM sp_cards_get(NULL, $1)",
        [cardid],
    );

    const card = cardResult.rows && cardResult.rows[0] ? cardResult.rows[0] : undefined;
    if (!card) {
      return res.status(404).json({
        error: {
          code: "NOT_FOUND",
          message: "Tarjeta no encontrada",
          timestamp: new Date().toISOString(),
          path: req.path,
        },
      });
    }

    // Validar que el usuario sea dueño o admin
    if (user.role !== "admin" && card.usuario_id !== user.id) {
      return res.status(403).json({
        error: {
          code: "FORBIDDEN",
          message: "No autorizado",
          timestamp: new Date().toISOString(),
          path: req.path,
        },
      });
    }

    // Verificar el OTP
    const crypto = require("crypto");
    const otpHash = crypto.createHash("sha256").update(otpCode).digest("hex");

    const otpResult = await db.query(
        "SELECT * FROM sp_otp_consume($1, $2, $3)",
        [user.id, "card_details", otpHash],
    );

    const otpRow = otpResult.rows && otpResult.rows[0] ? otpResult.rows[0] : undefined;
    if (!otpRow || !otpRow.is_valid) {
      return res.status(401).json({
        error: {
          code: "INVALID_OTP",
          message: "Código OTP inválido o expirado",
          timestamp: new Date().toISOString(),
          path: req.path,
        },
      });
    }

    // Consultar directamente la tabla tarjeta para obtener pin_hash y cvv_hash
    const cardDetailsResult = await db.query(
        "SELECT pin_hash, cvv_hash FROM tarjeta WHERE id = $1",
        [cardid],
    );

    const cardDetails = cardDetailsResult.rows && cardDetailsResult.rows[0] ?
      cardDetailsResult.rows[0] : undefined;

    if (!cardDetails || !cardDetails.pin_hash || !cardDetails.cvv_hash) {
      console.error("Datos sensibles no encontrados en la base de datos para tarjeta:", cardid);
      return res.status(500).json({
        error: {
          code: "DATA_NOT_FOUND",
          message: "No se encontraron los datos sensibles de la tarjeta",
          timestamp: new Date().toISOString(),
          path: req.path,
        },
      });
    }

    // Desencriptar PIN y CVV
    let decryptedPIN;
    let decryptedCVV;
    try {
      decryptedPIN = decrypt(cardDetails.pin_hash);
      decryptedCVV = decrypt(cardDetails.cvv_hash);
    } catch (decryptError) {
      console.error("Error al desencriptar datos sensibles:", decryptError.message);
      console.error("pin_hash:", cardDetails.pin_hash);
      console.error("cvv_hash:", cardDetails.cvv_hash);
      return res.status(500).json({
        error: {
          code: "DECRYPTION_ERROR",
          message: "Error al recuperar datos sensibles",
          timestamp: new Date().toISOString(),
          path: req.path,
        },
      });
    }

    // REGISTRAR EN AUDITORÍA - Acción sensible
    try {
      await audit.logViewSensitiveData(user.id, cardid, "PIN/CVV");
    } catch (auditError) {
      console.error("Error registrando auditoría de vista de datos sensibles:", auditError.message);
    }

    res.status(200).json({
      message: "Acceso temporal concedido",
      cardId: card.id,
      numeroEnmascarado: card.numero_enmascarado,
      pin: decryptedPIN,
      cvv: decryptedCVV,
      expiresIn: 30,
      warning: "Esta información es sensible y solo estará visible temporalmente",
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  createCard,
  listCards,
  getCardDetail,
  listCardMovements,
  addCardMovement,
  generateOtpForCardDetails,
  viewCardDetailsWithOtp,
};
