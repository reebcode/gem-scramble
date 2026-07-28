import {
  countVowelsOnBoard,
  findWordsOnBoard,
} from "./boardSolver.js";

/** Classic 16 Boggle dice. */
const BOGGLE_DICE: string[][] = [
  ["A", "A", "E", "E", "G", "N"],
  ["E", "L", "R", "T", "T", "Y"],
  ["A", "O", "O", "T", "T", "W"],
  ["A", "B", "B", "J", "O", "O"],
  ["E", "H", "R", "T", "V", "W"],
  ["C", "I", "M", "O", "T", "U"],
  ["D", "I", "S", "T", "T", "Y"],
  ["E", "I", "O", "S", "S", "T"],
  ["D", "E", "L", "R", "V", "Y"],
  ["A", "C", "H", "O", "P", "S"],
  ["H", "I", "M", "N", "Q", "U"],
  ["E", "E", "I", "N", "S", "U"],
  ["E", "E", "G", "H", "N", "W"],
  ["A", "F", "F", "K", "P", "S"],
  ["H", "L", "N", "N", "R", "Z"],
  ["D", "E", "I", "L", "R", "X"],
];

const MIN_VOWELS = 4;
const MIN_WORDS = 25;
const MIN_WORDS_LEN4 = 12;
const MAX_ATTEMPTS = 50;

function rollDiceBoard(size: number): string[][] {
  let seed = Date.now() ^ (Math.floor(Math.random() * 0x7fffffff) ^ 0x9e3779b9);
  const nextInt = (max: number) => {
    seed = (1664525 * seed + 1013904223) & 0x7fffffff;
    return seed % max;
  };
  const bag = [...BOGGLE_DICE];
  for (let i = bag.length - 1; i > 0; i--) {
    const j = nextInt(i + 1);
    [bag[i], bag[j]] = [bag[j], bag[i]];
  }
  const grid: string[][] = Array.from({ length: size }, () =>
    Array.from({ length: size }, () => "A")
  );
  let idx = 0;
  for (let r = 0; r < size; r++) {
    for (let c = 0; c < size; c++) {
      const die = bag[idx % bag.length];
      const face = die[nextInt(die.length)];
      grid[r][c] = face === "Q" ? "QU" : face;
      idx++;
    }
  }
  return grid;
}

/** Roll a board, re-rolling until it has enough common dictionary words. */
export function generateDiceBoard(size: number): string[][] {
  let best: string[][] | null = null;
  let bestCount = -1;

  for (let attempt = 0; attempt < MAX_ATTEMPTS; attempt++) {
    const board = rollDiceBoard(size);
    if (countVowelsOnBoard(board) < MIN_VOWELS) continue;

    const words = findWordsOnBoard(board, 3);
    const wordCount = words.size;
    let wordsLen4 = 0;
    for (const w of words) {
      if (w.length >= 4) wordsLen4++;
    }

    if (wordCount > bestCount) {
      best = board;
      bestCount = wordCount;
    }

    if (wordCount >= MIN_WORDS && wordsLen4 >= MIN_WORDS_LEN4) {
      return board;
    }
  }

  return best ?? rollDiceBoard(size);
}
