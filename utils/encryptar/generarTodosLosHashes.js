// ====================================
// GENERADOR DE HASHES PARA INSERT DE PRUEBA
// Genera todos los hashes necesarios para insert-datos-prueba.sql
// ====================================

// NOTA: Ejecutar desde la carpeta raíz del proyecto:
// node utils/encryptar/generarTodosLosHashes.js

// Intentar cargar bcrypt desde functions/node_modules
let bcrypt;
try {
  bcrypt = require("../../functions/node_modules/bcrypt");
} catch (err) {
  console.error("Error: bcrypt no encontrado.");
  console.error("Instalar con: cd functions && npm install bcrypt");
  process.exit(1);
}

const saltRounds = 12; // Debe coincidir con tu configuración

// ====================================
// FUNCIÓN PRINCIPAL (ASYNC/AWAIT)
// ====================================
async function generateAllHashes() {
  console.log("========================================");
  console.log("GENERANDO HASHES PARA INSERTS DE PRUEBA");
  console.log("========================================\n");

  // ====================================
  // 1. API KEY (bcrypt)
  // ====================================
  const apiKeyPlain = "Plu8Kj-T6YgR-xY790n-123H45-800-80YS-psa-txoa19!";
  
  console.log("1. API KEY (bcrypt)");
  console.log("-".repeat(40));
  console.log("API Key original:", apiKeyPlain);
  const apiKeyHash = await bcrypt.hash(apiKeyPlain, saltRounds);
  console.log("API Key hash (bcrypt):", apiKeyHash);
  console.log("");

  // ====================================
  // 2. CONTRASEÑAS DE USUARIOS
  // ====================================
  const passwords = [
    { user: "admin", password: "Admin123!" },
    { user: "juanperez", password: "Juan123!" },
    { user: "mariagonzalez", password: "Maria123!" },
    { user: "carlosramirez", password: "Carlos123!" }
  ];

  console.log("2. CONTRASEÑAS DE USUARIOS (bcrypt)");
  console.log("-".repeat(40));
  
  for (const item of passwords) {
    const hash = await bcrypt.hash(item.password, saltRounds);
    console.log(`Usuario: ${item.user}`);
    console.log(`  Password: ${item.password}`);
    console.log(`  Hash: ${hash}`);
    console.log("");
  }

  // ====================================
  // 3. PIN Y CVV DE TARJETAS
  // ====================================
  console.log("3. PIN Y CVV DE TARJETAS (bcrypt)");
  console.log("-".repeat(40));
  
  const cvvPlain = "123";
  const pinPlain = "1234";
  
  const cvvHash = await bcrypt.hash(cvvPlain, saltRounds);
  console.log(`CVV: ${cvvPlain}`);
  console.log(`  Hash: ${cvvHash}`);
  console.log("");
  
  const pinHash = await bcrypt.hash(pinPlain, saltRounds);
  console.log(`PIN: ${pinPlain}`);
  console.log(`  Hash: ${pinHash}`);
  console.log("");

  // ====================================
  // 4. CÓDIGOS OTP (ejemplo)
  // ====================================
  console.log("4. CÓDIGOS OTP DE EJEMPLO (bcrypt)");
  console.log("-".repeat(40));
  
  const otpPlain = "123456";
  const otpHash = await bcrypt.hash(otpPlain, saltRounds);
  console.log(`OTP: ${otpPlain}`);
  console.log(`  Hash: ${otpHash}`);
  console.log("");
  
  console.log("========================================");
  console.log("GENERACION COMPLETADA");
  console.log("========================================");
}

// Ejecutar la función principal
console.log("\nGenerando hashes... (esto puede tardar unos segundos)\n");
generateAllHashes().catch(err => {
  console.error("Error generando hashes:", err);
  process.exit(1);
});
