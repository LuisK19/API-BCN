<<<<<<< HEAD
-- ====================================
-- STORED PROCEDURES PARA CREATE-ANE.SQL
-- Base de datos simplificada segun anexos
-- ====================================

-- 1. SP para login - obtener usuario por username o email
CREATE OR REPLACE FUNCTION sp_auth_user_get_by_username_or_email(
    p_username_or_email VARCHAR
)
RETURNS TABLE (
    user_id UUID,
    contrasena_hash VARCHAR(255),
    rol_nombre VARCHAR(50),
    usuario VARCHAR(50),
    correo VARCHAR(255),
    estado VARCHAR(20),
    nombre_completo TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id, 
        u.contrasena_hash, 
        r.nombre as rol_nombre,
        u.usuario,
        u.correo,
        u.estado,
        u.nombre || ' ' || u.primer_apellido || COALESCE(' ' || u.segundo_apellido, '') as nombre_completo
    FROM usuario u
    INNER JOIN rol r ON u.rol = r.id
    WHERE u.usuario = p_username_or_email OR u.correo = p_username_or_email;
END;
$$ LANGUAGE plpgsql;

-- 2. SP para verificar API Key
CREATE OR REPLACE FUNCTION sp_api_key_is_active(
    p_api_key_hash VARCHAR(255)
)
RETURNS TABLE (
    is_active BOOLEAN,
    key_id UUID,
    etiqueta VARCHAR(100)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        activa as is_active,
        id as key_id,
        apiKey.etiqueta
    FROM apiKey
    WHERE clave_hash = p_api_key_hash;
END;
$$ LANGUAGE plpgsql;

-- 3. SP para crear OTP
CREATE OR REPLACE FUNCTION sp_otp_create(
    p_user_id UUID,
    p_proposito VARCHAR(50),
    p_expires_in_seconds INTEGER,
    p_codigo_hash VARCHAR(255)
)
RETURNS UUID AS $$
DECLARE
    v_otp_id UUID;
BEGIN
    -- Comentarios/Contrato:
    -- Entrada:
    --  - p_user_id: UUID del usuario propietario del OTP
    --  - p_proposito: proposito/uso del OTP (p. ej. 'login', 'password_reset')
    --  - p_expires_in_seconds: tiempo de expiracion en segundos
    --  - p_codigo_hash: hash del codigo OTP (no almacenar OTP en claro)
    -- Salida:
    --  - UUID del registro creado en la tabla Otps
    INSERT INTO Otps (usuario_id, codigo_hash, proposito, fecha_expiracion)
    VALUES (
        p_user_id, 
        p_codigo_hash, 
        p_proposito, 
        NOW() + (p_expires_in_seconds || ' seconds')::INTERVAL
    )
    RETURNING id INTO v_otp_id;

    RETURN v_otp_id;
END;
$$ LANGUAGE plpgsql;

-- 4. SP para consumir OTP
CREATE OR REPLACE FUNCTION sp_otp_consume(
    p_user_id UUID,
    p_proposito VARCHAR(50),
    p_codigo_hash VARCHAR(255)
)
RETURNS TABLE (
    is_valid BOOLEAN,
    otp_id UUID
) AS $$
DECLARE
    v_otp_record Otps%ROWTYPE;
BEGIN
    -- Buscar el OTP no consumido y valido
    -- Nota: SELECT INTO fallara si devuelve mas de una fila. Se asume que existe una restriccion
    --       que impide multiples OTPs identicos vigentes para el mismo usuario y proposito.
    -- Recomendacion: si la tabla puede contener multiples filas, usar "LIMIT 1" o asegurar UNIQUE contraints.
    SELECT * INTO v_otp_record
    FROM Otps
    WHERE usuario_id = p_user_id
        AND proposito = p_proposito
        AND codigo_hash = p_codigo_hash
        AND fecha_consumido IS NULL
        AND fecha_expiracion > NOW();

    IF v_otp_record.id IS NULL THEN
        RETURN QUERY SELECT FALSE, NULL::UUID;
    ELSE
        -- Marcar como consumido
        UPDATE Otps
        SET fecha_consumido = NOW()
        WHERE id = v_otp_record.id;

        RETURN QUERY SELECT TRUE, v_otp_record.id;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- 5. SP para crear usuario
CREATE OR REPLACE FUNCTION sp_users_create(
    p_tipo_identificacion UUID,
    p_identificacion VARCHAR(50),
    p_nombre VARCHAR(100),
    p_primer_apellido VARCHAR(100),
    p_segundo_apellido VARCHAR(100),
    p_correo VARCHAR(255),
    p_telefono VARCHAR(20),
    p_usuario VARCHAR(50),
    p_contrasena_hash VARCHAR(255),
    p_rol UUID,
    p_fecha_nacimiento DATE DEFAULT NULL
)
RETURNS TABLE (
    user_id UUID,
    success BOOLEAN,
    message VARCHAR(100)
) AS $$
DECLARE
    v_user_id UUID;
BEGIN
    -- Contrato:
    --  - Entrada: varios datos personales y credenciales ya validados/formateados por la capa aplicativa.
    --  - Salida: user_id (UUID) o NULL y success boolean + message explicativo.
    -- Notas importantes:
    --  - Esta funcion verifica unicidad en las columnas identificacion, correo y usuario mediante EXISTS.
    --  - Se recomienda tambien tener UNIQUE constraints a nivel de esquema para evitar race conditions.
    --  - La funcion no valida formato de correo, telefono o fuerza de contraseña; debe realizarse antes de llamar.
    -- Verificar unicidad
    IF EXISTS (SELECT 1 FROM usuario WHERE identificacion = p_identificacion) THEN
        RETURN QUERY SELECT NULL::UUID, FALSE, CAST('La identificacion ya existe' AS VARCHAR(100));
        RETURN;
    END IF;

    IF EXISTS (SELECT 1 FROM usuario WHERE correo = p_correo) THEN
        RETURN QUERY SELECT NULL::UUID, FALSE, CAST('El correo ya existe' AS VARCHAR(100));
        RETURN;
    END IF;

    IF EXISTS (SELECT 1 FROM usuario WHERE usuario = p_usuario) THEN
        RETURN QUERY SELECT NULL::UUID, FALSE, CAST('El usuario ya existe' AS VARCHAR(100));
        RETURN;
    END IF;

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
        fecha_nacimiento
    )
    VALUES (
        p_tipo_identificacion,
        p_identificacion,
        p_nombre,
        p_primer_apellido,
        p_segundo_apellido,
        p_correo,
        p_telefono,
        p_usuario,
        p_contrasena_hash,
        p_rol,
        p_fecha_nacimiento
    )
    RETURNING id INTO v_user_id;

    RETURN QUERY SELECT v_user_id, TRUE, CAST('Usuario creado exitosamente' AS VARCHAR(100));
END;
$$ LANGUAGE plpgsql;
--DROP FUNCTION IF EXISTS sp_transfer_create_internal(UUID, UUID, DECIMAL, TEXT, UUID) CASCADE;

--DROP FUNCTION IF EXISTS sp_users_get_by_identification(VARCHAR) CASCADE;
-- 6. SP para obtener usuario por identificacion
CREATE OR REPLACE FUNCTION sp_users_get_by_identification(
    p_identificacion VARCHAR(50)
)
RETURNS TABLE (
    id UUID,
    nombre VARCHAR(100),
    primer_apellido VARCHAR(100),
    segundo_apellido VARCHAR(100),
    correo VARCHAR(255),
    telefono VARCHAR(20),
    usuario VARCHAR(50),
    rol_nombre VARCHAR(50),
    fecha_creacion TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id,
        u.nombre,
        u.primer_apellido,
        u.segundo_apellido,
        u.correo,
        u.telefono,
        u.usuario,
        r.nombre as rol_nombre,
        u.fecha_creacion
    FROM usuario u
    INNER JOIN rol r ON u.rol = r.id
    WHERE u.identificacion = p_identificacion;
END;
$$ LANGUAGE plpgsql;

-- 7. SP para actualizar usuario
CREATE OR REPLACE FUNCTION sp_users_update(
    p_user_id UUID,
    p_nombre VARCHAR(100) DEFAULT NULL,
    p_primer_apellido VARCHAR(100) DEFAULT NULL,
    p_segundo_apellido VARCHAR(100) DEFAULT NULL,
    p_correo VARCHAR(255) DEFAULT NULL,
    p_telefono VARCHAR(20) DEFAULT NULL,
    p_usuario VARCHAR(50) DEFAULT NULL,
    p_rol UUID DEFAULT NULL
)
RETURNS TABLE (
    success BOOLEAN,
    message VARCHAR(100)
) AS $$
BEGIN
    -- Validar unicidad si se esta actualizando correo
    IF p_correo IS NOT NULL AND EXISTS (
        SELECT 1 FROM usuario WHERE correo = p_correo AND id != p_user_id
    ) THEN
        RETURN QUERY SELECT FALSE, CAST('El correo ya esta en uso por otro usuario' AS VARCHAR(100));
        RETURN;
    END IF;

    -- Validar unicidad si se esta actualizando usuario
    IF p_usuario IS NOT NULL AND EXISTS (
        SELECT 1 FROM usuario WHERE usuario = p_usuario AND id != p_user_id
    ) THEN
        RETURN QUERY SELECT FALSE, CAST('El nombre de usuario ya esta en uso por otro usuario' AS VARCHAR(100));
        RETURN;
    END IF;

    UPDATE usuario
    SET 
        nombre = COALESCE(p_nombre, nombre),
        primer_apellido = COALESCE(p_primer_apellido, primer_apellido),
        segundo_apellido = COALESCE(p_segundo_apellido, segundo_apellido),
        correo = COALESCE(p_correo, correo),
        telefono = COALESCE(p_telefono, telefono),
        usuario = COALESCE(p_usuario, usuario),
        rol = COALESCE(p_rol, rol),
        fecha_actualizacion = NOW()
    WHERE id = p_user_id;

    IF FOUND THEN
        RETURN QUERY SELECT TRUE, CAST('Usuario actualizado exitosamente' AS VARCHAR(100));
    ELSE
        RETURN QUERY SELECT FALSE, CAST('Usuario no encontrado' AS VARCHAR(100));
    END IF;
END;
$$ LANGUAGE plpgsql;

-- 8. SP para eliminar usuario
CREATE OR REPLACE FUNCTION sp_users_delete(
    p_user_id UUID
)
RETURNS TABLE (
    success BOOLEAN,
    message VARCHAR(100)
) AS $$
DECLARE
    v_user_exists BOOLEAN;
BEGIN
    -- Verificar que el usuario existe
    SELECT EXISTS(SELECT 1 FROM usuario WHERE id = p_user_id) INTO v_user_exists;
    
    IF NOT v_user_exists THEN
        RETURN QUERY SELECT FALSE, CAST('Usuario no encontrado' AS VARCHAR(100));
        RETURN;
    END IF;

    -- Eliminar en cascada (sin tablas transferencia ni destinatarioFrecuente)
    DELETE FROM movimientoCuenta WHERE cuenta_id IN (SELECT id FROM cuenta WHERE usuario_id = p_user_id);
    DELETE FROM movimientoTarjeta WHERE tarjeta_id IN (SELECT id FROM tarjeta WHERE usuario_id = p_user_id);
    DELETE FROM Otps WHERE usuario_id = p_user_id;
    DELETE FROM cuenta WHERE usuario_id = p_user_id;
    DELETE FROM tarjeta WHERE usuario_id = p_user_id;
    DELETE FROM Auditoria WHERE usuario_id = p_user_id;
    DELETE FROM usuario WHERE id = p_user_id;

    RETURN QUERY SELECT TRUE, CAST('Usuario y todos sus registros eliminados exitosamente' AS VARCHAR(100));
END;
$$ LANGUAGE plpgsql;

-- 9. SP para crear cuenta 
CREATE OR REPLACE FUNCTION sp_accounts_create(
    p_usuario_id UUID,
    p_iban VARCHAR(50),
    p_alias VARCHAR(100),
    p_tipo UUID,
    p_moneda UUID,
    p_saldo_inicial DECIMAL(18,2)
)
RETURNS TABLE (
    account_id UUID,
    success BOOLEAN,
    message VARCHAR(100)
) AS $$
DECLARE
    v_account_id UUID;
    v_estado_activo UUID;
BEGIN
    -- Obtener el ID del estado "Activa"
    SELECT id INTO v_estado_activo FROM estadoCuenta WHERE nombre = 'Activa';
    
    IF v_estado_activo IS NULL THEN
        RETURN QUERY SELECT NULL::UUID, FALSE, CAST('Estado de cuenta activa no encontrado' AS VARCHAR(100));
        RETURN;
    END IF;

    -- Verificar que el IBAN sea unico
    IF EXISTS (SELECT 1 FROM cuenta WHERE iban = p_iban) THEN
        RETURN QUERY SELECT NULL::UUID, FALSE, CAST('El IBAN ya existe' AS VARCHAR(100));
        RETURN;
    END IF;

    INSERT INTO cuenta (
        usuario_id,
        iban,
        alias,
        tipoCuenta,
        moneda,
        saldo,
        estado
    )
    VALUES (
        p_usuario_id,
        p_iban,
        p_alias,
        p_tipo,
        p_moneda,
        p_saldo_inicial,
        v_estado_activo
    )
    RETURNING id INTO v_account_id;

    RETURN QUERY SELECT v_account_id, TRUE, CAST('Cuenta creada exitosamente' AS VARCHAR(100));
END;
$$ LANGUAGE plpgsql;

-- 10. SP para obtener cuentas 
CREATE OR REPLACE FUNCTION sp_accounts_get(
    p_owner_id UUID DEFAULT NULL,
    p_account_id UUID DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    usuario_id UUID,
    iban VARCHAR(50),
    alias VARCHAR(100),
    tipo_cuenta_nombre VARCHAR(50),
    moneda_iso VARCHAR(3),
    moneda_nombre VARCHAR(50),
    saldo DECIMAL(18,2),
    estado_nombre VARCHAR(50),
    fecha_creacion TIMESTAMP
) AS $$
BEGIN

    RETURN QUERY
    SELECT 
        c.id,
        c.usuario_id,
        c.iban,
        c.alias,
        tc.nombre as tipo_cuenta_nombre,
        m.iso as moneda_iso,
        m.nombre as moneda_nombre,
        c.saldo,
        ec.nombre as estado_nombre,
        c.fecha_creacion
    FROM cuenta c
    INNER JOIN tipoCuenta tc ON c.tipoCuenta = tc.id
    INNER JOIN moneda m ON c.moneda = m.id
    INNER JOIN estadoCuenta ec ON c.estado = ec.id
    WHERE 
        (p_owner_id IS NOT NULL AND c.usuario_id = p_owner_id) OR
        (p_account_id IS NOT NULL AND c.id = p_account_id);
END;
$$ LANGUAGE plpgsql;

-- 11. SP para cambiar estado de cuenta
CREATE OR REPLACE FUNCTION sp_accounts_set_status(
    p_account_id UUID,
    p_nuevo_estado UUID
)
RETURNS TABLE (
    success BOOLEAN,
    message VARCHAR(100)
) AS $$
DECLARE
    v_current_balance DECIMAL(18,2);
    v_new_status_name VARCHAR(50);
BEGIN
    -- Obtener saldo actual y nombre del nuevo estado
    SELECT saldo INTO v_current_balance FROM cuenta WHERE id = p_account_id;
    SELECT nombre INTO v_new_status_name FROM estadoCuenta WHERE id = p_nuevo_estado;

    -- Validar que la cuenta existe
    IF v_current_balance IS NULL THEN
        RETURN QUERY SELECT FALSE, CAST('Cuenta no encontrada' AS VARCHAR(100));
        RETURN;
    END IF;

    -- Validar reglas de negocio
    IF v_new_status_name = 'Cerrada' AND v_current_balance != 0 THEN
        RETURN QUERY SELECT FALSE, CAST('No se puede cerrar una cuenta con saldo diferente de cero' AS VARCHAR(100));
        RETURN;
    END IF;

    IF v_new_status_name = 'Bloqueada' AND v_current_balance < 0 THEN
        RETURN QUERY SELECT FALSE, CAST('No se puede bloquear una cuenta con saldo negativo' AS VARCHAR(100));
        RETURN;
    END IF;

    UPDATE cuenta
    SET 
        estado = p_nuevo_estado,
        fecha_actualizacion = NOW()
    WHERE id = p_account_id;

    RETURN QUERY SELECT TRUE, CAST('Estado de cuenta actualizado exitosamente' AS VARCHAR(100));
END;
$$ LANGUAGE plpgsql;

-- 12. SP para listar movimientos de cuenta 
CREATE OR REPLACE FUNCTION sp_account_movements_list(
    p_account_id UUID,
    p_from_date DATE DEFAULT NULL,
    p_to_date DATE DEFAULT NULL,
    p_type UUID DEFAULT NULL,
    p_q VARCHAR DEFAULT NULL,
    p_page INTEGER DEFAULT 1,
    p_page_size INTEGER DEFAULT 10
)
RETURNS TABLE (
    items JSON,
    total INTEGER,
    page INTEGER,
    page_size INTEGER
) AS $$
DECLARE
    v_total INTEGER;
    v_items JSON;
BEGIN
    -- Contar el total de movimientos
    SELECT COUNT(*) INTO v_total
    FROM movimientoCuenta mc
    WHERE mc.cuenta_id = p_account_id
        AND (p_from_date IS NULL OR mc.fecha::DATE >= p_from_date)
        AND (p_to_date IS NULL OR mc.fecha::DATE <= p_to_date)
        AND (p_type IS NULL OR mc.tipo = p_type)
        AND (p_q IS NULL OR mc.descripcion ILIKE '%' || p_q || '%' OR mc.comerciante ILIKE '%' || p_q || '%');

    -- Obtener los movimientos paginados como JSON
    SELECT json_agg(
        json_build_object(
            'id', movimiento_data.id,
            'fecha', movimiento_data.fecha,
            'tipo', movimiento_data.tipo_nombre,
            'descripcion', movimiento_data.descripcion,
            'moneda', movimiento_data.moneda_iso,
            'monto', movimiento_data.monto,
            'comerciante', movimiento_data.comerciante,
            'categoria', movimiento_data.categoria,
            'ubicacion', movimiento_data.ubicacion,
            'referencia', movimiento_data.referencia
        )
    ) INTO v_items
    FROM (
        SELECT 
            mc.id,
            mc.fecha,
            tmc.nombre as tipo_nombre,
            mc.descripcion,
            m.iso as moneda_iso,
            mc.monto,
            mc.comerciante,
            mc.categoria,
            mc.ubicacion,
            mc.referencia
        FROM movimientoCuenta mc
        INNER JOIN tipoMovimientoCuenta tmc ON mc.tipo = tmc.id
        INNER JOIN moneda m ON mc.moneda = m.id
        WHERE mc.cuenta_id = p_account_id
            AND (p_from_date IS NULL OR mc.fecha::DATE >= p_from_date)
            AND (p_to_date IS NULL OR mc.fecha::DATE <= p_to_date)
            AND (p_type IS NULL OR mc.tipo = p_type)
            AND (p_q IS NULL OR mc.descripcion ILIKE '%' || p_q || '%' OR mc.comerciante ILIKE '%' || p_q || '%')
        ORDER BY mc.fecha DESC
        LIMIT p_page_size
        OFFSET (p_page - 1) * p_page_size
    ) AS movimiento_data;

    -- Devolver los resultados
    RETURN QUERY SELECT v_items, v_total, p_page, p_page_size;
END;
$$ LANGUAGE plpgsql;

-- 13. SP para crear tarjeta 
CREATE OR REPLACE FUNCTION sp_cards_create(
    p_usuario_id UUID,
    p_tipo UUID,
    p_numero_enmascarado VARCHAR(50),
    p_fecha_expiracion VARCHAR(5),
    p_cvv_encriptado VARCHAR(255),
    p_pin_encriptado VARCHAR(255),
    p_moneda UUID,
    p_limite_credito DECIMAL(18,2),
    p_saldo_actual DECIMAL(18,2) DEFAULT 0,
    p_compania VARCHAR(50) DEFAULT 'VISA',
    p_categoria VARCHAR(50) DEFAULT NULL,  -- categoria para CSS (gold, platinum, black, blue, saprisa)
    p_tasa_interes DECIMAL(5,2) DEFAULT 18.50
)
RETURNS TABLE (
    card_id UUID,
    success BOOLEAN,
    message VARCHAR(100)
) AS $$
DECLARE
    v_card_id UUID;
    v_tipo_tarjeta_nombre VARCHAR(50);
    v_nombre_completo VARCHAR(300);
    v_categoria VARCHAR(50);
BEGIN
    -- Contrato y notas:
    --  - Entrada: datos de tarjeta donde los datos sensibles (CVV, PIN) deben llegar en forma encriptada/hashed.
    --  - Salida: card_id o NULL, success boolean y message.
    --  - Importante: las columnas `fecha_corte` y `fecha_pago` se insertan aqui como textos descriptivos
    --    ('25 de cada mes', '10 del mes siguiente'). Si en el esquema de la BD esas columnas son de tipo DATE/TIMESTAMP
    --    esto provocara error. 
    -- Obtener el nombre del tipo de tarjeta
    SELECT nombre INTO v_tipo_tarjeta_nombre FROM tipoTarjeta WHERE id = p_tipo;
    
    IF v_tipo_tarjeta_nombre IS NULL THEN
        RETURN QUERY SELECT NULL::UUID, FALSE, CAST('Tipo de tarjeta no encontrado' AS VARCHAR(100));
        RETURN;
    END IF;

    -- NO se valida el tipo especifico porque la tabla tipoTarjeta en anezos tiene los valores de tipoCuenta

    -- Obtener nombre completo del usuario
    SELECT nombre || ' ' || primer_apellido || COALESCE(' ' || segundo_apellido, '')
    INTO v_nombre_completo
    FROM usuario WHERE id = p_usuario_id;
    
    IF v_nombre_completo IS NULL THEN
        RETURN QUERY SELECT NULL::UUID, FALSE, CAST('Usuario no encontrado' AS VARCHAR(100));
        RETURN;
    END IF;

    -- Validar limite de credito
    IF p_limite_credito IS NULL OR p_limite_credito <= 0 THEN
        RETURN QUERY SELECT NULL::UUID, FALSE, CAST('El limite de credito debe ser mayor a cero' AS VARCHAR(100));
        RETURN;
    END IF;

    -- Validar compañia de tarjeta 
    IF LOWER(p_compania) NOT IN ('alipay', 'amex', 'diners', 'discover', 'elo', 'generic', 
                                 'hiper', 'hipercard', 'jcb', 'maestro', 'mastercard', 'mir', 
                                 'paypal', 'unionpay', 'visa') THEN
        RETURN QUERY SELECT NULL::UUID, FALSE, CAST('Compañia de tarjeta no valida. Compañias soportadas: visa, mastercard, amex, diners, discover, jcb, maestro, unionpay, paypal, alipay, mir, elo, hiper, hipercard, generic' AS VARCHAR(100));
        RETURN;
    END IF;

    -- Usar categoria del parametro o asignar 'blue' por defecto
    -- No se valida la categoria para permitir flexibilidad en el frontend
    IF p_categoria IS NOT NULL THEN
        v_categoria := LOWER(p_categoria);  -- Normalizar a minusculas
    ELSE
        v_categoria := 'blue';  -- Categoria por defecto
    END IF;

    -- Insertar la tarjeta
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
    )
    VALUES (
        p_usuario_id,
        p_tipo,
        p_numero_enmascarado,
        v_nombre_completo,
        p_fecha_expiracion,
        p_cvv_encriptado,
        p_pin_encriptado,
        p_moneda,
        p_limite_credito,
        COALESCE(p_saldo_actual, 0),
        p_tasa_interes,
        '25 de cada mes',
        '10 del mes siguiente',
        UPPER(p_compania),
        v_categoria,
        'Activa'
    )
    RETURNING id INTO v_card_id;

    RETURN QUERY SELECT v_card_id, TRUE, CAST('Tarjeta creada exitosamente' AS VARCHAR(100));
END;
$$ LANGUAGE plpgsql;

-- 14. SP para obtener tarjetas 
CREATE OR REPLACE FUNCTION sp_cards_get(
    p_owner_id UUID DEFAULT NULL,
    p_card_id UUID DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    usuario_id UUID,
    tipo_tarjeta_nombre VARCHAR(50),
    numero_enmascarado VARCHAR(50),
    titular VARCHAR(100),
    fecha_expiracion VARCHAR(5),
    moneda_iso VARCHAR(3),
    moneda_nombre VARCHAR(50),
    limite_credito DECIMAL(18,2),
    saldo_actual DECIMAL(18,2),
    tasa_interes DECIMAL(5,2),
    fecha_corte VARCHAR(50),
    fecha_pago VARCHAR(50),
    compania VARCHAR(50),
    categoria VARCHAR(50),
    estado VARCHAR(20),
    fecha_creacion TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.id,
        t.usuario_id,
        tt.nombre as tipo_tarjeta_nombre,
        t.numero_enmascarado,
        t.titular,
        t.fecha_expiracion,
        m.iso as moneda_iso,
        m.nombre as moneda_nombre,
        t.limite_credito,
        t.saldo_actual,
        t.tasa_interes,
        t.fecha_corte,
        t.fecha_pago,
        t.compania,
        t.categoria,
        t.estado,
        t.fecha_creacion
    FROM tarjeta t
    INNER JOIN tipoTarjeta tt ON t.tipo = tt.id
    INNER JOIN moneda m ON t.moneda = m.id
    WHERE 
        (p_owner_id IS NOT NULL AND t.usuario_id = p_owner_id) OR
        (p_card_id IS NOT NULL AND t.id = p_card_id);
END;
$$ LANGUAGE plpgsql;

-- 15. SP para listar movimientos de tarjeta (SOLO CReDITO)
CREATE OR REPLACE FUNCTION sp_card_movements_list(
    p_card_id UUID,
    p_from_date DATE DEFAULT NULL,
    p_to_date DATE DEFAULT NULL,
    p_type UUID DEFAULT NULL,
    p_q VARCHAR DEFAULT NULL,
    p_page INTEGER DEFAULT 1,
    p_page_size INTEGER DEFAULT 10
)
RETURNS TABLE (
    items JSON,
    total INTEGER,
    page INTEGER,
    page_size INTEGER
) AS $$
DECLARE
    v_total INTEGER;
    v_items JSON;
BEGIN
    -- Notas:
    --  - Paginacion basica con LIMIT/OFFSET. Para sets muy grandes considerar cursores o keyset pagination.
    --  - Los filtros p_from_date/p_to_date/p_type/p_q aplican solo si no son NULL.
    --  - El campo `items` es un JSON agregado; si no hay filas devuelve NULL. El consumidor debe manejar NULL vs []
    -- Contar el total de movimientos
    SELECT COUNT(*) INTO v_total
    FROM movimientoTarjeta mt
    WHERE mt.tarjeta_id = p_card_id
        AND (p_from_date IS NULL OR mt.fecha::DATE >= p_from_date)
        AND (p_to_date IS NULL OR mt.fecha::DATE <= p_to_date)
        AND (p_type IS NULL OR mt.tipo = p_type)
        AND (p_q IS NULL OR mt.descripcion ILIKE '%' || p_q || '%' OR mt.comerciante ILIKE '%' || p_q || '%');

    -- Obtener los movimientos paginados como JSON
    SELECT json_agg(
        json_build_object(
            'id', movimiento_data.id,
            'fecha', movimiento_data.fecha,
            'tipo', movimiento_data.tipo_nombre,
            'descripcion', movimiento_data.descripcion,
            'moneda', movimiento_data.moneda_iso,
            'monto', movimiento_data.monto,
            'comerciante', movimiento_data.comerciante,
            'ubicacion', movimiento_data.ubicacion,
            'referencia', movimiento_data.referencia
        )
    ) INTO v_items
    FROM (
        SELECT 
            mt.id,
            mt.fecha,
            tmt.nombre as tipo_nombre,
            mt.descripcion,
            m.iso as moneda_iso,
            mt.monto,
            mt.comerciante,
            mt.ubicacion,
            mt.referencia
        FROM movimientoTarjeta mt
        INNER JOIN tipoMovimientoTarjeta tmt ON mt.tipo = tmt.id
        INNER JOIN moneda m ON mt.moneda = m.id
        WHERE mt.tarjeta_id = p_card_id
            AND (p_from_date IS NULL OR mt.fecha::DATE >= p_from_date)
            AND (p_to_date IS NULL OR mt.fecha::DATE <= p_to_date)
            AND (p_type IS NULL OR mt.tipo = p_type)
            AND (p_q IS NULL OR mt.descripcion ILIKE '%' || p_q || '%' OR mt.comerciante ILIKE '%' || p_q || '%')
        ORDER BY mt.fecha DESC
        LIMIT p_page_size
        OFFSET (p_page - 1) * p_page_size
    ) AS movimiento_data;

    -- Devolver resultados
    RETURN QUERY SELECT v_items, v_total, p_page, p_page_size;
END;
$$ LANGUAGE plpgsql;

-- 16. SP para agregar movimiento de tarjeta (SOLO CReDITO)
CREATE OR REPLACE FUNCTION sp_card_movement_add(
    p_card_id UUID,
    p_fecha TIMESTAMP,
    p_tipo UUID,
    p_descripcion TEXT,
    p_moneda UUID,
    p_monto DECIMAL(18,2),
    p_comerciante VARCHAR(100) DEFAULT NULL,
    p_ubicacion VARCHAR(100) DEFAULT NULL
)
RETURNS TABLE (
    movement_id UUID,
    nuevo_saldo DECIMAL(18,2),
    success BOOLEAN,
    message VARCHAR(100)
) AS $$
DECLARE
    v_movement_id UUID;
    v_saldo_actual DECIMAL(18,2);
    v_nuevo_saldo DECIMAL(18,2);
    v_limite_credito DECIMAL(18,2);
    v_tipo_movimiento VARCHAR(50);
BEGIN
    -- Obtener informacion de la tarjeta
    -- Nota: si la tarjeta no existe, v_saldo_actual quedara NULL y se maneja abajo.
    SELECT t.saldo_actual, t.limite_credito
    INTO v_saldo_actual, v_limite_credito
    FROM tarjeta t
    WHERE t.id = p_card_id
    LIMIT 1;

    IF v_saldo_actual IS NULL THEN
        RETURN QUERY SELECT NULL::UUID, NULL::DECIMAL, FALSE, CAST('Tarjeta no encontrada' AS VARCHAR(100));
        RETURN;
    END IF;

    -- Obtener tipo de movimiento (Compra o Pago)
    SELECT nombre INTO v_tipo_movimiento FROM tipoMovimientoTarjeta WHERE id = p_tipo;

    IF v_tipo_movimiento = 'Compra' THEN
        -- COMPRA: aumenta saldo (deuda)
        v_nuevo_saldo := v_saldo_actual + p_monto;
        
        -- Validar que no exceda el limite de credito
        IF v_nuevo_saldo > v_limite_credito THEN
            RETURN QUERY SELECT NULL::UUID, v_saldo_actual, FALSE, CAST('Compra excede el limite de credito disponible' AS VARCHAR(100));
            RETURN;
        END IF;

    ELSIF v_tipo_movimiento = 'Pago' THEN
        -- PAGO: disminuye saldo (abono)
        v_nuevo_saldo := v_saldo_actual - p_monto;
        
        -- No permitir pagos mayores al saldo
        IF v_nuevo_saldo < 0 THEN
            RETURN QUERY SELECT NULL::UUID, v_saldo_actual, FALSE, CAST('El pago excede el saldo actual de la tarjeta' AS VARCHAR(100));
            RETURN;
        END IF;

    ELSE
        RETURN QUERY SELECT NULL::UUID, v_saldo_actual, FALSE, CAST('Tipo de movimiento no valido' AS VARCHAR(100));
        RETURN;
    END IF;

    -- Insertar movimiento
    INSERT INTO movimientoTarjeta (
        tarjeta_id,
        fecha,
        tipo,
        descripcion,
        moneda,
        monto,
        comerciante,
        ubicacion
    )
    VALUES (
        p_card_id,
        p_fecha,
        p_tipo,
        p_descripcion,
        p_moneda,
        p_monto,
        p_comerciante,
        p_ubicacion
    )
    RETURNING id INTO v_movement_id;

    -- Actualizar saldo de la tarjeta
    UPDATE tarjeta
    SET 
        saldo_actual = v_nuevo_saldo,
        fecha_actualizacion = NOW()
    WHERE id = p_card_id;

    RETURN QUERY SELECT v_movement_id, v_nuevo_saldo, TRUE, CAST('Movimiento registrado exitosamente' AS VARCHAR(100));
END;
$$ LANGUAGE plpgsql;

-- 17. SP para transferencia interna (SIN TABLA TRANSFERENCIA)
-- Registra 2 movimientos en movimientoCuenta vinculados por referencia
CREATE OR REPLACE FUNCTION sp_transfer_create_internal(
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
) AS $$
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
BEGIN
    -- Obtener el rol del usuario que ejecuta la transferencia
    SELECT r.nombre INTO v_user_role
    FROM usuario u
    INNER JOIN rol r ON u.rol = r.id
    WHERE u.id = p_user_id;
    -- Contrato y notas importantes sobre atomicidad:
    --  - La funcion crea dos movimientos en `movimientoCuenta` y actualiza saldos en `cuenta`.
    --  - Es critico que ambas actualizaciones sean atomicas. En PL/pgSQL una funcion se ejecuta en la transaccion
    --    del caller; si el caller no maneja la transaccion, un error aqui deberia revertir los cambios.
    -- Verificar que las cuentas existan y obtener sus datos
    SELECT moneda, saldo, usuario_id 
    INTO v_from_account_currency, v_from_account_balance, v_from_account_owner
    FROM cuenta 
    WHERE id = p_from_account_id;

    SELECT moneda INTO v_to_account_currency
    FROM cuenta
    WHERE id = p_to_account_id;

    -- Validaciones
    IF v_from_account_currency IS NULL OR v_to_account_currency IS NULL THEN
        RETURN QUERY SELECT NULL::VARCHAR, NULL::VARCHAR, 'error'::VARCHAR, FALSE, CAST('Una o ambas cuentas no existen' AS VARCHAR(100));
        RETURN;
    END IF;

    IF v_from_account_currency != v_to_account_currency THEN
        RETURN QUERY SELECT NULL::VARCHAR, NULL::VARCHAR, 'error'::VARCHAR, FALSE, CAST('Las cuentas deben tener la misma moneda' AS VARCHAR(100));
        RETURN;
    END IF;

    IF v_from_account_balance < p_amount THEN
        RETURN QUERY SELECT NULL::VARCHAR, NULL::VARCHAR, 'error'::VARCHAR, FALSE, CAST('Saldo insuficiente' AS VARCHAR(100));
        RETURN;
    END IF;

    -- Validar propiedad de cuenta SOLO si el usuario NO es admin
    IF v_user_role != 'admin' AND v_from_account_owner != p_user_id THEN
        RETURN QUERY SELECT NULL::VARCHAR, NULL::VARCHAR, 'error'::VARCHAR, FALSE, CAST('La cuenta origen no pertenece al usuario' AS VARCHAR(100));
        RETURN;
    END IF;

    -- Generar numero de recibo unico
    v_receipt_number := 'TRF-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(EXTRACT(EPOCH FROM NOW())::BIGINT::TEXT, 10, '0');

    -- Obtener IDs de tipos de movimiento
    SELECT id INTO v_tipo_debito FROM tipoMovimientoCuenta WHERE nombre = 'Debito';
    SELECT id INTO v_tipo_credito FROM tipoMovimientoCuenta WHERE nombre = 'Credito';

    -- Iniciar transaccion: Crear movimiento DeBITO en cuenta origen
    INSERT INTO movimientoCuenta (
        cuenta_id,
        fecha,
        tipo,
        descripcion,
        moneda,
        monto,
        referencia
    )
    VALUES (
        p_from_account_id,
        NOW(),
        v_tipo_debito,
        'Transferencia enviada: ' || p_descripcion,
        v_from_account_currency,
        -p_amount,  -- Negativo porque sale dinero
        v_receipt_number
    )
    RETURNING id INTO v_movement_debito_id;

    -- Actualizar saldo de cuenta origen
    UPDATE cuenta
    SET 
        saldo = saldo - p_amount,
        fecha_actualizacion = NOW()
    WHERE id = p_from_account_id;

    -- Crear movimiento CReDITO en cuenta destino
    INSERT INTO movimientoCuenta (
        cuenta_id,
        fecha,
        tipo,
        descripcion,
        moneda,
        monto,
        referencia
    )
    VALUES (
        p_to_account_id,
        NOW(),
        v_tipo_credito,
        'Transferencia recibida: ' || p_descripcion,
        v_to_account_currency,
        p_amount,  -- Positivo porque entra dinero
        v_receipt_number
    )
    RETURNING id INTO v_movement_credito_id;

    -- Actualizar saldo de cuenta destino
    UPDATE cuenta
    SET 
        saldo = saldo + p_amount,
        fecha_actualizacion = NOW()
    WHERE id = p_to_account_id;

    RETURN QUERY SELECT 
        v_receipt_number::VARCHAR, 
        v_receipt_number::VARCHAR, 
        'completed'::VARCHAR, 
        TRUE, 
        CAST('Transferencia completada exitosamente' AS VARCHAR(100));
EXCEPTION
    WHEN OTHERS THEN
        RETURN QUERY SELECT NULL::VARCHAR, NULL::VARCHAR, 'error'::VARCHAR, FALSE, CAST('Error al procesar la transferencia' AS VARCHAR(100));
END;
$$ LANGUAGE plpgsql;

-- 18. SP para validar cuenta bancaria 
CREATE OR REPLACE FUNCTION sp_bank_validate_account(
    p_iban VARCHAR(50)
)
RETURNS TABLE (
    account_exists BOOLEAN,
    owner_name VARCHAR(200),
    owner_id UUID,
    account_id UUID,
    currency_iso VARCHAR(3)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        TRUE as account_exists,
        (u.nombre || ' ' || u.primer_apellido || COALESCE(' ' || u.segundo_apellido, ''))::VARCHAR(200) as owner_name,
        u.id as owner_id,
        c.id as account_id,
        m.iso as currency_iso
    FROM cuenta c
    INNER JOIN usuario u ON c.usuario_id = u.id
    INNER JOIN moneda m ON c.moneda = m.id
    INNER JOIN estadoCuenta ec ON c.estado = ec.id
    WHERE c.iban = p_iban
        AND ec.nombre = 'Activa';
    
    -- Si no se encontro ninguna cuenta activa
    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, NULL::VARCHAR, NULL::UUID, NULL::UUID, NULL::VARCHAR;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- 19. SP para auditoria (puntos extras)
CREATE OR REPLACE FUNCTION sp_audit_log(
    p_accion VARCHAR(100),
    p_entidad VARCHAR(100),
    p_actor_user_id UUID DEFAULT NULL,
    p_entidad_id UUID DEFAULT NULL,
    p_detalles JSONB DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
    v_audit_id INTEGER;
BEGIN
    INSERT INTO Auditoria (usuario_id, accion, detalles)
    VALUES (
        p_actor_user_id,
        p_accion || ' - ' || p_entidad || COALESCE(' [' || p_entidad_id::TEXT || ']', ''),
        p_detalles
    )
    RETURNING id INTO v_audit_id;

    RETURN v_audit_id;
END;
$$ LANGUAGE plpgsql;

-- 20. SP para listar auditoria por usuario
CREATE OR REPLACE FUNCTION sp_audit_list_by_user(
    p_user_id UUID
)
RETURNS TABLE (
    id INTEGER,
    accion VARCHAR(100),
    detalles JSONB,
    fecha TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.id,
        a.accion,
        a.detalles,
        a.fecha
    FROM Auditoria a
    WHERE a.usuario_id = p_user_id
    ORDER BY a.fecha DESC;
END;
$$ LANGUAGE plpgsql;

-- 21. SP extra: obtener usuario por ID
CREATE OR REPLACE FUNCTION sp_users_get_by_id(
    p_user_id UUID
)
RETURNS TABLE (
    id UUID,
    nombre VARCHAR(100),
    primer_apellido VARCHAR(100),
    segundo_apellido VARCHAR(100),
    correo VARCHAR(255),
    telefono VARCHAR(20),
    usuario VARCHAR(50),
    rol_nombre VARCHAR(50),
    identificacion VARCHAR(50),
    tipo_identificacion_nombre VARCHAR(50),
    fecha_nacimiento DATE,
    fecha_creacion TIMESTAMP,
    estado VARCHAR(20)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id,
        u.nombre,
        u.primer_apellido,
        u.segundo_apellido,
        u.correo,
        u.telefono,
        u.usuario,
        r.nombre as rol_nombre,
        u.identificacion,
        ti.nombre as tipo_identificacion_nombre,
        u.fecha_nacimiento,
        u.fecha_creacion,
        u.estado
    FROM usuario u
    INNER JOIN rol r ON u.rol = r.id
    INNER JOIN tipoIdentificacion ti ON u.tipo_identificacion = ti.id
    WHERE u.id = p_user_id;
END;
$$ LANGUAGE plpgsql;

-- 22. SP extra: cambiar contraseña de usuario
CREATE OR REPLACE FUNCTION sp_users_change_password(
    p_user_id UUID,
    p_nuevo_contrasena_hash VARCHAR(255)
)
RETURNS TABLE (
    success BOOLEAN,
    message VARCHAR(100)
) AS $$
BEGIN
    UPDATE usuario
    SET 
        contrasena_hash = p_nuevo_contrasena_hash,
        fecha_actualizacion = NOW()
    WHERE id = p_user_id;

    IF FOUND THEN
        RETURN QUERY SELECT TRUE, CAST('Contraseña actualizada exitosamente' AS VARCHAR(100));
    ELSE
        RETURN QUERY SELECT FALSE, CAST('Usuario no encontrado' AS VARCHAR(100));
    END IF;
END;
$$ LANGUAGE plpgsql;

-- ====================================
-- FIN DE STORED PROCEDURES
-- Total: 22 SPs implementados
-- ====================================

-- NOTAS:
-- 1. Se elimino toda logica de tarjetas de debito
-- 2. Se elimino tabla transferencia (se usan 2 movimientos vinculados por referencia)
-- 3. Se elimino tabla banco (no esta en anexos)
-- 4. Se elimino tabla destinatarioFrecuente (no esta en anexos)
-- 5. Campos simplificados segun anexos estrictos
-- 6. movimientoCuenta ahora registra transferencias usando campo referencia
=======
-- ====================================
-- STORED PROCEDURES PARA CREATE-ANE.SQL
-- Base de datos simplificada según anexos
-- ====================================

-- 1. SP para login - obtener usuario por username o email
CREATE OR REPLACE FUNCTION sp_auth_user_get_by_username_or_email(
    p_username_or_email VARCHAR
)
RETURNS TABLE (
    user_id UUID,
    contrasena_hash VARCHAR(255),
    rol_nombre VARCHAR(50),
    usuario VARCHAR(50),
    correo VARCHAR(255),
    estado VARCHAR(20),
    nombre_completo TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id, 
        u.contrasena_hash, 
        r.nombre as rol_nombre,
        u.usuario,
        u.correo,
        u.estado,
        u.nombre || ' ' || u.primer_apellido || COALESCE(' ' || u.segundo_apellido, '') as nombre_completo
    FROM usuario u
    INNER JOIN rol r ON u.rol = r.id
    WHERE u.usuario = p_username_or_email OR u.correo = p_username_or_email;
END;
$$ LANGUAGE plpgsql;

-- 2. SP para verificar API Key
CREATE OR REPLACE FUNCTION sp_api_key_is_active(
    p_api_key_hash VARCHAR(255)
)
RETURNS TABLE (
    is_active BOOLEAN,
    key_id UUID,
    etiqueta VARCHAR(100)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        activa as is_active,
        id as key_id,
        apiKey.etiqueta
    FROM apiKey
    WHERE clave_hash = p_api_key_hash;
END;
$$ LANGUAGE plpgsql;

-- 3. SP para crear OTP
CREATE OR REPLACE FUNCTION sp_otp_create(
    p_user_id UUID,
    p_proposito VARCHAR(50),
    p_expires_in_seconds INTEGER,
    p_codigo_hash VARCHAR(255)
)
RETURNS UUID AS $$
DECLARE
    v_otp_id UUID;
BEGIN
    -- Comentarios/Contrato:
    -- Entrada:
    --  - p_user_id: UUID del usuario propietario del OTP
    --  - p_proposito: proposito/uso del OTP (p. ej. 'login', 'password_reset')
    --  - p_expires_in_seconds: tiempo de expiracion en segundos
    --  - p_codigo_hash: hash del codigo OTP (no almacenar OTP en claro)
    -- Salida:
    --  - UUID del registro creado en la tabla Otps
    INSERT INTO Otps (usuario_id, codigo_hash, proposito, fecha_expiracion)
    VALUES (
        p_user_id, 
        p_codigo_hash, 
        p_proposito, 
        NOW() + (p_expires_in_seconds || ' seconds')::INTERVAL
    )
    RETURNING id INTO v_otp_id;

    RETURN v_otp_id;
END;
$$ LANGUAGE plpgsql;

-- 4. SP para consumir OTP
CREATE OR REPLACE FUNCTION sp_otp_consume(
    p_user_id UUID,
    p_proposito VARCHAR(50),
    p_codigo_hash VARCHAR(255)
)
RETURNS TABLE (
    is_valid BOOLEAN,
    otp_id UUID
) AS $$
DECLARE
    v_otp_record Otps%ROWTYPE;
BEGIN
    -- Buscar el OTP no consumido y valido
    -- Nota: SELECT INTO fallara si devuelve mas de una fila. Se asume que existe una restriccion
    --       que impide múltiples OTPs identicos vigentes para el mismo usuario y proposito.
    -- Recomendacion: si la tabla puede contener múltiples filas, usar "LIMIT 1" o asegurar UNIQUE contraints.
    SELECT * INTO v_otp_record
    FROM Otps
    WHERE usuario_id = p_user_id
        AND proposito = p_proposito
        AND codigo_hash = p_codigo_hash
        AND fecha_consumido IS NULL
        AND fecha_expiracion > NOW();

    IF v_otp_record.id IS NULL THEN
        RETURN QUERY SELECT FALSE, NULL::UUID;
    ELSE
        -- Marcar como consumido
        UPDATE Otps
        SET fecha_consumido = NOW()
        WHERE id = v_otp_record.id;

        RETURN QUERY SELECT TRUE, v_otp_record.id;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- 5. SP para crear usuario
CREATE OR REPLACE FUNCTION sp_users_create(
    p_tipo_identificacion UUID,
    p_identificacion VARCHAR(50),
    p_nombre VARCHAR(100),
    p_primer_apellido VARCHAR(100),
    p_segundo_apellido VARCHAR(100),
    p_correo VARCHAR(255),
    p_telefono VARCHAR(20),
    p_usuario VARCHAR(50),
    p_contrasena_hash VARCHAR(255),
    p_rol UUID,
    p_fecha_nacimiento DATE DEFAULT NULL
)
RETURNS TABLE (
    user_id UUID,
    success BOOLEAN,
    message VARCHAR(100)
) AS $$
DECLARE
    v_user_id UUID;
BEGIN
    -- Contrato:
    --  - Entrada: varios datos personales y credenciales ya validados/formateados por la capa aplicativa.
    --  - Salida: user_id (UUID) o NULL y success boolean + message explicativo.
    -- Notas importantes:
    --  - Esta funcion verifica unicidad en las columnas identificacion, correo y usuario mediante EXISTS.
    --  - Se recomienda tambien tener UNIQUE constraints a nivel de esquema para evitar race conditions.
    --  - La funcion no valida formato de correo, telefono o fuerza de contraseña; debe realizarse antes de llamar.
    -- Verificar unicidad
    IF EXISTS (SELECT 1 FROM usuario WHERE identificacion = p_identificacion) THEN
        RETURN QUERY SELECT NULL::UUID, FALSE, CAST('La identificacion ya existe' AS VARCHAR(100));
        RETURN;
    END IF;

    IF EXISTS (SELECT 1 FROM usuario WHERE correo = p_correo) THEN
        RETURN QUERY SELECT NULL::UUID, FALSE, CAST('El correo ya existe' AS VARCHAR(100));
        RETURN;
    END IF;

    IF EXISTS (SELECT 1 FROM usuario WHERE usuario = p_usuario) THEN
        RETURN QUERY SELECT NULL::UUID, FALSE, CAST('El usuario ya existe' AS VARCHAR(100));
        RETURN;
    END IF;

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
        fecha_nacimiento
    )
    VALUES (
        p_tipo_identificacion,
        p_identificacion,
        p_nombre,
        p_primer_apellido,
        p_segundo_apellido,
        p_correo,
        p_telefono,
        p_usuario,
        p_contrasena_hash,
        p_rol,
        p_fecha_nacimiento
    )
    RETURNING id INTO v_user_id;

    RETURN QUERY SELECT v_user_id, TRUE, CAST('Usuario creado exitosamente' AS VARCHAR(100));
END;
$$ LANGUAGE plpgsql;
--DROP FUNCTION IF EXISTS sp_transfer_create_internal(UUID, UUID, DECIMAL, TEXT, UUID) CASCADE;

--DROP FUNCTION IF EXISTS sp_users_get_by_identification(VARCHAR) CASCADE;
-- 6. SP para obtener usuario por identificacion
CREATE OR REPLACE FUNCTION sp_users_get_by_identification(
    p_identificacion VARCHAR(50)
)
RETURNS TABLE (
    id UUID,
    nombre VARCHAR(100),
    primer_apellido VARCHAR(100),
    segundo_apellido VARCHAR(100),
    correo VARCHAR(255),
    telefono VARCHAR(20),
    usuario VARCHAR(50),
    rol_nombre VARCHAR(50),
    fecha_creacion TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id,
        u.nombre,
        u.primer_apellido,
        u.segundo_apellido,
        u.correo,
        u.telefono,
        u.usuario,
        r.nombre as rol_nombre,
        u.fecha_creacion
    FROM usuario u
    INNER JOIN rol r ON u.rol = r.id
    WHERE u.identificacion = p_identificacion;
END;
$$ LANGUAGE plpgsql;

-- 7. SP para actualizar usuario
CREATE OR REPLACE FUNCTION sp_users_update(
    p_user_id UUID,
    p_nombre VARCHAR(100) DEFAULT NULL,
    p_primer_apellido VARCHAR(100) DEFAULT NULL,
    p_segundo_apellido VARCHAR(100) DEFAULT NULL,
    p_correo VARCHAR(255) DEFAULT NULL,
    p_telefono VARCHAR(20) DEFAULT NULL,
    p_usuario VARCHAR(50) DEFAULT NULL,
    p_rol UUID DEFAULT NULL
)
RETURNS TABLE (
    success BOOLEAN,
    message VARCHAR(100)
) AS $$
BEGIN
    -- Validar unicidad si se esta actualizando correo
    IF p_correo IS NOT NULL AND EXISTS (
        SELECT 1 FROM usuario WHERE correo = p_correo AND id != p_user_id
    ) THEN
        RETURN QUERY SELECT FALSE, CAST('El correo ya esta en uso por otro usuario' AS VARCHAR(100));
        RETURN;
    END IF;

    -- Validar unicidad si se esta actualizando usuario
    IF p_usuario IS NOT NULL AND EXISTS (
        SELECT 1 FROM usuario WHERE usuario = p_usuario AND id != p_user_id
    ) THEN
        RETURN QUERY SELECT FALSE, CAST('El nombre de usuario ya esta en uso por otro usuario' AS VARCHAR(100));
        RETURN;
    END IF;

    UPDATE usuario
    SET 
        nombre = COALESCE(p_nombre, nombre),
        primer_apellido = COALESCE(p_primer_apellido, primer_apellido),
        segundo_apellido = COALESCE(p_segundo_apellido, segundo_apellido),
        correo = COALESCE(p_correo, correo),
        telefono = COALESCE(p_telefono, telefono),
        usuario = COALESCE(p_usuario, usuario),
        rol = COALESCE(p_rol, rol),
        fecha_actualizacion = NOW()
    WHERE id = p_user_id;

    IF FOUND THEN
        RETURN QUERY SELECT TRUE, CAST('Usuario actualizado exitosamente' AS VARCHAR(100));
    ELSE
        RETURN QUERY SELECT FALSE, CAST('Usuario no encontrado' AS VARCHAR(100));
    END IF;
END;
$$ LANGUAGE plpgsql;

-- 8. SP para eliminar usuario
CREATE OR REPLACE FUNCTION sp_users_delete(
    p_user_id UUID
)
RETURNS TABLE (
    success BOOLEAN,
    message VARCHAR(100)
) AS $$
DECLARE
    v_user_exists BOOLEAN;
BEGIN
    -- Verificar que el usuario existe
    SELECT EXISTS(SELECT 1 FROM usuario WHERE id = p_user_id) INTO v_user_exists;
    
    IF NOT v_user_exists THEN
        RETURN QUERY SELECT FALSE, CAST('Usuario no encontrado' AS VARCHAR(100));
        RETURN;
    END IF;

    -- Eliminar en cascada (sin tablas transferencia ni destinatarioFrecuente)
    DELETE FROM movimientoCuenta WHERE cuenta_id IN (SELECT id FROM cuenta WHERE usuario_id = p_user_id);
    DELETE FROM movimientoTarjeta WHERE tarjeta_id IN (SELECT id FROM tarjeta WHERE usuario_id = p_user_id);
    DELETE FROM Otps WHERE usuario_id = p_user_id;
    DELETE FROM cuenta WHERE usuario_id = p_user_id;
    DELETE FROM tarjeta WHERE usuario_id = p_user_id;
    DELETE FROM Auditoria WHERE usuario_id = p_user_id;
    DELETE FROM usuario WHERE id = p_user_id;

    RETURN QUERY SELECT TRUE, CAST('Usuario y todos sus registros eliminados exitosamente' AS VARCHAR(100));
END;
$$ LANGUAGE plpgsql;

-- 9. SP para crear cuenta 
CREATE OR REPLACE FUNCTION sp_accounts_create(
    p_usuario_id UUID,
    p_iban VARCHAR(50),
    p_alias VARCHAR(100),
    p_tipo UUID,
    p_moneda UUID,
    p_saldo_inicial DECIMAL(18,2)
)
RETURNS TABLE (
    account_id UUID,
    success BOOLEAN,
    message VARCHAR(100)
) AS $$
DECLARE
    v_account_id UUID;
    v_estado_activo UUID;
BEGIN
    -- Obtener el ID del estado "Activa"
    SELECT id INTO v_estado_activo FROM estadoCuenta WHERE nombre = 'Activa';
    
    IF v_estado_activo IS NULL THEN
        RETURN QUERY SELECT NULL::UUID, FALSE, CAST('Estado de cuenta activa no encontrado' AS VARCHAR(100));
        RETURN;
    END IF;

    -- Verificar que el IBAN sea único
    IF EXISTS (SELECT 1 FROM cuenta WHERE iban = p_iban) THEN
        RETURN QUERY SELECT NULL::UUID, FALSE, CAST('El IBAN ya existe' AS VARCHAR(100));
        RETURN;
    END IF;

    INSERT INTO cuenta (
        usuario_id,
        iban,
        alias,
        tipoCuenta,
        moneda,
        saldo,
        estado
    )
    VALUES (
        p_usuario_id,
        p_iban,
        p_alias,
        p_tipo,
        p_moneda,
        p_saldo_inicial,
        v_estado_activo
    )
    RETURNING id INTO v_account_id;

    RETURN QUERY SELECT v_account_id, TRUE, CAST('Cuenta creada exitosamente' AS VARCHAR(100));
END;
$$ LANGUAGE plpgsql;

-- 10. SP para obtener cuentas 
CREATE OR REPLACE FUNCTION sp_accounts_get(
    p_owner_id UUID DEFAULT NULL,
    p_account_id UUID DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    usuario_id UUID,
    iban VARCHAR(50),
    alias VARCHAR(100),
    tipo_cuenta_nombre VARCHAR(50),
    moneda_iso VARCHAR(3),
    moneda_nombre VARCHAR(50),
    saldo DECIMAL(18,2),
    estado_nombre VARCHAR(50),
    fecha_creacion TIMESTAMP
) AS $$
BEGIN

    RETURN QUERY
    SELECT 
        c.id,
        c.usuario_id,
        c.iban,
        c.alias,
        tc.nombre as tipo_cuenta_nombre,
        m.iso as moneda_iso,
        m.nombre as moneda_nombre,
        c.saldo,
        ec.nombre as estado_nombre,
        c.fecha_creacion
    FROM cuenta c
    INNER JOIN tipoCuenta tc ON c.tipoCuenta = tc.id
    INNER JOIN moneda m ON c.moneda = m.id
    INNER JOIN estadoCuenta ec ON c.estado = ec.id
    WHERE 
        (p_owner_id IS NOT NULL AND c.usuario_id = p_owner_id) OR
        (p_account_id IS NOT NULL AND c.id = p_account_id);
END;
$$ LANGUAGE plpgsql;

-- 11. SP para cambiar estado de cuenta
CREATE OR REPLACE FUNCTION sp_accounts_set_status(
    p_account_id UUID,
    p_nuevo_estado UUID
)
RETURNS TABLE (
    success BOOLEAN,
    message VARCHAR(100)
) AS $$
DECLARE
    v_current_balance DECIMAL(18,2);
    v_new_status_name VARCHAR(50);
BEGIN
    -- Obtener saldo actual y nombre del nuevo estado
    SELECT saldo INTO v_current_balance FROM cuenta WHERE id = p_account_id;
    SELECT nombre INTO v_new_status_name FROM estadoCuenta WHERE id = p_nuevo_estado;

    -- Validar que la cuenta existe
    IF v_current_balance IS NULL THEN
        RETURN QUERY SELECT FALSE, CAST('Cuenta no encontrada' AS VARCHAR(100));
        RETURN;
    END IF;

    -- Validar reglas de negocio
    IF v_new_status_name = 'Cerrada' AND v_current_balance != 0 THEN
        RETURN QUERY SELECT FALSE, CAST('No se puede cerrar una cuenta con saldo diferente de cero' AS VARCHAR(100));
        RETURN;
    END IF;

    IF v_new_status_name = 'Bloqueada' AND v_current_balance < 0 THEN
        RETURN QUERY SELECT FALSE, CAST('No se puede bloquear una cuenta con saldo negativo' AS VARCHAR(100));
        RETURN;
    END IF;

    UPDATE cuenta
    SET 
        estado = p_nuevo_estado,
        fecha_actualizacion = NOW()
    WHERE id = p_account_id;

    RETURN QUERY SELECT TRUE, CAST('Estado de cuenta actualizado exitosamente' AS VARCHAR(100));
END;
$$ LANGUAGE plpgsql;

-- 12. SP para listar movimientos de cuenta 
CREATE OR REPLACE FUNCTION sp_account_movements_list(
    p_account_id UUID,
    p_from_date DATE DEFAULT NULL,
    p_to_date DATE DEFAULT NULL,
    p_type UUID DEFAULT NULL,
    p_q VARCHAR DEFAULT NULL,
    p_page INTEGER DEFAULT 1,
    p_page_size INTEGER DEFAULT 10
)
RETURNS TABLE (
    items JSON,
    total INTEGER,
    page INTEGER,
    page_size INTEGER
) AS $$
DECLARE
    v_total INTEGER;
    v_items JSON;
BEGIN
    -- Contar el total de movimientos
    SELECT COUNT(*) INTO v_total
    FROM movimientoCuenta mc
    WHERE mc.cuenta_id = p_account_id
        AND (p_from_date IS NULL OR mc.fecha::DATE >= p_from_date)
        AND (p_to_date IS NULL OR mc.fecha::DATE <= p_to_date)
        AND (p_type IS NULL OR mc.tipo = p_type)
        AND (p_q IS NULL OR mc.descripcion ILIKE '%' || p_q || '%' OR mc.comerciante ILIKE '%' || p_q || '%');

    -- Obtener los movimientos paginados como JSON
    SELECT json_agg(
        json_build_object(
            'id', movimiento_data.id,
            'fecha', movimiento_data.fecha,
            'tipo', movimiento_data.tipo_nombre,
            'descripcion', movimiento_data.descripcion,
            'moneda', movimiento_data.moneda_iso,
            'monto', movimiento_data.monto,
            'comerciante', movimiento_data.comerciante,
            'categoria', movimiento_data.categoria,
            'ubicacion', movimiento_data.ubicacion,
            'referencia', movimiento_data.referencia
        )
    ) INTO v_items
    FROM (
        SELECT 
            mc.id,
            mc.fecha,
            tmc.nombre as tipo_nombre,
            mc.descripcion,
            m.iso as moneda_iso,
            mc.monto,
            mc.comerciante,
            mc.categoria,
            mc.ubicacion,
            mc.referencia
        FROM movimientoCuenta mc
        INNER JOIN tipoMovimientoCuenta tmc ON mc.tipo = tmc.id
        INNER JOIN moneda m ON mc.moneda = m.id
        WHERE mc.cuenta_id = p_account_id
            AND (p_from_date IS NULL OR mc.fecha::DATE >= p_from_date)
            AND (p_to_date IS NULL OR mc.fecha::DATE <= p_to_date)
            AND (p_type IS NULL OR mc.tipo = p_type)
            AND (p_q IS NULL OR mc.descripcion ILIKE '%' || p_q || '%' OR mc.comerciante ILIKE '%' || p_q || '%')
        ORDER BY mc.fecha DESC
        LIMIT p_page_size
        OFFSET (p_page - 1) * p_page_size
    ) AS movimiento_data;

    -- Devolver los resultados
    RETURN QUERY SELECT v_items, v_total, p_page, p_page_size;
END;
$$ LANGUAGE plpgsql;

-- 13. SP para crear tarjeta 
CREATE OR REPLACE FUNCTION sp_cards_create(
    p_usuario_id UUID,
    p_tipo UUID,
    p_numero_enmascarado VARCHAR(50),
    p_fecha_expiracion VARCHAR(5),
    p_cvv_encriptado VARCHAR(255),
    p_pin_encriptado VARCHAR(255),
    p_moneda UUID,
    p_limite_credito DECIMAL(18,2),
    p_saldo_actual DECIMAL(18,2) DEFAULT 0,
    p_compania VARCHAR(50) DEFAULT 'VISA',
    p_categoria VARCHAR(50) DEFAULT NULL,  -- categoria para CSS (gold, platinum, black, blue, saprisa)
    p_tasa_interes DECIMAL(5,2) DEFAULT 18.50
)
RETURNS TABLE (
    card_id UUID,
    success BOOLEAN,
    message VARCHAR(100)
) AS $$
DECLARE
    v_card_id UUID;
    v_tipo_tarjeta_nombre VARCHAR(50);
    v_nombre_completo VARCHAR(300);
    v_categoria VARCHAR(50);
BEGIN
    -- Contrato y notas:
    --  - Entrada: datos de tarjeta donde los datos sensibles (CVV, PIN) deben llegar en forma encriptada/hashed.
    --  - Salida: card_id o NULL, success boolean y message.
    --  - Importante: las columnas `fecha_corte` y `fecha_pago` se insertan aqui como textos descriptivos
    --    ('25 de cada mes', '10 del mes siguiente'). Si en el esquema de la BD esas columnas son de tipo DATE/TIMESTAMP
    --    esto provocara error. 
    -- Obtener el nombre del tipo de tarjeta
    SELECT nombre INTO v_tipo_tarjeta_nombre FROM tipoTarjeta WHERE id = p_tipo;
    
    IF v_tipo_tarjeta_nombre IS NULL THEN
        RETURN QUERY SELECT NULL::UUID, FALSE, CAST('Tipo de tarjeta no encontrado' AS VARCHAR(100));
        RETURN;
    END IF;

    -- NO se valida el tipo especifico porque la tabla tipoTarjeta en anezos tiene los valores de tipoCuenta

    -- Obtener nombre completo del usuario
    SELECT nombre || ' ' || primer_apellido || COALESCE(' ' || segundo_apellido, '')
    INTO v_nombre_completo
    FROM usuario WHERE id = p_usuario_id;
    
    IF v_nombre_completo IS NULL THEN
        RETURN QUERY SELECT NULL::UUID, FALSE, CAST('Usuario no encontrado' AS VARCHAR(100));
        RETURN;
    END IF;

    -- Validar limite de credito
    IF p_limite_credito IS NULL OR p_limite_credito <= 0 THEN
        RETURN QUERY SELECT NULL::UUID, FALSE, CAST('El limite de credito debe ser mayor a cero' AS VARCHAR(100));
        RETURN;
    END IF;

    -- Validar compañia de tarjeta 
    IF LOWER(p_compania) NOT IN ('alipay', 'amex', 'diners', 'discover', 'elo', 'generic', 
                                 'hiper', 'hipercard', 'jcb', 'maestro', 'mastercard', 'mir', 
                                 'paypal', 'unionpay', 'visa') THEN
        RETURN QUERY SELECT NULL::UUID, FALSE, CAST('Compañia de tarjeta no valida. Compañias soportadas: visa, mastercard, amex, diners, discover, jcb, maestro, unionpay, paypal, alipay, mir, elo, hiper, hipercard, generic' AS VARCHAR(100));
        RETURN;
    END IF;

    -- Usar categoria del parametro o asignar 'blue' por defecto
    -- No se valida la categoria para permitir flexibilidad en el frontend
    IF p_categoria IS NOT NULL THEN
        v_categoria := LOWER(p_categoria);  -- Normalizar a minúsculas
    ELSE
        v_categoria := 'blue';  -- Categoria por defecto
    END IF;

    -- Insertar la tarjeta
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
    )
    VALUES (
        p_usuario_id,
        p_tipo,
        p_numero_enmascarado,
        v_nombre_completo,
        p_fecha_expiracion,
        p_cvv_encriptado,
        p_pin_encriptado,
        p_moneda,
        p_limite_credito,
        COALESCE(p_saldo_actual, 0),
        p_tasa_interes,
        '25 de cada mes',
        '10 del mes siguiente',
        UPPER(p_compania),
        v_categoria,
        'Activa'
    )
    RETURNING id INTO v_card_id;

    RETURN QUERY SELECT v_card_id, TRUE, CAST('Tarjeta creada exitosamente' AS VARCHAR(100));
END;
$$ LANGUAGE plpgsql;

-- 14. SP para obtener tarjetas 
CREATE OR REPLACE FUNCTION sp_cards_get(
    p_owner_id UUID DEFAULT NULL,
    p_card_id UUID DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    usuario_id UUID,
    tipo_tarjeta_nombre VARCHAR(50),
    numero_enmascarado VARCHAR(50),
    titular VARCHAR(100),
    fecha_expiracion VARCHAR(5),
    moneda_iso VARCHAR(3),
    moneda_nombre VARCHAR(50),
    limite_credito DECIMAL(18,2),
    saldo_actual DECIMAL(18,2),
    tasa_interes DECIMAL(5,2),
    fecha_corte VARCHAR(50),
    fecha_pago VARCHAR(50),
    compania VARCHAR(50),
    categoria VARCHAR(50),
    estado VARCHAR(20),
    fecha_creacion TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.id,
        t.usuario_id,
        tt.nombre as tipo_tarjeta_nombre,
        t.numero_enmascarado,
        t.titular,
        t.fecha_expiracion,
        m.iso as moneda_iso,
        m.nombre as moneda_nombre,
        t.limite_credito,
        t.saldo_actual,
        t.tasa_interes,
        t.fecha_corte,
        t.fecha_pago,
        t.compania,
        t.categoria,
        t.estado,
        t.fecha_creacion
    FROM tarjeta t
    INNER JOIN tipoTarjeta tt ON t.tipo = tt.id
    INNER JOIN moneda m ON t.moneda = m.id
    WHERE 
        (p_owner_id IS NOT NULL AND t.usuario_id = p_owner_id) OR
        (p_card_id IS NOT NULL AND t.id = p_card_id);
END;
$$ LANGUAGE plpgsql;

-- 15. SP para listar movimientos de tarjeta (SOLO CReDITO)
CREATE OR REPLACE FUNCTION sp_card_movements_list(
    p_card_id UUID,
    p_from_date DATE DEFAULT NULL,
    p_to_date DATE DEFAULT NULL,
    p_type UUID DEFAULT NULL,
    p_q VARCHAR DEFAULT NULL,
    p_page INTEGER DEFAULT 1,
    p_page_size INTEGER DEFAULT 10
)
RETURNS TABLE (
    items JSON,
    total INTEGER,
    page INTEGER,
    page_size INTEGER
) AS $$
DECLARE
    v_total INTEGER;
    v_items JSON;
BEGIN
    -- Notas:
    --  - Paginacion basica con LIMIT/OFFSET. Para sets muy grandes considerar cursores o keyset pagination.
    --  - Los filtros p_from_date/p_to_date/p_type/p_q aplican solo si no son NULL.
    --  - El campo `items` es un JSON agregado; si no hay filas devuelve NULL. El consumidor debe manejar NULL vs []
    -- Contar el total de movimientos
    SELECT COUNT(*) INTO v_total
    FROM movimientoTarjeta mt
    WHERE mt.tarjeta_id = p_card_id
        AND (p_from_date IS NULL OR mt.fecha::DATE >= p_from_date)
        AND (p_to_date IS NULL OR mt.fecha::DATE <= p_to_date)
        AND (p_type IS NULL OR mt.tipo = p_type)
        AND (p_q IS NULL OR mt.descripcion ILIKE '%' || p_q || '%' OR mt.comerciante ILIKE '%' || p_q || '%');

    -- Obtener los movimientos paginados como JSON
    SELECT json_agg(
        json_build_object(
            'id', movimiento_data.id,
            'fecha', movimiento_data.fecha,
            'tipo', movimiento_data.tipo_nombre,
            'descripcion', movimiento_data.descripcion,
            'moneda', movimiento_data.moneda_iso,
            'monto', movimiento_data.monto,
            'comerciante', movimiento_data.comerciante,
            'ubicacion', movimiento_data.ubicacion,
            'referencia', movimiento_data.referencia
        )
    ) INTO v_items
    FROM (
        SELECT 
            mt.id,
            mt.fecha,
            tmt.nombre as tipo_nombre,
            mt.descripcion,
            m.iso as moneda_iso,
            mt.monto,
            mt.comerciante,
            mt.ubicacion,
            mt.referencia
        FROM movimientoTarjeta mt
        INNER JOIN tipoMovimientoTarjeta tmt ON mt.tipo = tmt.id
        INNER JOIN moneda m ON mt.moneda = m.id
        WHERE mt.tarjeta_id = p_card_id
            AND (p_from_date IS NULL OR mt.fecha::DATE >= p_from_date)
            AND (p_to_date IS NULL OR mt.fecha::DATE <= p_to_date)
            AND (p_type IS NULL OR mt.tipo = p_type)
            AND (p_q IS NULL OR mt.descripcion ILIKE '%' || p_q || '%' OR mt.comerciante ILIKE '%' || p_q || '%')
        ORDER BY mt.fecha DESC
        LIMIT p_page_size
        OFFSET (p_page - 1) * p_page_size
    ) AS movimiento_data;

    -- Devolver resultados
    RETURN QUERY SELECT v_items, v_total, p_page, p_page_size;
END;
$$ LANGUAGE plpgsql;

-- 16. SP para agregar movimiento de tarjeta (SOLO CReDITO)
CREATE OR REPLACE FUNCTION sp_card_movement_add(
    p_card_id UUID,
    p_fecha TIMESTAMP,
    p_tipo UUID,
    p_descripcion TEXT,
    p_moneda UUID,
    p_monto DECIMAL(18,2),
    p_comerciante VARCHAR(100) DEFAULT NULL,
    p_ubicacion VARCHAR(100) DEFAULT NULL
)
RETURNS TABLE (
    movement_id UUID,
    nuevo_saldo DECIMAL(18,2),
    success BOOLEAN,
    message VARCHAR(100)
) AS $$
DECLARE
    v_movement_id UUID;
    v_saldo_actual DECIMAL(18,2);
    v_nuevo_saldo DECIMAL(18,2);
    v_limite_credito DECIMAL(18,2);
    v_tipo_movimiento VARCHAR(50);
BEGIN
    -- Obtener informacion de la tarjeta
    -- Nota: si la tarjeta no existe, v_saldo_actual quedara NULL y se maneja abajo.
    SELECT t.saldo_actual, t.limite_credito
    INTO v_saldo_actual, v_limite_credito
    FROM tarjeta t
    WHERE t.id = p_card_id
    LIMIT 1;

    IF v_saldo_actual IS NULL THEN
        RETURN QUERY SELECT NULL::UUID, NULL::DECIMAL, FALSE, CAST('Tarjeta no encontrada' AS VARCHAR(100));
        RETURN;
    END IF;

    -- Obtener tipo de movimiento (Compra o Pago)
    SELECT nombre INTO v_tipo_movimiento FROM tipoMovimientoTarjeta WHERE id = p_tipo;

    IF v_tipo_movimiento = 'Compra' THEN
        -- COMPRA: aumenta saldo (deuda)
        v_nuevo_saldo := v_saldo_actual + p_monto;
        
        -- Validar que no exceda el limite de credito
        IF v_nuevo_saldo > v_limite_credito THEN
            RETURN QUERY SELECT NULL::UUID, v_saldo_actual, FALSE, CAST('Compra excede el limite de credito disponible' AS VARCHAR(100));
            RETURN;
        END IF;

    ELSIF v_tipo_movimiento = 'Pago' THEN
        -- PAGO: disminuye saldo (abono)
        v_nuevo_saldo := v_saldo_actual - p_monto;
        
        -- No permitir pagos mayores al saldo
        IF v_nuevo_saldo < 0 THEN
            RETURN QUERY SELECT NULL::UUID, v_saldo_actual, FALSE, CAST('El pago excede el saldo actual de la tarjeta' AS VARCHAR(100));
            RETURN;
        END IF;

    ELSE
        RETURN QUERY SELECT NULL::UUID, v_saldo_actual, FALSE, CAST('Tipo de movimiento no valido' AS VARCHAR(100));
        RETURN;
    END IF;

    -- Insertar movimiento
    INSERT INTO movimientoTarjeta (
        tarjeta_id,
        fecha,
        tipo,
        descripcion,
        moneda,
        monto,
        comerciante,
        ubicacion
    )
    VALUES (
        p_card_id,
        p_fecha,
        p_tipo,
        p_descripcion,
        p_moneda,
        p_monto,
        p_comerciante,
        p_ubicacion
    )
    RETURNING id INTO v_movement_id;

    -- Actualizar saldo de la tarjeta
    UPDATE tarjeta
    SET 
        saldo_actual = v_nuevo_saldo,
        fecha_actualizacion = NOW()
    WHERE id = p_card_id;

    RETURN QUERY SELECT v_movement_id, v_nuevo_saldo, TRUE, CAST('Movimiento registrado exitosamente' AS VARCHAR(100));
END;
$$ LANGUAGE plpgsql;

-- 17. SP para transferencia interna (SIN TABLA TRANSFERENCIA)
-- Registra 2 movimientos en movimientoCuenta vinculados por referencia
CREATE OR REPLACE FUNCTION sp_transfer_create_internal(
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
) AS $$
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
BEGIN
    -- Obtener el rol del usuario que ejecuta la transferencia
    SELECT r.nombre INTO v_user_role
    FROM usuario u
    INNER JOIN rol r ON u.rol = r.id
    WHERE u.id = p_user_id;
    -- Contrato y notas importantes sobre atomicidad:
    --  - La funcion crea dos movimientos en `movimientoCuenta` y actualiza saldos en `cuenta`.
    --  - Es critico que ambas actualizaciones sean atomicas. En PL/pgSQL una funcion se ejecuta en la transaccion
    --    del caller; si el caller no maneja la transaccion, un error aqui deberia revertir los cambios.
    -- Verificar que las cuentas existan y obtener sus datos
    SELECT moneda, saldo, usuario_id 
    INTO v_from_account_currency, v_from_account_balance, v_from_account_owner
    FROM cuenta 
    WHERE id = p_from_account_id;

    SELECT moneda INTO v_to_account_currency
    FROM cuenta
    WHERE id = p_to_account_id;

    -- Validaciones
    IF v_from_account_currency IS NULL OR v_to_account_currency IS NULL THEN
        RETURN QUERY SELECT NULL::VARCHAR, NULL::VARCHAR, 'error'::VARCHAR, FALSE, CAST('Una o ambas cuentas no existen' AS VARCHAR(100));
        RETURN;
    END IF;

    IF v_from_account_currency != v_to_account_currency THEN
        RETURN QUERY SELECT NULL::VARCHAR, NULL::VARCHAR, 'error'::VARCHAR, FALSE, CAST('Las cuentas deben tener la misma moneda' AS VARCHAR(100));
        RETURN;
    END IF;

    IF v_from_account_balance < p_amount THEN
        RETURN QUERY SELECT NULL::VARCHAR, NULL::VARCHAR, 'error'::VARCHAR, FALSE, CAST('Saldo insuficiente' AS VARCHAR(100));
        RETURN;
    END IF;

    -- Validar propiedad de cuenta SOLO si el usuario NO es admin
    IF v_user_role != 'admin' AND v_from_account_owner != p_user_id THEN
        RETURN QUERY SELECT NULL::VARCHAR, NULL::VARCHAR, 'error'::VARCHAR, FALSE, CAST('La cuenta origen no pertenece al usuario' AS VARCHAR(100));
        RETURN;
    END IF;

    -- Generar número de recibo único
    v_receipt_number := 'TRF-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(EXTRACT(EPOCH FROM NOW())::BIGINT::TEXT, 10, '0');

    -- Obtener IDs de tipos de movimiento
    SELECT id INTO v_tipo_debito FROM tipoMovimientoCuenta WHERE nombre = 'Debito';
    SELECT id INTO v_tipo_credito FROM tipoMovimientoCuenta WHERE nombre = 'Credito';

    -- Iniciar transaccion: Crear movimiento DeBITO en cuenta origen
    INSERT INTO movimientoCuenta (
        cuenta_id,
        fecha,
        tipo,
        descripcion,
        moneda,
        monto,
        referencia
    )
    VALUES (
        p_from_account_id,
        NOW(),
        v_tipo_debito,
        'Transferencia enviada: ' || p_descripcion,
        v_from_account_currency,
        -p_amount,  -- Negativo porque sale dinero
        v_receipt_number
    )
    RETURNING id INTO v_movement_debito_id;

    -- Actualizar saldo de cuenta origen
    UPDATE cuenta
    SET 
        saldo = saldo - p_amount,
        fecha_actualizacion = NOW()
    WHERE id = p_from_account_id;

    -- Crear movimiento CReDITO en cuenta destino
    INSERT INTO movimientoCuenta (
        cuenta_id,
        fecha,
        tipo,
        descripcion,
        moneda,
        monto,
        referencia
    )
    VALUES (
        p_to_account_id,
        NOW(),
        v_tipo_credito,
        'Transferencia recibida: ' || p_descripcion,
        v_to_account_currency,
        p_amount,  -- Positivo porque entra dinero
        v_receipt_number
    )
    RETURNING id INTO v_movement_credito_id;

    -- Actualizar saldo de cuenta destino
    UPDATE cuenta
    SET 
        saldo = saldo + p_amount,
        fecha_actualizacion = NOW()
    WHERE id = p_to_account_id;

    RETURN QUERY SELECT 
        v_receipt_number::VARCHAR, 
        v_receipt_number::VARCHAR, 
        'completed'::VARCHAR, 
        TRUE, 
        CAST('Transferencia completada exitosamente' AS VARCHAR(100));
EXCEPTION
    WHEN OTHERS THEN
        RETURN QUERY SELECT NULL::VARCHAR, NULL::VARCHAR, 'error'::VARCHAR, FALSE, CAST('Error al procesar la transferencia' AS VARCHAR(100));
END;
$$ LANGUAGE plpgsql;

-- 18. SP para validar cuenta bancaria 
CREATE OR REPLACE FUNCTION sp_bank_validate_account(
    p_iban VARCHAR(50)
)
RETURNS TABLE (
    account_exists BOOLEAN,
    owner_name VARCHAR(200),
    owner_id UUID,
    account_id UUID,
    currency_iso VARCHAR(3)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        TRUE as account_exists,
        (u.nombre || ' ' || u.primer_apellido || COALESCE(' ' || u.segundo_apellido, ''))::VARCHAR(200) as owner_name,
        u.id as owner_id,
        c.id as account_id,
        m.iso as currency_iso
    FROM cuenta c
    INNER JOIN usuario u ON c.usuario_id = u.id
    INNER JOIN moneda m ON c.moneda = m.id
    INNER JOIN estadoCuenta ec ON c.estado = ec.id
    WHERE c.iban = p_iban
        AND ec.nombre = 'Activa';
    
    -- Si no se encontro ninguna cuenta activa
    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, NULL::VARCHAR, NULL::UUID, NULL::UUID, NULL::VARCHAR;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- 19. SP para auditoria (puntos extras)
CREATE OR REPLACE FUNCTION sp_audit_log(
    p_accion VARCHAR(100),
    p_entidad VARCHAR(100),
    p_actor_user_id UUID DEFAULT NULL,
    p_entidad_id UUID DEFAULT NULL,
    p_detalles JSONB DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
    v_audit_id INTEGER;
BEGIN
    INSERT INTO Auditoria (usuario_id, accion, detalles)
    VALUES (
        p_actor_user_id,
        p_accion || ' - ' || p_entidad || COALESCE(' [' || p_entidad_id::TEXT || ']', ''),
        p_detalles
    )
    RETURNING id INTO v_audit_id;

    RETURN v_audit_id;
END;
$$ LANGUAGE plpgsql;

-- 20. SP para listar auditoria por usuario
CREATE OR REPLACE FUNCTION sp_audit_list_by_user(
    p_user_id UUID
)
RETURNS TABLE (
    id INTEGER,
    accion VARCHAR(100),
    detalles JSONB,
    fecha TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.id,
        a.accion,
        a.detalles,
        a.fecha
    FROM Auditoria a
    WHERE a.usuario_id = p_user_id
    ORDER BY a.fecha DESC;
END;
$$ LANGUAGE plpgsql;

-- 21. SP extra: obtener usuario por ID
CREATE OR REPLACE FUNCTION sp_users_get_by_id(
    p_user_id UUID
)
RETURNS TABLE (
    id UUID,
    nombre VARCHAR(100),
    primer_apellido VARCHAR(100),
    segundo_apellido VARCHAR(100),
    correo VARCHAR(255),
    telefono VARCHAR(20),
    usuario VARCHAR(50),
    rol_nombre VARCHAR(50),
    identificacion VARCHAR(50),
    tipo_identificacion_nombre VARCHAR(50),
    fecha_nacimiento DATE,
    fecha_creacion TIMESTAMP,
    estado VARCHAR(20)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id,
        u.nombre,
        u.primer_apellido,
        u.segundo_apellido,
        u.correo,
        u.telefono,
        u.usuario,
        r.nombre as rol_nombre,
        u.identificacion,
        ti.nombre as tipo_identificacion_nombre,
        u.fecha_nacimiento,
        u.fecha_creacion,
        u.estado
    FROM usuario u
    INNER JOIN rol r ON u.rol = r.id
    INNER JOIN tipoIdentificacion ti ON u.tipo_identificacion = ti.id
    WHERE u.id = p_user_id;
END;
$$ LANGUAGE plpgsql;

-- 22. SP extra: cambiar contraseña de usuario
CREATE OR REPLACE FUNCTION sp_users_change_password(
    p_user_id UUID,
    p_nuevo_contrasena_hash VARCHAR(255)
)
RETURNS TABLE (
    success BOOLEAN,
    message VARCHAR(100)
) AS $$
BEGIN
    UPDATE usuario
    SET 
        contrasena_hash = p_nuevo_contrasena_hash,
        fecha_actualizacion = NOW()
    WHERE id = p_user_id;

    IF FOUND THEN
        RETURN QUERY SELECT TRUE, CAST('Contraseña actualizada exitosamente' AS VARCHAR(100));
    ELSE
        RETURN QUERY SELECT FALSE, CAST('Usuario no encontrado' AS VARCHAR(100));
    END IF;
END;
$$ LANGUAGE plpgsql;

-- ====================================
-- FIN DE STORED PROCEDURES
-- Total: 22 SPs implementados
-- ====================================

-- NOTAS:
-- 1. Se elimino toda logica de tarjetas de debito
-- 2. Se elimino tabla transferencia (se usan 2 movimientos vinculados por referencia)
-- 3. Se elimino tabla banco (no esta en anexos)
-- 4. Se elimino tabla destinatarioFrecuente (no esta en anexos)
-- 5. Campos simplificados según anexos estrictos
-- 6. movimientoCuenta ahora registra transferencias usando campo referencia
>>>>>>> da9e1a801059a120b4a9d353485bf277624781f0
