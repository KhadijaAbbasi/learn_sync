const path = require("path");
const admin = require("firebase-admin");

let initialized = false;

function initFirebase() {
  if (initialized) {
    return admin;
  }

  const credPath =
    process.env.GOOGLE_APPLICATION_CREDENTIALS ||
    process.env.FIREBASE_SERVICE_ACCOUNT ||
    "";

  if (!credPath || credPath.includes("path/to/")) {
    throw new Error(
      "Set GOOGLE_APPLICATION_CREDENTIALS (or FIREBASE_SERVICE_ACCOUNT) in server/.env to your service account JSON path."
    );
  }

  const resolved = path.isAbsolute(credPath)
    ? credPath
    : path.resolve(__dirname, credPath);

  // eslint-disable-next-line import/no-dynamic-require, global-require
  const serviceAccount = require(resolved);

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });

  initialized = true;
  return admin;
}

function getAuth() {
  return initFirebase().auth();
}

function getDb() {
  return initFirebase().firestore();
}

module.exports = { initFirebase, getAuth, getDb, admin };
