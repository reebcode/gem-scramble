import cors from "cors";
import type { CorsOptions } from "cors";

/**
 * Origins that are always permitted. Railway env vars are merged on top, but
 * these defaults mean Firebase Hosting works even if CORS_ORIGINS is missing
 * or misconfigured in the dashboard.
 */
const DEFAULT_ORIGINS = [
  "https://gemscramble.web.app",
  "https://gemscramble.firebaseapp.com",
  "https://scramblecash.web.app",
  "https://scramblecash.firebaseapp.com",
  "http://localhost",
  "http://127.0.0.1",
  "http://localhost:3000",
  "http://localhost:8080",
  "http://127.0.0.1:3000",
  "http://127.0.0.1:8080",
];

export function getAllowedOrigins(): string[] {
  const fromEnv = (process.env.CORS_ORIGINS || "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
  return [...new Set([...DEFAULT_ORIGINS, ...fromEnv])];
}

export function buildCorsMiddleware() {
  const allowed = getAllowedOrigins();

  const options: CorsOptions = {
    origin(origin, callback) {
      // Same-origin requests and server-to-server calls may omit Origin.
      if (!origin) {
        callback(null, true);
        return;
      }
      if (allowed.includes(origin)) {
        callback(null, origin);
        return;
      }
      // Reject without throwing so the response still flows through Express.
      callback(null, false);
    },
    // Auth uses Bearer tokens / userId query params, not cookies.
    credentials: false,
    methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization"],
    optionsSuccessStatus: 204,
  };

  return cors(options);
}
