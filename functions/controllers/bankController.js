/* eslint-disable padded-blocks */
/* eslint-disable require-jsdoc */
const db = require("../config/database");
const axios = require("axios");
const {getWebSocketManager} = require("../utils/websocketManager");

const CENTRAL_TOKEN = "BANK-CENTRAL-IC8057-2025";
const CENTRAL_BANK_URL = "http://137.184.36.3:6000";

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
    "B08": "Banco Órbita",
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
        message: "Token inválido o ausente",
      });
    }

    // Validación IBAN requerido
    const {iban} = req.body;
    if (!iban) {
      return res.status(400).json({
        error: "INVALID_ACCOUNT_FORMAT",
        message: "El IBAN es obligatorio.",
      });
    }

    // Validación de formato IBAN (acepta cualquier banco B01-B08)
    const ibanRegex = /^CR01B(0[1-8])\d{12}$/;
    if (!ibanRegex.test(iban)) {
      return res.status(400).json({
        error: "INVALID_ACCOUNT_FORMAT",
        message: "El formato del IBAN no es válido. Debe ser CR01BXX seguido de 12 dígitos.",
      });
    }

    // Obtener código del banco del IBAN
    const bankCode = iban.substring(4, 7);
    const bankName = getBankName(bankCode);

    // Si el IBAN NO es de nuestro banco (B02), devolver exists: false
    if (!isFromThisBank(iban)) {
      return res.status(200).json({
        exists: false,
        info: null,
        bank: bankName,
      });
    }

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
        bank: bankName,
      });
    }

    return res.status(200).json({
      exists: true,
      info: {
        name: row.owner_name,
        identification: row.owner_id,
        currency: row.currency_iso,
        debit: true,
        credit: true,
      },
      bank: bankName,
    });

  } catch (error) {
    console.error("Error en validateAccount:", error);
    return res.status(500).json({
      error: "SERVER_ERROR",
      message: "Error interno del servidor",
    });
  }
};

// Ping al Banco Central para verificar si está vivo
const pingCentralBank = async (req, res) => {
  try {
    console.log("[Bank Controller] Haciendo ping al Banco Central...");
    console.log(`[Bank Controller] URL: ${CENTRAL_BANK_URL}`);

    const startTime = Date.now();

    // Intentar hacer ping con timeout corto (5 segundos)
    const response = await axios.get(`${CENTRAL_BANK_URL}/health`, {
      timeout: 5000,
      headers: {
        "X-API-TOKEN": CENTRAL_TOKEN,
      },
    }).catch((error) => {
      return {
        success: false,
        error: error.message,
        code: error.code,
      };
    });

    const responseTime = Date.now() - startTime;

    if (response.success === false) {
      return res.status(503).json({
        status: "offline",
        message: "Banco Central no disponible",
        details: {
          url: CENTRAL_BANK_URL,
          error: response.error,
          code: response.code,
          responseTime: `${responseTime}ms`,
        },
      });
    }

    return res.status(200).json({
      status: "online",
      message: "Banco Central disponible",
      details: {
        url: CENTRAL_BANK_URL,
        responseTime: `${responseTime}ms`,
        data: response.data,
      },
    });

  } catch (error) {
    console.error("[Bank Controller] Error en ping:", error.message);
    return res.status(503).json({
      status: "error",
      message: "Error al contactar Banco Central",
      details: {
        error: error.message,
      },
    });
  }
};

// Verificar estado del WebSocket
const checkWebSocketStatus = async (req, res) => {
  try {
    const wsManager = getWebSocketManager();

    const status = {
      connected: wsManager.isConnected,
      socketId: wsManager.socket && wsManager.socket.id ? wsManager.socket.id : null,
      pendingTransfers: wsManager.pendingTransfers.size,
      reconnectAttempts: wsManager.reconnectAttempts,
      maxReconnectAttempts: wsManager.maxReconnectAttempts,
      config: {
        bankId: wsManager.config.bankId,
        bankName: wsManager.config.bankName,
        centralBankUrl: wsManager.config.centralBankUrl,
        transferTimeout: `${wsManager.config.transferTimeout / 1000}s`,
      },
    };

    // Intentar conectar si no está conectado
    if (!wsManager.isConnected) {
      console.log("[Bank Controller] WebSocket desconectado, intentando conectar...");
      wsManager.connect();

      // Esperar 3 segundos
      await new Promise((resolve) => setTimeout(resolve, 3000));

      status.connected = wsManager.isConnected;
      status.socketId = wsManager.socket && wsManager.socket.id ? wsManager.socket.id : null;
    }

    return res.status(200).json({
      status: status.connected ? "connected" : "disconnected",
      message: status.connected ?
        "WebSocket conectado al Banco Central" :
        "WebSocket no conectado",
      details: status,
    });

  } catch (error) {
    console.error("[Bank Controller] Error verificando WebSocket:", error.message);
    return res.status(500).json({
      status: "error",
      message: "Error al verificar estado del WebSocket",
      details: {
        error: error.message,
      },
    });
  }
};

module.exports = {validateAccount, pingCentralBank, checkWebSocketStatus};
