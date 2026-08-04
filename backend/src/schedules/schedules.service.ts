import { Injectable, Logger, NotFoundException } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';
import { RobotsService } from '../robots/robots.service';
import { TuyaService } from '../tuya/tuya.service';
import { UpsertScheduleDto } from './dto/upsert-schedule.dto';

/// Mirrors the encode functions in the Flutter app's
/// `tuya_wire_protocol.dart` — kept in sync by hand since this is a
/// separate runtime (TypeScript backend vs. Dart client), not shared code.
const MODE_TO_TUYA: Record<string, string> = {
  auto: 'smart',
  room: 'select_room',
  zone: 'zone',
  spot: 'pose',
  custom: 'smart',
};

const VACUUM_POWER_TO_SUCTION: Record<string, string> = {
  silent: 'gentle',
  eco: 'gentle',
  standard: 'normal',
  strong: 'strong',
  turbo: 'max',
  maximum: 'max',
  custom: 'normal',
};

const WATER_LEVEL_TO_OUTPUT: Record<string, string> = {
  off: 'closed',
  low: 'low',
  medium: 'middle',
  high: 'high',
  ultra: 'high',
};

@Injectable()
export class SchedulesService {
  private readonly logger = new Logger(SchedulesService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly robotsService: RobotsService,
    private readonly tuyaService: TuyaService,
  ) {}

  async findAll(userId: string, robotId: string) {
    await this.robotsService.findOneForUser(userId, robotId);
    return this.prisma.schedule.findMany({ where: { robotId } });
  }

  async create(userId: string, robotId: string, dto: UpsertScheduleDto) {
    const robot = await this.robotsService.findOneForUser(userId, robotId);
    const tuyaTimerId = await this.pushToDevice(robot.tuyaDeviceId, dto);
    return this.prisma.schedule.create({
      data: { ...dto, roomIds: JSON.stringify(dto.roomIds), robotId, tuyaTimerId },
    });
  }

  async update(userId: string, robotId: string, scheduleId: string, dto: UpsertScheduleDto) {
    const robot = await this.robotsService.findOneForUser(userId, robotId);
    const existing = await this.ensureScheduleBelongsToRobot(userId, robotId, scheduleId);

    // Tuya's timer API has no documented in-place update we've verified
    // against this device — delete-and-recreate is the safe, confirmed
    // path, matching how `createTimer`/`deleteTimer` were validated.
    if (existing.tuyaTimerId) {
      await this.deleteFromDevice(robot.tuyaDeviceId, existing.tuyaTimerId);
    }
    const tuyaTimerId = await this.pushToDevice(robot.tuyaDeviceId, dto);

    return this.prisma.schedule.update({
      where: { id: scheduleId },
      data: { ...dto, roomIds: JSON.stringify(dto.roomIds), tuyaTimerId },
    });
  }

  async remove(userId: string, robotId: string, scheduleId: string) {
    const robot = await this.robotsService.findOneForUser(userId, robotId);
    const existing = await this.ensureScheduleBelongsToRobot(userId, robotId, scheduleId);
    if (existing.tuyaTimerId) {
      await this.deleteFromDevice(robot.tuyaDeviceId, existing.tuyaTimerId);
    }
    await this.prisma.schedule.delete({ where: { id: scheduleId } });
  }

  /// Pushes a schedule to the robot's own clock via Tuya's Device Timer
  /// service, so it fires even when the phone is offline and this backend
  /// is asleep. Returns null (rather than throwing) for non-Tuya robots or
  /// if the push fails — the schedule still works as an in-app record
  /// either way, only device-side firing is lost.
  private async pushToDevice(
    tuyaDeviceId: string | null,
    dto: UpsertScheduleDto,
  ): Promise<string | null> {
    if (!tuyaDeviceId) return null;
    try {
      return await this.tuyaService.createTimer(tuyaDeviceId, {
        aliasName: this.sanitizeAliasName(dto.label),
        time: dto.time,
        timezoneId: 'Asia/Kolkata',
        loops: this.toLoopsBitmask(dto.daysOfWeek),
        functions: this.toTuyaFunctions(dto),
      });
    } catch (error) {
      this.logger.error(`Failed to push schedule to Tuya device ${tuyaDeviceId}: ${String(error)}`);
      return null;
    }
  }

  private async deleteFromDevice(tuyaDeviceId: string | null, timerId: string): Promise<void> {
    if (!tuyaDeviceId) return;
    try {
      await this.tuyaService.deleteTimer(tuyaDeviceId, timerId);
    } catch (error) {
      this.logger.error(`Failed to delete Tuya timer ${timerId}: ${String(error)}`);
    }
  }

  /// Confirmed empirically: alphanumerics/spaces/hyphens are accepted,
  /// but keep it conservative since the real rejection reason for the
  /// original "alias_name param is illegal" error turned out to be a
  /// missing `category` field, not the alias content — so this hasn't
  /// been pushed to its actual limits.
  private sanitizeAliasName(label: string): string {
    const cleaned = label.replace(/[^a-zA-Z0-9 \-]/g, '').trim();
    return (cleaned || 'BotDyNax Schedule').slice(0, 50);
  }

  /// CSV of weekday indices 0(Sun)-6(Sat) -> Tuya's 7-char loops bitmask,
  /// same Sun-first order, so index i maps directly to bitmask position i.
  private toLoopsBitmask(daysOfWeek: string): string {
    const days = daysOfWeek === 'DAILY'
      ? [0, 1, 2, 3, 4, 5, 6]
      : daysOfWeek.split(',').filter(Boolean).map(Number);
    const bits = Array(7).fill('0');
    for (const d of days) {
      if (d >= 0 && d <= 6) bits[d] = '1';
    }
    return bits.join('');
  }

  private toTuyaFunctions(dto: UpsertScheduleDto): Array<{ code: string; value: unknown }> {
    return [
      { code: 'mode', value: MODE_TO_TUYA[dto.mode] ?? 'smart' },
      { code: 'suction', value: VACUUM_POWER_TO_SUCTION[dto.vacuumPower] ?? 'normal' },
      { code: 'water_output', value: WATER_LEVEL_TO_OUTPUT[dto.waterLevel] ?? 'middle' },
      { code: 'switch_go', value: true },
    ];
  }

  private async ensureScheduleBelongsToRobot(userId: string, robotId: string, scheduleId: string) {
    await this.robotsService.findOneForUser(userId, robotId);
    const schedule = await this.prisma.schedule.findUnique({ where: { id: scheduleId } });
    if (!schedule || schedule.robotId !== robotId) {
      throw new NotFoundException('Schedule not found');
    }
    return schedule;
  }
}
