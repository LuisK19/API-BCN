-- ============================================
-- PASO 1: Crear tabla para logs de eventos WebSocket
-- ============================================
CREATE TABLE IF NOT EXISTS ws_eventos (
    evento_id SERIAL PRIMARY KEY,
    transfer_id UUID NOT NULL,
    evento_tipo VARCHAR(50) NOT NULL,
    evento_data JSONB,
    fecha_evento TIMESTAMP DEFAULT NOW(),
    banco_origen VARCHAR(10),
    banco_destino VARCHAR(10),
    estado VARCHAR(20),
    notas TEXT
);

-- Índices para ws_eventos
CREATE INDEX IF NOT EXISTS idx_ws_eventos_transfer ON ws_eventos(transfer_id);
CREATE INDEX IF NOT EXISTS idx_ws_eventos_tipo ON ws_eventos(evento_tipo);
CREATE INDEX IF NOT EXISTS idx_ws_eventos_fecha ON ws_eventos(fecha_evento DESC);

COMMENT ON TABLE ws_eventos IS 'Registro de todos los eventos WebSocket para auditoría de transferencias interbancarias';

-- ============================================
-- PASO 2: Crear tabla para reservas temporales de fondos
-- ============================================
CREATE TABLE IF NOT EXISTS transferencia_reserva (
    reserva_id SERIAL PRIMARY KEY,
    transfer_id_ws UUID NOT NULL UNIQUE,
    cuenta_id UUID NOT NULL REFERENCES cuenta(id),
    monto DECIMAL(18,2) NOT NULL,
    fecha_reserva TIMESTAMP DEFAULT NOW(),
    fecha_expiracion TIMESTAMP,
    estado VARCHAR(20) DEFAULT 'active',
    descripcion TEXT,
    cuenta_destino_iban VARCHAR(50),
    CONSTRAINT fk_reserva_cuenta FOREIGN KEY (cuenta_id) REFERENCES cuenta(id)
);

-- Índices para reservas
CREATE INDEX IF NOT EXISTS idx_reserva_transfer ON transferencia_reserva(transfer_id_ws);
CREATE INDEX IF NOT EXISTS idx_reserva_cuenta ON transferencia_reserva(cuenta_id);
CREATE INDEX IF NOT EXISTS idx_reserva_estado ON transferencia_reserva(estado);

COMMENT ON TABLE transferencia_reserva IS 'Reservas temporales de fondos durante transferencias interbancarias';

-- ============================================
-- PASO 3: Crear tabla para transferencias interbancarias
-- ============================================
-- Esta tabla vincula los movimientos interbancarios
CREATE TABLE IF NOT EXISTS transferencia_interbancaria (
    id SERIAL PRIMARY KEY,
    transfer_id_ws UUID NOT NULL UNIQUE,
    cuenta_origen_id UUID NOT NULL REFERENCES cuenta(id),
    cuenta_destino_iban VARCHAR(50) NOT NULL,
    monto DECIMAL(18,2) NOT NULL,
    moneda UUID NOT NULL REFERENCES moneda(id),
    descripcion TEXT,
    estado VARCHAR(20) DEFAULT 'pending',
    tipo VARCHAR(30) DEFAULT 'interbancaria',
    fecha_inicio TIMESTAMP DEFAULT NOW(),
    fecha_completado TIMESTAMP,
    banco_origen VARCHAR(10),
    banco_destino VARCHAR(10),
    movimiento_debito_id UUID REFERENCES movimientoCuenta(id),
    movimiento_credito_id UUID,
    notas TEXT
);

-- Índices para transferencia_interbancaria
CREATE INDEX IF NOT EXISTS idx_transfer_ws_id ON transferencia_interbancaria(transfer_id_ws);
CREATE INDEX IF NOT EXISTS idx_transfer_estado ON transferencia_interbancaria(estado);
CREATE INDEX IF NOT EXISTS idx_transfer_cuenta_origen ON transferencia_interbancaria(cuenta_origen_id);
CREATE INDEX IF NOT EXISTS idx_transfer_fecha ON transferencia_interbancaria(fecha_inicio DESC);

