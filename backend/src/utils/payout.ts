import { MatchPlayer } from "../state/match.interface.js";

function sum(numbers: number[]): number {
  return numbers.reduce((acc, n) => acc + n, 0);
}

function clampToNonNegativeInt(value: number): number {
  const v = Math.floor(value);
  return v < 0 ? 0 : v;
}

/**
 * Rank players and allocate winnings using payout multipliers with tie handling.
 *
 * Rules:
 * - Sort by score desc.
 * - Consider top N ranks where N = min(players.length, multipliers.length).
 * - Compute per-rank allocations proportionally to multipliers, rounding down to cents.
 *   Distribute remainder cents to rank 1.
 * - For ties spanning ranks r..r+k, sum the allocations for those ranks
 *   (only ranks within N contribute). Split equally among tied players, distributing
 *   leftover cents to earlier players in the tie ordering.
 * - Players outside top N receive 0 unless included in a tie group that overlaps top N.
 * - Rank reported for each player is the starting place of their tie group (standard competition ranking).
 */
export function rankAndAllocateWinnings(
  players: MatchPlayer[],
  totalPrizeGems: number,
  multipliers: number[]
): MatchPlayer[] {
  const sorted: MatchPlayer[] = players
    .slice()
    .sort((a, b) => (b.score ?? 0) - (a.score ?? 0));

  // Assign provisional rank indices (1-based) for ordering
  const ordered = sorted.map((p, idx) => ({ ...p, _orderRank: idx + 1 }));

  const n = Math.min(ordered.length, Math.max(0, multipliers.length));
  if (totalPrizeGems <= 0 || n === 0) {
    // No prize pool or no payout multipliers: return with ranks and zero winnings
    // Rank = standard competition ranking, winnings = 0
    const result: MatchPlayer[] = [];
    let i = 0;
    while (i < ordered.length) {
      const groupScore = ordered[i].score;
      let j = i;
      while (j + 1 < ordered.length && ordered[j + 1].score === groupScore) j++;
      const groupStartRank = i + 1;
      for (let k = i; k <= j; k++) {
        result.push({ ...ordered[k], rank: groupStartRank, winnings: 0 });
      }
      i = j + 1;
    }
    // Remove internal field
    return result.map(({ _orderRank, ...rest }: any) => rest as MatchPlayer);
  }

  // Compute per-rank allocation amounts for ranks 1..n
  const weights = multipliers
    .slice(0, n)
    .map((w) => Math.max(0, Number(w) || 0));
  const weightSum = sum(weights);
  // Guard: if sum is zero, no payouts
  const baseRankAmounts = new Array<number>(n).fill(0);
  if (weightSum > 0) {
    let distributed = 0;
    for (let r = 0; r < n; r++) {
      const amt = clampToNonNegativeInt(
        (totalPrizeGems * weights[r]) / weightSum
      );
      baseRankAmounts[r] = amt;
      distributed += amt;
    }
    const remainder = totalPrizeGems - distributed;
    if (remainder > 0) {
      baseRankAmounts[0] += remainder; // give remainder to 1st place
    }
  }

  // Walk tie groups and allocate winnings
  const withWinnings: MatchPlayer[] = [];
  let i = 0;
  while (i < ordered.length) {
    const groupScore = ordered[i].score;
    let j = i;
    while (j + 1 < ordered.length && ordered[j + 1].score === groupScore) j++;
    const groupStartRank = i + 1; // 1-based
    const groupEndRank = j + 1; // 1-based inclusive

    // Sum base allocations for the covered ranks within 1..n
    let groupTotal = 0;
    for (let r = groupStartRank; r <= groupEndRank; r++) {
      if (r >= 1 && r <= n) groupTotal += baseRankAmounts[r - 1];
    }

    if (groupTotal <= 0) {
      // Entire group outside payout ranks
      for (let k = i; k <= j; k++) {
        withWinnings.push({ ...ordered[k], rank: groupStartRank, winnings: 0 });
      }
    } else {
      const groupSize = j - i + 1;
      const per = Math.floor(groupTotal / groupSize);
      let rem = groupTotal - per * groupSize;
      for (let k = i; k <= j; k++) {
        const bonus = rem > 0 ? 1 : 0;
        const amt = per + bonus;
        withWinnings.push({
          ...ordered[k],
          rank: groupStartRank,
          winnings: amt,
        });
        if (rem > 0) rem -= 1; // distribute leftover cents to earlier players
      }
    }

    i = j + 1;
  }

  // Remove internal field
  return withWinnings.map(
    ({ _orderRank, ...rest }: any) => rest as MatchPlayer
  );
}
