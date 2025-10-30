import { RedisMatchRepository } from "./redisMatchRepository.js";
import { MatchRepository } from "./matchRepository.interface.js";

// Factory function to create the appropriate repository
let cachedRepository: MatchRepository | null = null;

export function createMatchRepository(): MatchRepository {
  if (cachedRepository) {
    return cachedRepository;
  }

  const redisUrl = process.env.REDIS_URL;
  if (!redisUrl) {
    throw new Error(
      "REDIS_URL environment variable is not set. Redis is required for match management."
    );
  }

  console.log("Using Redis match repository (singleton)");
  cachedRepository = new RedisMatchRepository(redisUrl);
  return cachedRepository;
}

// Optional: expose a method to close the singleton (used in graceful shutdown/tests)
export async function disconnectMatchRepository(): Promise<void> {
  if (cachedRepository && typeof cachedRepository.disconnect === "function") {
    try {
      await cachedRepository.disconnect();
    } finally {
      cachedRepository = null;
    }
  }
}
