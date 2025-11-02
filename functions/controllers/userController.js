const db = require("../config/database");
const bcrypt = require("bcrypt");
const audit = require("../utils/auditHelper");

// Crear usuario
const createUser = async (req, res, next) => {
  const {
    tipoIdentificacion,
    identificacion,
    nombre,
    primerApellido,
    segundoApellido,
    correo,
    telefono,
    usuario,
    contrasena,
    rol,
    fechaNacimiento,
  } = req.body;
  if (
    !tipoIdentificacion ||
    !identificacion ||
    !nombre ||
    !primerApellido ||
    !correo ||
    !usuario ||
    !contrasena ||
    !rol ||
    !fechaNacimiento
  ) {
    return res.status(422).json({
      error: {
        code: "VALIDATION_ERROR",
        message: "Faltan campos obligatorios",
        timestamp: new Date().toISOString(),
        path: req.path,
      },
    });
  }
  try {
    const contrasenaHash = await bcrypt.hash(contrasena, 12);
    const result = await db.query(
        "SELECT * FROM sp_users_create($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)",
        [
          tipoIdentificacion,
          identificacion,
          nombre,
          primerApellido,
          segundoApellido || "",
          correo,
          telefono || "",
          usuario,
          contrasenaHash,
          rol,
          fechaNacimiento,
        ],
    );
    const userId = result.rows && result.rows[0] ? result.rows[0].user_id : undefined;
    if (!userId) {
      return res.status(400).json({
        error: {
          code: "CREATE_FAILED",
          message: "No se pudo crear el usuario",
          timestamp: new Date().toISOString(),
          path: req.path,
        },
      });
    }

    // REGISTRAR EN AUDITORÍA
    try {
      await audit.logUserCreate(
          req.user ? req.user.id : userId, // Si no hay req.user (registro público), usar el userId creado
          userId,
          {
            identificacion,
            nombre,
            apellido: `${primerApellido} ${segundoApellido || ""}`.trim(),
            correo,
            usuario,
            rol,
          },
      );
    } catch (auditError) {
      console.error("Error registrando auditoría de creación de usuario:", auditError.message);
    }

    res.status(201).json({userId, message: "Usuario creado exitosamente"});
  } catch (error) {
    next(error);
  }
};

// Consultar usuario por identificación
const getUserByIdentification = async (req, res, next) => {
  const {identification} = req.params;
  const user = req.user;
  try {
    const result = await db.query(
        "SELECT * FROM sp_users_get_by_identification($1)",
        [identification],
    );
    const found = result.rows && result.rows[0] ? result.rows[0] : undefined;
    if (!found) {
      return res.status(404).json({
        error: {
          code: "NOT_FOUND",
          message: "Usuario no encontrado",
          timestamp: new Date().toISOString(),
          path: req.path,
        },
      });
    }

    // Validación: Admin puede ver cualquier usuario, o el usuario puede ver su propia info
    const isAdmin = user.role === "admin";
    const isOwnInfo = user.identification === found.identificacion;
    if (!isAdmin && !isOwnInfo) {
      return res.status(403).json({
        error: {
          code: "FORBIDDEN",
          message: "No autorizado para consultar este usuario",
          timestamp: new Date().toISOString(),
          path: req.path,
        },
      });
    }
    res.status(200).json({user: found});
  } catch (error) {
    next(error);
  }
};

const getAllUsers = async (req, res, next) => {
  try {
    const result = await db.query("SELECT * FROM usuario");
    res.status(200).json({users: result.rows});
  } catch (error) {
    next(error);
  }
};

// Actualizar usuario (solo admin)
const updateUser = async (req, res, next) => {
  const {id} = req.params;
  const user = req.user;
  if (user.role !== "admin") {
    return res.status(403).json({
      error: {
        code: "FORBIDDEN",
        message: "Solo admin puede actualizar usuarios",
        timestamp: new Date().toISOString(),
        path: req.path,
      },
    });
  }
  const {
    nombre,
    primerApellido,
    segundoApellido,
    correo,
    telefono,
    usuario: username,
    rol: newRol,
  } = req.body;

  // Si algún campo no viene, envía null
  const params = [
    id,
    nombre !== undefined ? nombre : null,
    primerApellido !== undefined ? primerApellido : null,
    segundoApellido !== undefined ? segundoApellido : null,
    correo !== undefined ? correo : null,
    telefono !== undefined ? telefono : null,
    username !== undefined ? username : null,
    newRol !== undefined ? newRol : null,
  ];
  try {
    const result = await db.query(
        "SELECT * FROM sp_users_update($1, $2, $3, $4, $5, $6, $7, $8)",
        params,
    );
    const success = result.rows && result.rows[0] ? result.rows[0].success : undefined;
    if (!success) {
      return res.status(400).json({
        error: {
          code: "UPDATE_FAILED",
          message: "No se pudo actualizar el usuario",
          timestamp: new Date().toISOString(),
          path: req.path,
        },
      });
    }

    // REGISTRAR EN AUDITORÍA
    try {
      const camposActualizados = Object.keys(req.body);
      await audit.logUserUpdate(user.id, id, {
        camposActualizados,
        valores: req.body,
      });
    } catch (auditError) {
      console.error("Error registrando auditoría de actualización de usuario:", auditError.message);
    }

    res.status(200).json({message: "Usuario actualizado exitosamente"});
  } catch (error) {
    next(error);
  }
};

// Eliminar usuario (solo admin)
const deleteUser = async (req, res, next) => {
  const {id} = req.params;
  const user = req.user;
  if (user.role !== "admin") {
    return res.status(403).json({
      error: {
        code: "FORBIDDEN",
        message: "Solo admin puede eliminar usuarios",
        timestamp: new Date().toISOString(),
        path: req.path,
      },
    });
  }
  try {
    // Obtener información del usuario antes de eliminar
    const userInfoResult = await db.query(
        "SELECT identificacion, usuario FROM usuario WHERE id = $1",
        [id],
    );
    const userInfo = userInfoResult.rows[0];

    const result = await db.query(
        "SELECT * FROM sp_users_delete($1)",
        [id],
    );
    const success = result.rows && result.rows[0] ? result.rows[0].success : undefined;
    if (!success) {
      return res.status(400).json({
        error: {
          code: "DELETE_FAILED",
          message: "No se pudo eliminar el usuario",
          timestamp: new Date().toISOString(),
          path: req.path,
        },
      });
    }

    // REGISTRAR EN AUDITORÍA
    try {
      await audit.logUserDelete(user.id, id, {
        identificacion: userInfo ? userInfo.identificacion : null,
        usuario: userInfo ? userInfo.usuario : null,
      });
    } catch (auditError) {
      console.error("Error registrando auditoría de eliminación de usuario:", auditError.message);
    }

    res.status(200).json({message: "Usuario eliminado exitosamente"});
  } catch (error) {
    next(error);
  }
};

module.exports = {
  createUser,
  getUserByIdentification,
  getAllUsers,
  updateUser,
  deleteUser,
};
