import { Router, Request } from "express";
import { z } from "zod";
import { generateDiceBoard } from "../utils/board.js";
import { canFormWordOnBoard } from "../utils/wordValidation.js";
import { InternalMatch, MatchPlayer } from "../state/match.interface.js";
import { initDictionary, isWord } from "../services/dictionary.js";
import { getLobbyConfig, LOBBIES } from "../config/lobbies.js";
import {
  creditPrize,
  tryDebitUser,
  getOrCreateUserByAuthUid,
  getUserById,
} from "../services/database.js";
import { createMatchRepository } from "../repositories/matchRepository.js";
import { MatchRepository } from "../repositories/matchRepository.interface.js";
import { prisma } from "../services/database.js";
import { isDevAuth } from "../config/auth.js";
import { User } from "@prisma/client";
import { rankAndAllocateWinnings } from "../utils/payout.js";

const router = Router();

let _repo: MatchRepository | null = null;
function repo(): MatchRepository {
  if (!_repo) {
    _repo = createMatchRepository();
  }
  return _repo;
}

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

async function saveCompletedMatch(match: InternalMatch) {
  try {
    const cfg = getLobbyConfig(match.lobbyType);
    const rankedPlayers = rankAndAllocateWinnings(
      match.players,
      match.prizePool,
      cfg?.payoutMultipliers ?? []
    );

    await prisma.completedMatch.create({
      data: {
        id: match.id,
        lobbyType: match.lobbyType,
        entryFee: match.entryFee,
        prizePool: match.prizePool,
        gameDuration: match.gameDuration,
        status: match.status,
        createdAt: new Date(match.createdAt),
        startedAt: match.startedAt ? new Date(match.startedAt) : null,
        endedAt: new Date(match.endedAt!),
        board: match.board,
        players: rankedPlayers as any,
      },
    });

    console.log(`Saved completed match ${match.id} to database`);
  } catch (error) {
    console.error(`Failed to save completed match ${match.id}:`, error);
  }
}

const joinSchema = z.object({
  lobbyType: z.string().min(1),
  userId: z.string().min(1),
  playerName: z.string().min(1).optional(),
});

export async function createWaitingMatch(
  lobbyType: string
): Promise<InternalMatch | null> {
  const cfg = getLobbyConfig(lobbyType);
  if (!cfg) return null;
  const id = `${lobbyType}-${Date.now().toString(36)}`;
  console.log(`Creating new waiting match with ID: ${id}`);
  const board = generateDiceBoard(cfg.boardSize);
  const nowIso = new Date().toISOString();
  const match: InternalMatch = {
    id,
    lobbyType,
    board,
    createdAt: nowIso,
    startedAt: null,
    endedAt: null,
    entryFee: cfg.entryFee,
    prizePool: cfg.totalPrizeGems,
    gameDuration: cfg.gameDuration,
    players: [],
    status: "waiting",
    autoCompleteAt: new Date(Date.now() + 60 * 60 * 1000).toISOString(),
  };
  await repo().save(match);
  await repo().setWaiting(lobbyType, id);
  return match;
}

export async function ensureWaitingMatches() {
  for (const c of LOBBIES) {
    const id = await repo().getWaiting(c.lobbyType);
    if (!id) {
      await createWaitingMatch(c.lobbyType);
      continue;
    }
    const m = await repo().get(id);
    if (!m || m.status !== "waiting") {
      await repo().clearWaiting(c.lobbyType);
      await createWaitingMatch(c.lobbyType);
    }
  }
}

