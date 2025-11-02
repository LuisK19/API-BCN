const {Pool} = require("pg");
const functions = require("firebase-functions");
require("dotenv").config();

console.log("[database.js] Configurando conexión a base de datos...");

// Detectar si estamos en Firebase Functions (producción) o local
const isProduction = process.env.FUNCTIONS_EMULATOR !== "true" &&
                     process.env.NODE_ENV !== "development";

let dbConfig;

if (isProduction) {
  // Configuración para Firebase Functions (Producción)
  console.log("[database.js] Modo: PRODUCCIÓN (Firebase Functions)");
  const config = functions.config();
  dbConfig = {
    user: (config.db && config.db.user) || process.env.PGUSER,
    password: (config.db && config.db.password) || process.env.PGPASSWORD,
    host: (config.db && config.db.host) || process.env.PGHOST,
    port: parseInt((config.db && config.db.port) || process.env.PGPORT || "5432"),
    database: (config.db && config.db.name) || process.env.PGDATABASE,
    ssl: false, // Deshabilitado porque el servidor no soporta SSL
    max: 10, // Máximo de conexiones en el pool
    idleTimeoutMillis: 30000, // Cerrar conexiones inactivas después de 30s
    connectionTimeoutMillis: 10000, // Timeout de 10s para conectar
  };
} else {
  // Configuración para desarrollo local (usa .env)
  console.log("[database.js] Modo: DESARROLLO (Local/Emulador)");
  dbConfig = {
    user: process.env.PGUSER,
    password: process.env.PGPASSWORD,
    host: process.env.PGHOST,
    port: parseInt(process.env.PGPORT || "5432"),
    database: process.env.PGDATABASE,
    ssl: false, // Deshabilitado porque el servidor no soporta SSL
  };
}

console.log("[database.js] Configuración del pool:");
console.log("  - Host:", dbConfig.host);
console.log("  - Port:", dbConfig.port);
console.log("  - Database:", dbConfig.database);
console.log("  - User:", dbConfig.user);
console.log("  - SSL:", dbConfig.ssl ? "Habilitado" : "Deshabilitado");

const pool = new Pool(dbConfig);

pool.on("connect", () => {
  console.log("[database.js] Conectado exitosamente a PostgreSQL");
});

pool.on("error", (err) => {
  console.error("[database.js] Error de conexión a la BD:", err.message);
});

module.exports = {
  query: (text, params) => pool.query(text, params),
  pool,
};
