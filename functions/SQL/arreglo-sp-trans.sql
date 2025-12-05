-- ============================================================================
-- PASO 1: Eliminar el SP antiguo
-- ============================================================================
DROP FUNCTION IF EXISTS sp_transfer_create_internal(UUID, UUID, DECIMAL, TEXT, UUID);

-- ============================================================================
-- PASO 2: Crear el SP corregido
-- ============================================================================
CREATE FUNCTION sp_transfer_create_internal(
    p_from_account_id UUID,
    p_to_account_id UUID,
    p_amount DECIMAL(18,2),
    p_descripcion TEXT,
    p_user_id UUID
)
RETURNS TABLE (
    transfer_id VARCHAR(100),
    receipt_number VARCHAR(100),
    status VARCHAR(20),
    success BOOLEAN,
    message VARCHAR(100)
) 
LANGUAGE plpgsql
AS $$
DECLARE
    v_receipt_number VARCHAR(100);
    v_from_account_currency UUID;
    v_to_account_currency UUID;
    v_from_account_balance DECIMAL(18,2);
    v_from_account_owner UUID;
    v_tipo_debito UUID;
    v_tipo_credito UUID;
    v_movement_debito_id UUID;
    v_movement_credito_id UUID;
    v_user_role VARCHAR(50);
BEGIN
    -- Obtener rol del usuario
    SELECT r.nombre INTO v_user_role
    FROM usuario u
    INNER JOIN rol r ON u.rol = r.id
    WHERE u.id = p_user_id;

    -- Obtener datos de cuenta origen
    SELECT moneda, saldo, usuario_id 
    INTO v_from_account_currency, v_from_account_balance, v_from_account_owner
    FROM cuenta 
    WHERE id = p_from_account_id;

    -- Obtener datos de cuenta destino
    SELECT moneda INTO v_to_account_currency
    FROM cuenta
    WHERE id = p_to_account_id;

    -- Validación: cuentas existen
    IF v_from_account_currency IS NULL OR v_to_account_currency IS NULL THEN
        RETURN QUERY SELECT NULL::VARCHAR, NULL::VARCHAR, 'error'::VARCHAR, FALSE, 
            CAST('Una o ambas cuentas no existen' AS VARCHAR(100));
        RETURN;
    END IF;

    -- Validación: misma moneda
    IF v_from_account_currency != v_to_account_currency THEN
        RETURN QUERY SELECT NULL::VARCHAR, NULL::VARCHAR, 'error'::VARCHAR, FALSE, 
            CAST('Las cuentas deben tener la misma moneda' AS VARCHAR(100));
        RETURN;
    END IF;

    -- Validación: saldo suficiente
    IF v_from_account_balance < p_amount THEN
        RETURN QUERY SELECT NULL::VARCHAR, NULL::VARCHAR, 'error'::VARCHAR, FALSE, 
            CAST('Saldo insuficiente' AS VARCHAR(100));
        RETURN;
    END IF;

    -- Validación: propiedad de cuenta (excepto admin)
    IF v_user_role != 'admin' AND v_from_account_owner != p_user_id THEN
        RETURN QUERY SELECT NULL::VARCHAR, NULL::VARCHAR, 'error'::VARCHAR, FALSE, 
            CAST('La cuenta origen no pertenece al usuario' AS VARCHAR(100));
        RETURN;
    END IF;

    -- Generar número de recibo
    v_receipt_number := 'TRF-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || 
                        LPAD(EXTRACT(EPOCH FROM NOW())::BIGINT::TEXT, 10, '0');

    -- Obtener IDs de tipos de movimiento
    SELECT id INTO v_tipo_debito FROM tipoMovimientoCuenta WHERE nombre = 'Débito';
    SELECT id INTO v_tipo_credito FROM tipoMovimientoCuenta WHERE nombre = 'Crédito';

    -- Verificar que los tipos existan
    IF v_tipo_debito IS NULL OR v_tipo_credito IS NULL THEN
        RETURN QUERY SELECT NULL::VARCHAR, NULL::VARCHAR, 'error'::VARCHAR, FALSE, 
            CAST('Error: Tipos de movimiento no encontrados en la BD' AS VARCHAR(100));
        RETURN;
    END IF;

    -- Insertar movimiento DÉBITO (cuenta origen)
    INSERT INTO movimientoCuenta (
        cuenta_id, fecha, tipo, descripcion, moneda, monto, referencia
    )
    VALUES (
        p_from_account_id, 
        NOW(), 
        v_tipo_debito, 
        'Transferencia enviada: ' || p_descripcion, 
        v_from_account_currency, 
        p_amount, 
        v_receipt_number
    )
    RETURNING id INTO v_movement_debito_id;

    -- Actualizar saldo cuenta origen
    UPDATE cuenta 
    SET saldo = saldo - p_amount, fecha_actualizacion = NOW()
    WHERE id = p_from_account_id;

    -- Insertar movimiento CRÉDITO (cuenta destino)
    INSERT INTO movimientoCuenta (
        cuenta_id, fecha, tipo, descripcion, moneda, monto, referencia
    )
    VALUES (
        p_to_account_id, 
        NOW(), 
        v_tipo_credito, 
        'Transferencia recibida: ' || p_descripcion,
        v_to_account_currency, 
        p_amount, 
        v_receipt_number
    )
    RETURNING id INTO v_movement_credito_id;

    -- Actualizar saldo cuenta destino
    UPDATE cuenta 
    SET saldo = saldo + p_amount, fecha_actualizacion = NOW()
    WHERE id = p_to_account_id;

    -- Retornar éxito
    RETURN QUERY SELECT 
        v_receipt_number::VARCHAR, 
        v_receipt_number::VARCHAR, 
        'completed'::VARCHAR, 
        TRUE, 
        CAST('Transferencia completada exitosamente' AS VARCHAR(100));

EXCEPTION
    WHEN OTHERS THEN
        RETURN QUERY SELECT 
            NULL::VARCHAR, 
            NULL::VARCHAR, 
            'error'::VARCHAR, 
            FALSE, 
            CAST('Error: ' || SQLERRM AS VARCHAR(100));
END;
$$;

-- ============================================================================
-- PASO 3: Verificar que se creó correctamente
-- ============================================================================
SELECT 'SP creado exitosamente' AS resultado;

-- Verificar que los tipos de movimiento existen
SELECT id, nombre FROM tipoMovimientoCuenta WHERE nombre IN ('Débito', 'Crédito');