router.post("/join", async (req, res) => {
  const parsed = joinSchema.safeParse(req.body || {});
  if (!parsed.success) {
    return res.status(400).json({ error: "Invalid request data" });
  }
  const { lobbyType, userId } = parsed.data;
  const playerName = parsed.data.playerName || "Player";

  try {
    const nowIso = new Date().toISOString();

    // Check if user is already in any active match where they haven't submitted words
    const userMatches = await repo().listByUser(userId);
    const activeMatch = userMatches.find((m) => {
      if (m.status === "completed") return false; // Completed matches don't count

      const player = m.players.find((p) => p.id === userId);
      if (!player) return false;

      // User is in an active match and hasn't submitted words yet
      return !player.submittedAt;
    });

    // If user is in an active match, check if they're trying to join the same match
    if (activeMatch) {
      if (activeMatch.lobbyType === lobbyType) {
        // User is trying to rejoin their current match - allow it
        return res.json(toClientMatch(activeMatch, userId));
      } else {
        // User is trying to join a different match - block them
        return res.status(409).json({
          error:
            "User is already in an active match and hasn't submitted words yet",
          currentMatch: toClientMatch(activeMatch, userId),
        });
      }
    }

    // Find an available match with space for this lobby type
    const allMatches = await repo().listAll();
    const availableMatch = allMatches.find((m) => {
      return (
        m.lobbyType === lobbyType &&
        m.status === "waiting" &&
        m.players.length < (getLobbyConfig(lobbyType)?.maxPlayers ?? 7) &&
        !m.players.find((p) => p.id === userId)
      );
    });

    if (availableMatch) {
      // Join existing match
      const cfgExisting = getLobbyConfig(lobbyType);
      const ok = await tryDebitUser(userId, cfgExisting?.entryFee ?? 100, {
        lobbyType: lobbyType,
        matchId: availableMatch.id,
      });
      if (!ok) {
        return res.status(402).json({ error: "insufficient funds" });
      }

      const cfgForDeadline = getLobbyConfig(lobbyType);
      const deadlineAt = new Date(
        Date.now() + (cfgForDeadline?.gameDuration ?? 300) * 1000
      ).toISOString();
      availableMatch.players.push({
        id: userId,
        name: playerName,
        words: [],
        score: 0,
        joinedAt: nowIso,
        deadlineAt,
        paidEntry: true,
      });

      await repo().save(availableMatch);
      return res.json(toClientMatch(availableMatch, userId));
    }

    const cfg = getLobbyConfig(lobbyType);
    if (!cfg) {
      return res.status(400).json({ error: "Invalid lobby type" });
    }
    const board = generateDiceBoard(cfg.boardSize);
    const id = `${lobbyType}-${Date.now().toString(36)}`;
    const entryFee = cfg.entryFee;
    const prizePool = cfg.totalPrizeGems;
    const match: InternalMatch = {
      id,
      lobbyType,
      board,
      createdAt: nowIso,
      startedAt: null,
      endedAt: null,
      entryFee,
      prizePool,
      gameDuration: cfg.gameDuration,
      players: [
        {
          id: userId,
          name: playerName,
          words: [],
          score: 0,
          joinedAt: nowIso,
          deadlineAt: new Date(
            Date.now() + (cfg.gameDuration ?? 300) * 1000
          ).toISOString(),
          paidEntry: false,
        },
      ],
      status: "waiting",
      autoCompleteAt: new Date(Date.now() + 60 * 60 * 1000).toISOString(),
    };

    const paidEntry = await tryDebitUser(userId, entryFee, {
      lobbyType: lobbyType,
      matchId: id,
    });

    if (!paidEntry) {
      return res.status(402).json({ error: "insufficient funds" });
    }

    match.players[0].paidEntry = true;

    await repo().save(match);
    return res.json(toClientMatch(match, userId));
  } catch (error: any) {
    console.error(
      `Failed to join lobby ${lobbyType} for user ${userId}:`,
      error
    );
    res
      .status(500)
      .json({ error: "Failed to join lobby", details: error.message });
  }
});

const leaveMatchSchema = z.object({
  userId: z.string().min(1),
});

