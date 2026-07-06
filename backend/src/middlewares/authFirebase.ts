import { Request, Response, NextFunction } from "express";
import { verifyIdToken, initFirebase } from "../config/firebase.js";
import { isDevAuth } from "../config/auth.js";

initFirebase();

export async function authFirebase(
  req: Request,
  res: Response,
  next: NextFunction
) {
  const auth = req.headers.authorization;
  if (!auth) {
    if (isDevAuth()) {
      // Dev fallback: allow without token
      (req as any).user = { id: "dev" };
      return next();
    }
    return res.status(401).json({ error: "Unauthorized" });
  }
  const token = auth.replace("Bearer ", "");
  const decoded = await verifyIdToken(token);
  if (!decoded) return res.status(401).json({ error: "Unauthorized" });
  (req as any).user = { uid: decoded.uid };
  return next();
}
