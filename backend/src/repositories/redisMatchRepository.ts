import { InternalMatch } from "../state/match.interface.js";
import { MatchRepository } from "./matchRepository.interface.js";
import Redis from "ioredis";

export class RedisMatchRepository implements MatchRepository {
  private redisClient: Redis;

  constructor(redisUrl: string) {
    const preferIPv6 =
      process.env.REDIS_PREFER_IPV6 === "true" ||
      Boolean(process.env.RAILWAY_STATIC_URL) ||
      process.env.RAILWAY_PROJECT_ID !== undefined;

    const connectionOptions = preferIPv6 ? { family: 6 as 6 } : undefined;

    this.redisClient = new Redis(redisUrl, connectionOptions as any);
    this.redisClient.on("error", (err) =>
      console.error("Redis Client Error", err)
    );
  }

  async getWaiting(lobbyId: string): Promise<string | null> {
    try {
      return await this.redisClient.get(`lobby:${lobbyId}:waiting`);
    } catch (error) {
      console.error(`Failed to get waiting match for lobby ${lobbyId}:`, error);
      return null;
    }
  }

  async setWaiting(lobbyId: string, matchId: string): Promise<void> {
    await this.redisClient.set(`lobby:${lobbyId}:waiting`, matchId);
  }

  async clearWaiting(lobbyId: string): Promise<void> {
    await this.redisClient.del(`lobby:${lobbyId}:waiting`);
  }

  async get(matchId: string): Promise<InternalMatch | null> {
    try {
      const matchData = await this.redisClient.get(`match:${matchId}`);
      if (!matchData) {
        return null;
      }
      return JSON.parse(matchData) as InternalMatch;
    } catch (error) {
      console.error(`Failed to get match ${matchId}:`, error);
      return null;
    }
  }

  async save(match: InternalMatch): Promise<void> {
    const key = `match:${match.id}`;
    await this.redisClient.set(key, JSON.stringify(match));
    if (match.status === "completed") {
      // Auto-expire completed matches after 1 hour to prevent buildup
      await this.redisClient.expire(key, 60 * 60);
    }
    for (const player of match.players) {
      if (player.id) {
        await this.redisClient.sadd(`user:${player.id}:matches`, match.id);
      }
    }
  }

  async listByUser(userId: string): Promise<InternalMatch[]> {
    try {
      const matchIds = await this.redisClient.smembers(
        `user:${userId}:matches`
      );
      if (!matchIds || matchIds.length === 0) {
        return [];
      }
      const matchKeys = matchIds.map((id: string) => `match:${id}`);
      const matchData = await this.redisClient.mget(matchKeys);

      return matchData
        .filter((data: string | null): data is string => data !== null)
        .map((data: string) => JSON.parse(data) as InternalMatch);
    } catch (error) {
      console.error(`Failed to list matches for user ${userId}:`, error);
      return [];
    }
  }

  async listAll(): Promise<InternalMatch[]> {
    const matches: InternalMatch[] = [];
    let cursor = "0";
    do {
      const [nextCursor, keys] = await this.redisClient.scan(
        cursor,
        "MATCH",
        "match:*",
        "COUNT",
        100
      );
      cursor = nextCursor;

      if (keys.length > 0) {
        const matchData = await this.redisClient.mget(keys);
        const foundMatches = matchData
          .filter((data: string | null): data is string => data !== null)
          .map((data: string) => JSON.parse(data) as InternalMatch);
        matches.push(...foundMatches);
      }
    } while (cursor !== "0");

    return matches;
  }

  async ensureWaitingForAllLobbies(): Promise<void> {}

  async remove(matchId: string): Promise<void> {
    try {
      const key = `match:${matchId}`;
      const raw = await this.redisClient.get(key);
      if (raw) {
        const match = JSON.parse(raw) as InternalMatch;
        // Remove match key
        await this.redisClient.del(key);
        // Remove match from each player's set
        for (const player of match.players) {
          if (player.id) {
            await this.redisClient.srem(`user:${player.id}:matches`, matchId);
          }
        }
      } else {
        await this.redisClient.del(key);
      }
    } catch (err) {
      console.error(`Failed to remove match ${matchId} from Redis:`, err);
    }
  }

  async disconnect(): Promise<void> {
    try {
      await this.redisClient.quit();
    } catch (err) {
      try {
        // Fallback to force close
        this.redisClient.disconnect();
      } catch (_ignored) {}
    }
  }

  async ping(): Promise<boolean> {
    try {
      const res = await this.redisClient.ping();
      return res === "PONG";
    } catch {
      return false;
    }
  }
}
