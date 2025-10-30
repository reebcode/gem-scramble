export function generateDiceBoard(size: number): string[][] {
  const dice: string[][] = [
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
  // Shuffle with LCG
  let seed = Date.now() ^ 0x9e3779b9;
  const nextInt = (max: number) => {
    seed = (1664525 * seed + 1013904223) & 0x7fffffff;
    return seed % max;
  };
  const bag = [...dice];
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