// POST /matches/leave
router.post("/leave", async (req, res) => {
  const parsed = leaveMatchSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: "Invalid request data" });
  }
  const { userId } = parsed.data;

  try {
    const userMatches = await repo().listByUser(userId);
    const activeMatch = userMatches.find((m: InternalMatch) => {
      if (m.status === "completed") return false;

      const player = m.players.find((p: MatchPlayer) => p.id === userId);
      return player && !player.submittedAt; // Only matches where user hasn't submitted
    });

    if (!activeMatch) {
      return res.status(404).json({
        error: "No active match found where user hasn't submitted words",
      });
    }

    // Remove user from the match
    activeMatch.players = activeMatch.players.filter(
      (p: MatchPlayer) => p.id !== userId
    );

    // If no players left, delete the match
    if (activeMatch.players.length === 0) {
      await repo().clearWaiting(activeMatch.lobbyType);
      // Note: We don't have a delete method in the repository, so we'll just clear the waiting status
    } else {
      // Save the updated match
      await repo().save(activeMatch);
    }

    res.json({ success: true, message: "Left match successfully" });
  } catch (error: any) {
    console.error(`Failed to leave match for user ${userId}:`, error);
    res
      .status(500)
      .json({ error: "Failed to leave match", details: error.message });
  }
});

const submitSchema = z.object({
  userId: z.string().min(1),
  words: z.array(z.string()).default([]),
});

const saveWordsSchema = z.object({
  userId: z.string().min(1),
  words: z.array(z.string()).default([]),
});

const validateWordSchema = z.object({
  // userId provided only in dev mode; in production we use Firebase auth
  userId: z.string().min(1).optional(),
  word: z.string().min(1),
});

// POST /matches/:matchId/save-words - Save words without submitting
router.post("/:matchId/save-words", async (req, res) => {
  const { matchId } = req.params;
  const parsed = saveWordsSchema.safeParse(req.body || {});
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.message });
  }
  const { userId, words } = parsed.data;

  const match = await repo().get(matchId);
  if (!match) return res.status(404).json({ error: "match not found" });

  const player = match.players.find((p: MatchPlayer) => p.id === userId);
  if (!player) return res.status(404).json({ error: "player not in match" });

  // Just save the words without validation or scoring
  player.words = words.map((w) => String(w).trim().toUpperCase());
  await repo().save(match);

  res.json({ ok: true, savedWords: player.words });
});

// POST /matches/:matchId/validate - Validate a single word against dictionary and board
router.post("/:matchId/validate", async (req, res) => {
  const { matchId } = req.params;
  const parsed = validateWordSchema.safeParse(req.body || {});
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.message });
  }
  const { word } = parsed.data;

  try {
    const user = await getRequestingUser(req);
    const userId = user.id;
    const match = await repo().get(matchId);
    if (!match) return res.status(404).json({ error: "match not found" });

    const player = match.players.find((p: MatchPlayer) => p.id === userId);
    if (!player) return res.status(404).json({ error: "player not in match" });

    await initDictionary();
    const normalized = String(word).trim().toUpperCase();
    const basicOk = normalized.length >= 3 && /^[A-Z]+$/.test(normalized);
    const valid =
      basicOk &&
      isWord(normalized) &&
      canFormWordOnBoard(match.board, normalized);

    return res.json({ ok: true, valid, normalized });
  } catch (error: any) {
    console.error("Failed to validate word:", error);
    return res.status(500).json({
      ok: false,
      error: "Failed to validate word",
      details: error.message,
    });
  }
});

