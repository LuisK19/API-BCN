const jwt = require("jsonwebtoken");

const apiKeyMiddleware = (req, res, next) => {
  const apiKey = req.headers["x-api-key"];
  if (!apiKey) {
    return res.status(401).json({
      error: {
        code: "UNAUTHORIZED",
        message: "API Key is required",
        timestamp: new Date().toISOString(),
        path: req.path,
      },
    });
  }
  // La validación real se hace en el controlador usando el SP y bcrypt
  next();
};

const jwtMiddleware = (req, res, next) => {
  let token;
  if (req.headers["authorization"]) {
    const parts = req.headers["authorization"].split(" ");
    token = parts.length === 2 ? parts[1] : undefined;
  }
  if (!token) {
    return res.status(401).json({
      error: {
        code: "UNAUTHORIZED",
        message: "Token is required",
        timestamp: new Date().toISOString(),
        path: req.path,
      },
    });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded;
    next();
  } catch (error) {
    return res.status(401).json({
      error: {
        code: "UNAUTHORIZED",
        message: "Invalid or expired token",
        timestamp: new Date().toISOString(),
        path: req.path,
      },
    });
  }
};

const roleMiddleware = (roles) => {
  return (req, res, next) => {
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({
        error: {
          code: "FORBIDDEN",
          message: "Insufficient permissions",
          timestamp: new Date().toISOString(),
          path: req.path,
        },
      });
    }
    next();
  };
};

module.exports = {
  apiKeyMiddleware,
  jwtMiddleware,
  roleMiddleware,
  authenticateToken: jwtMiddleware,
};
