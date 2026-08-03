import { Injectable, NotFoundException } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';
import { RobotsService } from '../robots/robots.service';
import { UpsertScheduleDto } from './dto/upsert-schedule.dto';

@Injectable()
export class SchedulesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly robotsService: RobotsService,
  ) {}

  async findAll(userId: string, robotId: string) {
    await this.robotsService.findOneForUser(userId, robotId);
    return this.prisma.schedule.findMany({ where: { robotId } });
  }

  async create(userId: string, robotId: string, dto: UpsertScheduleDto) {
    await this.robotsService.findOneForUser(userId, robotId);
    return this.prisma.schedule.create({
      data: { ...dto, roomIds: JSON.stringify(dto.roomIds), robotId },
    });
  }

  async update(userId: string, robotId: string, scheduleId: string, dto: UpsertScheduleDto) {
    await this.ensureScheduleBelongsToRobot(userId, robotId, scheduleId);
    return this.prisma.schedule.update({
      where: { id: scheduleId },
      data: { ...dto, roomIds: JSON.stringify(dto.roomIds) },
    });
  }

  async remove(userId: string, robotId: string, scheduleId: string) {
    await this.ensureScheduleBelongsToRobot(userId, robotId, scheduleId);
    await this.prisma.schedule.delete({ where: { id: scheduleId } });
  }

  private async ensureScheduleBelongsToRobot(
    userId: string,
    robotId: string,
    scheduleId: string,
  ): Promise<void> {
    await this.robotsService.findOneForUser(userId, robotId);
    const schedule = await this.prisma.schedule.findUnique({ where: { id: scheduleId } });
    if (!schedule || schedule.robotId !== robotId) {
      throw new NotFoundException('Schedule not found');
    }
  }
}
