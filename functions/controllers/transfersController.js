/* eslint-disable no-trailing-spaces */
const db = require("../config/database");
const audit = require("../utils/auditHelper");
const {getWebSocketManager} = require("../utils/websocketManager");

// Transferencia interna (entre cuentas del mismo banco)
const createInternalTransfer = async (req, res, next) => {
  const user = req.user;
  const {
    fromAccountId,
    toAccountId,
    amount,
    descripcion,
  } = req.body;

  // Validar campos obligatorios
  if (!fromAccountId || !toAccountId || !amount || !descripcion) {
    return res.status(422).json({
      error: {
        code: "VALIDATION_ERROR",
        message: "Faltan campos obligatorios: fromAccountId, toAccountId, amount, descripcion",
        timestamp: new Date().toISOString(),
        path: req.path,
      },
    });
  }

  // Validar que las cuentas no sean la misma
  if (fromAccountId === toAccountId) {
    return res.status(400).json({
      error: {
        code: "INVALID_TRANSFER",
        message: "No se puede transferir a la misma cuenta",
        timestamp: new Date().toISOString(),
        path: req.path,
      },
    });
  }

  // Validar que el monto sea positivo
  if (amount <= 0) {
    return res.status(400).json({
      error: {
        code: "INVALID_AMOUNT",
        message: "El monto debe ser mayor a cero",
        timestamp: new Date().toISOString(),
        path: req.path,
      },
    });
  }

  try {
    // Obtener la moneda de la cuenta origen
    const cuentaOrigenResult = await db.query(
        `SELECT c.moneda, c.usuario_id, c.saldo
         FROM cuenta c
         WHERE c.id = $1`,
        [fromAccountId],
    );

    if (cuentaOrigenResult.rows.length === 0) {
      return res.status(404).json({
        error: {
          code: "ACCOUNT_NOT_FOUND",
          message: "Cuenta origen no encontrada",
          timestamp: new Date().toISOString(),
          path: req.path,
        },
      });
    }

    const cuentaOrigen = cuentaOrigenResult.rows[0];

    // Validar que la cuenta pertenece al usuario autenticado
    if (cuentaOrigen.usuario_id !== user.id) {
      return res.status(403).json({
        error: {
          code: "FORBIDDEN",
          message: "No tienes permiso para usar esta cuenta",
          timestamp: new Date().toISOString(),
          path: req.path,
        },
      });
    }

    // Validar saldo suficiente
    if (parseFloat(cuentaOrigen.saldo) < parseFloat(amount)) {
      return res.status(400).json({
        error: {
          code: "NO_FUNDS",
          message: "Saldo insuficiente en la cuenta origen",
          timestamp: new Date().toISOString(),
          path: req.path,
        },
      });
    }

    // Llamar al SP de transferencia interna
    const result = await db.query(
        "SELECT * FROM sp_transfer_create_internal($1, $2, $3, $4, $5)",
        [fromAccountId, toAccountId, amount, descripcion, user.id],
    );

    const row = result.rows && result.rows[0] ? result.rows[0] : undefined;

    if (!row || !row.success) {
      return res.status(400).json({
        error: {
          code: "TRANSFER_FAILED",
          message: row ? row.message : "No se pudo completar la transferencia",
          timestamp: new Date().toISOString(),
          path: req.path,
        },
      });
    }

    // REGISTRAR EN AUDITORÍA
    try {
      await audit.logTransfer(user.id, fromAccountId, {
        toAccountId,
        amount,
        descripcion,
        receiptNumber: row.receipt_number,
        status: row.status,
      });
    } catch (auditError) {
      console.error("Error registrando auditoría de transferencia:", auditError.message);
    }

    // Respuesta exitosa
    res.status(201).json({
      transferId: row.transfer_id,
      receiptNumber: row.receipt_number,
      status: row.status,
      message: row.message,
      details: {
        fromAccountId,
        toAccountId,
        amount,
        descripcion,
        timestamp: new Date().toISOString(),
      },
    });
  } catch (error) {
    console.error("Error en createInternalTransfer:", error);
    next(error);
  }
};

