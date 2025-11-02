-- ====================================
-- INSERTS DE DATOS DE PRUEBA
-- Para Create-Ane.sql
-- ====================================

-- NOTA: Los datos de catálogo ya se insertan en Create-Ane.sql
-- Este archivo contiene datos de prueba para usuarios, cuentas y tarjetas

-- PROPoSITO:
-- Este script inserta datos de prueba para simular un ambiente bancario funcional
-- con usuarios, cuentas, tarjetas y transacciones de ejemplo.

-- PREREQUISITOS:
-- 1. La base de datos debe estar creada y con su esquema definido (create-ane.sql)
-- 2. Las tablas de catalogo deben estar pobladas con los datos base
-- 3. No debe existir conflicto con datos existentes (IDs, usuarios, etc.)

-- ESTRUCTURA DEL SCRIPT:
-- 1. API Key de prueba para desarrollo
-- 2. Usuario administrador y tres usuarios cliente con diferentes perfiles
-- 3. Cuentas bancarias en diferentes monedas (CRC y USD)
-- 4. Tarjetas de credito de diferentes categorias
-- 5. Movimientos de cuenta (debitos y creditos)
-- 6. Movimientos de tarjeta (compras y pagos)

-- NOTAS DE SEGURIDAD:
-- - Las contraseñas estan hasheadas usando bcrypt (costo=12)
-- - Los numeros de tarjeta estan enmascarados (solo ultimos 4 digitos visibles)
-- - CVV y PIN estan hasheados, nunca en texto plano
-- - La API Key de prueba solo debe usarse en ambiente de desarrollo

-- ====================================
-- 1. API KEY DE PRUEBA
-- ====================================
INSERT INTO apiKey (clave_hash, etiqueta, activa) VALUES 
('$2b$12$lX5V1PD9Lf9R9UnXz95RjOB.Ks2/b74C04dxozneT1sRghvY07jJG', 'API Key de prueba para desarrollo', TRUE);

-- ====================================
-- 2. USUARIOS DE PRUEBA
-- ====================================

-- Usuario Admin
-- Username: admin
-- Password: Admin123! 
-- Hash bcrypt: $2b$12$DXHIi6KSwRiOrZmTU/DJA.xVklaM.dcZJh6G6eEAdN0j.3A2e9OFi
INSERT INTO usuario (
    tipo_identificacion,
    identificacion,
    nombre,
    primer_apellido,
    segundo_apellido,
    correo,
    telefono,
    usuario,
    contrasena_hash,
    rol,
    fecha_nacimiento,
    estado
) VALUES (
    (SELECT id FROM tipoIdentificacion WHERE nombre = 'Nacional'),
    '1-1111-1111',
    'Administrador',
    'Sistema',
    'BCN',
    'admin@bancobcn.com',
    '8888-8888',
    'admin',
    '$2b$12$DXHIi6KSwRiOrZmTU/DJA.xVklaM.dcZJh6G6eEAdN0j.3A2e9OFi',
    (SELECT id FROM rol WHERE nombre = 'admin'),
    '1990-01-01',
    'active'
);

-- Usuario Cliente 1: Juan Pérez
-- Username: juanperez
-- Password: Juan123!
-- Hash bcrypt: $2b$10$aH5VqKvZ8yKzX9mP3nQ0xO5JYvZ8Y9X0Z1Z2Z3Z4Z5Z6Z7Z8Z9Z1A
INSERT INTO usuario (
    tipo_identificacion,
    identificacion,
    nombre,
    primer_apellido,
    segundo_apellido,
    correo,
    telefono,
    usuario,
    contrasena_hash,
    rol,
    fecha_nacimiento,
    estado
) VALUES (
    (SELECT id FROM tipoIdentificacion WHERE nombre = 'Nacional'),
    '1-2345-6789',
    'Juan',
    'Pérez',
    'Rodríguez',
    'juan.perez@email.com',
    '8888-1234',
    'juanperez',
    '$2b$12$Rf3zOAMHbl4rXiObac3iTuwGo8xp4CoPLkFT5ix0D7omELc4LwIau',
    (SELECT id FROM rol WHERE nombre = 'cliente'),
    '1985-03-15',
    'active'
);

