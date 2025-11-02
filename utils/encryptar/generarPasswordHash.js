// generarPasswordHash.js
const bcrypt = require("bcrypt");
const saltRounds = 12;

const passwordPlain = "JuanP123!";
bcrypt.hash(passwordPlain, saltRounds, (err, hash) => {
  if (err) throw err;
  console.log("Contraseña original:", passwordPlain);
  console.log("Hash generado:", hash);
});
