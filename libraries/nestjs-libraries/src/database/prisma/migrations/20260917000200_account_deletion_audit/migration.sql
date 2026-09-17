-- CreateTable
CREATE TABLE "AccountDeletionAudit" (
    "id" TEXT NOT NULL,
    "userIdHash" TEXT NOT NULL,
    "email" TEXT,
    "orgIdsDeleted" TEXT[],
    "orgIdsLeft" TEXT[],
    "source" TEXT NOT NULL DEFAULT 'mobile',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AccountDeletionAudit_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "AccountDeletionAudit_userIdHash_idx" ON "AccountDeletionAudit"("userIdHash");

-- CreateIndex
CREATE INDEX "AccountDeletionAudit_createdAt_idx" ON "AccountDeletionAudit"("createdAt");
