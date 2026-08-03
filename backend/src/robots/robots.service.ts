import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { AuthProvider, Robot } from '@prisma/client';

import { MqttBridgeService } from '../mqtt/mqtt-bridge.service';
import { PrismaService } from '../prisma/prisma.service';
import { RegisterRobotDto } from './dto/register-robot.dto';
import { UpdateRobotDto } from './dto/update-robot.dto';

@Injectable()
export class RobotsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly mqttBridge: MqttBridgeService,
  ) {}

  findAllForUser(userId: string): Promise<Robot[]> {
    return this.prisma.robot.findMany({ where: { ownerId: userId } });
  }

  async findOneForUser(userId: string, robotId: string): Promise<Robot> {
    const robot = await this.prisma.robot.findUnique({ where: { id: robotId } });
    if (!robot) throw new NotFoundException('Robot not found');
    if (robot.ownerId !== userId) throw new ForbiddenException('This robot belongs to another account');
    return robot;
  }

  /// Idempotent by `serialNumber`: the app calls this every time it
  /// connects to a robot via BLE/WiFi/MQTT/Tuya/Simulator to make sure a
  /// backend fleet record exists for it (needed for schedules/history/
  /// accessories), without erroring on the second-and-later calls for the
  /// same physical robot.
  ///
  /// Guest identities are ephemeral (a new one is minted every time a
  /// session can't be restored) — if a robot is currently owned by a
  /// GUEST account, a new caller re-registering the same serial number is
  /// treated as "still you, new session" and takes over ownership, rather
  /// than being permanently locked out. Robots owned by a real account
  /// (email/Google/Apple) stay protected — those never get silently
  /// reassigned.
  async register(userId: string, dto: RegisterRobotDto): Promise<Robot> {
    const existing = await this.prisma.robot.findUnique({
      where: { serialNumber: dto.serialNumber },
      include: { owner: true },
    });
    if (existing) {
      if (existing.ownerId !== userId) {
        if (existing.owner.authProvider !== AuthProvider.GUEST) {
          throw new ForbiddenException('This robot is already registered to another account');
        }
        return this.prisma.robot.update({ where: { id: existing.id }, data: { ownerId: userId } });
      }
      return existing;
    }
    return this.prisma.robot.create({
      data: { ...dto, ownerId: userId },
    });
  }

  async update(userId: string, robotId: string, dto: UpdateRobotDto): Promise<Robot> {
    await this.findOneForUser(userId, robotId);
    return this.prisma.robot.update({ where: { id: robotId }, data: dto });
  }

  async unpair(userId: string, robotId: string): Promise<void> {
    await this.findOneForUser(userId, robotId);
    await this.prisma.robot.delete({ where: { id: robotId } });
  }

  /// Ties this robot record to a real Tuya device id (e.g. an OEM'd
  /// product like the Milagrow iMap Max W300). Every /tuya/* call is
  /// scoped through this — never a raw device id from the client — so a
  /// user can only ever reach Tuya devices tied to a robot they own.
  async linkTuyaDevice(userId: string, robotId: string, tuyaDeviceId: string): Promise<Robot> {
    await this.findOneForUser(userId, robotId);
    return this.prisma.robot.update({ where: { id: robotId }, data: { tuyaDeviceId } });
  }

  async requireTuyaDeviceId(userId: string, robotId: string): Promise<string> {
    const robot = await this.findOneForUser(userId, robotId);
    if (!robot.tuyaDeviceId) {
      throw new BadRequestException('This robot is not linked to a Tuya device yet');
    }
    return robot.tuyaDeviceId;
  }

  /// Publishes a command to `botdynax/{robotId}/commands` — the same topic
  /// contract the app's own MQTTTransport subscribes to, and that real
  /// BotDyNax firmware should subscribe to as well.
  async sendCommand(userId: string, robotId: string, command: Record<string, unknown>): Promise<void> {
    await this.findOneForUser(userId, robotId);
    if (typeof command.cmd !== 'string') {
      throw new BadRequestException('Command payload must include a "cmd" field');
    }
    this.mqttBridge.publishCommand(robotId, command);
  }
}
