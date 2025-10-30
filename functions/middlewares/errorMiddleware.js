const errorHandler = (err, req, res, next) => {
  const timestamp = new Date().toISOString();
  const path = req.path;

  let errorCode = "INTERNAL_ERROR";
  let statusCode = 500;
  let message = "Internal Server Error";
  let details = {};

  if (err.code === "23505") {
    statusCode = 409;
    errorCode = "CONFLICT";
    message = "Resource already exists";
    details = {field: err.detail};
  } else if (err.statusCode) {
    statusCode = err.statusCode;
    errorCode = err.errorCode || "CUSTOM_ERROR";
    message = err.message;
    details = err.details || {};
  }

  const errorResponse = {
    error: {
      code: errorCode,
      message: message,
      details: details,
      timestamp: timestamp,
      path: path,
    },
  };

  // Log the error for debugging
  console.error(err);

  res.status(statusCode).json(errorResponse);
};

module.exports = errorHandler;
