import { Router } from "express";
import { prisma } from "../config/prisma.js";
import { z } from "zod";
import { generateDiceBoard } from "../utils/board.js";

const router = Router();

const createSchema = z.object({
  size: z.number().int().min(4).max(6).default(4),
});

router.post("/", async (req, res) => {
  const parsed = createSchema.safeParse(req.body);
  if (!parsed.success)
    return res.status(400).json({ error: parsed.error.message });
  const { size } = parsed.data;

  // Simple dice-based board with random seed (client will get the grid and id)
  const seed = Date.now().toString(36);
  const grid = generateDiceBoard(size);

  // No longer storing boards in database - they're generated on-demand
  return res.json({ boardId: seed, seed, size, grid });
});

export default router;
