export type AuthMode = "dev" | "firebase";

export function getAuthMode(): AuthMode {
  const explicit = (process.env.AUTH_MODE || "").toLowerCase();
  if (explicit === "dev" || explicit === "firebase")
    return explicit as AuthMode;

  const nodeEnv = (process.env.NODE_ENV || "").toLowerCase();
  if (nodeEnv === "production") return "firebase";

  return "dev";
}

export function isDevAuth(): boolean {
  return getAuthMode() === "dev";
}


