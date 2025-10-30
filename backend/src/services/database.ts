import { Prisma, PrismaClient } from "@prisma/client";

export const prisma = new PrismaClient();

/**
 * Finds a user by their Firebase Authentication UID or creates a new one if not found.
 * This is the primary way to provision users in production.
 * @param authUid The Firebase UID.
 * @returns The existing or newly created user.
 */
export async function getOrCreateUserByAuthUid(authUid: string) {
  const existing = await prisma.user.findUnique({
    where: { authUid },
    include: { transactions: true },
  });

  if (existing) {
    return existing;
  }

  // Create a new user if one doesn't exist for this authUid
  const created = await prisma.user.create({
    data: {
      authUid,
      // Initial balances for new users - start with 100 free gems
      gemBalance: 100,
      bonusGems: 0,
    },
    include: { transactions: true },
  });
  return created;
}

/**
 * Finds a user by their internal database ID.
 * Throws an error if the user is not found.
 * @param userId The user's internal ID.
 * @returns The user.
 */
export async function getUserById(userId: string) {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    include: { transactions: true },
  });
  if (!user) {
    throw new Error(`User with ID ${userId} not found.`);
  }
  return user;
}

// Helper function to add transaction
export async function addTransaction(
  userId: string,
  type: string,
  amount: number,
  currency: "gems" | "bonus_gems",
  note?: string,
  matchId?: string,
  lobbyType?: string
) {
  // Atomic create + balance update
  try {
    const result = await prisma.$transaction(async (tx) => {
      const transaction = await tx.transaction.create({
        data: {
          userId,
          type,
          amount,
          currency,
          note,
          matchId,
          lobbyType,
        },
      });

      const balanceField = currency === "gems" ? "gemBalance" : "bonusGems";
      await tx.user.update({
        where: { id: userId },
        data: { [balanceField]: { increment: amount } },
      });

      return transaction;
    });
    return result;
  } catch (err: any) {
    // Treat duplicate (userId, matchId, type) as idempotent success
    if (
      err instanceof Prisma.PrismaClientKnownRequestError &&
      err.code === "P2002"
    ) {
      return null;
    }
    throw err;
  }
}

// Helper function to get user balance
export async function getUserBalance(userId: string) {
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user) throw new Error("user not found");
  return {
    gems: user.gemBalance,
    bonusGems: user.bonusGems,
  };
}

// Helper function to try debit from user
export async function tryDebitUser(
  userId: string,
  amountGems: number,
  opts: { lobbyType?: string; matchId?: string }
): Promise<boolean> {
  try {
    const success = await prisma.$transaction(async (tx) => {
      const user = await tx.user.findUnique({ where: { id: userId } });
      if (!user) return false;

      // Use gems first, then bonus gems
      let usedGems = Math.min(user.gemBalance, amountGems);
      let usedBonusGems = 0;

      if (usedGems < amountGems) {
        const need = amountGems - usedGems;
        usedBonusGems = Math.min(user.bonusGems, need);
      }

      if (usedGems + usedBonusGems < amountGems) {
        return false; // insufficient gems
      }

      const totalDebited = usedGems + usedBonusGems;

      // Create entry fee record first; if this is a duplicate, throw P2002 and abort
      await tx.transaction.create({
        data: {
          userId: user.id,
          type: "entryFee",
          amount: -totalDebited,
          currency: "gems",
          note:
            usedBonusGems > 0
              ? `Match entry fee (${usedGems} gems, ${usedBonusGems} bonus gems)`
              : `Match entry fee (${usedGems} gems)`,
          matchId: opts.matchId,
          lobbyType: opts.lobbyType,
        },
      });

      // Then update balances
      await tx.user.update({
        where: { id: user.id },
        data: {
          gemBalance: { increment: -usedGems },
          bonusGems: { increment: -usedBonusGems },
        },
      });

      return true;
    });
    return success;
  } catch (err: any) {
    if (
      err instanceof Prisma.PrismaClientKnownRequestError &&
      err.code === "P2002"
    ) {
      // Duplicate entryFee for this user/match/type → already debited
      return true;
    }
    console.error("tryDebitUser failed:", err);
    return false;
  }
}

// Helper function to credit prize to user
export async function creditPrize(
  userId: string,
  amountGems: number,
  opts: { lobbyType?: string; matchId?: string; place?: number }
): Promise<void> {
  if (amountGems <= 0) return;
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user) return;
  try {
    const place = opts.place ?? 1;
    const suffix =
      place % 10 === 1 && place % 100 !== 11
        ? "st"
        : place % 10 === 2 && place % 100 !== 12
        ? "nd"
        : place % 10 === 3 && place % 100 !== 13
        ? "rd"
        : "th";
    await addTransaction(
      user.id,
      "prize",
      amountGems,
      "gems",
      `Prize for ${place}${suffix} place`,
      opts.matchId,
      opts.lobbyType
    );
  } catch (err: any) {
    if (
      err instanceof Prisma.PrismaClientKnownRequestError &&
      err.code === "P2002"
    ) {
      // Prize already credited for this user/match/type
      return;
    }
    console.error(`Failed to credit prize for user ${userId}:`, err);
  }
}
