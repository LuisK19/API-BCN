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
-- ====================================
-- INSERTS DE DATOS DE PRUEBA (ACTUALIZADO)
-- Proyecto Banco – IC8057
-- Banco B02 – Banca Capital Nacional
-- Formato IBAN CR01B02 + 12 dígitos
-- ====================================
INSERT INTO apiKey (clave_hash, etiqueta, activa) VALUES 
('$2b$12$lX5V1PD9Lf9R9UnXz95RjOB.Ks2/b74C04dxozneT1sRghvY07jJG',
 'API Key de prueba para desarrollo',
 TRUE);

----------------------------------------
-- 2. USUARIOS DE PRUEBA
----------------------------------------

-- Usuario ADMIN
INSERT INTO usuario (
    tipo_identificacion, identificacion, nombre, primer_apellido, segundo_apellido,
    correo, telefono, usuario, contrasena_hash, rol, fecha_nacimiento, estado
) VALUES (
    (SELECT id FROM tipoIdentificacion WHERE nombre = 'Nacional'),
    '1-1111-1111',
    'Administrador', 'Sistema', 'BCN',
    'admin@bancobcn.com',
    '8888-8888',
    'admin',
    '$2b$12$DXHIi6KSwRiOrZmTU/DJA.xVklaM.dcZJh6G6eEAdN0j.3A2e9OFi',
    (SELECT id FROM rol WHERE nombre = 'admin'),
    '1990-01-01',
    'active'
);

-- Usuario JUAN PÉREZ
INSERT INTO usuario (
    tipo_identificacion, identificacion, nombre, primer_apellido, segundo_apellido,
    correo, telefono, usuario, contrasena_hash, rol, fecha_nacimiento, estado
) VALUES (
    (SELECT id FROM tipoIdentificacion WHERE nombre = 'Nacional'),
    '1-2345-6789',
    'Juan', 'Pérez', 'Rojas',
    'juan.perez@email.com',
    '8888-1234',
    'juanperez',
    '$2b$12$Rf3zOAMHbl4rXiObac3iTuwGo8xp4CoPLkFT5ix0D7omELc4LwIau',
    (SELECT id FROM rol WHERE nombre = 'cliente'),
    '1985-03-15',
    'active'
);

-- Usuario MARÍA GONZÁLEZ
INSERT INTO usuario (
    tipo_identificacion, identificacion, nombre, primer_apellido, segundo_apellido,
    correo, telefono, usuario, contrasena_hash, rol, fecha_nacimiento, estado
) VALUES (
    (SELECT id FROM tipoIdentificacion WHERE nombre = 'Nacional'),
    '2-3456-7890',
    'María', 'González', 'Jiménez',
    'maria.gonzalez@email.com',
    '8888-5678',
    'mariagonzalez',
    '$2b$12$VUvwDcK45.00OY0oOIhfxutlFKHuunCcgE6mm6fpnBISSCAuC0iT.',
    (SELECT id FROM rol WHERE nombre = 'cliente'),
    '1992-07-22',
    'active'
);

-- Usuario CARLOS RAMÍREZ
INSERT INTO usuario (
    tipo_identificacion, identificacion, nombre, primer_apellido, segundo_apellido,
    correo, telefono, usuario, contrasena_hash, rol, fecha_nacimiento, estado
) VALUES (
    (SELECT id FROM tipoIdentificacion WHERE nombre = 'DIMEX'),
    '123456789012',
    'Carlos', 'Ramírez', 'López',
    'carlos.ramirez@email.com',
    '8888-9012',
    'carlosramirez',
    '$2b$12$tcQrCnFXiHOloc9SmqNi6.d5QvfKMgpoYfffiwsJHm7OpP1M6sBqi',
    (SELECT id FROM rol WHERE nombre = 'cliente'),
    '1988-11-30',
    'active'
);

----------------------------------------
-- 3. CUENTAS BANCARIAS (IBAN ACTUALIZADOS)
----------------------------------------

-- Juan Pérez – USD
INSERT INTO cuenta (
    usuario_id, iban, alias, tipoCuenta, moneda, saldo, estado
) VALUES (
    (SELECT id FROM usuario WHERE identificacion = '1-2345-6789'),
    'CR01B02000000001111',
    'Cuenta Ahorros USD',
    (SELECT id FROM tipoCuenta WHERE nombre = 'Ahorros'),
    (SELECT id FROM moneda WHERE iso = 'USD'),
    5000.00,
    (SELECT id FROM estadoCuenta WHERE nombre = 'Activa')
);

