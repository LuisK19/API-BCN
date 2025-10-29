
# API REST - Proyecto 2 - IC8057

API REST desarrollada para el sistema bancario del Proyecto 2 de IC8057, siguiendo los requisitos académicos: autenticación segura, control de roles, integración con procedimientos almacenados (SPs) y manejo robusto de errores.

## Objetivo general

Desarrollar una API REST funcional y segura que sirva como backend para el sistema bancario, implementando autenticación, control de roles y conexión con una base de datos relacional mediante Stored Procedures.

## Objetivos específicos

- Modelar y crear una base de datos relacional con SPs para usuarios, cuentas, tarjetas y movimientos.
- Implementar endpoints REST para operaciones CRUD sobre las entidades principales.
- Integrar autenticación y autorización usando API Key y JWT, validando roles y propiedad de recursos.
- Validar integridad y acceso en cada endpoint, devolviendo errores adecuados.
- Garantizar respuestas JSON estructuradas y uso correcto de códigos HTTP.
- Documentar y entregar la API con pruebas Postman y guía de uso.

## Requisitos generales

- Node.js + Express.js
- PostgreSQL con SPs para todas las operaciones
- Autenticación inicial por API Key, operaciones protegidas por JWT
- Validación de roles y propiedad de recursos
- Respuestas JSON uniformes y manejo de errores
- Documentación completa y colección Postman

## Estructura del Proyecto

```
node-rest-api/
├── app.js                      # Archivo principal
├── package.json                # Configuración del proyecto
├── .env                        # Variables de entorno
├── controllers/                # Lógica de negocio y conexión con SPs
├── routes/                     # Definición de rutas REST
├── middlewares/                # Autenticación, autorización y errores
├── utils/                      # Utilidades varias
├── SQL/                        # Scripts de SPs y estructura de BD
└── docs/                       # Colección Postman y documentación
```


## Instalación y ejecución

1. **Clonar el repositorio**
  ```bash
  git clone <url-del-repositorio>
  cd node-rest-api
  ```
2. **Instalar dependencias**
  ```bash
  npm install
  ```
3. **Configurar variables de entorno**
  Crea un archivo `.env` en la raíz del proyecto:
  ```env
  PORT=3000
  API_KEY=tu_api_key_para_autenticacion
  JWT_SECRET=tu_clave_secreta_jwt_muy_segura
  DEV_DB_USER=usuario
  DEV_DB_HOST=localhost
  DEV_DB_PORT=5432
  DEV_DB_NAME=nombre_bd
  DEV_DB_PASSWORD=tu_password
  DEV_DB_SSL=false
  ```
4. **Ejecutar la aplicación**
  ```bash
  npm run dev   # Modo desarrollo
  npm start     # Modo producción
  ```
  El servidor se ejecutará en `http://localhost:3000`



## Endpoints implementados y Stored Procedures (SP) asociadas

| Método | Ruta | Descripción | SP asociada | Estado |
|--------|------|-------------|-------------|--------|
| POST   | /api/v1/auth/login           | Login usuario/email + contraseña | sp_auth_user_get_by_username_or_email, sp_api_key_is_active | ✅ |
| POST   | /api/v1/auth/forgot-password | Generar OTP para recuperación    | sp_otp_create | ✅ |
| POST   | /api/v1/auth/verify-otp      | Verificar y consumir OTP         | sp_otp_consume | ✅ |
| POST   | /api/v1/auth/reset-password  | Resetear contraseña con OTP      | sp_otp_consume | ✅ |
| POST   | /api/v1/users                | Crear usuario                    | sp_users_create | ✅ |
| GET    | /api/v1/users/:identification| Consultar usuario por identificación | sp_users_get_by_identification | ✅ |
| PUT    | /api/v1/users/:id            | Actualizar usuario               | sp_users_update | ✅ |
| DELETE | /api/v1/users/:id            | Eliminar usuario                 | sp_users_delete | ✅ |
| POST   | /api/v1/accounts             | Crear cuenta bancaria            | sp_accounts_create |  |
| GET    | /api/v1/accounts             | Listar cuentas de usuario        | sp_accounts_get |  |
| GET    | /api/v1/accounts/:accountid  | Consultar detalle de cuenta      | sp_accounts_get |  |
| POST   | /api/v1/accounts/:accountid/status | Cambiar estado de cuenta  | sp_accounts_set_status |  |
| GET    | /api/v1/accounts/:accountid/movements | Listar movimientos de cuenta | sp_account_movements_list |  |
| POST   | /api/v1/transfers/internal   | Transferencia interna            | sp_transfer_create_internal |  |
| POST   | /api/v1/cards                | Crear tarjeta                    | sp_cards_create |  |
| GET    | /api/v1/cards                | Listar tarjetas de usuario       | sp_cards_get |  |
| GET    | /api/v1/cards/:cardid        | Consultar detalle de tarjeta     | sp_cards_get |  |
| GET    | /api/v1/cards/:cardid/movements | Listar movimientos de tarjeta | sp_card_movements_list |  |
| POST   | /api/v1/cards/:cardid/movements | Agregar movimiento de tarjeta | sp_card_movement_add |  |
| POST   | /api/v1/cards/:cardid/otp    | Generar OTP para PIN/CVV         | sp_otp_create |  |
| POST   | /api/v1/cards/:cardid/view-details | Verificar OTP y ver PIN/CVV | sp_otp_consume |  |
| POST   | /api/v1/bank/validate-account| Validar cuenta bancaria          | sp_bank_validate_account |  |
| GET    | /api/v1/audit/:userId        | Consultar historial de auditoría | sp_audit_list_by_user |  |

**Estado:** Marca con ✅ los endpoints ya implementados y deja en blanco los pendientes.


## Pruebas y documentación

1. Importa la colección Postman desde `docs/Laboratorio-8-API-REST.postman_collection.json`
2. Importa el environment desde `docs/Laboratorio-8-Environment.postman_environment.json`
3. Ejecuta las pruebas siguiendo la guía en `docs/README.md`

### Headers requeridos

- Para endpoints públicos:
  ```
  x-api-key: tu-api-key
  ```
- Para endpoints protegidos:
  ```
  Authorization: Bearer <jwt-token-obtenido-del-login>
  ```
- Para negociación de contenido:
  ```
  Accept: application/json  # Para JSON (default)
  Accept: application/xml   # Para XML
  ```


## Códigos de estado HTTP

| Código | Descripción | Casos de uso |
|--------|-------------|--------------|
| 200    | OK          | Consultas exitosas |
| 201    | Created     | Recurso creado |
| 204    | No Content  | Recurso eliminado |
| 401    | Unauthorized| API Key/JWT faltante o inválido |
| 403    | Forbidden   | Permisos insuficientes |
| 404    | Not Found   | Recurso no encontrado |
| 409    | Conflict    | Duplicidad o conflicto |
| 422    | Unprocessable Entity | Errores de validación |
| 500    | Internal Server Error| Errores del servidor |


## Formato de respuestas

### Respuesta exitosa
```json
{
  "data": { ... },
  "pagination": { "page": 1, "limit": 10 }
}
```

### Respuesta de error
```json
{
  "error": {
    "code": "NOT_FOUND",
    "message": "Usuario no encontrado",
    "details": {},
    "timestamp": "2025-10-27T09:04:16.114Z",
    "path": "/api/v1/users/999"
  }
}
```


actualizar en base:


sp_accounts_create
sp_accounts_set_status
sp_cards_create
sp_cards_update_status
sp_users_change_password