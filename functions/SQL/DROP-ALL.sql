-- ====================================
-- SCRIPT PARA LIMPIAR COMPLETAMENTE LA BASE DE DATOS
-- Elimina TODAS las tablas y stored procedures
-- ====================================
-- Uso: Ejecutar en PostgreSQL antes de recrear el esquema
-- ====================================

-- ====================================
-- PASO 1: ELIMINAR TODAS LAS FUNCIONES (STORED PROCEDURES)
-- ====================================

DROP FUNCTION IF EXISTS sp_auth_user_get_by_username_or_email(VARCHAR) CASCADE;
DROP FUNCTION IF EXISTS sp_api_key_is_active(VARCHAR) CASCADE;
DROP FUNCTION IF EXISTS sp_otp_create(UUID, VARCHAR, INTEGER, VARCHAR) CASCADE;
DROP FUNCTION IF EXISTS sp_otp_consume(UUID, VARCHAR, VARCHAR) CASCADE;
DROP FUNCTION IF EXISTS sp_users_create(UUID, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, UUID, DATE) CASCADE;
DROP FUNCTION IF EXISTS sp_users_get_by_identification(VARCHAR) CASCADE;
DROP FUNCTION IF EXISTS sp_users_get_by_id(UUID) CASCADE;
DROP FUNCTION IF EXISTS sp_users_update(UUID, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, UUID) CASCADE;
DROP FUNCTION IF EXISTS sp_users_delete(UUID) CASCADE;
DROP FUNCTION IF EXISTS sp_users_change_password(UUID, VARCHAR) CASCADE;
DROP FUNCTION IF EXISTS sp_accounts_create(UUID, VARCHAR, VARCHAR, UUID, UUID, DECIMAL) CASCADE;
DROP FUNCTION IF EXISTS sp_accounts_get(UUID, UUID) CASCADE;
DROP FUNCTION IF EXISTS sp_accounts_set_status(UUID, UUID) CASCADE;
DROP FUNCTION IF EXISTS sp_account_movements_list(UUID, DATE, DATE, UUID, VARCHAR, INTEGER, INTEGER) CASCADE;

-- sp_cards_create: Firma correcta de sp-ane.sql (12 parámetros)
-- p_usuario_id, p_tipo, p_numero_enmascarado, p_fecha_expiracion, p_cvv_encriptado, 
-- p_pin_encriptado, p_moneda, p_limite_credito, p_saldo_actual, p_compania, p_categoria, p_tasa_interes
DROP FUNCTION IF EXISTS sp_cards_create(UUID, UUID, VARCHAR(50), VARCHAR(5), VARCHAR(255), VARCHAR(255), UUID, DECIMAL(18,2), DECIMAL(18,2), VARCHAR(50), VARCHAR(50), DECIMAL(5,2)) CASCADE;

-- Eliminar también posibles versiones viejas con firmas diferentes
DROP FUNCTION IF EXISTS sp_cards_create(UUID, UUID, VARCHAR, VARCHAR, VARCHAR, VARCHAR, UUID, DECIMAL, DECIMAL, VARCHAR, VARCHAR, DECIMAL) CASCADE;
DROP FUNCTION IF EXISTS sp_cards_create(UUID, UUID, VARCHAR, VARCHAR, VARCHAR, VARCHAR, UUID, VARCHAR, DECIMAL, DECIMAL, UUID, VARCHAR) CASCADE;

DROP FUNCTION IF EXISTS sp_cards_get(UUID, UUID) CASCADE;
DROP FUNCTION IF EXISTS sp_cards_update_status(UUID, VARCHAR) CASCADE;
DROP FUNCTION IF EXISTS sp_card_movements_list(UUID, DATE, DATE, UUID, VARCHAR, INTEGER, INTEGER) CASCADE;

-- sp_card_movement_add: Firma correcta de sp-ane.sql (8 parámetros)
-- p_card_id, p_fecha, p_tipo, p_descripcion, p_moneda, p_monto, p_comerciante, p_ubicacion
DROP FUNCTION IF EXISTS sp_card_movement_add(UUID, TIMESTAMP, UUID, TEXT, UUID, DECIMAL(18,2), VARCHAR(100), VARCHAR(100)) CASCADE;

