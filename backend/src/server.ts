import "dotenv/config";
import express from "express";
import helmet from "helmet";
import cors from "cors";
import pino from "pino";
import pinoHttp from "pino-http";
import "express-async-errors";
import { connectPrisma } from "./config/prisma.js";
import { initDictionary, isWord } from "./services/dictionary.js";
import { authFirebase } from "./middlewares/authFirebase.js";
import boards from "./modules/boards.js";
import lobbies from "./modules/lobbies.js";
import matches from "./modules/matches.js";
import validate from "./modules/validate.js";
import users from "./modules/users.js";
import wallet from "./modules/wallet.js";

const logger = pino({ level: process.env.LOG_LEVEL || "info" });

// Debug environment variables
console.log("Environment variables check:");
console.log("REDIS_URL:", process.env.REDIS_URL ? "SET" : "NOT SET");
console.log("DATABASE_URL:", process.env.DATABASE_URL ? "SET" : "NOT SET");
console.log("NODE_ENV:", process.env.NODE_ENV);
console.log("PORT:", process.env.PORT);

const app = express();
app.use(helmet());
app.use(cors({ origin: true, credentials: true }));
app.use(express.json({ limit: "1mb" }));
app.use(pinoHttp({ logger }));

app.get("/health", (req, res) => {
  res.json({ ok: true, ts: Date.now() });
});

app.get("/config", (req, res) => {
  res.json({
    authMode:
      process.env.AUTH_MODE ||
      (process.env.NODE_ENV === "production" ? "firebase" : "dev"),
  });
});

app.use("/lobbies", lobbies);
app.use("/boards", boards);
app.use("/matches", authFirebase, matches);
app.use("/validate", validate);
app.use("/users", authFirebase, users);
app.use("/wallet", authFirebase, wallet);

// Background tick: auto-complete stale matches and auto-submit words
import {
  createMatchRepository,
  disconnectMatchRepository,
} from "./repositories/matchRepository.js";
// removed duplicate dictionary import
import { getLobbyConfig } from "./config/lobbies.js";
import { canFormWordOnBoard } from "./utils/wordValidation.js";
import { prisma, creditPrize } from "./services/database.js";
import { rankAndAllocateWinnings } from "./utils/payout.js";

// Create a single shared repository instance for the process
const matchRepo = createMatchRepository();

async function autoSubmitWordsForPlayer(match: any, player: any) {
  if (player.submittedAt) {
    return; // Player already submitted
  }

  await initDictionary();
  const rawWords: string[] = Array.isArray(player.words) ? player.words : [];
  const normalized = rawWords
    .map((w) => String(w).trim().toUpperCase())
    .filter((w) => w.length >= 3 && /^[A-Z]+$/.test(w));
  const unique = Array.from(
    new Set(
      normalized.filter((w) => isWord(w) && canFormWordOnBoard(match.board, w))
    )
  );

  const baseScore = unique.reduce((acc, w) => acc + w.length * w.length, 0);
  const bonus = 0; // at deadline, remaining time bonus is zero
  const score = baseScore + bonus;

  player.words = unique;
  player.score = score;
  player.wordScore = baseScore;
  player.timeBonus = bonus;
  player.submittedAt = new Date().toISOString();

  console.log(
    `Auto-submitted ${unique.length} words for player ${player.name} in match ${match.id}`
  );
}