-- Usuario Cliente 2: María González
-- Username: mariagonzalez
-- Password: Maria123!
-- Hash bcrypt: $2b$10$bH5VqKvZ8yKzX9mP3nQ0xO5JYvZ8Y9X0Z1Z2Z3Z4Z5Z6Z7Z8Z9Z2B
INSERT INTO usuario (
    tipo_identificacion,
    identificacion,
    nombre,
    primer_apellido,
    segundo_apellido,
    correo,
    telefono,
    usuario,
    contrasena_hash,
    rol,
    fecha_nacimiento,
    estado
) VALUES (
    (SELECT id FROM tipoIdentificacion WHERE nombre = 'Nacional'),
    '2-3456-7890',
    'María',
    'González',
    'Jiménez',
    'maria.gonzalez@email.com',
    '8888-5678',
    'mariagonzalez',
    '$2b$12$VUvwDcK45.00OY0oOIhfxutlFKHuunCcgE6mm6fpnBISSCAuC0iT.',
    (SELECT id FROM rol WHERE nombre = 'cliente'),
    '1992-07-22',
    'active'
);

-- Usuario Cliente 3: Carlos Ramírez (DIMEX)
-- Username: carlosramirez
-- Password: Carlos123!
-- Hash bcrypt: $2b$10$cH5VqKvZ8yKzX9mP3nQ0xO5JYvZ8Y9X0Z1Z2Z3Z4Z5Z6Z7Z8Z9Z3C
INSERT INTO usuario (
    tipo_identificacion,
    identificacion,
    nombre,
    primer_apellido,
    segundo_apellido,
    correo,
    telefono,
    usuario,
    contrasena_hash,
    rol,
    fecha_nacimiento,
    estado
) VALUES (
    (SELECT id FROM tipoIdentificacion WHERE nombre = 'DIMEX'),
    '123456789012',
    'Carlos',
    'Ramírez',
    'López',
    'carlos.ramirez@email.com',
    '8888-9012',
    'carlosramirez',
    '$2b$12$tcQrCnFXiHOloc9SmqNi6.d5QvfKMgpoYfffiwsJHm7OpP1M6sBqi',
    (SELECT id FROM rol WHERE nombre = 'cliente'),
    '1988-11-30',
    'active'
);

-- ====================================
-- 3. CUENTAS BANCARIAS
-- ====================================

-- Cuenta de Juan Pérez - Ahorro en Colones
INSERT INTO cuenta (
    usuario_id,
    iban,
    alias,
    tipoCuenta,
    moneda,
    saldo,
    estado
) VALUES (
    (SELECT id FROM usuario WHERE identificacion = '1-2345-6789'),
    'CR12015201001026284066',
    'Cuenta Principal Colones',
    (SELECT id FROM tipoCuenta WHERE nombre = 'Ahorros'),
    (SELECT id FROM moneda WHERE iso = 'CRC'),
    1500000.00,
    (SELECT id FROM estadoCuenta WHERE nombre = 'Activa')
);

-- Cuenta de Juan Pérez - Ahorro en Dólares
INSERT INTO cuenta (
    usuario_id,
    iban,
    alias,
    tipoCuenta,
    moneda,
    saldo,
    estado
) VALUES (
    (SELECT id FROM usuario WHERE identificacion = '1-2345-6789'),
    'CR12015201001026284067',
    'Cuenta Ahorros USD',
    (SELECT id FROM tipoCuenta WHERE nombre = 'Ahorros'),
    (SELECT id FROM moneda WHERE iso = 'USD'),
    5000.00,
    (SELECT id FROM estadoCuenta WHERE nombre = 'Activa')
);

