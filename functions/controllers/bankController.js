const db = require("../config/database");

const validateAccount = async (req, res, next) => {
  try {
    const {iban} = req.body;

    // Validar que el IBAN venga en el request
    if (!iban) {
      return res.status(422).json({
        error: {
          code: "VALIDATION_ERROR",
          message: "El IBAN es requerido",
          details: {iban: "Este campo es obligatorio"},
          timestamp: new Date().toISOString(),
          path: req.originalUrl,
        },
      });
    }

    // Llamar al SP de validación
    const result = await db.query(
        "SELECT * FROM sp_bank_validate_account($1)",
        [iban],
    );

    const accountInfo = result.rows[0];

    // Si la cuenta no existe o no está activa
    if (!accountInfo.account_exists) {
      return res.status(404).json({
        error: {
          code: "ACCOUNT_NOT_FOUND",
          message: "Cuenta bancaria no encontrada o inactiva",
          details: {iban},
          timestamp: new Date().toISOString(),
          path: req.originalUrl,
        },
      });
    }

    // Retornar información de la cuenta
    return res.status(200).json({
      data: {
        exists: accountInfo.account_exists,
        iban: iban,
        ownerName: accountInfo.owner_name,
        ownerId: accountInfo.owner_id,
        accountId: accountInfo.account_id,
        currencyIso: accountInfo.currency_iso,
      },
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  validateAccount,
};
