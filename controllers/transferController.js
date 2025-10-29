const db = require('../config/database');

exports.internalTransfer = async (req, res) => {
  try {
    const { fromAccountId, toAccountId, amount, description } = req.body;
    const userId = req.user.userId;

    // Verificar que la cuenta origen pertenece al usuario
    const fromAccount = await db.query(
      'SELECT id, saldo FROM cuenta WHERE id = $1 AND usuario_id = $2',
      [fromAccountId, userId]
    );
    if (fromAccount.rows.length === 0) {
      return res.status(403).json({
        error: 'Acceso denegado',
        message: 'No tienes permisos para transferir desde esta cuenta'
      });
    }
    if (fromAccount.rows[0].saldo < amount) {
      return res.status(400).json({
        error: 'Saldo insuficiente',
        message: 'No tienes saldo suficiente para la transferencia'
      });
    }
    // Verificar que la cuenta destino existe
    const toAccount = await db.query(
      'SELECT id FROM cuenta WHERE id = $1',
      [toAccountId]
    );
    if (toAccount.rows.length === 0) {
      return res.status(404).json({
        error: 'Cuenta destino no encontrada',
        message: 'La cuenta destino no existe'
      });
    }
    // Realizar transferencia (simplificado)
    await db.query('BEGIN');
    await db.query(
      'UPDATE cuenta SET saldo = saldo - $1 WHERE id = $2',
      [amount, fromAccountId]
    );
    await db.query(
      'UPDATE cuenta SET saldo = saldo + $1 WHERE id = $2',
      [amount, toAccountId]
    );
    await db.query(
      `INSERT INTO movimientoCuenta (cuenta_id, tipo, monto, descripcion, fecha)
       VALUES ($1, 1, $2, $3, CURRENT_TIMESTAMP)`,
      [fromAccountId, -amount, description || 'Transferencia interna']
    );
    await db.query(
      `INSERT INTO movimientoCuenta (cuenta_id, tipo, monto, descripcion, fecha)
       VALUES ($1, 2, $2, $3, CURRENT_TIMESTAMP)`,
      [toAccountId, amount, description || 'Transferencia interna']
    );
    await db.query('COMMIT');
    res.json({
      success: true,
      message: 'Transferencia realizada con éxito'
    });
  } catch (error) {
    await db.query('ROLLBACK');
    console.error('Error en transferencia interna:', error);
    res.status(500).json({
      error: 'Error interno del servidor',
      message: error.message
    });
  }
};