COMMENT ON TABLE transferencia_interbancaria IS 'Registro de transferencias interbancarias via WebSocket';
COMMENT ON COLUMN transferencia_interbancaria.estado IS 'Estado: pending, reserved, completed, failed, reversed';
COMMENT ON COLUMN transferencia_interbancaria.tipo IS 'Tipo: interbancaria';
COMMENT ON COLUMN transferencia_interbancaria.transfer_id_ws IS 'ID único de la transferencia en el sistema WebSocket';

-- ============================================
-- PASO 4: Función para limpiar reservas expiradas
-- ============================================
CREATE OR REPLACE FUNCTION limpiar_reservas_expiradas()
RETURNS INTEGER AS $$
DECLARE
    contador INTEGER;
BEGIN
    -- Marcar como expiradas las reservas con más de 5 minutos
    UPDATE transferencia_reserva
    SET estado = 'expired'
    WHERE estado = 'active'
    AND fecha_reserva < NOW() - INTERVAL '5 minutes';
    
    GET DIAGNOSTICS contador = ROW_COUNT;
    RETURN contador;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- PASO 5: Función para registrar evento WebSocket
-- ============================================
CREATE OR REPLACE FUNCTION registrar_evento_ws(
    p_transfer_id UUID,
    p_evento_tipo VARCHAR(50),
    p_evento_data JSONB,
    p_banco_origen VARCHAR(10),
    p_banco_destino VARCHAR(10),
    p_estado VARCHAR(20),
    p_notas TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_evento_id INTEGER;
BEGIN
    INSERT INTO ws_eventos (
        transfer_id,
        evento_tipo,
        evento_data,
        banco_origen,
        banco_destino,
        estado,
        notas
    )
    VALUES (
        p_transfer_id,
        p_evento_tipo,
        p_evento_data,
        p_banco_origen,
        p_banco_destino,
        p_estado,
        p_notas
    )
    RETURNING evento_id INTO v_evento_id;
    
    RETURN v_evento_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- PASO 6: Verificar estructura creada
-- ============================================
DO $$
DECLARE
    v_ws_eventos_exists BOOLEAN;
    v_reserva_exists BOOLEAN;
    v_transfer_exists BOOLEAN;
BEGIN
    -- Verificar tabla ws_eventos
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'ws_eventos'
    ) INTO v_ws_eventos_exists;
    
    -- Verificar tabla transferencia_reserva
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'transferencia_reserva'
    ) INTO v_reserva_exists;
    
    -- Verificar tabla transferencia_interbancaria
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'transferencia_interbancaria'
    ) INTO v_transfer_exists;
    
    RAISE NOTICE '============================================';
    RAISE NOTICE 'VERIFICACIÓN DE INSTALACIÓN';
    RAISE NOTICE '============================================';
    
    IF v_ws_eventos_exists THEN
        RAISE NOTICE 'Tabla ws_eventos creada correctamente';
    ELSE
        RAISE WARNING 'ERROR: Tabla ws_eventos NO existe';
    END IF;
    
    IF v_reserva_exists THEN
        RAISE NOTICE 'Tabla transferencia_reserva creada correctamente';
    ELSE
        RAISE WARNING 'ERROR: Tabla transferencia_reserva NO existe';
    END IF;
    
    IF v_transfer_exists THEN
        RAISE NOTICE 'Tabla transferencia_interbancaria creada correctamente';
    ELSE
        RAISE WARNING 'ERROR: Tabla transferencia_interbancaria NO existe';
    END IF;
    
    RAISE NOTICE '============================================';
    RAISE NOTICE 'INSTALACIÓN COMPLETADA';
    RAISE NOTICE '============================================';
END $$;

-- ============================================
-- PASO 7: Información de tablas creadas
-- ============================================
SELECT 
    'ws_eventos' as tabla,
    COUNT(*) as registros_actuales
FROM ws_eventos;

SELECT 
    'transferencia_reserva' as tabla,
    COUNT(*) as reservas_activas
FROM transferencia_reserva
WHERE estado = 'active';

SELECT 
    'transferencia_interbancaria' as tabla,
    COUNT(*) as transferencias_totales
FROM transferencia_interbancaria;

