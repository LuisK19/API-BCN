const {Pool} = require("pg");
require("dotenv").config();

const ENV = process.env.NODE_ENV === "production" ? "PROD" : "DEV";

const pool = new Pool({
  user: process.env[`${ENV}_DB_USER`],
  host: process.env[`${ENV}_DB_HOST`],
  database: process.env[`${ENV}_DB_NAME`],
  password: process.env[`${ENV}_DB_PASSWORD`],
  port: process.env[`${ENV}_DB_PORT`],
  ssl: process.env[`${ENV}_DB_SSL`] === "true" ? {rejectUnauthorized: false} : false,
});

pool.on("connect", () => {
  console.log("Conectado a la base de datos PostgreSQL");
});

pool.on("error", (err) => {
  console.error("Error de conexión a la BD:", err);
});

module.exports = {
  query: (text, params) => pool.query(text, params),
  pool,
};