-- Cuenta de María González - Corriente en Colones
INSERT INTO cuenta (
    usuario_id,
    iban,
    alias,
    tipoCuenta,
    moneda,
    saldo,
    estado
) VALUES (
    (SELECT id FROM usuario WHERE identificacion = '2-3456-7890'),
    'CR12015201001026284068',
    'Cuenta Corriente Personal',
    (SELECT id FROM tipoCuenta WHERE nombre = 'Corriente'),
    (SELECT id FROM moneda WHERE iso = 'CRC'),
    2500000.00,
    (SELECT id FROM estadoCuenta WHERE nombre = 'Activa')
);

-- Cuenta de María González - Ahorro en Dólares
INSERT INTO cuenta (
    usuario_id,
    iban,
    alias,
    tipoCuenta,
    moneda,
    saldo,
    estado
) VALUES (
    (SELECT id FROM usuario WHERE identificacion = '2-3456-7890'),
    'CR12015201001026284069',
    'Ahorros Dólares',
    (SELECT id FROM tipoCuenta WHERE nombre = 'Ahorros'),
    (SELECT id FROM moneda WHERE iso = 'USD'),
    10000.00,
    (SELECT id FROM estadoCuenta WHERE nombre = 'Activa')
);

-- Cuenta de Carlos Ramírez - Ahorro en Colones
INSERT INTO cuenta (
    usuario_id,
    iban,
    alias,
    tipoCuenta,
    moneda,
    saldo,
    estado
) VALUES (
    (SELECT id FROM usuario WHERE identificacion = '123456789012'),
    'CR12015201001026284070',
    'Mi Cuenta Principal',
    (SELECT id FROM tipoCuenta WHERE nombre = 'Ahorros'),
    (SELECT id FROM moneda WHERE iso = 'CRC'),
    800000.00,
    (SELECT id FROM estadoCuenta WHERE nombre = 'Activa')
);

-- ====================================
-- 4. TARJETAS DE CRÉDITO
-- ====================================

-- Tarjeta PLATINUM de Juan Pérez
-- CVV: 987 -> Encriptado AES-256-CBC
-- PIN: 2345 -> Encriptado AES-256-CBC
INSERT INTO tarjeta (
    usuario_id,
    tipo,
    numero_enmascarado,
    titular,
    fecha_expiracion,
    cvv_hash,
    pin_hash,
    moneda,
    limite_credito,
    saldo_actual,
    tasa_interes,
    fecha_corte,
    fecha_pago,
    compania,
    categoria,
    estado
) VALUES (
    (SELECT id FROM usuario WHERE identificacion = '1-2345-6789'),
    (SELECT id FROM tipoTarjeta WHERE nombre = 'Crédito'),
    '4532 **** **** 1234',
    'Juan Pérez Rodríguez',
    '12/28',
    'c88125dafeddd8074b45c598f4aac961:ced8414c5ad82a7d90468ab1e61a143b',
    '590dfcac4148497be4918e29b32b122f:9e85f9131ac441bc85a7794c0b247974',
    (SELECT id FROM moneda WHERE iso = 'USD'),
    15000.00,
    2500.00,
    18.50,
    '25 de cada mes',
    '10 del mes siguiente',
    'VISA',
    'platinum',
    'Activa'
);

