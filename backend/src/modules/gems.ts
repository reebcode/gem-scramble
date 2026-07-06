import { Router, Request } from "express";
import { z } from "zod";
import {
  prisma,
  getUserById,
  addTransaction,
} from "../services/database.js";
import { getRequestingUser } from "../utils/requestUser.js";
import { isDevAuth } from "../config/auth.js";
import { User } from "@prisma/client";

const router = Router();

/**
 * Check if the requesting user has admin privileges.
 * TODO: Implement proper admin role checking (e.g., via Firebase custom claims or database roles)
 * For now, this is a placeholder that should be replaced with actual admin verification.
 */
async function isAdmin(req: Request): Promise<boolean> {
  // SECURITY: This is a placeholder. In production, you should:
  // 1. Check Firebase custom claims for admin role
  // 2. Or check a database field for admin status
  // 3. Or use a separate admin API key/secret
  
  if (isDevAuth()) {
    // In dev mode, allow admin operations (WARNING: Not secure for production!)
    return true;
  }
  
  // In production, check Firebase custom claims
  const authUid = (req as any).user?.uid;
  if (!authUid) return false;
  
  // TODO: Implement Firebase Admin SDK to check custom claims
  // const admin = await getFirebaseAdmin();
  // const user = await admin.auth().getUser(authUid);
  // return user.customClaims?.admin === true;
  
  // For now, deny all admin operations in production until properly implemented
  return false;
}

const AwardGemsSchema = z.object({
  amount: z.coerce.number().int().positive().max(10000), // Max 10,000 gems per award
  reason: z.string().min(1).max(500),
  targetUserId: z.string().uuid().optional(), // Optional: award to specific user (admin only)
});

// POST /gems/award - Award bonus gems to a user
// SECURITY: This endpoint requires admin privileges
router.post("/award", async (req, res) => {
  try {
    // Check admin privileges
    const admin = await isAdmin(req);
    if (!admin) {
      return res.status(403).json({
        error: "Forbidden",
        message: "Admin privileges required to award gems",
      });
    }

    const parsed = AwardGemsSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: parsed.error.message });
    }

    const { amount, reason, targetUserId } = parsed.data;

    // Determine target user: if targetUserId provided, use it; otherwise award to requesting user
    let targetUser: User;
    if (targetUserId) {
      // Admin awarding to specific user
      targetUser = await getUserById(targetUserId);
    } else {
      // Awarding to self (only in dev mode or if explicitly allowed)
      targetUser = await getRequestingUser(req);
    }

    // Create transaction atomically
    await addTransaction(
      targetUser.id,
      "bonus",
      amount,
      "bonus_gems",
      reason
    );

    res.json({
      success: true,
      message: `Awarded ${amount} bonus gems to user ${targetUser.id}`,
      userId: targetUser.id,
      amount,
    });
  } catch (error: any) {
    console.error("Failed to award gems:", error);
    res.status(500).json({ error: "Failed to award gems" });
  }
});

export default router;