router.post("/:matchId/words", async (req, res) => {
  const { matchId } = req.params;
  const parsed = submitSchema.safeParse(req.body || {});
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.message });
  }
  const { userId, words } = parsed.data;

  const match = await repo().get(matchId);
  if (!match) return res.status(404).json({ error: "match not found" });

  const player = match.players.find((p: MatchPlayer) => p.id === userId);
  if (!player) return res.status(404).json({ error: "player not in match" });

  await initDictionary();
  const normalized = words
    .map((w) => String(w).trim().toUpperCase())
    .filter((w) => w.length >= 3 && /^[A-Z]+$/.test(w));

  // Enforce server-side board validation and dictionary check
  const unique = Array.from(
    new Set(
      normalized.filter((w) => isWord(w) && canFormWordOnBoard(match.board, w))
    )
  );
  const cfgForScore = getLobbyConfig(match.lobbyType);
  const perSecond = cfgForScore?.timeBonusPerSecond ?? 0;
  const maxBonus = cfgForScore?.timeBonusMaxPoints ?? Infinity;
  // Enforce per-player deadline
  const deadlineAtMs = player.deadlineAt
    ? new Date(player.deadlineAt).getTime()
    : new Date(player.joinedAt).getTime() + match.gameDuration * 1000;
  const nowMs = Date.now();
  if (nowMs > deadlineAtMs) {
    return res.status(403).json({
      ok: false,
      error: "deadline passed",
      details: "Player deadline has passed; submission rejected.",
    });
  }

  const remainingSeconds = Math.max(
    0,
    Math.floor((deadlineAtMs - nowMs) / 1000)
  );
  const baseScore = unique.reduce((acc, w) => acc + w.length * w.length, 0);
  const bonus = Math.min(Math.floor(remainingSeconds * perSecond), maxBonus);
  const score = baseScore + bonus;
  player.words = unique;
  player.score = score;
  player.wordScore = baseScore;
  player.timeBonus = bonus;
  player.submittedAt = new Date().toISOString();

  const cfg = getLobbyConfig(match.lobbyType);
  const requiredPlayers = cfg?.maxPlayers ?? 7; // Wait for all players
  // Only count a player as done if they actually submitted
  const allSubmitted =
    match.players.length === requiredPlayers &&
    match.players.every((p: MatchPlayer) => !!p.submittedAt);

  if (allSubmitted) {
    match.status = "completed";
    match.endedAt = new Date().toISOString();
    await saveCompletedMatch(match);

    if (!match.payoutAt) {
      try {
        const cfgForPayout = getLobbyConfig(match.lobbyType);
        const winners = rankAndAllocateWinnings(
          match.players,
          match.prizePool,
          cfgForPayout?.payoutMultipliers ?? []
        );
        for (const p of winners) {
          const amount = Math.floor(p.winnings || 0);
          if (amount > 0) {
            await creditPrize(p.id, amount, {
              lobbyType: match.lobbyType,
              matchId: match.id,
              place: (p.rank as number) || 1,
            });
          }
        }
        match.payoutAt = new Date().toISOString();
      } catch (error) {
        console.error("Error processing prize payout:", error);
      }
    }
  }

  // Persist or remove from Redis
  if (match.status === "completed") {
    // Remove from Redis now that it's saved in Postgres
    await repo().remove(match.id);
  } else {
    await repo().save(match);
  }

  res.json({
    ok: true,
    myScore: score,
    completed: match.status === "completed",
  });
});

router.get("/:matchId", async (req, res) => {
  try {
    const { matchId } = req.params;
    const user = await getRequestingUser(req);
    let match = await repo().get(matchId);
    if (!match) {
      // Fallback to completed match in Postgres
      const cm = await prisma.completedMatch.findUnique({
        where: { id: matchId },
      });
      if (!cm) return res.status(404).json({ error: "match not found" });
      // Rehydrate minimal shape for client
      const hydrated: InternalMatch = {
        id: matchId,
        lobbyType: cm.lobbyType,
        board: (cm as any).board,
        createdAt: cm.createdAt.toISOString(),
        startedAt: cm.startedAt ? cm.startedAt.toISOString() : null,
        endedAt: cm.endedAt.toISOString(),
        entryFee: cm.entryFee,
        prizePool: cm.prizePool,
        gameDuration: cm.gameDuration,
        players: (cm as any).players,
        status: "completed",
        autoCompleteAt: cm.endedAt.toISOString(),
        payoutAt: (cm as any).payoutAt,
      };
      return res.json(toClientMatch(hydrated, user.id));
    }
    res.json(toClientMatch(match, user.id));
  } catch (error: any) {
    console.error("Failed to get match:", error);
    res.status(500).json({
      error: "Failed to get match",
      details: error.message,
    });
  }
});

