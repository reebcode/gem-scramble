export type Board = string[][];

export interface MatchPlayer {
  id: string;
  name: string;
  words: string[];
  score: number;
  wordScore?: number;
  timeBonus?: number;
  joinedAt: string;
  // Per-player absolute deadline when their timer ends
  deadlineAt?: string;
  paidEntry: boolean;
  submittedAt?: string;
  rank?: number;
  winnings?: number;
}

export interface InternalMatch {
  id: string;
  lobbyType: string;
  board: Board;
  createdAt: string;
  startedAt: string | null;
  endedAt: string | null;
  entryFee: number;
  prizePool: number;
  gameDuration: number;
  players: MatchPlayer[];
  status: "waiting" | "started" | "completed";
  autoCompleteAt: string;
  payoutAt?: string;
}
