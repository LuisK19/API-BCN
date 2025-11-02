/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {setGlobalOptions} = require("firebase-functions");
const functions = require("firebase-functions");
const express = require("express");
const cors = require("cors");
const dotenv = require("dotenv");

console.log("[index.js] Iniciando carga de variables de entorno...");
dotenv.config();
console.log("[index.js] Variables cargadas:");
console.log("  - NODE_ENV:", process.env.NODE_ENV);
console.log("  - DEV_PORT:", process.env.DEV_PORT);
console.log("  - PGHOST:", process.env.PGHOST);
console.log("  - PGPORT:", process.env.PGPORT);
console.log("  - PGDATABASE:", process.env.PGDATABASE);
console.log("  - PGUSER:", process.env.PGUSER);

const authRoutes = require("./routes/auth");
const usersRoutes = require("./routes/users");
const accountsRoutes = require("./routes/accounts");
const cardsRoutes = require("./routes/cards");
const transfersRoutes = require("./routes/transfers");
const bankRoutes = require("./routes/bank");
const auditRoutes = require("./routes/audit");
const errorMiddleware = require("./middlewares/errorMiddleware");

const app = express();

app.use(cors({
  origin: true,
  credentials: true,
}));

app.use(express.json());

app.use("/api/v1/auth", authRoutes);
app.use("/api/v1/users", usersRoutes);
app.use("/api/v1/accounts", accountsRoutes);
app.use("/api/v1/cards", cardsRoutes);
app.use("/api/v1/transfers", transfersRoutes);
app.use("/api/v1/bank", bankRoutes);
app.use("/api/v1/audit", auditRoutes);
app.get("/api/v1/health", (req, res) => {
  res.json({
    status: "OK",
    message: "API del Banco funcionando en Firebase Functions",
    environment: process.env.NODE_ENV || "production",
    timestamp: new Date().toISOString(),
  });
});

app.get("/api/v1/environment", (req, res) => {
  const ENV = process.env.NODE_ENV === "production" ? "PROD" : "DEV";
  res.json({
    environment: ENV,
    database: {
      host: process.env[`${ENV}_DB_HOST`],
      port: process.env[`${ENV}_DB_PORT`],
      name: process.env[`${ENV}_DB_NAME`],
    },
    timestamp: new Date().toISOString(),
  });
});

app.use(errorMiddleware);

app.use((req, res) => {
  res.status(404).json({
    error: {
      code: "NOT_FOUND",
      message: "Ruta no encontrada",
      timestamp: new Date().toISOString(),
      path: req.path,
    },
  });
});

// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
setGlobalOptions({maxInstances: 10});

// Exportar como Cloud Function
exports.api = functions.https.onRequest(app);

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });
