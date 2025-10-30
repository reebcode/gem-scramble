import { readFileSync } from "fs";
import { fileURLToPath } from "url";
import { dirname, join } from "path";

export type LobbyConfig = {
  lobbyType: string;
  name: string;
  entryFee: number; // gems
  boardSize: 4 | 5;
  gameDuration: number; // seconds
  maxPlayers: number; // e.g., 7
  payoutMultipliers: number[]; // e.g., [3, 1.5, 0.5]
  totalPrizeGems: number; // explicit total prize pool in gems
  timeBonusPerSecond?: number; // fixed per-second bonus
  timeBonusMaxPoints?: number; // absolute cap of time bonus
};

// Validate lobby configuration
function validateLobbyConfig(lobby: any): lobby is LobbyConfig {
  return (
    typeof lobby.lobbyType === "string" &&
    typeof lobby.name === "string" &&
    typeof lobby.entryFee === "number" &&
    (lobby.boardSize === 4 || lobby.boardSize === 5) &&
    typeof lobby.gameDuration === "number" &&
    typeof lobby.maxPlayers === "number" &&
    Array.isArray(lobby.payoutMultipliers) &&
    typeof lobby.totalPrizeGems === "number" &&
    lobby.entryFee >= 0 &&
    lobby.gameDuration >= 60 &&
    lobby.gameDuration <= 1800 &&
    lobby.maxPlayers >= 2 &&
    lobby.maxPlayers <= 10
  );
}

// Load lobby configuration from JSON file
function loadLobbyConfig(): LobbyConfig[] {
  try {
    const __filename = fileURLToPath(import.meta.url);
    const __dirname = dirname(__filename);
    const configPath = join(__dirname, "lobbies.json");
    const configData = readFileSync(configPath, "utf-8");
    const config = JSON.parse(configData);

    if (!config.lobbies || !Array.isArray(config.lobbies)) {
      console.error("Invalid lobby config: lobbies array not found");
      return [];
    }

    const validLobbies = config.lobbies.filter((lobby: any) => {
      if (!validateLobbyConfig(lobby)) {
        console.error(
          `Invalid lobby config for ${lobby.lobbyType || "unknown"}:`,
          lobby
        );
        return false;
      }
      return true;
    });

    console.log(`Loaded ${validLobbies.length} valid lobbies from config`);
    return validLobbies;
  } catch (error) {
    console.error("Failed to load lobby config:", error);
    // Fallback to empty array if config file is missing
    return [];
  }
}

export const LOBBIES: LobbyConfig[] = loadLobbyConfig();

export function getLobbyConfig(lobbyType: string): LobbyConfig | undefined {
  return LOBBIES.find((l) => l.lobbyType === lobbyType);
}
