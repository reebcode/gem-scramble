import { Router } from "express";
import { z } from "zod";
import { hasPrefix, isWord } from "../services/dictionary.js";

const router = Router();

const validateSchema = z.object({ words: z.array(z.string()).default([]) });
const checkSchema = z.object({ word: z.string().min(1) });

router.post("/words", (req, res) => {
  const parsed = validateSchema.safeParse(req.body || {});
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.message });
  }
  const input = parsed.data.words.map((w) => String(w).toUpperCase());
  const result = input.map((w) => ({ word: w, valid: isWord(w) }));
  res.json({ results: result });
});

router.get("/word", (req, res) => {
  const parsed = checkSchema.safeParse({ word: String(req.query.word || "") });
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.message });
  }
  const w = parsed.data.word.toUpperCase();
  res.json({ word: w, valid: isWord(w), prefix: hasPrefix(w) });
});

export default router;
