-- Habilitar UUID
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Tablas de catálogo/configuración

-- Tabla: rol
-- Descripción: 
--  Contiene la información de los roles definidos 
--  en el sistema, los cuales determinan los 
--  permisos y el nivel de acceso de los usuarios.
CREATE TABLE rol (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nombre VARCHAR(50) NOT NULL UNIQUE,
    descripcion TEXT,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabla: tipoIdentificacion
-- Descripción:
--  Almacena los diferentes tipos de identificación 
--  que pueden asociarse a un usuario o entidad del sistema
CREATE TABLE tipoIdentificacion (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nombre VARCHAR(50) NOT NULL UNIQUE,
    descripcion TEXT,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabla: tipoCuenta
-- Descripción:
--  Contiene los distintos tipos de cuentas que 
--  puede manejar el sistema financiero o bancario,
--  como cuenta corriente, cuenta de ahorros.
CREATE TABLE tipoCuenta (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nombre VARCHAR(50) NOT NULL UNIQUE,
    descripcion TEXT,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabla: moneda
-- Descripción:
--  Almacena las diferentes monedas que pueden 
--  ser utilizadas en las transacciones del sistema.
CREATE TABLE moneda (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nombre VARCHAR(50) NOT NULL UNIQUE,
    iso VARCHAR(3) NOT NULL UNIQUE,
    simbolo VARCHAR(5),
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabla: estadoCuenta
-- Descripción:
--  Define los posibles estados en los que
--  una cuenta puede encontrarse, como activa,
--  bloqueada o cerrada.
CREATE TABLE estadoCuenta (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nombre VARCHAR(50) NOT NULL UNIQUE,
    descripcion TEXT,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabla: tipoMovimientoCuenta
-- Descripción:
--  Contiene los diferentes tipos de movimientos
--  que se pueden registrar en una cuenta,
--  como depósitos, retiros o transferencias.
CREATE TABLE tipoMovimientoCuenta (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nombre VARCHAR(50) NOT NULL UNIQUE,
    descripcion TEXT,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabla: tipoTarjeta
-- Descripción:
--  Almacena los distintos tipos de tarjetas
--  que el sistema puede manejar, tarjetas de credito.
CREATE TABLE tipoTarjeta (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nombre VARCHAR(50) NOT NULL UNIQUE,
    descripcion TEXT,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabla: tipoMovimientoTarjeta
-- Descripción:
--  Define los tipos de movimientos que se pueden
--  realizar con las tarjetas, como compras o pagos.
CREATE TABLE tipoMovimientoTarjeta (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nombre VARCHAR(50) NOT NULL UNIQUE,
    descripcion TEXT,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tablas principales del sistema
--Tabla: usuario
-- Descripción:
--  Almacena la información de los usuarios del sistema,
--  incluyendo datos personales, credenciales de acceso
CREATE TABLE usuario (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tipo_identificacion UUID NOT NULL REFERENCES tipoIdentificacion(id),
    identificacion VARCHAR(50) UNIQUE NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    primer_apellido VARCHAR(100) NOT NULL,
    segundo_apellido VARCHAR(100),
    correo VARCHAR(255) UNIQUE NOT NULL,
    telefono VARCHAR(20),
    usuario VARCHAR(50) UNIQUE NOT NULL,
    contrasena_hash VARCHAR(255) NOT NULL,
    rol UUID REFERENCES rol(id),
    fecha_nacimiento DATE,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ultimo_login TIMESTAMP,
    estado VARCHAR(20) DEFAULT 'active'
);

-- Tabla: cuenta
-- Descripción:
--  Contiene la información de las cuentas bancarias
--  asociadas a los usuarios, incluyendo detalles como
--  el tipo de cuenta, moneda, saldo y estado.
CREATE TABLE cuenta (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    usuario_id UUID NOT NULL REFERENCES usuario(id),
    iban VARCHAR(50) UNIQUE NOT NULL,
    alias VARCHAR(100),
    tipoCuenta UUID NOT NULL REFERENCES tipoCuenta(id),
    moneda UUID NOT NULL REFERENCES moneda(id),
    saldo DECIMAL(18,2) DEFAULT 0.00,
    estado UUID NOT NULL REFERENCES estadoCuenta(id),
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabla: movimientoCuenta
-- Descripción:
--  Registra los movimientos realizados en las cuentas,
--  incluyendo depósitos, retiros y transferencias,
--  junto con detalles adicionales como comerciante y categoría.
CREATE TABLE movimientoCuenta (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    cuenta_id UUID NOT NULL REFERENCES cuenta(id),
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    tipo UUID NOT NULL REFERENCES tipoMovimientoCuenta(id),
    descripcion TEXT,
    moneda UUID NOT NULL REFERENCES moneda(id),
    monto DECIMAL(18,2) NOT NULL,

    -- Información adicional
    comerciante VARCHAR(100),
    categoria VARCHAR(50),
    ubicacion VARCHAR(100),
    referencia VARCHAR(100)
);

-- Tabla: tarjeta
-- Descripción:
--  Almacena la información de las tarjetas
--  asociadas a las cuentas de los usuarios,
--  incluyendo detalles como tipo de tarjeta,
--  límite de crédito, saldo y datos de seguridad.
CREATE TABLE tarjeta (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    usuario_id UUID NOT NULL REFERENCES usuario(id),
    tipo UUID NOT NULL REFERENCES tipoTarjeta(id),
    numero_enmascarado VARCHAR(50) NOT NULL, -- Formato: 1234 **** **** 5678

    titular VARCHAR(100),


    fecha_expiracion VARCHAR(5) NOT NULL,
    cvv_hash VARCHAR(255) NOT NULL,
    pin_hash VARCHAR(255) NOT NULL,
    moneda UUID NOT NULL REFERENCES moneda(id),

    limite_credito DECIMAL(18,2) NOT NULL,
    saldo_actual DECIMAL(18,2) DEFAULT 0.00,

    -- info adicional 
    tasa_interes DECIMAL(5,2),
    fecha_corte VARCHAR(50),
    fecha_pago VARCHAR(50),

    -- Campos comunes
    compania VARCHAR(50),
    categoria VARCHAR(50),
    estado VARCHAR(20) DEFAULT 'Activa',

    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabla: movimientoTarjeta
-- Descripción:
--  Registra los movimientos realizados con las tarjetas,
--  como compras y pagos, junto con detalles adicionales
--  como comerciante y ubicación.
CREATE TABLE movimientoTarjeta (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tarjeta_id UUID NOT NULL REFERENCES tarjeta(id),
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    tipo UUID NOT NULL REFERENCES tipoMovimientoTarjeta(id),
    descripcion TEXT,
    moneda UUID NOT NULL REFERENCES moneda(id),
    monto DECIMAL(18,2) NOT NULL,

    -- Información adicional
    comerciante VARCHAR(100),
    ubicacion VARCHAR(100),
    referencia VARCHAR(100)
);

-- Tablas de seguridad y autenticación
-- Tabla: Otps
-- Descripción:
--  Almacena los códigos OTP generados para
--  diversas operaciones de seguridad, como
--  restablecimiento de contraseña o verificación de transacciones.
CREATE TABLE Otps (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    usuario_id UUID NOT NULL REFERENCES usuario(id),
    codigo_hash VARCHAR(255) NOT NULL, -- Para SHA-256 (64 caracteres)
    proposito VARCHAR(50) CHECK (proposito IN ('password_reset', 'card_details')),
    fecha_expiracion TIMESTAMP NOT NULL,
    fecha_consumido TIMESTAMP NULL,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabla: apiKey
-- Descripción:
--  Contiene las claves API generadas para
--  permitir el acceso programático al sistema,
--  junto con su estado y metadatos asociados.
CREATE TABLE apiKey (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    clave_hash VARCHAR(255) NOT NULL, -- Para SHA-256 (64 caracteres)
    etiqueta VARCHAR(100),
    activa BOOLEAN DEFAULT true,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabla opcional para puntos extras
-- Tabla: Auditoria
-- Descripción:
--  Registra las acciones importantes realizadas
--  en el sistema para fines de auditoría y seguimiento.
CREATE TABLE Auditoria (
    id SERIAL PRIMARY KEY,
    usuario_id UUID NOT NULL REFERENCES usuario(id),
    accion VARCHAR(100) NOT NULL,
    detalles JSONB,
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabla: destinatarioFrecuente
-- Descripción:
--  Almacena la información de los destinatarios
--  frecuentes a los que los usuarios realizan
--  transferencias, facilitando el proceso de envío de dinero.
CREATE TABLE destinatarioFrecuente (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    usuario_id UUID REFERENCES usuario(id),
    nombre VARCHAR(100) NOT NULL,
    numero_cuenta VARCHAR(50) NOT NULL,
    banco UUID REFERENCES banco(id),
    alias VARCHAR(100),
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- Insertar datos básicos en las tablas de catálogo
INSERT INTO rol (nombre, descripcion) VALUES 
('admin', 'Administrador del sistema con acceso completo'),
('cliente', 'Usuario cliente con acceso limitado a sus datos');

INSERT INTO tipoIdentificacion (nombre, descripcion) VALUES 
('Nacional', 'Cédula nacional'),
('DIMEX', 'Documento de identidad migratorio para extranjeros'),
('Pasaporte', 'Pasaporte internacional');

INSERT INTO tipoCuenta (nombre, descripcion) VALUES 
('Ahorros', 'Cuenta de ahorros'),
('Corriente', 'Cuenta corriente');

INSERT INTO moneda (nombre, iso) VALUES 
('Colones', 'CRC'),
('Dólares', 'USD');

INSERT INTO estadoCuenta (nombre, descripcion) VALUES 
('Activa', 'Cuenta activa y operativa'),
('Bloqueada', 'Cuenta temporalmente bloqueada'),
('Cerrada', 'Cuenta cerrada permanentemente');

INSERT INTO tipoMovimientoCuenta (nombre, descripcion) VALUES 
('Crédito', 'Movimiento de ingreso de fondos'),
('Débito', 'Movimiento de retiro de fondos');

INSERT INTO tipoTarjeta (nombre, descripcion) VALUES 
('Débito', 'Tarjeta de débito asociada a cuenta'),
('Crédito', 'Tarjeta de crédito con límite asignado');

INSERT INTO tipoMovimientoTarjeta (nombre, descripcion) VALUES 
('Compra', 'Compra realizada con tarjeta'),
('Pago', 'Pago realizado a la tarjeta');