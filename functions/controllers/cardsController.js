const db = require("../config/database");

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
    cuentaAsociada,
    alias,
  } = req.body;

  // Validar campos obligatorios
  if (!tipo || !numeroEnmascarado || !fechaExpiracion || !cvvEncriptado || !pinEncriptado || !moneda || !compania) {
    return res.status(422).json({
      error: {
        code: "VALIDATION_ERROR",
        message: "Faltan campos obligatorios: tipo, numeroEnmascarado, fechaExpiracion, " +
                 "cvvEncriptado, pinEncriptado, moneda, compania",
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
    const result = await db.query(
        "SELECT * FROM sp_cards_create($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)",
        [
          user.id,
          tipo,
          numeroEnmascarado,
          fechaExpiracion,
          cvvEncriptado,
          pinEncriptado,
          moneda,
          compania.toLowerCase(),
          limiteCredito || null,
          saldoActual || 0,
          cuentaAsociada || null,
          alias || null,
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

    res.status(201).json({cardId: row.card_id, message: row.message});
  } catch (error) {
    next(error);
  }
};

// Listar tarjetas de usuario
const listCards = async (req, res, next) => {
  const user = req.user;
  try {
    const result = await db.query(
        "SELECT * FROM sp_cards_get($1, NULL)",
        [user.id],
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
    categoria,
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
        "SELECT * FROM sp_card_movement_add($1, $2, $3, $4, $5, $6, $7, $8, $9)",
        [
          cardid,
          fecha,
          tipo,
          descripcion,
          moneda,
          parseFloat(monto),
          comerciante || null,
          categoria || null,
          ubicacion || null,
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
        [user.id, "view_card_details", 300, otpHash],
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
        [user.id, "view_card_details", otpHash],
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

    // OTP válido - devolver datos sensibles (en producción estos estarían encriptados)
    // NOTA: pin_hash y cvv_hash están hasheados, en producción necesitarían desencriptarse
    res.status(200).json({
      message: "Acceso temporal concedido",
      cardId: card.id,
      numeroEnmascarado: card.numero_enmascarado,
      // En producción, estos deberían desencriptarse temporalmente
      pin: "****", // Placeholder - implementar desencriptación
      cvv: "***", // Placeholder - implementar desencriptación
      expiresIn: 30, // 30 segundos de visibilidad
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
