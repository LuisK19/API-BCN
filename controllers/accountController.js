const db = require('../config/database');

exports.getUserAccounts = async (req, res) => {
  try {
    const userId = req.user.userId;
    const result = await db.query(
      `SELECT c.*, tc.nombre as tipo_cuenta, m.iso as moneda_iso, m.simbolo as moneda_simbolo,
              ec.nombre as estado_nombre
       FROM cuenta c
       JOIN tipoCuenta tc ON c.tipoCuenta = tc.id
       JOIN moneda m ON c.moneda = m.id
       JOIN estadoCuenta ec ON c.estado = ec.id
       WHERE c.usuario_id = $1
       ORDER BY c.fecha_creacion DESC`,
      [userId]
    );
    res.json({
      success: true,
      data: result.rows,
      count: result.rows.length
    });
  } catch (error) {
    console.error('Error obteniendo cuentas:', error);
    res.status(500).json({
      error: 'Error interno del servidor',
      message: error.message
    });
  }
};

exports.getAccountById = async (req, res) => {
  try {
    const accountId = req.params.id;
    const userId = req.user.userId;
    const result = await db.query(
      `SELECT c.*, tc.nombre as tipo_cuenta, m.iso as moneda_iso, m.simbolo as moneda_simbolo,
              ec.nombre as estado_nombre
       FROM cuenta c
       JOIN tipoCuenta tc ON c.tipoCuenta = tc.id
       JOIN moneda m ON c.moneda = m.id
       JOIN estadoCuenta ec ON c.estado = ec.id
       WHERE c.id = $1 AND c.usuario_id = $2`,
      [accountId, userId]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({
        error: 'Cuenta no encontrada',
        message: 'No existe la cuenta o no tienes acceso'
      });
    }
    res.json({
      success: true,
      data: result.rows[0]
    });
  } catch (error) {
    console.error('Error obteniendo cuenta:', error);
    res.status(500).json({
      error: 'Error interno del servidor',
      message: error.message
    });
  }
};

exports.getAccountMovements = async (req, res) => {
  try {
    const accountId = req.params.id;
    const userId = req.user.userId;
    // Verificar que la cuenta pertenece al usuario
    const accountCheck = await db.query(
      'SELECT id FROM cuenta WHERE id = $1 AND usuario_id = $2',
      [accountId, userId]
    );
    if (accountCheck.rows.length === 0) {
      return res.status(403).json({
        error: 'Acceso denegado',
        message: 'No tienes permisos para ver esta cuenta'
      });
    }
    const result = await db.query(
      `SELECT mc.*, tmc.nombre as tipo_movimiento, m.iso as moneda_iso
       FROM movimientoCuenta mc
       JOIN tipoMovimientoCuenta tmc ON mc.tipo = tmc.id
       JOIN moneda m ON mc.moneda = m.id
       WHERE mc.cuenta_id = $1
       ORDER BY mc.fecha DESC
       LIMIT 50`,
      [accountId]
    );
    res.json({
      success: true,
      data: result.rows,
      count: result.rows.length
    });
  } catch (error) {
    console.error('Error obteniendo movimientos:', error);
    res.status(500).json({
      error: 'Error interno del servidor',
      message: error.message
    });
  }
};
