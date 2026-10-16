-- CreateEnum
CREATE TYPE "AlertType" AS ENUM ('FALL_CANDIDATE', 'SPO2_DROP', 'BPM_ABNORMAL', 'TEMP_ABNORMAL', 'BAND_UNWORN', 'BAND_OFFLINE');

-- CreateEnum
CREATE TYPE "AlertStatus" AS ENUM ('PENDING', 'ACKNOWLEDGED_HANDLED', 'ACKNOWLEDGED_FALSE_ALARM', 'ESCALATED_TELEGRAM');

-- CreateTable
CREATE TABLE "User" (
    "id" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "password" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "role" TEXT NOT NULL DEFAULT 'FAMILY',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Elder" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "age" INTEGER NOT NULL,
    "comorbidities" TEXT,
    "notes" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Elder_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Device" (
    "id" TEXT NOT NULL,
    "deviceId" TEXT NOT NULL,
    "elderId" TEXT,
    "isOnline" BOOLEAN NOT NULL DEFAULT false,
    "isWorn" BOOLEAN NOT NULL DEFAULT true,
    "isCharging" BOOLEAN NOT NULL DEFAULT false,
    "batteryLevel" INTEGER NOT NULL DEFAULT 100,
    "lastSeenAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Device_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "VitalTelemetry" (
    "id" TEXT NOT NULL,
    "deviceId" TEXT NOT NULL,
    "bpm" INTEGER NOT NULL,
    "spo2" INTEGER NOT NULL,
    "temp" DOUBLE PRECISION,
    "signalQuality" INTEGER NOT NULL,
    "timestamp" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "VitalTelemetry_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AlertEvent" (
    "id" TEXT NOT NULL,
    "deviceId" TEXT NOT NULL,
    "elderId" TEXT,
    "type" "AlertType" NOT NULL,
    "status" "AlertStatus" NOT NULL DEFAULT 'PENDING',
    "title" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "peakG" DOUBLE PRECISION,
    "stillDurationS" INTEGER,
    "preBpm" INTEGER,
    "postBpm" INTEGER,
    "handledBy" TEXT,
    "handledAt" TIMESTAMP(3),
    "escalatedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AlertEvent_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "EmergencyContact" (
    "id" TEXT NOT NULL,
    "elderId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "telegramChatId" TEXT NOT NULL,
    "priorityOrder" INTEGER NOT NULL DEFAULT 1,
    "isAgreed" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "EmergencyContact_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ThresholdConfig" (
    "id" TEXT NOT NULL,
    "elderId" TEXT NOT NULL,
    "minSpo2" INTEGER NOT NULL DEFAULT 95,
    "minBpm" INTEGER NOT NULL DEFAULT 60,
    "maxBpm" INTEGER NOT NULL DEFAULT 100,
    "maxTemp" DOUBLE PRECISION NOT NULL DEFAULT 37.5,
    "isDefault" BOOLEAN NOT NULL DEFAULT true,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ThresholdConfig_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ThresholdAuditLog" (
    "id" TEXT NOT NULL,
    "elderId" TEXT NOT NULL,
    "changedBy" TEXT NOT NULL,
    "oldValues" JSONB NOT NULL,
    "newValues" JSONB NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ThresholdAuditLog_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "User_email_key" ON "User"("email");

-- CreateIndex
CREATE UNIQUE INDEX "Device_deviceId_key" ON "Device"("deviceId");

-- CreateIndex
CREATE UNIQUE INDEX "Device_elderId_key" ON "Device"("elderId");

-- CreateIndex
CREATE INDEX "VitalTelemetry_deviceId_timestamp_idx" ON "VitalTelemetry"("deviceId", "timestamp");

-- CreateIndex
CREATE INDEX "AlertEvent_deviceId_createdAt_idx" ON "AlertEvent"("deviceId", "createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "ThresholdConfig_elderId_key" ON "ThresholdConfig"("elderId");

-- AddForeignKey
ALTER TABLE "Device" ADD CONSTRAINT "Device_elderId_fkey" FOREIGN KEY ("elderId") REFERENCES "Elder"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "VitalTelemetry" ADD CONSTRAINT "VitalTelemetry_deviceId_fkey" FOREIGN KEY ("deviceId") REFERENCES "Device"("deviceId") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AlertEvent" ADD CONSTRAINT "AlertEvent_deviceId_fkey" FOREIGN KEY ("deviceId") REFERENCES "Device"("deviceId") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AlertEvent" ADD CONSTRAINT "AlertEvent_elderId_fkey" FOREIGN KEY ("elderId") REFERENCES "Elder"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "EmergencyContact" ADD CONSTRAINT "EmergencyContact_elderId_fkey" FOREIGN KEY ("elderId") REFERENCES "Elder"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ThresholdConfig" ADD CONSTRAINT "ThresholdConfig_elderId_fkey" FOREIGN KEY ("elderId") REFERENCES "Elder"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ThresholdAuditLog" ADD CONSTRAINT "ThresholdAuditLog_elderId_fkey" FOREIGN KEY ("elderId") REFERENCES "Elder"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ThresholdAuditLog" ADD CONSTRAINT "ThresholdAuditLog_changedBy_fkey" FOREIGN KEY ("changedBy") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
