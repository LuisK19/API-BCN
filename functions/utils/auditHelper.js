const db = require("../config/database");

/**
 * Helper para registrar acciones en el sistema de auditoría
 *
 * Este módulo facilita el registro de eventos importantes en la tabla Auditoria,
 * permitiendo rastrear las acciones de los usuarios y cumplir con los puntos extra.
 */

/**
 * Tipos de acciones comunes para auditoría
 */
const AuditAction = {
  LOGIN: "LOGIN",
  LOGOUT: "LOGOUT",
  CREATE: "CREATE",
  UPDATE: "UPDATE",
  DELETE: "DELETE",
  TRANSFER: "TRANSFER",
  VIEW_SENSITIVE_DATA: "VIEW_SENSITIVE_DATA",
  OTP_GENERATE: "OTP_GENERATE",
  PASSWORD_RESET: "PASSWORD_RESET",
  MOVEMENT_ADD: "MOVEMENT_ADD",
  STATUS_CHANGE: "STATUS_CHANGE",
};

/**
 * Tipos de entidades que se auditan
 */
const AuditEntity = {
  USUARIO: "Usuario",
  CUENTA: "Cuenta",
  TARJETA: "Tarjeta",
  TRANSFERENCIA: "Transferencia",
};

/**
 * Registra una acción en el sistema de auditoría
 *
 * @param {string} accion - Tipo de acción (usar AuditAction)
 * @param {string} entidad - Entidad afectada (usar AuditEntity)
 * @param {string} actorUserId - UUID del usuario que realiza la acción
 * @param {string} entidadId - UUID del recurso afectado (opcional)
 * @param {object} detalles - Objeto con información adicional (opcional)
 * @return {Promise<number>} ID del registro de auditoría creado
 */
const logAudit = async (
    accion,
    entidad,
    actorUserId,
    entidadId = null,
    detalles = null,
) => {
  try {
    const result = await db.query(
        "SELECT sp_audit_log($1, $2, $3, $4, $5::jsonb) as audit_id",
        [accion, entidad, actorUserId, entidadId, detalles ? JSON.stringify(detalles) : null],
    );

    return result.rows[0].audit_id;
  } catch (error) {
    // No lanzar error para no afectar la operación principal
    console.error("Error registrando auditoría:", error.message);
    console.error("Detalles del error:", error);
    return null;
  }
};

const logLogin = async (userId, req) => {
  return logAudit(AuditAction.LOGIN, AuditEntity.USUARIO, userId, userId, {
    ip: req.ip || req.connection.remoteAddress,
    userAgent: req.get("user-agent"),
    timestamp: new Date().toISOString(),
  });
};

const logAccountCreate = async (userId, accountId, accountDetails) => {
  return logAudit(
      AuditAction.CREATE,
      AuditEntity.CUENTA,
      userId,
      accountId,
      accountDetails,
  );
};

const logTransfer = async (userId, fromAccountId, transferDetails) => {
  return logAudit(
      AuditAction.TRANSFER,
      AuditEntity.CUENTA,
      userId,
      fromAccountId,
      transferDetails,
  );
};

const logViewSensitiveData = async (userId, cardId, dataType) => {
  return logAudit(
      AuditAction.VIEW_SENSITIVE_DATA,
      AuditEntity.TARJETA,
      userId,
      cardId,
      {tipo: dataType, via: "OTP"},
  );
};

const logCardCreate = async (userId, cardId, cardDetails) => {
  return logAudit(
      AuditAction.CREATE,
      AuditEntity.TARJETA,
      userId,
      cardId,
      cardDetails,
  );
};

const logStatusChange = async (userId, entityType, entityId, statusDetails) => {
  return logAudit(
      AuditAction.STATUS_CHANGE,
      entityType,
      userId,
      entityId,
      statusDetails,
  );
};

const logOTPGenerate = async (userId, entityId, purpose) => {
  return logAudit(AuditAction.OTP_GENERATE, AuditEntity.USUARIO, userId, entityId, {
    proposito: purpose,
  });
};

const logPasswordReset = async (userId) => {
  return logAudit(
      AuditAction.PASSWORD_RESET,
      AuditEntity.USUARIO,
      userId,
      userId,
      {via: "OTP"},
  );
};

const logUserUpdate = async (actorUserId, targetUserId, changes) => {
  return logAudit(
      AuditAction.UPDATE,
      AuditEntity.USUARIO,
      actorUserId,
      targetUserId,
      changes,
  );
};

const logUserCreate = async (actorUserId, newUserId, userDetails) => {
  return logAudit(
      AuditAction.CREATE,
      AuditEntity.USUARIO,
      actorUserId,
      newUserId,
      userDetails,
  );
};

const logUserDelete = async (actorUserId, targetUserId, userInfo) => {
  return logAudit(
      AuditAction.DELETE,
      AuditEntity.USUARIO,
      actorUserId,
      targetUserId,
      userInfo,
  );
};

const logCardMovementAdd = async (userId, cardId, movementDetails) => {
  return logAudit(
      AuditAction.MOVEMENT_ADD,
      AuditEntity.TARJETA,
      userId,
      cardId,
      movementDetails,
  );
};

/**
 * Registra un registro público de usuario (sin actor, el usuario se registra a sí mismo)
 * @param {string} userId - UUID del usuario creado
 * @param {object} req - Request object para obtener IP
 * @return {Promise<number>}
 */
const logRegister = async (userId, req) => {
  const ip = req.ip || (req.connection && req.connection.remoteAddress);
  return logAudit(
      AuditAction.CREATE,
      AuditEntity.USUARIO,
      userId, // El usuario se crea a sí mismo
      userId, // Entidad afectada es el mismo usuario
      {
        ip: ip,
        userAgent: req.headers["user-agent"],
        registroPublico: true,
      },
  );
};

module.exports = {
  // Función principal
  logAudit,

  // Constantes
  AuditAction,
  AuditEntity,

  // Helpers específicos
  logLogin,
  logRegister,
  logAccountCreate,
  logTransfer,
  logViewSensitiveData,
  logCardCreate,
  logStatusChange,
  logOTPGenerate,
  logPasswordReset,
  logUserUpdate,
  logUserCreate,
  logUserDelete,
  logCardMovementAdd,
};
