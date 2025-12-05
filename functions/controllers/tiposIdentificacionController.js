const db = require("../config/database");

/**
 * Obtener todos los tipos de identificación disponibles
 * GET /api/v1/tipos-identificacion
 * Endpoint público (sin autenticación)
 * @param {object} req - Request
 * @param {object} res - Response
 * @param {function} next - Next middleware
 * @return {Promise<void>}
 */
const getTiposIdentificacion = async (req, res, next) => {
  try {
    const result = await db.query(`
      SELECT 
        id, 
        nombre, 
        descripcion 
      FROM tipoIdentificacion 
      ORDER BY nombre ASC
    `);

    res.status(200).json({
      tiposIdentificacion: result.rows,
    });
  } catch (error) {
    console.error("Error obteniendo tipos de identificación:", error);
    next(error);
  }
};

module.exports = {
  getTiposIdentificacion,
};
