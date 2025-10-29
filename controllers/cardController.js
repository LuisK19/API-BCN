const db = require('../config/database');

exports.getUserCards = async (req, res) => {
  try {
    const userId = req.user.userId;
    const result = await db.query(
      `SELECT t.*, tc.nombre as tipo_tarjeta, m.iso as moneda_iso, m.simbolo as moneda_simbolo,
              et.nombre as estado_nombre
       FROM tarjeta t
       JOIN tipoTarjeta tc ON t.tipoTarjeta = tc.id
       JOIN moneda m ON t.moneda = m.id
       JOIN estadoTarjeta et ON t.estado = et.id
       WHERE t.usuario_id = $1
       ORDER BY t.fecha_creacion DESC`,
      [userId]
    );
    res.json({
      success: true,
      data: result.rows,
      count: result.rows.length
    });
  } catch (error) {
    console.error('Error obteniendo tarjetas:', error);
    res.status(500).json({
      error: 'Error interno del servidor',
      message: error.message
    });
  }
};
