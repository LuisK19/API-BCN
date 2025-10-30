const bcrypt = require("bcrypt");
const saltRounds = 12; // Usa el mismo valor que tienes en tu .env

const apiKeyPlain = "Plu8Kj-T6YgR-xY790n-123H45-800-80YS-psa-txoa19!";
bcrypt.hash(apiKeyPlain, saltRounds, (err, hash) => {
  if (err) throw err;
  console.log("API Key original:", apiKeyPlain);
  console.log("API Key hash:", hash);
});
