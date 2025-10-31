// scripts/generar-iban-terminal.js
// Script para generar un IBAN de Costa Rica desde la terminal

const { generarIbanCR } = require('./generarIbanCR');

const iban = generarIbanCR();
console.log('IBAN generado:', iban);
