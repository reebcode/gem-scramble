import { Router, Request } from "express";
import { z } from "zod";
import {
  getOrCreateUserByAuthUid,
  getUserById,
  prisma,
} from "../services/database.js";
import { MatchPlayer } from "../state/match.interface.js";
import { isDevAuth } from "../config/auth.js";
import { User } from "@prisma/client";

const router = Router();

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

// GET /users/me - Get current user profile
router.get("/me", async (req, res) => {
  try {
    const user = await getRequestingUser(req);
    const needsUsername = !user.username || user.username.trim() === "";

    res.json({
      id: user.id,
      username: user.username,
      needsUsername,
      cash: user.cashBalance,
      bonusCash: user.bonusBalance,
      gems: user.gemBalance,
      createdAt: user.createdAt.toISOString(),
      lastActiveAt: user.updatedAt.toISOString(),
    });
  } catch (error: any) {
    console.error("Failed to get user data:", error);
    res.status(500).json({
      error: "Failed to get user data",
      details: error.message,
    });
  }
});

const SetUsernameSchema = z.object({
  username: z.string().min(1).max(20),
});

// POST /users/username - Set or update a user's username
router.post("/username", async (req, res) => {
  const parsed = SetUsernameSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.message });
  }
  const { username } = parsed.data;

  try {
    const user = await getRequestingUser(req);

    const existingUser = await prisma.user.findUnique({
      where: { username },
    });

    if (existingUser && existingUser.id !== user.id) {
      return res.status(409).json({ error: "Username already taken" });
    }

    const updatedUser = await prisma.user.update({
      where: { id: user.id },
      data: { username },
    });

    res.json({
      id: updatedUser.id,
      username: updatedUser.username,
      needsUsername: false,
    });
  } catch (error: any) {
    console.error("Failed to set username:", error);
    res.status(500).json({
      error: "Failed to set username",
      details: error.message,
    });
  }
});

const DevLoginSchema = z.object({
  username: z.string().min(1).max(20),
});

// POST /users/login-or-register - Dev mode only
router.post("/login-or-register", async (req, res) => {
  if (!isDevAuth()) {
    return res
      .status(403)
      .json({ error: "This endpoint is only available in dev mode." });
  }

  console.log("Request body:", req.body);
  console.log("Request headers:", req.headers);

  const parsed = DevLoginSchema.safeParse(req.body);
  if (!parsed.success) {
    console.error("Schema validation failed:", parsed.error);
    return res.status(400).json({ error: parsed.error.message });
  }
  const { username } = parsed.data;

  try {
    console.log(`Attempting to login/register user: ${username}`);

    let user = await prisma.user.findUnique({
      where: { username },
    });

    if (!user) {
      console.log(`User ${username} not found, creating new user`);
      user = await prisma.user.create({
        data: {
          username,
          cashBalance: 10000, // Generous starting balance for dev
          bonusBalance: 1000,
          gemBalance: 100,
        },
      });
      console.log(`Created new user: ${user.id}`);
    } else {
      console.log(`Found existing user: ${user.id}`);
    }

    res.json({
      id: user.id,
      username: user.username,
      needsUsername: !user.username,
      cash: user.cashBalance,
      bonusCash: user.bonusBalance,
      gems: user.gemBalance,
      createdAt: user.createdAt.toISOString(),
      lastActiveAt: user.updatedAt.toISOString(),
    });
  } catch (error: any) {
    console.error("Failed to login or register in dev mode:", error);
    console.error("Error stack:", error.stack);
    console.error("Error name:", error.name);
    console.error("Error code:", error.code);
    res.status(500).json({
      error: "Failed to login or register",
      details: error.message,
      stack: error.stack,
    });
  }
});

// GET /users/matches - Get user's match history
router.get("/matches", async (req, res) => {
  try {
    const user = await getRequestingUser(req);

    const recentMatches = await prisma.completedMatch.findMany({
      where: {
        players: {
          string_contains: `\"id\":\"${user.id}\"`,
        },
      },
      orderBy: { endedAt: "desc" },
      take: 50,
    });

    const formattedMatches = recentMatches
      .map((match) => {
        const players = match.players as unknown as MatchPlayer[];
        if (!players || !Array.isArray(players)) return null;

        const userPlayer = players.find((p: MatchPlayer) => p.id === user.id);
        const otherPlayer = players.find((p: MatchPlayer) => p.id !== user.id);
        return {
          matchId: match.id,
          lobbyId: match.lobbyType,
          status: match.status,
          createdAt: match.createdAt.toISOString(),
          startedAt: match.startedAt?.toISOString(),
          endedAt: match.endedAt.toISOString(),
          entryFee: match.entryFee,
          prizePool: match.prizePool,
          myScore: userPlayer?.score || 0,
          opponentScore: otherPlayer?.score || 0,
        };
      })
      .filter((match) => match !== null);

    res.json({ matches: formattedMatches || [] });
  } catch (error: any) {
    console.error("Failed to get user matches:", error);
    res.status(500).json({
      error: "Failed to get user matches",
      details: error.message,
    });
  }
});

export default router;