// Enhanced match details endpoint for results screen
router.get("/:matchId/details", async (req, res) => {
  try {
    const { matchId } = req.params;
    const user = await getRequestingUser(req);
    let match = await repo().get(matchId);
    if (!match) {
      const cm = await prisma.completedMatch.findUnique({
        where: { id: matchId },
      });
      if (!cm) return res.status(404).json({ error: "match not found" });
      const hydrated: InternalMatch = {
        id: matchId,
        lobbyType: cm.lobbyType,
        board: (cm as any).board,
        createdAt: cm.createdAt.toISOString(),
        startedAt: cm.startedAt ? cm.startedAt.toISOString() : null,
        endedAt: cm.endedAt.toISOString(),
        entryFee: cm.entryFee,
        prizePool: cm.prizePool,
        gameDuration: cm.gameDuration,
        players: (cm as any).players,
        status: "completed",
        autoCompleteAt: cm.endedAt.toISOString(),
        payoutAt: (cm as any).payoutAt,
      };
      match = hydrated as any;
    }

    // Check if user is in this match
    const userPlayer = (match as InternalMatch).players.find(
      (p: MatchPlayer) => p.id === user.id
    );
    if (!userPlayer) {
      return res.status(403).json({ error: "user not in this match" });
    }

    // Return detailed match information
    const m = match as InternalMatch;
    const matchDetails = {
      matchId: m.id,
      lobbyId: m.lobbyType,
      board: m.board,
      status: m.status,
      createdAt: m.createdAt,
      startedAt: m.startedAt,
      endedAt: m.endedAt,
      entryFee: m.entryFee,
      prizePool: m.prizePool,
      gameDuration: m.gameDuration,
      players: m.players.map((player: MatchPlayer) => ({
        id: player.id,
        name: player.name,
        words: player.words,
        score: player.score,
        joinedAt: player.joinedAt,
        submittedAt: player.submittedAt,
        paidEntry: player.paidEntry,
        isCurrentUser: player.id === user.id,
      })),
      // Calculate time remaining if match is still active
      timeRemaining:
        m.status === "completed"
          ? 0
          : Math.max(
              0,
              m.gameDuration -
                Math.floor(
                  (Date.now() - new Date(m.createdAt).getTime()) / 1000
                )
            ),
    };

    res.json(matchDetails);
  } catch (error: any) {
    console.error(`Failed to get match details:`, error);
    res
      .status(500)
      .json({ error: "Failed to get match details", details: error.message });
  }
});

router.get("/", async (req, res) => {
  try {
    const user = await getRequestingUser(req);

    // Active matches from Redis
    const active = await repo().listByUser(user.id);

    // Recently completed matches from Postgres (fallback for history)
    // Fetch recent and filter in memory for user participation
    const recentCompleted = await prisma.completedMatch.findMany({
      orderBy: { endedAt: "desc" },
      take: 50,
    });
    const completedForUser: InternalMatch[] = [];
    for (const cm of recentCompleted) {
      const players = (cm as any).players as any[];
      const participated = Array.isArray(players)
        ? players.some((p: any) => p && p.id === user.id)
        : false;
      if (!participated) continue;
      completedForUser.push({
        id: cm.id,
        lobbyType: cm.lobbyType,
        board: (cm as any).board,
        createdAt: cm.createdAt.toISOString(),
        startedAt: cm.startedAt ? cm.startedAt.toISOString() : null,
        endedAt: cm.endedAt.toISOString(),
        entryFee: cm.entryFee,
        prizePool: cm.prizePool,
        gameDuration: cm.gameDuration,
        players: players as any,
        status: "completed",
        autoCompleteAt: cm.endedAt.toISOString(),
        payoutAt: (cm as any).payoutAt,
      });
    }

    // Merge, preferring active for any dupes
    const byId = new Map<string, InternalMatch>();
    for (const m of completedForUser) byId.set(m.id, m);
    for (const m of active) byId.set(m.id, m);
    const merged = Array.from(byId.values());

    const list = merged.map((m: InternalMatch) => toClientMatch(m, user.id));
    res.json({ matches: list });
  } catch (error: any) {
    console.error(`Failed to get matches for user:`, error);
    res.status(500).json({
      error: "Failed to get matches",
      details: error.message,
    });
  }
});

