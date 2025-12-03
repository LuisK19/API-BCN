const db = require("../config/database");

const CENTRAL_TOKEN = "BANK-CENTRAL-IC8057-2025";

// Obtener nombre del banco por código
function getBankName(code) {
  const banks = {
    "B01": "Banca Prometedora",
    "B02": "Banca Capital Nacional",
    "B03": "Banco Astralis",
    "B04": "Banco DyG",
    "B05": "Bancrap",
    "B06": "Banco Damena",
    "B07": "Banco NSFM",
    "B08": "Banco Órbita"
  };

  return banks[code] || "Desconocido";
}

// Verificar si IBAN pertenece a este banco
function isFromThisBank(iban) {
  return iban.substring(4, 7) === "B02";
}

const validateAccount = async (req, res) => {
  try {
    // Validación token Banco Central
    const token = req.headers["x-api-token"];
    if (!token || token !== CENTRAL_TOKEN) {
      return res.status(401).json({
        error: "UNAUTHORIZED",
        message: "Token inválido o ausente"
      });
    }

    // Validación IBAN requerido
    const { iban } = req.body;
    if (!iban) {
      return res.status(400).json({
        error: "INVALID_ACCOUNT_FORMAT",
        message: "El IBAN es obligatorio."
      });
    }

    // Validación de formato IBAN
    const ibanRegex = /^CR01B02\d{12}$/;
    if (!ibanRegex.test(iban)) {
      return res.status(400).json({
        error: "INVALID_ACCOUNT_FORMAT",
        message: "El formato del IBAN no es válido."
      });
    }

    // Obtener código del banco del IBAN
    const bankCode = iban.substring(4, 7);
    const bankName = getBankName(bankCode);

    // Buscar cuenta
    const query = `
      SELECT 
        c.iban,
        u.nombre || ' ' || u.primer_apellido || ' ' || u.segundo_apellido AS owner_name,
        u.identificacion AS owner_id,
        m.iso AS currency_iso
      FROM cuenta c
      JOIN usuario u ON u.id = c.usuario_id
      JOIN moneda m ON m.id = c.moneda
      WHERE c.iban = $1
      LIMIT 1;
    `;

    const result = await db.query(query, [iban]);
    const row = result.rows[0];

    if (!row) {
      return res.status(200).json({
        exists: false,
        info: null,
        bank: bankName
      });
    }

    return res.status(200).json({
      exists: true,
      info: {
        name: row.owner_name,
        identification: row.owner_id,
        currency: row.currency_iso,
        debit: true,
        credit: true
      },
      bank: bankName
    });

  } catch (error) {
    console.error("Error en validateAccount:", error);
    return res.status(500).json({
      error: "SERVER_ERROR",
      message: "Error interno del servidor"
    });
  }
};

module.exports = { validateAccount };
