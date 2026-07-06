import { PrismaClient } from "@prisma/client";

export const prisma = new PrismaClient({
  log: ["error", "warn"],
});

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Connect to Postgres with retries. Railway free-tier databases can take
 * 30–60s to wake from sleep; without this the deploy crashes on first P1001.
 */
export async function connectPrisma() {
  const maxAttempts = Number(process.env.DB_CONNECT_MAX_ATTEMPTS || 12);
  const delayMs = Number(process.env.DB_CONNECT_RETRY_MS || 5000);

  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      await prisma.$connect();
      if (attempt > 1) {
        console.log(`[prisma] connected on attempt ${attempt}`);
      }
      return;
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      console.error(`[prisma] connect attempt ${attempt} failed: ${message}`);
      if (attempt >= maxAttempts) throw error;
      console.log(`[prisma] retrying in ${delayMs}ms...`);
      await sleep(delayMs);
    }
  }
}
