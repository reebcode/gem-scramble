# Lobby Configuration

This directory contains the lobby configuration for Gem Scramble.

## Files

- `lobbies.json` - Main configuration file for all lobby types
- `lobbies.ts` - TypeScript loader and type definitions

## Adding/Modifying Lobbies

Edit `lobbies.json`:

```json
{
  "lobbies": [
    {
      "lobbyType": "gems100",
      "name": "100 Gems Entry",
      "entryFee": 100,
      "boardSize": 4,
      "gameDuration": 300,
      "maxPlayers": 7,
      "payoutMultipliers": [3, 1.5, 0.5],
      "totalPrizeGems": 700,
      "timeBonusPerSecond": 0.2,
      "timeBonusMaxPoints": 60
    }
  ]
}
```

## Configuration Fields

| Field                | Type     | Description                                |
| -------------------- | -------- | ------------------------------------------ |
| `lobbyType`          | string   | Unique identifier (e.g., "gems10")         |
| `name`               | string   | Display name (e.g., "10 Gems Entry")       |
| `entryFee`           | number   | Entry fee in gems                          |
| `boardSize`          | number   | Board size (4 or 5)                        |
| `gameDuration`       | number   | Game duration in seconds (300 = 5 minutes) |
| `maxPlayers`         | number   | Maximum players per lobby (2–10)           |
| `payoutMultipliers`  | number[] | Prize distribution multipliers by rank     |
| `totalPrizeGems`     | number   | Total prize pool in gems                   |
| `timeBonusPerSecond` | number   | Bonus points per second remaining          |
| `timeBonusMaxPoints` | number   | Maximum time bonus points                  |

## Examples

### High-stakes 5x5 lobby

```json
{
  "lobbyType": "gems1000",
  "name": "1000 Gems Entry",
  "entryFee": 1000,
  "boardSize": 5,
  "gameDuration": 300,
  "maxPlayers": 7,
  "payoutMultipliers": [4, 2, 1],
  "totalPrizeGems": 7000,
  "timeBonusPerSecond": 0.2,
  "timeBonusMaxPoints": 60
}
```

### Free practice lobby

```json
{
  "lobbyType": "free",
  "name": "Free Practice",
  "entryFee": 0,
  "boardSize": 4,
  "gameDuration": 300,
  "maxPlayers": 7,
  "payoutMultipliers": [0, 0, 0],
  "totalPrizeGems": 0,
  "timeBonusPerSecond": 0,
  "timeBonusMaxPoints": 0
}
```

## Hot Reloading

Configuration is loaded at server startup. To apply changes:

1. Edit `lobbies.json`
2. Restart the server (`npm run dev`)

## Validation

`lobbies.ts` validates that:

- All required fields are present
- `boardSize` is 4 or 5
- `entryFee` and `totalPrizeGems` are non-negative
- `gameDuration` is 60–1800 seconds
- `maxPlayers` is 2–10

If validation fails, the server logs an error and falls back to an empty lobby list.
