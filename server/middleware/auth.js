const { getAuth } = require("../firebase");

async function requireAuth(req, res, next) {
  try {
    const header = req.headers.authorization || "";
    const match = header.match(/^Bearer\s+(.+)$/i);
    if (!match) {
      return res.status(401).json({
        error: "auth-required",
        message: "Missing Authorization Bearer token.",
      });
    }

    const decoded = await getAuth().verifyIdToken(match[1]);
    req.uid = decoded.uid;
    req.token = decoded;
    return next();
  } catch (err) {
    return res.status(401).json({
      error: "invalid-token",
      message: "Invalid or expired ID token.",
    });
  }
}

module.exports = { requireAuth };
