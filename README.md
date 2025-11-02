
# API REST - Sistema Bancario

API REST desarrollada con Node.js y Express.js como backend para un sistema bancario, implementando autenticación segura, control de roles y operaciones CRUD sobre PostgreSQL mediante Stored Procedures.

## Tecnologías

- Node.js 22
- Express.js
- Firebase Functions
- PostgreSQL
- JWT (JSON Web Token)
- Bcrypt para encriptación

## Estructura del Proyecto

```
Api-Banco/
├── functions/
│   ├── index.js                # Punto de entrada de la aplicación
│   ├── package.json            # Dependencias del proyecto
│   ├── config/
│   │   └── database.js         # Configuración de conexión a PostgreSQL
│   ├── controllers/            # Lógica de negocio
│   ├── routes/                 # Definición de endpoints
│   ├── middlewares/            # Autenticación y manejo de errores
│   └── SQL/                    # Scripts de base de datos
└── docs/                       # Colecciones de Postman
```

## Instalación

1. Clonar el repositorio:
```bash
git clone https://github.com/LuisK19/API-BCN
cd Api-Banco
```

2. Instalar dependencias:
```bash
cd functions
npm install
```

3. Configurar variables de entorno:
Crear archivo `.env` en la carpeta `functions/`:
```env
NODE_ENV=development
JWT_SECRET=tu_clave_secreta_jwt

PGUSER=user_bcn
PGHOST=134.199.141.222
PGPORT=15434
PGDATABASE=fecr_bcn
PGPASSWORD=tu_password
PGSSL=false
```

## Ejecución

**Desarrollo local:**
```bash
npm run serve
```

**Despliegue a Firebase:**
```bash
firebase deploy --only functions
```

**URL de producción:**
```
https://us-central1-api-banco-web.cloudfunctions.net/api
```

## Endpoints Principales

Todos los endpoints están bajo el prefijo `/api/v1`

### Autenticación
- `POST /auth/login` - Iniciar sesión
- `POST /auth/forgot-password` - Recuperar contraseña
- `POST /auth/verify-otp` - Verificar código OTP
- `POST /auth/reset-password` - Restablecer contraseña

### Usuarios
- `POST /users` - Crear usuario
- `GET /users/:identification` - Consultar usuario
- `PUT /users/:id` - Actualizar usuario
- `DELETE /users/:id` - Eliminar usuario

### Cuentas
- `POST /accounts` - Crear cuenta
- `GET /accounts` - Listar cuentas
- `GET /accounts/:accountid` - Detalle de cuenta
- `POST /accounts/:accountid/status` - Cambiar estado
- `GET /accounts/:accountid/movements` - Listar movimientos

### Tarjetas
- `POST /cards` - Crear tarjeta
- `GET /cards` - Listar tarjetas
- `GET /cards/:cardid` - Detalle de tarjeta
- `GET /cards/:cardid/movements` - Movimientos de tarjeta
- `POST /cards/:cardid/otp` - Generar OTP para PIN/CVV
- `POST /cards/:cardid/view-details` - Ver detalles sensibles

### Transferencias
- `POST /transfers/internal` - Transferencia interna

### Validación
- `POST /bank/validate-account` - Validar cuenta bancaria

### Auditoría
- `GET /audit/:userId` - Historial de auditoría

## Autenticación

**API Key (endpoints públicos):**
```
x-api-key: tu-api-key
```

**JWT (endpoints protegidos):**
```
Authorization: Bearer <token>
```

## Códigos de Estado HTTP

| Código | Descripción |
|--------|-------------|
| 200 | Operación exitosa |
| 201 | Recurso creado |
| 400 | Solicitud incorrecta |
| 401 | No autenticado |
| 403 | No autorizado |
| 404 | No encontrado |
| 500 | Error del servidor |

## Formato de Respuestas

**Éxito:**
```json
{
  "data": { ... },
  "pagination": { "page": 1, "limit": 10 }
}
```

**Error:**
```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Descripción del error",
    "timestamp": "2025-11-02T10:30:00.000Z",
    "path": "/api/v1/endpoint"
  }
}
```

## Documentación

- Repositorio: https://github.com/LuisK19/API-BCN
- Postman: https://documenter.getpostman.com/view/48954743/2sB3WpRLnA
- Firebase (API): https://console.firebase.google.com/u/0/project/api-banco-web/overview
- Colecciones Postman en: `functions/docs/`

## Seguridad

- Contraseñas encriptadas con bcrypt
- PIN y CVV cifrados en base de datos
- Tokens JWT con expiración
- Validación de roles (admin/client)
- Validación de propiedad de recursos