function toClientMatch(m: InternalMatch, playerId: string) {
  const me = m.players.find((p: MatchPlayer) => p.id === playerId);
  const other = m.players.find((p: MatchPlayer) => p.id !== playerId);

  const opponentWords = m.status === "completed" ? other?.words || [] : [];

  // Calculate individual player's time remaining
  let timeRemaining = m.gameDuration;
  if (me && !me.submittedAt) {
    const now = Date.now();
    const deadlineMs = me.deadlineAt
      ? new Date(me.deadlineAt).getTime()
      : new Date(me.joinedAt).getTime() + m.gameDuration * 1000;
    timeRemaining = Math.max(0, Math.floor((deadlineMs - now) / 1000));
  }

  return {
    matchId: m.id,
    lobbyId: m.lobbyType,
    board: m.board,
    timer: timeRemaining,
    myWords: me?.words || [],
    opponentWords: opponentWords,
    completed: m.status === "completed",
    myScore: me?.score || 0,
    myWordScore: me?.wordScore,
    myTimeBonus: me?.timeBonus,
    opponentScore: other?.score || 0,
    opponentId: other?.id || null,
    opponentUsername: other?.name || "Opponent",
    createdAt: m.createdAt,
    startedAt: m.startedAt,
    endedAt: m.endedAt,
    entryFee: m.entryFee,
    prizePool: m.prizePool,
    gameDuration: m.gameDuration,
    // expose player deadline for client-side seeding
    playerDeadlineAt: me?.deadlineAt || null,
  };
}

export default router;

// Dev-only: simulate a completed match with fake players and trigger payouts
router.post("/dev/simulate", async (req, res) => {
  if (!isDevAuth()) return res.status(403).json({ error: "forbidden" });

  const schema = z.object({
    lobbyType: z.string(),
    numPlayers: z.number().int().min(1).max(10).default(3),
    scores: z.array(z.number().int().min(0)).optional(),
  });
  const parsed = schema.safeParse(req.body || {});
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.message });
  }
  const { lobbyType, numPlayers, scores } = parsed.data;

  const cfg = getLobbyConfig(lobbyType);
  if (!cfg) return res.status(400).json({ error: "invalid lobbyType" });

  const nowIso = new Date().toISOString();
  const id = `${lobbyType}-sim-${Date.now().toString(36)}`;
  const board = generateDiceBoard(cfg.boardSize);
  const players: MatchPlayer[] = Array.from({ length: numPlayers }).map(
    (_, i) => ({
      id: `sim-user-${i + 1}`,
      name: `Sim ${i + 1}`,
      words: [],
      score: scores?.[i] ?? Math.floor(Math.random() * 100),
      wordScore: scores?.[i] ?? undefined,
      timeBonus: 0,
      joinedAt: nowIso,
      deadlineAt: nowIso,
      paidEntry: true,
      submittedAt: nowIso,
    })
  );

  const match: InternalMatch = {
    id,
    lobbyType,
    board,
    createdAt: nowIso,
    startedAt: nowIso,
    endedAt: nowIso,
    entryFee: cfg.entryFee,
    prizePool: cfg.totalPrizeGems,
    gameDuration: cfg.gameDuration,
    players,
    status: "completed",
    autoCompleteAt: nowIso,
  };

  // Persist completed match with computed payouts
  await saveCompletedMatch(match);

  // Credit payouts idempotently
  if (!match.payoutAt) {
    try {
      // Ensure dev users exist so prize credits can be recorded
      for (const p of players) {
        await prisma.user.upsert({
          where: { id: p.id },
          update: {},
          create: {
            id: p.id,
            username: p.name,
            cashBalance: 0,
            bonusBalance: 0,
            gemBalance: 0,
          },
        });
      }

      const winners = rankAndAllocateWinnings(
        match.players,
        match.prizePool,
        cfg.payoutMultipliers
      );
      for (const p of winners) {
        const amount = Math.floor(p.winnings || 0);
        if (amount > 0) {
          await creditPrize(p.id, amount, {
            lobbyType: match.lobbyType,
            matchId: match.id,
            place: (p.rank as number) || 1,
          });
        }
      }
      match.payoutAt = new Date().toISOString();
    } catch (e) {
      console.error("Dev simulate payout error:", e);
    }
  }

  res.json({ ok: true, matchId: id });
});

