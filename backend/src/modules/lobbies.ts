import { Router } from "express";
import { LOBBIES } from "../config/lobbies.js";
import { createMatchRepository } from "../repositories/matchRepository.js";
import { MatchRepository } from "../repositories/matchRepository.interface.js";

const router = Router();

let matchRepo: MatchRepository | null = null;
function repo(): MatchRepository {
  if (!matchRepo) {
    matchRepo = createMatchRepository();
  }
  return matchRepo;
}

// Derive lobby list from config
const lobbies = LOBBIES.map((c) => ({
  lobbyId: c.lobbyType,
  name: `${c.name} - ${c.totalPrizeGems} gems total`,
  entryFee: c.entryFee,
  prizePool: c.totalPrizeGems,
  maxPlayers: c.maxPlayers,
  currentPlayers: 0,
  estimatedWaitTime: 0, // Will be calculated based on actual queue
  difficulty:
    c.boardSize === 5 ? (c.gameDuration > 120 ? "hard" : "medium") : "easy",
  boardSize: c.boardSize,
  gameDuration: c.gameDuration,
  isActive: true,
  createdAt: new Date().toISOString(),
}));

router.get("/", async (_req, res) => {
  const enriched = await Promise.all(
    lobbies.map(async (l) => {
      // Get current players from all waiting matches of this lobby type
      const allMatches = await repo().listAll();
      const waitingMatches = allMatches.filter(
        (m) => m.lobbyType === l.lobbyId && m.status === "waiting"
      );

      const currentPlayers = waitingMatches.reduce(
        (total, match) => total + match.players.length,
        0
      );

      return { ...l, currentPlayers };
    })
  );
  res.json({ lobbies: enriched });
});

export default router;
