import { Router } from "express";
import { z } from "zod";
import { prisma } from "../services/database.js";
import { MatchPlayer } from "../state/match.interface.js";
import { getRequestingUser } from "../utils/requestUser.js";
import { isDevAuth } from "../config/auth.js";

const router = Router();

// GET /users/me - Get current user profile
router.get("/me", async (req, res) => {
  try {
    const user = await getRequestingUser(req);
    const needsUsername = !user.username || user.username.trim() === "";

    res.json({
      id: user.id,
      username: user.username,
      needsUsername,
      gems: user.gemBalance,
      bonusGems: user.bonusGems,
      createdAt: user.createdAt.toISOString(),
      lastActiveAt: user.updatedAt.toISOString(),
    });
  } catch (error: any) {
    console.error("Failed to get user data:", error);
    res.status(500).json({ error: "Failed to get user data" });
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
    res.status(500).json({ error: "Failed to set username" });
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

  const parsed = DevLoginSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.message });
  }
  const { username } = parsed.data;

  try {
    let user = await prisma.user.findUnique({
      where: { username },
    });

    if (!user) {
      user = await prisma.user.create({
        data: {
          username,
          // Generous starting balance for dev/testing.
          gemBalance: 1000,
          bonusGems: 100,
        },
      });
    }

    res.json({
      id: user.id,
      username: user.username,
      needsUsername: !user.username,
      gems: user.gemBalance,
      bonusGems: user.bonusGems,
      createdAt: user.createdAt.toISOString(),
      lastActiveAt: user.updatedAt.toISOString(),
    });
  } catch (error: any) {
    console.error("Failed to login or register in dev mode:", error);
    res.status(500).json({ error: "Failed to login or register" });
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
    res.status(500).json({ error: "Failed to get user matches" });
  }
});

export default router;
