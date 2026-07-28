import { hasPrefix, isWord } from "../services/dictionary.js";

/** Find all dictionary words formable on the board (Boggle rules). */
export function findWordsOnBoard(
  board: string[][],
  minLength = 3
): Set<string> {
  const found = new Set<string>();
  if (!board?.length || !board[0]?.length) return found;

  const rows = board.length;
  const cols = board[0].length;
  const visited: boolean[][] = Array.from({ length: rows }, () =>
    Array.from({ length: cols }, () => false)
  );

  function dfs(r: number, c: number, prefix: string) {
    const next = prefix + board[r][c];
    if (!hasPrefix(next)) return;

    if (next.length >= minLength && isWord(next)) {
      found.add(next);
    }

    visited[r][c] = true;
    for (let dr = -1; dr <= 1; dr++) {
      for (let dc = -1; dc <= 1; dc++) {
        if (dr === 0 && dc === 0) continue;
        const nr = r + dr;
        const nc = c + dc;
        if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
        if (visited[nr][nc]) continue;
        dfs(nr, nc, next);
      }
    }
    visited[r][c] = false;
  }

  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) {
      dfs(r, c, "");
    }
  }

  return found;
}

export function countVowelsOnBoard(board: string[][]): number {
  let n = 0;
  for (const row of board) {
    for (const cell of row) {
      for (const ch of cell) {
        if ("AEIOU".includes(ch)) n++;
      }
    }
  }
  return n;
}