-- Tarjeta GOLD de Juan Pérez
-- CVV: 123 -> Encriptado AES-256-CBC
-- PIN: 1234 -> Encriptado AES-256-CBC
INSERT INTO tarjeta (
    usuario_id,
    tipo,
    numero_enmascarado,
    titular,
    fecha_expiracion,
    cvv_hash,
    pin_hash,
    moneda,
    limite_credito,
    saldo_actual,
    tasa_interes,
    fecha_corte,
    fecha_pago,
    compania,
    categoria,
    estado
) VALUES (
    (SELECT id FROM usuario WHERE identificacion = '1-2345-6789'),
    (SELECT id FROM tipoTarjeta WHERE nombre = 'Crédito'),
    '5425 **** **** 5678',
    'Juan Pérez Rodríguez',
    '06/27',
    'acc2270d7b840e78fea3985c9fd6f7dd:9793fa5647b0d5d7f1e6f376e899d473',
    'b754781c3091f93b4646c84755da1ed1:a822bc251c568ca873319e9db5bd5740',
    (SELECT id FROM moneda WHERE iso = 'CRC'),
    8000000.00,
    1500000.00,
    19.00,
    '25 de cada mes',
    '10 del mes siguiente',
    'MASTERCARD',
    'gold',
    'Activa'
);

-- Tarjeta BLACK de María González
-- CVV: 456 -> Encriptado AES-256-CBC
-- PIN: 5678 -> Encriptado AES-256-CBC
INSERT INTO tarjeta (
    usuario_id,
    tipo,
    numero_enmascarado,
    titular,
    fecha_expiracion,
    cvv_hash,
    pin_hash,
    moneda,
    limite_credito,
    saldo_actual,
    tasa_interes,
    fecha_corte,
    fecha_pago,
    compania,
    categoria,
    estado
) VALUES (
    (SELECT id FROM usuario WHERE identificacion = '2-3456-7890'),
    (SELECT id FROM tipoTarjeta WHERE nombre = 'Crédito'),
    '3782 **** **** 9012',
    'María González Jiménez',
    '03/29',
    '9b83eb26e6d717291e4ef2914965a166:26e95916add11480d56a965324d04327',
    '6c3987c54e78082a414fa0a0f36590e0:ff079f86394e4def0e50d3bc8ae9cd9d',
    (SELECT id FROM moneda WHERE iso = 'USD'),
    20000.00,
    5000.00,
    17.50,
    '25 de cada mes',
    '10 del mes siguiente',
    'AMEX',
    'black',
    'Activa'
);

-- Tarjeta BLUE de María González
-- CVV: 789 -> Encriptado AES-256-CBC
-- PIN: 9012 -> Encriptado AES-256-CBC
INSERT INTO tarjeta (
    usuario_id,
    tipo,
    numero_enmascarado,
    titular,
    fecha_expiracion,
    cvv_hash,
    pin_hash,
    moneda,
    limite_credito,
    saldo_actual,
    tasa_interes,
    fecha_corte,
    fecha_pago,
    compania,
    categoria,
    estado
) VALUES (
    (SELECT id FROM usuario WHERE identificacion = '2-3456-7890'),
    (SELECT id FROM tipoTarjeta WHERE nombre = 'Crédito'),
    '4111 **** **** 3456',
    'María González Jiménez',
    '09/26',
    '6a2baf72bd98979476deb19783e063c3:c783b4968d76199ea2c177d32c8edc15',
    'b86d9eac3645bc4e0495e97086003abf:bc2e8d03bccac4c408a3dc63dadc9b66',
    (SELECT id FROM moneda WHERE iso = 'CRC'),
    3000000.00,
    500000.00,
    20.00,
    '25 de cada mes',
    '10 del mes siguiente',
    'VISA',
    'blue',
    'Activa'
);

