const db = require("../config/database");
const audit = require("../utils/auditHelper");

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

module.exports = {
  createInternalTransfer,
};