// Dev-only: verify completed matches and prize transactions
router.post("/dev/verify", async (req, res) => {
  if (!isDevAuth()) return res.status(403).json({ error: "forbidden" });

  const schema = z.object({
    matchId: z.string().optional(),
    limit: z.number().int().min(1).max(200).optional().default(20),
  });
  const parsed = schema.safeParse(req.body || {});
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.message });
  }
  const { matchId, limit } = parsed.data;

  try {
    const matches = matchId
      ? await prisma.completedMatch.findMany({ where: { id: matchId } })
      : await prisma.completedMatch.findMany({
          orderBy: { endedAt: "desc" },
          take: limit,
        });

    const reports: any[] = [];
    let allOk = true;

    for (const cm of matches) {
      const cfg = getLobbyConfig(cm.lobbyType);
      const prizePool = cm.prizePool;
      const players = ((cm as any).players as any[]).map((p: any) => ({
        id: String(p.id),
        name: String(p.name || ""),
        words: Array.isArray(p.words) ? p.words : [],
        score: Number(p.score || 0),
        joinedAt: String(p.joinedAt || new Date().toISOString()),
        paidEntry: Boolean(p.paidEntry ?? true),
      }));

      const expected = rankAndAllocateWinnings(
        players as any,
        prizePool,
        cfg?.payoutMultipliers ?? []
      );

      const expectedMap = new Map<string, number>();
      for (const p of expected)
        expectedMap.set(p.id, Math.floor(p.winnings || 0));

      const recordedMap = new Map<string, number>();
      for (const p of (cm as any).players as any[]) {
        recordedMap.set(String(p.id), Math.floor(p.winnings || 0));
      }

      const tx = await prisma.transaction.findMany({
        where: { matchId: cm.id, type: "prize" },
      });
      const creditedMap = new Map<string, number>();
      for (const t of tx) {
        creditedMap.set(t.userId, (creditedMap.get(t.userId) || 0) + t.amount);
      }

      const users = Array.from(
        new Set([
          ...players.map((p: any) => p.id),
          ...Array.from(expectedMap.keys()),
          ...Array.from(recordedMap.keys()),
          ...tx.map((t) => t.userId),
        ])
      );

      const perPlayer: any[] = [];
      let matchOk = true;
      const discrepancies: string[] = [];

      for (const uid of users) {
        const exp = expectedMap.get(uid) || 0;
        const rec = recordedMap.get(uid) || 0;
        const cred = creditedMap.get(uid) || 0;
        const ok = exp === rec && rec === cred;
        if (!ok) {
          matchOk = false;
          discrepancies.push(
            `user ${uid}: expected=${exp} recorded=${rec} credited=${cred}`
          );
        }
        const pl = players.find((p: any) => p.id === uid);
        perPlayer.push({
          userId: uid,
          score: pl?.score ?? null,
          expected: exp,
          recorded: rec,
          credited: cred,
        });
      }

      const totalExpected = Array.from(expectedMap.values()).reduce(
        (a, b) => a + b,
        0
      );
      const totalCredited = tx.reduce((a, b) => a + b.amount, 0);
      if (totalExpected !== prizePool) {
        matchOk = false;
        discrepancies.push(
          `total mismatch: expectedTotal=${totalExpected} prizePool=${prizePool}`
        );
      }
      if (totalCredited !== totalExpected) {
        matchOk = false;
        discrepancies.push(
          `credited mismatch: creditedTotal=${totalCredited} expectedTotal=${totalExpected}`
        );
      }

      reports.push({
        matchId: cm.id,
        lobbyType: cm.lobbyType,
        prizePool,
        endedAt: cm.endedAt,
        ok: matchOk,
        totalExpected,
        totalCredited,
        players: perPlayer,
        discrepancies,
      });

      allOk &&= matchOk;
    }

    res.json({ ok: allOk, count: reports.length, reports });
  } catch (e: any) {
    console.error("verify error:", e);
    res.status(500).json({ error: e?.message || String(e) });
  }
});
