import { execSync } from "node:child_process";

const maxAttempts = Number(process.env.DB_MIGRATE_MAX_ATTEMPTS || 12);
const delayMs = Number(process.env.DB_MIGRATE_RETRY_MS || 5000);

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function main() {
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      console.log(
        `[migrate] attempt ${attempt}/${maxAttempts}: prisma migrate deploy`
      );
      execSync("npx prisma migrate deploy", { stdio: "inherit" });
      console.log("[migrate] success");
      return;
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      console.error(`[migrate] attempt ${attempt} failed: ${message}`);
      if (attempt >= maxAttempts) {
        console.error(
          "[migrate] giving up — is Postgres running and DATABASE_URL linked?"
        );
        process.exit(1);
      }
      console.log(`[migrate] retrying in ${delayMs}ms...`);
      await sleep(delayMs);
    }
  }
}

main();
