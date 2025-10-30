module.exports = {
  env: {
    es6: true,
    node: true,
  },
  parserOptions: {
    ecmaVersion: 2018,
  },
  extends: [
    "eslint:recommended",
    "google",
  ],
  rules: {
    "no-restricted-globals": ["error", "name", "length"],
    "prefer-arrow-callback": "error",
    "linebreak-style": "off", // DESHABILITADO completamente
    "no-unused-vars": "off",
    "no-console": "off",
    "quotes": ["error", "double", {"allowTemplateLiterals": true}],
    "max-len": ["error", {"code": 120}], // Aumentar límite de línea
  },
  overrides: [
    {
      files: ["**/*.spec.*"],
      env: {
        mocha: true,
      },
      rules: {},
    },
  ],
  globals: {},
};
