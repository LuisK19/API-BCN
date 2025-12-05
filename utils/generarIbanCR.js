// utils/generarIbanCR.js
// Generador de IBAN para Costa Rica y función de validación en API

/**
 * Genera un IBAN válido para Costa Rica siguiendo el estándar del Banco Central
 * Formato: CR01BXX + 12 dígitos
 * CR = País (Costa Rica)
 * 01 = Identificador interno fijo
 * B02 = Código del banco (Banca Capital Nacional)
 * XXXXXXXXXXXX = 12 dígitos únicos de la cuenta
 */
function generarIbanCR() {
  const pais = 'CR';
  const control = '01'; // Identificador interno fijo según estándar
  const banco = 'B02'; // Banca Capital Nacional
  const cuenta = String(Math.floor(Math.random() * 1e12)).padStart(12, '0'); // 12 dígitos aleatorios
  return `${pais}${control}${banco}${cuenta}`;
}

/**
 * Valida si el IBAN ya existe en la base de datos usando el endpoint de la API
 * @param {string} iban - IBAN a validar
 * @param {string} jwtToken - JWT del usuario autenticado
 * @param {string} apiKey - API Key activa
 * @returns {Promise<boolean>} true si el IBAN NO existe, false si ya existe
 */
async function validarIban(iban, jwtToken, apiKey) {
  const response = await fetch(`/api/v1/accounts?iban=${iban}`, {
    method: 'GET',
    headers: {
      'Authorization': `Bearer ${jwtToken}`,
      'x-api-key': apiKey,
      'Accept': 'application/json'
    }
  });
  const data = await response.json();
  // Si data.data está vacío, el IBAN no existe
  return !data.data || data.data.length === 0;
}

// Exportar para uso en frontend
module.exports = {
  generarIbanCR,
  validarIban
};
