import { InternalMatch } from "../state/match.interface.js";

export interface MatchRepository {
  getWaiting(lobbyId: string): Promise<string | null>;
  setWaiting(lobbyId: string, matchId: string): Promise<void>;
  clearWaiting(lobbyId: string): Promise<void>;
  get(matchId: string): Promise<InternalMatch | null>;
  save(match: InternalMatch): Promise<void>;
  listByUser(userId: string): Promise<InternalMatch[]>;
  listAll(): Promise<InternalMatch[]>;
  ensureWaitingForAllLobbies(): Promise<void>;
  remove(matchId: string): Promise<void>;
  disconnect(): Promise<void>;
  ping(): Promise<boolean>;
}
