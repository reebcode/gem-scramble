# Lobby Configuration

This directory contains the lobby configuration for Scramble Cash.

## Files

- `lobbies.json` - Main configuration file for all lobby types
- `lobbies.ts` - TypeScript loader and type definitions

## Adding/Modifying Lobbies

To add a new lobby or modify existing ones, edit `lobbies.json`:

```json
{
  "lobbies": [
    {
      "lobbyType": "usd1",
      "name": "$1 Entry",
      "entryFee": 100,
      "boardSize": 4,
      "gameDuration": 300,
      "maxPlayers": 7,
      "payoutMultipliers": [3, 1.5, 0.5],
      "totalPrizeCents": 500,
      "timeBonusPerSecond": 0.2,
      "timeBonusMaxPoints": 60
    }
  ]
}
```

## Configuration Fields

| Field                | Type     | Description                                |
| -------------------- | -------- | ------------------------------------------ |
| `lobbyType`          | string   | Unique identifier (e.g., "usd1", "usd5")   |
| `name`               | string   | Display name (e.g., "$1 Entry")            |
| `entryFee`           | number   | Entry fee in cents (100 = $1.00)           |
| `boardSize`          | number   | Board size (4 or 5)                        |
| `gameDuration`       | number   | Game duration in seconds (300 = 5 minutes) |
| `maxPlayers`         | number   | Maximum players per lobby (typically 7)    |
| `payoutMultipliers`  | number[] | Prize distribution multipliers             |
| `totalPrizeCents`    | number   | Total prize pool in cents                  |
| `timeBonusPerSecond` | number   | Bonus points per second remaining          |
| `timeBonusMaxPoints` | number   | Maximum time bonus points                  |

## Examples

### Add a $100 High Roller Lobby

```json
{
  "lobbyType": "usd100",
  "name": "$100 Entry",
  "entryFee": 10000,
  "boardSize": 5,
  "gameDuration": 600,
  "maxPlayers": 7,
  "payoutMultipliers": [4, 2, 1],
  "totalPrizeCents": 50000,
  "timeBonusPerSecond": 0.5,
  "timeBonusMaxPoints": 300
}
```

### Add a Free Practice Lobby

```json
{
  "lobbyType": "free",
  "name": "Free Practice",
  "entryFee": 0,
  "boardSize": 4,
  "gameDuration": 300,
  "maxPlayers": 7,
  "payoutMultipliers": [0, 0, 0],
  "totalPrizeCents": 0,
  "timeBonusPerSecond": 0,
  "timeBonusMaxPoints": 0
}
```

## Hot Reloading

The configuration is loaded at server startup. To apply changes:

1. Edit `lobbies.json`
2. Restart the server (`npm run dev`)

## Validation

The system will validate that:

- All required fields are present
- `boardSize` is 4 or 5
- `entryFee` and `totalPrizeCents` are positive numbers
- `gameDuration` is reasonable (60-1800 seconds)
- `maxPlayers` is between 2 and 10

If validation fails, the server will log an error and use an empty lobby list.

