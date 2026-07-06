export function canFormWordOnBoard(
  board: string[][],
  rawWord: string
): boolean {
  // Expect board tokens like "A" or "QU" and word as uppercase A-Z string
  if (!board || board.length === 0) return false;
  const word = rawWord.toUpperCase();
  if (word.length < 1) return false;

  const rows = board.length;
  const cols = board[0]?.length ?? 0;
  if (cols === 0) return false;

  const visited: boolean[][] = Array.from({ length: rows }, () =>
    Array.from({ length: cols }, () => false)
  );

  const tokenMatchesAtIndex = (token: string, index: number): boolean => {
    // Board tokens may be multi-letter (e.g., "QU"); require exact match
    if (index + token.length > word.length) return false;
    // Board already uppercase; word uppercase too
    for (let i = 0; i < token.length; i++) {
      if (word.charCodeAt(index + i) !== token.charCodeAt(i)) return false;
    }
    return true;
  };

  function dfs(r: number, c: number, index: number): boolean {
    const token = board[r][c];
    if (!tokenMatchesAtIndex(token, index)) return false;
    const nextIndex = index + token.length;

    if (nextIndex === word.length) {
      return true;
    }

    visited[r][c] = true;
    for (let dr = -1; dr <= 1; dr++) {
      for (let dc = -1; dc <= 1; dc++) {
        if (dr === 0 && dc === 0) continue;
        const nr = r + dr;
        const nc = c + dc;
        if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
        if (visited[nr][nc]) continue;
        if (dfs(nr, nc, nextIndex)) {
          visited[r][c] = false;
          return true;
        }
      }
    }
    visited[r][c] = false;
    return false;
  }

  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) {
      if (dfs(r, c, 0)) return true;
    }
  }

  return false;
}
