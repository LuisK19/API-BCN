// utils/generarIbanCR.js
// Generador de IBAN para Costa Rica y función de validación en API

/**
 * Genera un IBAN válido para Costa Rica (CR + 2 dígitos de control + 18 dígitos)
 * El formato oficial es: CRkk BBBB CCCC CCCC CCCC CC
 * Donde BBBB es el código de banco (6 dígitos), CCCC... es el número de cuenta (12 dígitos)
 */
function generarIbanCR() {
  const pais = 'CR';
  const control = Math.floor(10 + Math.random() * 90); // 2 dígitos de control
  const entidad = '000100'; // ejemplo: código banco (6 dígitos, puedes cambiarlo)
  const cuenta = String(Math.floor(Math.random() * 1e12)).padStart(12, '0'); // 12 dígitos
  return `${pais}${control}${entidad}${cuenta}`;
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
