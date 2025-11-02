const crypto = require("crypto");

// Configuración de encriptación AES (DEBE SER LA MISMA que en cardsController.js)
const ENCRYPTION_KEY = process.env.ENCRYPTION_KEY || "12345678901234567890123456789012"; // 32 bytes
const ENCRYPTION_IV_LENGTH = 16;

/**
 * Función para encriptar datos sensibles (PIN/CVV) con AES-256-CBC
 * @param {string} text - Texto a encriptar
 * @returns {string} - Texto encriptado en formato "iv:encryptedData"
 */
function encrypt(text) {
  const iv = crypto.randomBytes(ENCRYPTION_IV_LENGTH);
  const cipher = crypto.createCipheriv("aes-256-cbc", Buffer.from(ENCRYPTION_KEY), iv);
  let encrypted = cipher.update(text);
  encrypted = Buffer.concat([encrypted, cipher.final()]);
  return iv.toString("hex") + ":" + encrypted.toString("hex");
}

// Datos de las tarjetas existentes (PIN y CVV originales)
const tarjetas = [
  {
    id: "a6fd0c33-897f-4c78-a960-04a991e37b64",
    numero: "5425 **** **** 5678",
    titular: "Juan Pérez Rodríguez",
    cvv: "123",
    pin: "1234",
  },
  {
    id: "d44fd80c-a25e-459d-8099-bf4c394f3379",
    numero: "3782 **** **** 9012",
    titular: "María González Jiménez",
    cvv: "456",
    pin: "5678",
  },
  {
    id: "05f53dee-b99d-4831-b095-114af76d2b27",
    numero: "4111 **** **** 3456",
    titular: "María González Jiménez",
    cvv: "789",
    pin: "9012",
  },
  {
    id: "989dd6bd-785d-4252-8da2-8fefa45fda6d",
    numero: "5200 **** **** 7890",
    titular: "Carlos Ramírez López",
    cvv: "321",
    pin: "3456",
  },
  {
    id: "512f4f7c-2b77-472d-a7d5-9a7201001d63",
    numero: "4532 **** **** 9876",
    titular: "Juan Pérez Rojas",
    cvv: "654",
    pin: "7890",
  },
  {
    id: "eae008b8-7540-4308-944f-47e5d62fff7c",
    numero: "4532 **** **** 1234",
    titular: "Juan Pérez Rodríguez",
    cvv: "987",
    pin: "2345",
  },
];

console.log("========================================");
console.log("ENCRIPTACIÓN AES-256 PARA PIN Y CVV");
console.log("========================================\n");

console.log("CLAVE DE ENCRIPTACIÓN:");
console.log(`ENCRYPTION_KEY = "${ENCRYPTION_KEY}"`);
console.log("\nIMPORTANTE: Esta misma clave debe estar en tu archivo .env como ENCRYPTION_KEY\n");

console.log("========================================");
console.log("VALORES ENCRIPTADOS:");
console.log("========================================\n");

tarjetas.forEach((tarjeta, index) => {
  const cvvEncrypted = encrypt(tarjeta.cvv);
  const pinEncrypted = encrypt(tarjeta.pin);

  console.log(`-- Tarjeta ${index + 1}: ${tarjeta.numero} (${tarjeta.titular})`);
  console.log(`-- ID: ${tarjeta.id}`);
  console.log(`-- CVV original: ${tarjeta.cvv} | PIN original: ${tarjeta.pin}`);
  console.log(`UPDATE tarjeta SET cvv_hash = '${cvvEncrypted}', pin_hash = '${pinEncrypted}' WHERE id = '${tarjeta.id}';`);
  console.log("");
});

console.log("========================================");
console.log("SCRIPT SQL COMPLETO:");
console.log("========================================\n");

console.log("-- Actualizar todas las tarjetas con encriptación AES-256");
console.log("BEGIN;\n");

tarjetas.forEach((tarjeta) => {
  const cvvEncrypted = encrypt(tarjeta.cvv);
  const pinEncrypted = encrypt(tarjeta.pin);
  console.log(`UPDATE tarjeta SET cvv_hash = '${cvvEncrypted}', pin_hash = '${pinEncrypted}' WHERE id = '${tarjeta.id}';`);
});

console.log("\nCOMMIT;");

console.log("\n========================================");
console.log("VERIFICACIÓN:");
console.log("========================================\n");

console.log("-- Para verificar que las tarjetas fueron actualizadas:");
console.log("SELECT id, numero_enmascarado, LEFT(cvv_hash, 40) as cvv_inicio, LEFT(pin_hash, 40) as pin_inicio FROM tarjeta;");

console.log("\n========================================");
console.log("INSTRUCCIONES:");
console.log("========================================");
console.log("1. Copia el script SQL completo (entre BEGIN y COMMIT)");
console.log("2. Ejecuta el script en tu base de datos PostgreSQL");
console.log("3. Verifica con la query de verificación");
console.log("4. Reinicia el emulador de Firebase");
console.log("5. Prueba el endpoint POST /api/v1/cards/:cardid/details con OTP");
console.log("\nLos valores encriptados cambiarán cada vez que ejecutes este script");
console.log("    debido al IV (Initialization Vector) aleatorio de AES-256.");
console.log("========================================\n");
