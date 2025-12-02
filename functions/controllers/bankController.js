const db = require("../config/database");

const CENTRAL_TOKEN = "BANK-CENTRAL-IC8057-2025";

const validateAccount = async (req, res) => {
  try {
    // 1) Validar token del Banco Central
    const token = req.headers["x-api-token"];

    if (!token || token !== CENTRAL_TOKEN) {
      return res.status(401).json({
        error: "UNAUTHORIZED",
        message: "Token inválido o ausente"
      });
    }

    // 2) Validar campo IBAN
    const { iban } = req.body;

    if (!iban) {
      return res.status(400).json({
        error: "INVALID_ACCOUNT_FORMAT",
        message: "El IBAN es obligatorio."
      });
    }

    // 3) Validar formato IBAN según estándar del proyecto
    // CR01B07 + 12 dígitos
    const ibanRegex = /^CR01B07\d{12}$/;

    if (!ibanRegex.test(iban)) {
      return res.status(400).json({
        error: "INVALID_ACCOUNT_FORMAT",
        message: "El formato del IBAN no es válido."
      });
    }

    // 4) Buscar la cuenta en BD
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

    // 5) Si no existe → exists: false, info: null
    console.log("Resultado de la consulta:", row);
    if (!row) {
      return res.status(200).json({
        exists: false,
        info: null
      });
    }

    // 6) Si existe
    return res.status(200).json({
      exists: true,
      info: {
        name: row.owner_name,
        identification: row.owner_id,
        currency: row.currency_iso,
        debit: true,
        credit: true
      }
    });

  } catch (error) {
    console.error("Error en validateAccount:", error);
    return res.status(500).json({
      error: "SERVER_ERROR",
      message: "Error interno del servidor"
    });
  }
};

module.exports = {
  validateAccount
};
