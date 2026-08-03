import { AccessoryType, AuthProvider, PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main(): Promise<void> {
  const user = await prisma.user.upsert({
    where: { email: 'demo@botdynax.com' },
    update: {},
    create: {
      email: 'demo@botdynax.com',
      name: 'Demo User',
      authProvider: AuthProvider.EMAIL,
      // password: "botdynax123" — set via /auth/register in real use;
      // seed data skips password auth since this account is for API
      // exploration only.
    },
  });

  const robot = await prisma.robot.upsert({
    where: { serialNumber: 'BDX-DEMO-0001' },
    update: {},
    create: {
      ownerId: user.id,
      name: 'Living Room Vacuum',
      model: 'BotDyNax Vacuum X1',
      serialNumber: 'BDX-DEMO-0001',
      firmwareVersion: '1.4.2',
    },
  });

  const existingAccessories = await prisma.accessory.count({ where: { robotId: robot.id } });
  if (existingAccessories === 0) {
    await prisma.accessory.createMany({
      data: [
        { robotId: robot.id, type: AccessoryType.MAIN_BRUSH, remainingPercent: 0.78, ratedLifetimeMinutes: 18000, usedMinutes: 3960 },
        { robotId: robot.id, type: AccessoryType.SIDE_BRUSH, remainingPercent: 0.64, ratedLifetimeMinutes: 12000, usedMinutes: 4320 },
        { robotId: robot.id, type: AccessoryType.FILTER, remainingPercent: 0.41, ratedLifetimeMinutes: 9000, usedMinutes: 5310 },
        { robotId: robot.id, type: AccessoryType.MOP_PAD, remainingPercent: 0.85, ratedLifetimeMinutes: 6000, usedMinutes: 900 },
      ],
    });
  }

  // eslint-disable-next-line no-console
  console.log(`Seeded user ${user.email} with robot ${robot.name} (${robot.id})`);
}

main()
  .catch((error: unknown) => {
    // eslint-disable-next-line no-console
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
