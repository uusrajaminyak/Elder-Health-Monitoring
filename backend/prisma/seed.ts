import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Memulai seeding database...');

  // 1. Buat User Wali / Admin
  await prisma.user.upsert({
    where: { email: 'keluarga@zeroband.com' },
    update: {},
    create: {
      email: 'keluarga@zeroband.com',
      password: 'password123',
      name: 'Keluarga Wali',
      role: 'FAMILY',
    },
  });

  // 2. Buat Profil Lansia
  const elder = await prisma.elder.create({
    data: {
      name: 'Oma Mary',
      age: 72,
      comorbidities: 'Hipertensi, Riwayat Perburukan SpO2',
      notes: 'Membutuhkan pemantauan rutin SpO2 dan deteksi jatuh',
    },
  });

  // 3. Pair Device BAND-001 ke Profil Lansia
  await prisma.device.upsert({
    where: { deviceId: process.env.DEVICE_ID || 'BAND-001' },
    update: { elderId: elder.id },
    create: {
      deviceId: process.env.DEVICE_ID || 'BAND-001',
      elderId: elder.id,
      isOnline: false,
      isWorn: true,
      isCharging: false,
      batteryLevel: 85,
    },
  });

  // 4. Set Threshold Default (Hard Safety Guardrails)
  await prisma.thresholdConfig.upsert({
    where: { elderId: elder.id },
    update: {},
    create: {
      elderId: elder.id,
      minSpo2: 95,
      minBpm: 60,
      maxBpm: 100,
      maxTemp: 37.5,
      isDefault: true,
    },
  });

  // 5. Emergency Contact Telegram
  if (process.env.TELEGRAM_DEFAULT_CHAT_ID) {
    await prisma.emergencyContact.create({
      data: {
        elderId: elder.id,
        name: 'Grup Telegram Keluarga Utama',
        telegramChatId: process.env.TELEGRAM_DEFAULT_CHAT_ID,
        priorityOrder: 1,
        isAgreed: true,
      },
    });
  }

  console.log('✅ Seeding selesai! Profil Oma Mary & Device BAND-001 berhasil didaftarkan.');
}

main()
  .catch((e) => {
    console.error('❌ Gagal seeding:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });