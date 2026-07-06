import { Router } from "express";
import { z } from "zod";
import { prisma } from "../services/database.js";
import { getRequestingUser } from "../utils/requestUser.js";

const router = Router();

const GetTransactionsSchema = z.object({
  limit: z.coerce.number().int().positive().default(50),
  offset: z.coerce.number().int().nonnegative().default(0),
});

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
    res.status(500).json({ error: "Failed to get transactions" });
  }
});

export default router;