async function processMatchTimeout(match: any) {
  const now = Date.now();
  const durationMs = (match?.gameDuration ?? 300) * 1000;
  let anyPlayerTimedOut = false;

  // Check each player's individual timer (per-player deadline)
  for (const player of match.players) {
    if (!player.submittedAt) {
      const deadlineMs = player.deadlineAt
        ? new Date(player.deadlineAt).getTime()
        : new Date(player.joinedAt).getTime() + durationMs;
      if (now >= deadlineMs) {
        await autoSubmitWordsForPlayer(match, player);
        anyPlayerTimedOut = true;
        console.log(`Player ${player.name} timed out in match ${match.id}`);
      }
    }
  }

  // Check if all players have now submitted (either manually or by timeout)
  const cfg = getLobbyConfig(match.lobbyType);
  const requiredPlayers = cfg?.maxPlayers ?? 7;
  const allSubmitted =
    match.players.length === requiredPlayers &&
    match.players.every((p: any) => p.submittedAt);

  if (allSubmitted && match.status !== "completed") {
    console.log(`All players submitted in match ${match.id}, completing lobby`);

    // Mark match as completed
    match.status = "completed";
    match.endedAt = new Date().toISOString();

    // Rank players and compute winnings using configured multipliers
    const cfgForPayout = getLobbyConfig(match.lobbyType);
    const ranked = rankAndAllocateWinnings(
      match.players,
      match.prizePool,
      cfgForPayout?.payoutMultipliers ?? []
    );

    // Persist completed match to Postgres (idempotent)
    try {
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
          players: ranked as any,
        },
      });
    } catch (err: any) {
      // ignore if already saved
      if (!/Unique constraint/.test(String(err?.message ?? ""))) {
        console.error("Failed to save completed match:", err);
      }
    }

    // Credit prizes once
    if (!match.payoutAt) {
      try {
        for (const p of ranked) {
          const amount = Math.floor((p as any).winnings || 0);
          if (amount > 0) {
            await creditPrize(p.id, amount, {
              lobbyType: match.lobbyType,
              matchId: match.id,
              place: (p as any).rank || 1,
            });
          }
        }
        match.payoutAt = new Date().toISOString();
      } catch (err) {
        console.error("Error processing prize payout (tick):", err);
      }
    }

    return true; // Match was completed
  }

  return anyPlayerTimedOut; // Return true if any player was processed
}

let __tickRunning = false;
const __tickInterval = setInterval(async () => {
  if (__tickRunning) return;
  __tickRunning = true;
  try {
    const now = Date.now();
    const allMatches = await matchRepo.listAll();

    for (const m of allMatches) {
      let isCompleted = m.status === "completed";
      if (!isCompleted) {
        // Process 1-hour timeout
        const wasProcessed = await processMatchTimeout(m);
        if (wasProcessed) {
          // Re-evaluate completion after possible mutation in processMatchTimeout
          isCompleted = m.status === "completed";
          if (isCompleted) {
            // Remove from Redis to avoid duplicates; API path handles Postgres save
            await matchRepo.remove(m.id);
          } else {
            await matchRepo.save(m);
          }
        }

        // Also handle the old autoCompleteAt logic as fallback
        if (!isCompleted && m.autoCompleteAt) {
          const due = new Date(m.autoCompleteAt).getTime();
          if (now >= due && m.status !== "completed") {
            m.status = "completed";
            m.endedAt = new Date().toISOString();
            isCompleted = true;
            await matchRepo.remove(m.id);
          }
        }
      }
    }

    // No need to ensure waiting matches - they're created on demand
  } catch (error) {
    console.error("Error in background tick:", error);
  } finally {
    __tickRunning = false;
  }
}, 10_000); // Run every 10 seconds

// Error handler
app.use((err: any, req: any, res: any, _next: any) => {
  (req as any)?.log?.error({ err }, "Unhandled error");
  res
    .status(err?.status || 500)
    .json({ error: err?.message || "Internal Error" });
});

const port = Number(process.env.PORT || 8080);
app.listen(port, () => {
  logger.info({ port }, "API listening");

  // Initialize services
  Promise.all([connectPrisma(), initDictionary()])
    .then(() => {
      logger.info("Services initialized");
      console.log("Database connection successful");
    })
    .catch((err) => {
      logger.fatal({ err }, "Service initialization failed");
      console.error("Service initialization failed:", err);
      process.exit(1);
    });
});

// Graceful shutdown
async function shutdown(signal: string) {
  try {
    logger.info({ signal }, "Shutting down");
    clearInterval(__tickInterval);
    await Promise.all([
      disconnectMatchRepository().catch((e) =>
        logger.error({ e }, "Failed to disconnect Redis repository")
      ),
      prisma
        .$disconnect()
        .catch((e: any) => logger.error({ e }, "Failed to disconnect Prisma")),
    ]);
  } finally {
    process.exit(0);
  }
}

process.on("SIGINT", () => shutdown("SIGINT"));
process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("uncaughtException", (err) => {
  logger.error({ err }, "Uncaught exception");
  shutdown("uncaughtException");
});
process.on("unhandledRejection", (reason: any) => {
  logger.error({ err: reason }, "Unhandled promise rejection");
  shutdown("unhandledRejection");
});

// Override /health to include Redis and DB status
app.get("/health", async (_req, res) => {
  const redisOk = await matchRepo.ping().catch(() => false);
  let dbOk = true;
  try {
    await prisma.$queryRaw`SELECT 1`;
  } catch {
    dbOk = false;
  }
  res.json({ ok: redisOk && dbOk, redisOk, dbOk, ts: Date.now() });
});
