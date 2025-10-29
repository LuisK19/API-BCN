const db = require('../config/database');
const bcrypt = require('bcrypt');

// Crear usuario
const createUser = async (req, res, next) => {
  const { tipo_identificacion, identificacion, nombre, primer_apellido, segundo_apellido, correo, telefono, usuario, contrasena, rol, fecha_nacimiento } = req.body;
  if (!tipo_identificacion || !identificacion || !nombre || !primer_apellido || !correo || !usuario || !contrasena || !rol || !fecha_nacimiento) {
    return res.status(422).json({ error: { code: 'VALIDATION_ERROR', message: 'Faltan campos obligatorios', timestamp: new Date().toISOString(), path: req.path }});
  }
  try {
    const contrasena_hash = await bcrypt.hash(contrasena, 12);
    const result = await db.query('SELECT * FROM sp_users_create($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)', [
      tipo_identificacion, identificacion, nombre, primer_apellido, segundo_apellido || '', correo, telefono || '', usuario, contrasena_hash, rol, fecha_nacimiento
    ]);
    const user_id = result.rows[0]?.user_id;
    if (!user_id) {
      return res.status(400).json({ error: { code: 'CREATE_FAILED', message: 'No se pudo crear el usuario', timestamp: new Date().toISOString(), path: req.path }});
    }
    res.status(201).json({ user_id, message: 'Usuario creado exitosamente' });
  } catch (error) {
    next(error);
  }
};

// Consultar usuario por identificación
const getUserByIdentification = async (req, res, next) => {
  const { identification } = req.params;
  console.log('Identification param:', identification);
  const user = req.user;
  console.log('Authenticated user:', user);
  try {
    const result = await db.query('SELECT * FROM sp_users_get_by_identification($1)', [identification]);
    console.log('Database query result:', result);
    const found = result.rows[0];
    if (!found) {
      return res.status(404).json({ error: { code: 'NOT_FOUND', message: 'Usuario no encontrado', timestamp: new Date().toISOString(), path: req.path }});
    }
    // Solo admin o dueño puede consultar
    console.log('user:', user);
    if (user.role !== 'admin' && user.identification !== identification) {
      console.log('Unauthorized access attempt:', { user, identification });
      return res.status(403).json({ error: { code: 'FORBIDDEN', message: 'No autorizado', timestamp: new Date().toISOString(), path: req.path }});
    }
    res.status(200).json({ user: found });
  } catch (error) {
    next(error);
  }
};

const getAllUsers = async (req, res, next) => {
  try {
    const result = await db.query('SELECT * FROM usuario');
    res.status(200).json({ users: result.rows });
  } catch (error) {
    next(error);
  }
};

// Actualizar usuario (solo admin)
const updateUser = async (req, res, next) => {
  const { id } = req.params;
  const user = req.user;
  if (user.role !== 'admin') {
    return res.status(403).json({ error: { code: 'FORBIDDEN', message: 'Solo admin puede actualizar usuarios', timestamp: new Date().toISOString(), path: req.path }});
  }
  const {
    nombre,
    primer_apellido,
    segundo_apellido,
    correo,
    telefono,
    usuario: username,
    rol: newRol
  } = req.body;

  // Si algún campo no viene, envía null
  const params = [
    id,
    nombre !== undefined ? nombre : null,
    primer_apellido !== undefined ? primer_apellido : null,
    segundo_apellido !== undefined ? segundo_apellido : null,
    correo !== undefined ? correo : null,
    telefono !== undefined ? telefono : null,
    username !== undefined ? username : null,
    newRol !== undefined ? newRol : null
  ];
  try {
    const result = await db.query('SELECT * FROM sp_users_update($1, $2, $3, $4, $5, $6, $7, $8)', params);
    const success = result.rows[0]?.success;
    if (!success) {
      return res.status(400).json({ error: { code: 'UPDATE_FAILED', message: 'No se pudo actualizar el usuario', timestamp: new Date().toISOString(), path: req.path }});
    }
    res.status(200).json({ message: 'Usuario actualizado exitosamente' });
  } catch (error) {
    next(error);
  }
};

// Eliminar usuario (solo admin)
const deleteUser = async (req, res, next) => {
  const { id } = req.params;
  const user = req.user;
  if (user.role !== 'admin') {
    return res.status(403).json({ error: { code: 'FORBIDDEN', message: 'Solo admin puede eliminar usuarios', timestamp: new Date().toISOString(), path: req.path }});
  }
  try {
    const result = await db.query('SELECT * FROM sp_users_delete($1)', [id]);
    const success = result.rows[0]?.success;
    if (!success) {
      return res.status(400).json({ error: { code: 'DELETE_FAILED', message: 'No se pudo eliminar el usuario', timestamp: new Date().toISOString(), path: req.path }});
    }
    res.status(200).json({ message: 'Usuario eliminado exitosamente' });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  createUser,
  getUserByIdentification,
  getAllUsers,
  updateUser,
  deleteUser
};