// Transferencia interbancaria (via WebSocket)
const createInterbankTransfer = async (req, res, next) => {
  const user = req.user;
  const {
    fromAccountId,
    destinationIBAN,
    amount,
    descripcion,
  } = req.body;

  // Validar campos obligatorios
  if (!fromAccountId || !destinationIBAN || !amount) {
    return res.status(422).json({
      error: {
        code: "VALIDATION_ERROR",
        message: "Faltan campos obligatorios: fromAccountId, destinationIBAN, amount",
        timestamp: new Date().toISOString(),
        path: req.path,
      },
    });
  }

  // Validar formato IBAN: CR01 + código banco (3) + 12 dígitos = 22 caracteres total
  // Ejemplo: CR01B07123456789012
  if (!destinationIBAN.match(/^CR01[A-Z][0-9]{2}[0-9]{12}$/)) {
    return res.status(400).json({
      error: {
        code: "INVALID_IBAN",
        message: "Formato de IBAN inválido. Debe ser: CR01 + código banco (ej: B07) + 12 dígitos numéricos",
        timestamp: new Date().toISOString(),
        path: req.path,
      },
    });
  }

  // Validar que el monto sea positivo
  if (amount <= 0) {
    return res.status(400).json({
      error: {
        code: "INVALID_AMOUNT",
        message: "El monto debe ser mayor a cero",
        timestamp: new Date().toISOString(),
        path: req.path,
      },
    });
  }

  try {
    // Obtener cuenta origen con IBAN
    const cuentaOrigenResult = await db.query(
        `SELECT c.*, c.usuario_id, c.iban, m.iso as moneda_iso
         FROM cuenta c
         INNER JOIN moneda m ON c.moneda = m.id
         WHERE c.id = $1`,
        [fromAccountId],
    );

    if (cuentaOrigenResult.rows.length === 0) {
      return res.status(404).json({
        error: {
          code: "ACCOUNT_NOT_FOUND",
          message: "Cuenta origen no encontrada",
          timestamp: new Date().toISOString(),
          path: req.path,
        },
      });
    }

    const cuentaOrigen = cuentaOrigenResult.rows[0];

    // Validar que la cuenta pertenece al usuario autenticado
    if (cuentaOrigen.usuario_id !== user.id) {
      return res.status(403).json({
        error: {
          code: "FORBIDDEN",
          message: "No tienes permiso para usar esta cuenta",
          timestamp: new Date().toISOString(),
          path: req.path,
        },
      });
    }

    // Validar que el IBAN destino NO sea del mismo banco (B02)
    const destinationBankCode = destinationIBAN.substring(4, 7);
    const originBankCode = cuentaOrigen.iban.substring(4, 7);

    if (destinationBankCode === originBankCode) {
      return res.status(400).json({
        error: {
          code: "SAME_BANK",
          message: "Use transferencia interna para cuentas del mismo banco",
          timestamp: new Date().toISOString(),
          path: req.path,
        },
      });
    }

    // Validar que no sea la misma cuenta
    if (destinationIBAN === cuentaOrigen.iban) {
      return res.status(400).json({
        error: {
          code: "INVALID_TRANSFER",
          message: "No se puede transferir a la misma cuenta",
          timestamp: new Date().toISOString(),
          path: req.path,
        },
      });
    }

    // Validar fondos suficientes (incluyendo reservas)
    const reservasResult = await db.query(
        `SELECT COALESCE(SUM(monto), 0) as total_reservado 
         FROM transferencia_reserva 
         WHERE cuenta_id = $1 AND estado = 'active'`,
        [fromAccountId],
    );

    const saldoDisponible = parseFloat(cuentaOrigen.saldo) - parseFloat(reservasResult.rows[0].total_reservado);

    if (saldoDisponible < parseFloat(amount)) {
      return res.status(400).json({
        error: {
          code: "NO_FUNDS",
          message: "Fondos insuficientes para realizar la transferencia",
          details: {
            saldo: parseFloat(cuentaOrigen.saldo),
            reservado: parseFloat(reservasResult.rows[0].total_reservado),
            disponible: saldoDisponible,
            requerido: parseFloat(amount),
          },
          timestamp: new Date().toISOString(),
          path: req.path,
        },
      });
    }

    // Iniciar transferencia via WebSocket
    const wsManager = getWebSocketManager();

    const transferData = {
      from: cuentaOrigen.iban,
      to: destinationIBAN,
      amount: parseFloat(amount),
      currency: cuentaOrigen.moneda_iso,
      description: descripcion || "Transferencia interbancaria",
    };

    console.log("[TransfersController] Iniciando transferencia interbancaria via WebSocket");
    console.log(`[TransfersController] ${transferData.from} → ${transferData.to}`);
    console.log(`[TransfersController] Monto: ${transferData.currency} ${transferData.amount}`);

    const result = await wsManager.initiateTransfer(transferData);

    // REGISTRAR EN AUDITORÍA
    try {
      await audit.logTransfer(user.id, fromAccountId, {
        destinationIBAN,
        amount,
        descripcion,
        transferId: result.transferId,
        type: "interbancaria",
        status: "completed",
      });
    } catch (auditError) {
      console.error("Error registrando auditoría de transferencia:", auditError.message);
    }

    // Respuesta exitosa
    res.status(201).json({
      success: true,
      transferId: result.transferId,
      message: result.message,
      details: {
        from: transferData.from,
        to: transferData.to,
        amount: transferData.amount,
        currency: transferData.currency,
        descripcion: transferData.description,
        timestamp: new Date().toISOString(),
      },
    });
  } catch (error) {
    console.error("[TransfersController] Error en createInterbankTransfer:", error);

    // Mapear errores del WebSocket a respuestas HTTP
    if (error.code) {
      const statusCodes = {
        NO_FUNDS: 400,
        ACCOUNT_NOT_FOUND: 404,
        SAME_BANK: 400,
        DEST_BANK_OFFLINE: 503,
        TIMEOUT: 504,
        CONNECTION_ERROR: 503,
        ROLLBACK: 500,
        REJECTED: 400,
      };

      const statusCode = statusCodes[error.code] || 500;

      return res.status(statusCode).json({
        error: {
          code: error.code,
          message: error.message,
          timestamp: new Date().toISOString(),
          path: req.path,
        },
      });
    }

    next(error);
  }
};

module.exports = {
  createInternalTransfer,
  createInterbankTransfer,
};
