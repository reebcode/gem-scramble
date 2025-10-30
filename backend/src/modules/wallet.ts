import { Router, Request } from "express";
import { z } from "zod";
import {
  prisma,
  getOrCreateUserByAuthUid,
  getUserById,
} from "../services/database.js";
import { isDevAuth } from "../config/auth.js";
import { User } from "@prisma/client";

const router = Router();

const GetTransactionsSchema = z.object({
  limit: z.coerce.number().int().positive().default(50),
  offset: z.coerce.number().int().nonnegative().default(0),
});

/**
 * Retrieves the user for the current request, handling both Firebase and dev modes.
 * In Firebase mode, it uses the auth UID from the token.
 * In dev mode, it uses the userId from the query or body.
 * @param req The Express request object.
 * @returns The user object.
 */
async function getRequestingUser(req: Request): Promise<User> {
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

// GET /wallet/transactions?limit=50&offset=0
router.get("/transactions", async (req, res) => {
  try {
    const user = await getRequestingUser(req);
    const parsed = GetTransactionsSchema.safeParse(req.query);
    if (!parsed.success) {
      return res.status(400).json({ error: parsed.error.message });
    }
    const { limit, offset } = parsed.data;

    const transactions = await prisma.transaction.findMany({
      where: { userId: user.id },
      orderBy: { createdAt: "desc" },
      take: limit,
      skip: offset,
    });

    const formattedTransactions = transactions.map((tx) => ({
      txId: tx.id,
      type: tx.type,
      amount: tx.amount,
      currency: tx.currency === "bonus" ? "bonusCash" : tx.currency,
      timestamp: tx.createdAt.toISOString(),
      description: tx.note || "",
      matchId: tx.matchId || undefined,
      lobbyId: tx.lobbyType || undefined,
      status: "completed" as const,
    }));

    res.json({ transactions: formattedTransactions });
  } catch (error: any) {
    console.error("Failed to get transactions:", error);
    res.status(500).json({
      error: "Failed to get transactions",
      details: error.message,
    });
  }
});

export default router;