-- Eliminar también posibles versiones viejas
DROP FUNCTION IF EXISTS sp_card_movement_add(UUID, TIMESTAMP, UUID, TEXT, UUID, DECIMAL, VARCHAR, VARCHAR) CASCADE;
DROP FUNCTION IF EXISTS sp_card_movement_add(UUID, DATE, UUID, TEXT, UUID, DECIMAL, VARCHAR, VARCHAR, VARCHAR) CASCADE;

DROP FUNCTION IF EXISTS sp_transfer_create_internal(UUID, UUID, DECIMAL, TEXT, UUID) CASCADE;
DROP FUNCTION IF EXISTS sp_bank_validate_account(VARCHAR) CASCADE;
DROP FUNCTION IF EXISTS sp_audit_log(VARCHAR, VARCHAR, UUID, UUID, JSONB) CASCADE;
DROP FUNCTION IF EXISTS sp_audit_list_by_user(UUID) CASCADE;

-- ====================================
-- PASO 2: ELIMINAR TODAS LAS TABLAS
-- ====================================

-- Primero las tablas con foreign keys (orden inverso al de creación)
DROP TABLE IF EXISTS Auditoria CASCADE;
DROP TABLE IF EXISTS movimientoTarjeta CASCADE;
DROP TABLE IF EXISTS movimientoCuenta CASCADE;
DROP TABLE IF EXISTS transferencia CASCADE;  -- Por si existe de versión vieja
DROP TABLE IF EXISTS destinatarioFrecuente CASCADE;  -- Por si existe de versión vieja
DROP TABLE IF EXISTS tarjeta CASCADE;
DROP TABLE IF EXISTS cuenta CASCADE;
DROP TABLE IF EXISTS Otps CASCADE;
DROP TABLE IF EXISTS usuario CASCADE;
DROP TABLE IF EXISTS apiKey CASCADE;

-- Tablas catálogo
DROP TABLE IF EXISTS tipoMovimientoTarjeta CASCADE;
DROP TABLE IF EXISTS tipoMovimientoCuenta CASCADE;
DROP TABLE IF EXISTS estadoCuenta CASCADE;
DROP TABLE IF EXISTS tipoTarjeta CASCADE;
DROP TABLE IF EXISTS tipoCuenta CASCADE;
DROP TABLE IF EXISTS moneda CASCADE;
DROP TABLE IF EXISTS banco CASCADE;  -- Por si existe de versión vieja
DROP TABLE IF EXISTS tipoIdentificacion CASCADE;
DROP TABLE IF EXISTS rol CASCADE;

-- ====================================
-- PASO 3: LIMPIEZA AGRESIVA (por si quedó algo)
-- ====================================

-- Eliminar TODAS las funciones que empiecen con sp_ (método seguro)
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN 
        SELECT routine_name, routine_schema
        FROM information_schema.routines
        WHERE routine_schema = 'public' 
          AND routine_type = 'FUNCTION'
          AND routine_name LIKE 'sp_%'
    LOOP
        EXECUTE 'DROP FUNCTION IF EXISTS ' || quote_ident(r.routine_schema) || '.' || quote_ident(r.routine_name) || ' CASCADE';
        RAISE NOTICE 'Eliminada función: %', r.routine_name;
    END LOOP;
END $$;

-- ====================================
-- PASO 4: ELIMINAR EXTENSIONES (si se crearon)
-- ====================================

-- No eliminar uuid-ossp porque viene por defecto en PostgreSQL moderno
-- DROP EXTENSION IF EXISTS "uuid-ossp" CASCADE;

-- ====================================
-- PASO 5: VERIFICACIÓN
-- ====================================

-- Listar todas las tablas restantes (debería estar vacío)
SELECT tablename FROM pg_tables WHERE schemaname = 'public';

-- Listar todas las funciones restantes (debería estar vacío)
SELECT routine_name FROM information_schema.routines WHERE routine_schema = 'public' AND routine_type = 'FUNCTION';