-- Tarjeta SAPRISA de Carlos Ramírez
-- CVV: 321 -> Encriptado AES-256-CBC
-- PIN: 3456 -> Encriptado AES-256-CBC
INSERT INTO tarjeta (
    usuario_id,
    tipo,
    numero_enmascarado,
    titular,
    fecha_expiracion,
    cvv_hash,
    pin_hash,
    moneda,
    limite_credito,
    saldo_actual,
    tasa_interes,
    fecha_corte,
    fecha_pago,
    compania,
    categoria,
    estado
) VALUES (
    (SELECT id FROM usuario WHERE identificacion = '123456789012'),
    (SELECT id FROM tipoTarjeta WHERE nombre = 'Crédito'),
    '5200 **** **** 7890',
    'Carlos Ramírez López',
    '11/27',
    '908a00b4c3b3f9aa56206b92817217dc:2c0065a6c6df53555823868c881a2a68',
    '123d1f58021a0f3c710d8336b03d331e:9e66c9b853e70df6ead03fde1ed74b47',
    (SELECT id FROM moneda WHERE iso = 'CRC'),
    2500000.00,
    800000.00,
    18.00,
    '25 de cada mes',
    '10 del mes siguiente',
    'MASTERCARD',
    'saprisa',
    'Activa'
);

-- ====================================
-- 5. MOVIMIENTOS DE CUENTA
-- ====================================

-- Movimientos cuenta de Juan Pérez (Colones)
INSERT INTO movimientoCuenta (
    cuenta_id,
    fecha,
    tipo,
    descripcion,
    moneda,
    monto,
    comerciante,
    categoria,
    ubicacion,
    referencia
) VALUES 
(
    (SELECT id FROM cuenta WHERE iban = 'CR12015201001026284066'),
    NOW() - INTERVAL '5 days',
    (SELECT id FROM tipoMovimientoCuenta WHERE nombre = 'Crédito'),
    'Depósito en efectivo',
    (SELECT id FROM moneda WHERE iso = 'CRC'),
    500000.00,
    NULL,
    'Depósito',
    'Sucursal Central San José',
    'DEP-001'
),
(
    (SELECT id FROM cuenta WHERE iban = 'CR12015201001026284066'),
    NOW() - INTERVAL '3 days',
    (SELECT id FROM tipoMovimientoCuenta WHERE nombre = 'Débito'),
    'Pago servicios públicos',
    (SELECT id FROM moneda WHERE iso = 'CRC'),
    -75000.00,
    'ICE',
    'Servicios',
    'En línea',
    'PAG-002'
),
(
    (SELECT id FROM cuenta WHERE iban = 'CR12015201001026284066'),
    NOW() - INTERVAL '1 day',
    (SELECT id FROM tipoMovimientoCuenta WHERE nombre = 'Débito'),
    'Compra supermercado',
    (SELECT id FROM moneda WHERE iso = 'CRC'),
    -125000.00,
    'Automercado',
    'Supermercado',
    'Escazú',
    'COM-003'
);

-- Movimientos cuenta de María González (Colones)
INSERT INTO movimientoCuenta (
    cuenta_id,
    fecha,
    tipo,
    descripcion,
    moneda,
    monto,
    comerciante,
    categoria,
    referencia
) VALUES 
(
    (SELECT id FROM cuenta WHERE iban = 'CR12015201001026284068'),
    NOW() - INTERVAL '7 days',
    (SELECT id FROM tipoMovimientoCuenta WHERE nombre = 'Crédito'),
    'Transferencia recibida salario',
    (SELECT id FROM moneda WHERE iso = 'CRC'),
    1200000.00,
    NULL,
    'Salario',
    'SAL-001'
),
(
    (SELECT id FROM cuenta WHERE iban = 'CR12015201001026284068'),
    NOW() - INTERVAL '2 days',
    (SELECT id FROM tipoMovimientoCuenta WHERE nombre = 'Débito'),
    'Pago alquiler',
    (SELECT id FROM moneda WHERE iso = 'CRC'),
    -400000.00,
    NULL,
    'Vivienda',
    'ALQ-002'
);

-- ====================================
-- 6. MOVIMIENTOS DE TARJETA
-- ====================================

