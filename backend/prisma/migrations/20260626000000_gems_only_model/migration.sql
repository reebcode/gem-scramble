-- Reconcile the data model to a gems-only economy.
-- Removes the leftover cash/bonus-cash columns, introduces the bonus gems
-- column the application code expects, and adds the uniqueness constraint that
-- entry-fee / prize idempotency relies on.

-- AlterTable: drop cash-era columns, add bonus gems, align gem default.
ALTER TABLE "User" DROP COLUMN IF EXISTS "cashBalance";
ALTER TABLE "User" DROP COLUMN IF EXISTS "bonusBalance";
ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "bonusGems" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "User" ALTER COLUMN "gemBalance" SET DEFAULT 100;

-- CreateIndex: enforce one transaction per (user, match, type) so retries and
-- concurrent completions are idempotent at the database level.
CREATE UNIQUE INDEX IF NOT EXISTS "Transaction_userId_matchId_type_key"
  ON "Transaction"("userId", "matchId", "type");
