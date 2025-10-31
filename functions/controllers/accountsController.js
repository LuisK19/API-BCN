const db = require("../config/database");

// Crear cuenta bancaria
const createAccount = async (req, res, next) => {
  const user = req.user;
  const {
    iban,
    alias,
    tipoCuenta,
    moneda,
    saldoInicial,
  } = req.body;
  if (!iban || !alias || !tipoCuenta || !moneda || saldoInicial === undefined) {
    return res.status(422).json({
      error: {
        code: "VALIDATION_ERROR",
        message: "Faltan campos obligatorios",
        timestamp: new Date().toISOString(),
        path: req.path,
      },
    });
  }
  try {
    const result = await db.query(
        "SELECT * FROM sp_accounts_create($1, $2, $3, $4, $5, $6)",
        [user.id, iban, alias, tipoCuenta, moneda, saldoInicial],
    );
    const row = result.rows && result.rows[0] ? result.rows[0] : undefined;
    if (!row || !row.success) {
      return res.status(400).json({
        error: {
          code: "CREATE_FAILED",
          message: row ? row.message : "No se pudo crear la cuenta",
          timestamp: new Date().toISOString(),
          path: req.path,
        },
      });
    }
    res.status(201).json({accountId: row.account_id, message: row.message});
  } catch (error) {
    next(error);
  }
};

// Listar cuentas de usuario
const listAccounts = async (req, res, next) => {
  const user = req.user;
  try {
    const result = await db.query(
        "SELECT * FROM sp_accounts_get($1, NULL)",
        [user.id],
    );
    res.status(200).json({accounts: result.rows});
  } catch (error) {
    next(error);
  }
};

// Consultar detalle de cuenta
const getAccountDetail = async (req, res, next) => {
  const user = req.user;
  const {accountid} = req.params;
  try {
    const result = await db.query(
        "SELECT * FROM sp_accounts_get(NULL, $1)",
        [accountid],
    );
    const account = result.rows && result.rows[0] ? result.rows[0] : undefined;
    if (!account) {
      return res.status(404).json({
        error: {
          code: "NOT_FOUND",
          message: "Cuenta no encontrada",
          timestamp: new Date().toISOString(),
          path: req.path,
        },
      });
    }
    // Validar que el usuario sea dueño o admin
    if (user.role !== "admin" && account.usuario_id !== user.id) {
      return res.status(403).json({
        error: {
          code: "FORBIDDEN",
          message: "No autorizado",
          timestamp: new Date().toISOString(),
          path: req.path,
        },
      });
    }
    res.status(200).json({account});
  } catch (error) {
    next(error);
  }
};

// Cambiar estado de cuenta
const setAccountStatus = async (req, res, next) => {
  const user = req.user;
  const {accountid} = req.params;
  const {nuevoEstado} = req.body;
  if (!nuevoEstado) {
    return res.status(422).json({
      error: {
        code: "VALIDATION_ERROR",
        message: "Falta el nuevo estado",
        timestamp: new Date().toISOString(),
        path: req.path,
      },
    });
  }
  try {
    // Validar que el usuario sea dueño o admin
    const resultGet = await db.query(
        "SELECT * FROM sp_accounts_get(NULL, $1)",
        [accountid],
    );
    const account = resultGet.rows && resultGet.rows[0] ? resultGet.rows[0] : undefined;
    if (!account) {
      return res.status(404).json({
        error: {
          code: "NOT_FOUND",
          message: "Cuenta no encontrada",
          timestamp: new Date().toISOString(),
          path: req.path,
        },
      });
    }
    if (user.role !== "admin" && account.usuario_id !== user.id) {
      return res.status(403).json({
        error: {
          code: "FORBIDDEN",
          message: "No autorizado",
          timestamp: new Date().toISOString(),
          path: req.path,
        },
      });
    }
    // Cambiar estado
    const result = await db.query(
        "SELECT * FROM sp_accounts_set_status($1, $2)",
        [accountid, nuevoEstado],
    );
    const row = result.rows && result.rows[0] ? result.rows[0] : undefined;
    if (!row || !row.success) {
      return res.status(400).json({
        error: {
          code: "UPDATE_FAILED",
          message: row ? row.message : "No se pudo cambiar el estado",
          timestamp: new Date().toISOString(),
          path: req.path,
        },
      });
    }
    res.status(200).json({message: row.message});
  } catch (error) {
    console.error("Error en setAccountStatus:", error); // <-- Agrega esto
    next(error);
  }
};

module.exports = {
  createAccount,
  listAccounts,
  getAccountDetail,
  setAccountStatus,
};