-- Movimientos tarjeta PLATINUM de Juan Pérez
INSERT INTO movimientoTarjeta (
    tarjeta_id,
    fecha,
    tipo,
    descripcion,
    moneda,
    monto,
    comerciante,
    ubicacion,
    referencia
) VALUES 
(
    (SELECT id FROM tarjeta WHERE numero_enmascarado = '4532 **** **** 1234'),
    NOW() - INTERVAL '10 days',
    (SELECT id FROM tipoMovimientoTarjeta WHERE nombre = 'Compra'),
    'Compra en línea Amazon',
    (SELECT id FROM moneda WHERE iso = 'USD'),
    250.00,
    'Amazon.com',
    'En línea',
    'AMZ-001'
),
(
    (SELECT id FROM tarjeta WHERE numero_enmascarado = '4532 **** **** 1234'),
    NOW() - INTERVAL '6 days',
    (SELECT id FROM tipoMovimientoTarjeta WHERE nombre = 'Compra'),
    'Restaurante',
    (SELECT id FROM moneda WHERE iso = 'USD'),
    85.50,
    'Il Pizzaiolo',
    'Escazú',
    'REST-002'
),
(
    (SELECT id FROM tarjeta WHERE numero_enmascarado = '4532 **** **** 1234'),
    NOW() - INTERVAL '2 days',
    (SELECT id FROM tipoMovimientoTarjeta WHERE nombre = 'Pago'),
    'Pago parcial tarjeta',
    (SELECT id FROM moneda WHERE iso = 'USD'),
    500.00,
    NULL,
    'Banca en línea',
    'PAG-003'
);

-- Movimientos tarjeta GOLD de Juan Pérez
INSERT INTO movimientoTarjeta (
    tarjeta_id,
    fecha,
    tipo,
    descripcion,
    moneda,
    monto,
    comerciante,
    ubicacion
) VALUES 
(
    (SELECT id FROM tarjeta WHERE numero_enmascarado = '5425 **** **** 5678'),
    NOW() - INTERVAL '8 days',
    (SELECT id FROM tipoMovimientoTarjeta WHERE nombre = 'Compra'),
    'Gasolinera',
    (SELECT id FROM moneda WHERE iso = 'CRC'),
    45000.00,
    'Delta',
    'San José'
),
(
    (SELECT id FROM tarjeta WHERE numero_enmascarado = '5425 **** **** 5678'),
    NOW() - INTERVAL '4 days',
    (SELECT id FROM tipoMovimientoTarjeta WHERE nombre = 'Compra'),
    'Supermercado',
    (SELECT id FROM moneda WHERE iso = 'CRC'),
    125000.00,
    'PriceSmart',
    'Alajuela'
);

-- Movimientos tarjeta BLACK de María González
INSERT INTO movimientoTarjeta (
    tarjeta_id,
    fecha,
    tipo,
    descripcion,
    moneda,
    monto,
    comerciante,
    ubicacion
) VALUES 
(
    (SELECT id FROM tarjeta WHERE numero_enmascarado = '3782 **** **** 9012'),
    NOW() - INTERVAL '12 days',
    (SELECT id FROM tipoMovimientoTarjeta WHERE nombre = 'Compra'),
    'Hotel',
    (SELECT id FROM moneda WHERE iso = 'USD'),
    1200.00,
    'Marriott',
    'Miami, FL'
),
(
    (SELECT id FROM tarjeta WHERE numero_enmascarado = '3782 **** **** 9012'),
    NOW() - INTERVAL '11 days',
    (SELECT id FROM tipoMovimientoTarjeta WHERE nombre = 'Compra'),
    'Vuelo',
    (SELECT id FROM moneda WHERE iso = 'USD'),
    850.00,
    'American Airlines',
    'En línea'
),
(
    (SELECT id FROM tarjeta WHERE numero_enmascarado = '3782 **** **** 9012'),
    NOW() - INTERVAL '1 day',
    (SELECT id FROM tipoMovimientoTarjeta WHERE nombre = 'Pago'),
    'Pago completo tarjeta',
    (SELECT id FROM moneda WHERE iso = 'USD'),
    2050.00,
    NULL,
    'Banca en línea'
);
