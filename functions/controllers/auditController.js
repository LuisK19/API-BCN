const db = require("../config/database");


const listAuditByUser = async (req, res, next) => {
  try {
    const {userId} = req.params;
    const user = req.user; // Usuario autenticado desde JWT

    // Validar UUID format
    const uuidRegex =
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    if (!uuidRegex.test(userId)) {
      return res.status(422).json({
        error: {
          code: "INVALID_UUID",
          message: "El ID de usuario proporcionado no es válido",
          details: {userId},
          timestamp: new Date().toISOString(),
          path: req.originalUrl,
        },
      });
    }

    // Validar permisos: solo el propio usuario o un admin pueden ver la auditoría
    if (user.role !== "admin" && user.id !== userId) {
      return res.status(403).json({
        error: {
          code: "FORBIDDEN",
          message:
            "No tienes permisos para consultar el historial de auditoría de este usuario",
          details: {},
          timestamp: new Date().toISOString(),
          path: req.originalUrl,
        },
      });
    }

    // Llamar al SP
    const result = await db.query("SELECT * FROM sp_audit_list_by_user($1)", [
      userId,
    ]);

    const auditRecords = result.rows;

    // Retornar los registros de auditoría
    return res.status(200).json({
      data: {
        userId: userId,
        total: auditRecords.length,
        records: auditRecords.map((record) => ({
          id: record.id,
          accion: record.accion,
          detalles: record.detalles,
          fecha: record.fecha,
        })),
      },
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  listAuditByUser,
};
