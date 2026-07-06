/*
  Warnings:

  - You are about to drop the column `balanceBonus` on the `User` table. All the data in the column will be lost.
  - You are about to drop the column `balanceCash` on the `User` table. All the data in the column will be lost.
  - You are about to drop the column `balanceGems` on the `User` table. All the data in the column will be lost.
  - You are about to drop the `Board` table. If the table is not empty, all the data it contains will be lost.
  - You are about to drop the `Match` table. If the table is not empty, all the data it contains will be lost.
  - A unique constraint covering the columns `[username]` on the table `User` will be added. If there are existing duplicate values, this will fail.

*/
-- DropForeignKey
ALTER TABLE "Match" DROP CONSTRAINT "Match_boardId_fkey";

-- DropForeignKey
ALTER TABLE "Match" DROP CONSTRAINT "Match_playerId_fkey";

-- DropForeignKey
ALTER TABLE "Transaction" DROP CONSTRAINT "Transaction_userId_fkey";

-- AlterTable
ALTER TABLE "Transaction" ADD COLUMN     "lobbyType" TEXT,
ADD COLUMN     "matchId" TEXT;

-- AlterTable
ALTER TABLE "User" DROP COLUMN "balanceBonus",
DROP COLUMN "balanceCash",
DROP COLUMN "balanceGems",
ADD COLUMN     "bonusBalance" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "cashBalance" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "gemBalance" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "username" TEXT,
ALTER COLUMN "authUid" DROP NOT NULL;

-- DropTable
DROP TABLE "Board";

-- DropTable
DROP TABLE "Match";

-- CreateTable
CREATE TABLE "CompletedMatch" (
    "id" TEXT NOT NULL,
    "lobbyType" TEXT NOT NULL,
    "entryFee" INTEGER NOT NULL,
    "prizePool" INTEGER NOT NULL,
    "gameDuration" INTEGER NOT NULL,
    "status" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL,
    "startedAt" TIMESTAMP(3),
    "endedAt" TIMESTAMP(3) NOT NULL,
    "board" JSONB NOT NULL,
    "players" JSONB NOT NULL,

    CONSTRAINT "CompletedMatch_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "CompletedMatch_endedAt_idx" ON "CompletedMatch"("endedAt");

-- CreateIndex
CREATE UNIQUE INDEX "User_username_key" ON "User"("username");

-- AddForeignKey
ALTER TABLE "Transaction" ADD CONSTRAINT "Transaction_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
