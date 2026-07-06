import admin from "firebase-admin";

let initialized = false;

export function initFirebase() {
  if (initialized) return;
  if (
    !process.env.FIREBASE_PROJECT_ID ||
    !process.env.FIREBASE_CLIENT_EMAIL ||
    !process.env.FIREBASE_PRIVATE_KEY
  ) {
    console.warn(
      "Firebase Admin not configured; auth middleware will allow all requests in dev."
    );
    initialized = true;
    return;
  }

  admin.initializeApp({
    credential: admin.credential.cert({
      projectId: process.env.FIREBASE_PROJECT_ID,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, "\n"),
    }),
  });
  initialized = true;
}

export async function verifyIdToken(
  idToken: string
): Promise<admin.auth.DecodedIdToken | null> {
  try {
    if (!admin.apps.length) return null;
    return await admin.auth().verifyIdToken(idToken);
  } catch {
    return null;
  }
}