-- María González – USD
INSERT INTO cuenta (
    usuario_id, iban, alias, tipoCuenta, moneda, saldo, estado
) VALUES (
    (SELECT id FROM usuario WHERE identificacion = '2-3456-7890'),
    'CR01B02000000002222',
    'Ahorros Dólares',
    (SELECT id FROM tipoCuenta WHERE nombre = 'Ahorros'),
    (SELECT id FROM moneda WHERE iso = 'USD'),
    10000.00,
    (SELECT id FROM estadoCuenta WHERE nombre = 'Activa')
);

-- Admin – Cuenta de demostración
INSERT INTO cuenta (
    usuario_id, iban, alias, tipoCuenta, moneda, saldo, estado
) VALUES (
    (SELECT id FROM usuario WHERE usuario = 'admin'),
    'CR01B02000000003333',
    'Cuenta Principal',
    (SELECT id FROM tipoCuenta WHERE nombre = 'Corriente'),
    (SELECT id FROM moneda WHERE iso = 'CRC'),
    100000.00,
    (SELECT id FROM estadoCuenta WHERE nombre = 'Activa')
);

-- Carlos Ramírez – CRC
INSERT INTO cuenta (
    usuario_id, iban, alias, tipoCuenta, moneda, saldo, estado
) VALUES (
    (SELECT id FROM usuario WHERE identificacion = '123456789012'),
    'CR01B02000000004444',
    'Mi Cuenta Principal',
    (SELECT id FROM tipoCuenta WHERE nombre = 'Ahorros'),
    (SELECT id FROM moneda WHERE iso = 'CRC'),
    800000.00,
    (SELECT id FROM estadoCuenta WHERE nombre = 'Activa')
);

-- Juan Pérez – CRC
INSERT INTO cuenta (
    usuario_id, iban, alias, tipoCuenta, moneda, saldo, estado
) VALUES (
    (SELECT id FROM usuario WHERE identificacion = '1-2345-6789'),
    'CR01B02000000005555',
    'Cuenta Principal Colones',
    (SELECT id FROM tipoCuenta WHERE nombre = 'Ahorros'),
    (SELECT id FROM moneda WHERE iso = 'CRC'),
    1500000.00,
    (SELECT id FROM estadoCuenta WHERE nombre = 'Activa')
);

-- María González – CRC
INSERT INTO cuenta (
    usuario_id, iban, alias, tipoCuenta, moneda, saldo, estado
) VALUES (
    (SELECT id FROM usuario WHERE identificacion = '2-3456-7890'),
    'CR01B02000000006666',
    'Cuenta Corriente Personal',
    (SELECT id FROM tipoCuenta WHERE nombre = 'Corriente'),
    (SELECT id FROM moneda WHERE iso = 'CRC'),
    2500000.00,
    (SELECT id FROM estadoCuenta WHERE nombre = 'Activa')
);

----------------------------------------
-- 4. MOVIMIENTOS DE CUENTAS (ACTUALIZADOS CON NUEVOS IBAN)
----------------------------------------

-- Juan Pérez – CRC
INSERT INTO movimientoCuenta (
    cuenta_id, fecha, tipo, descripcion, moneda, monto, comerciante, categoria, ubicacion, referencia
) VALUES 
(
    (SELECT id FROM cuenta WHERE iban = 'CR01B02000000005555'),
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
    (SELECT id FROM cuenta WHERE iban = 'CR01B02000000005555'),
    NOW() - INTERVAL '3 days',
    (SELECT id FROM tipoMovimientoCuenta WHERE nombre = 'Débito'),
    'Pago servicios públicos',
    (SELECT id FROM moneda WHERE iso = 'CRC'),
    -75000.00,
    'ICE',
    'Servicios',
    'En línea',
    'PAG-002'
);

-- María González – CRC
INSERT INTO movimientoCuenta (
    cuenta_id, fecha, tipo, descripcion, moneda, monto, comerciante, categoria, referencia
) VALUES 
(
    (SELECT id FROM cuenta WHERE iban = 'CR01B02000000006666'),
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
    (SELECT id FROM cuenta WHERE iban = 'CR01B02000000006666'),
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
-- 5. MOVIMIENTOS DE TARJETA
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
