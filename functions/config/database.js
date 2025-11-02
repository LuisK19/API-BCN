const {Pool} = require("pg");
require("dotenv").config();

console.log("[database.js] Configurando conexión a base de datos...");

const pool = new Pool();

console.log("[database.js] Configuración del pool:");
console.log("  - Host:", process.env.PGHOST);
console.log("  - Port:", process.env.PGPORT);
console.log("  - Database:", process.env.PGDATABASE);
console.log("  - User:", process.env.PGUSER);

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
