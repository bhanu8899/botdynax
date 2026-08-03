import { Injectable } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';
import { RobotsService } from '../robots/robots.service';
import { CreateCleaningSessionDto } from './dto/create-cleaning-session.dto';

@Injectable()
export class HistoryService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly robotsService: RobotsService,
  ) {}

  async findAll(userId: string, robotId: string) {
    await this.robotsService.findOneForUser(userId, robotId);
    return this.prisma.cleaningSession.findMany({
      where: { robotId },
      orderBy: { startedAt: 'desc' },
    });
  }

  async create(userId: string, robotId: string, dto: CreateCleaningSessionDto) {
    await this.robotsService.findOneForUser(userId, robotId);
    return this.prisma.cleaningSession.create({
      data: {
        robotId,
        completedAt: new Date(),
        areaCleanedSqm: dto.areaCleanedSqm,
        durationSeconds: dto.durationSeconds,
        batteryUsedPercent: dto.batteryUsedPercent,
        errors: JSON.stringify(dto.errors ?? []),
        mapSnapshotUrl: dto.mapSnapshotUrl,
        cleaningScore: dto.cleaningScore,
      },
    });
  }
}
