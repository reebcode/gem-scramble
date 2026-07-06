import { Request } from "express";
import { User } from "@prisma/client";
import {
  getOrCreateUserByAuthUid,
  getUserById,
} from "../services/database.js";
import { isDevAuth } from "../config/auth.js";

/**
 * Retrieves the user for the current request, handling both Firebase and dev modes.
 * In Firebase mode, identity comes from the verified token payload attached by
 * the auth middleware. In dev mode, an explicit userId is read from the query
 * or body.
 * @param req The Express request object.
 * @returns The user object.
 */
export async function getRequestingUser(req: Request): Promise<User> {
  if (isDevAuth()) {
    const userId = req.body?.userId || req.query?.userId;
    if (typeof userId !== "string") {
      throw new Error(
        "A 'userId' is required in the body or query in dev mode."
      );
    }
    return getUserById(userId);
  } else {
    // In Firebase mode, the authFirebase middleware attaches the user payload
    const authUid = (req as any).user?.uid;
    if (typeof authUid !== "string") {
      throw new Error(
        "User not authenticated. No Firebase UID found in request."
      );
    }
    return getOrCreateUserByAuthUid(authUid);
  }
}
