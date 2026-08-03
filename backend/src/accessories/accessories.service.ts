import { Injectable, NotFoundException } from '@nestjs/common';
import { AccessoryType } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { RobotsService } from '../robots/robots.service';
import { UpsertAccessoryDto } from './dto/upsert-accessory.dto';

@Injectable()
export class AccessoriesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly robotsService: RobotsService,
  ) {}

  async findAll(userId: string, robotId: string) {
    await this.robotsService.findOneForUser(userId, robotId);
    return this.prisma.accessory.findMany({ where: { robotId } });
  }

  async upsert(userId: string, robotId: string, dto: UpsertAccessoryDto) {
    await this.robotsService.findOneForUser(userId, robotId);
    const existing = await this.prisma.accessory.findFirst({ where: { robotId, type: dto.type } });

    if (existing) {
      return this.prisma.accessory.update({ where: { id: existing.id }, data: dto });
    }
    return this.prisma.accessory.create({ data: { ...dto, robotId } });
  }

  async markReplaced(userId: string, robotId: string, accessoryId: string) {
    await this.robotsService.findOneForUser(userId, robotId);
    return this.prisma.accessory.update({
      where: { id: accessoryId },
      data: { remainingPercent: 1, usedMinutes: 0, lastReplacedAt: new Date() },
    });
  }

  /// Convenience for clients that only know the accessory's type (from live
  /// robot status), not its backend-assigned id.
  async markReplacedByType(userId: string, robotId: string, type: AccessoryType) {
    await this.robotsService.findOneForUser(userId, robotId);
    const existing = await this.prisma.accessory.findFirst({ where: { robotId, type } });
    if (!existing) {
      throw new NotFoundException(`No ${type} accessory recorded for this robot yet`);
    }
    return this.prisma.accessory.update({
      where: { id: existing.id },
      data: { remainingPercent: 1, usedMinutes: 0, lastReplacedAt: new Date() },
    });
  }
}
