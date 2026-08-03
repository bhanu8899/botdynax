import { Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { OnGatewayConnection, OnGatewayDisconnect, WebSocketGateway } from '@nestjs/websockets';
import { IncomingMessage } from 'http';
import { Subscription } from 'rxjs';
import { WebSocket } from 'ws';

import { JwtPayload } from '../auth/jwt-payload.interface';
import { MqttBridgeService, RobotFrame } from '../mqtt/mqtt-bridge.service';
import { PrismaService } from '../prisma/prisma.service';

interface RobotSocket extends WebSocket {
  robotId?: string;
}

/// Raw WebSocket endpoint at `ws://host/robots?robotId=..&token=..`.
///
/// Uses plain `ws` framing (via `@nestjs/platform-ws`, wired in main.ts)
/// rather than Socket.IO, so it speaks the exact same protocol the app's
/// `WifiTransport` (built on `web_socket_channel`) expects — no Socket.IO
/// client needed on the Flutter side.
@WebSocketGateway({ path: '/robots' })
export class RobotsGateway implements OnGatewayConnection, OnGatewayDisconnect {
  private readonly logger = new Logger(RobotsGateway.name);
  private readonly clientsByRobot = new Map<string, Set<RobotSocket>>();
  private bridgeSubscription: Subscription | undefined;

  constructor(
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
    private readonly prisma: PrismaService,
    private readonly mqttBridge: MqttBridgeService,
  ) {
    this.bridgeSubscription = this.mqttBridge.robotFrames$.subscribe((frame) => this.fanOut(frame));
  }

  async handleConnection(client: RobotSocket, request: IncomingMessage): Promise<void> {
    const url = new URL(request.url ?? '', 'ws://localhost');
    const robotId = url.searchParams.get('robotId');
    const token = url.searchParams.get('token');

    if (!robotId || !token) {
      client.close(4001, 'robotId and token query parameters are required');
      return;
    }

    try {
      const payload = await this.jwt.verifyAsync<JwtPayload>(token, {
        secret: this.config.get<string>('jwt.accessSecret'),
      });
      const robot = await this.prisma.robot.findUnique({ where: { id: robotId } });
      if (!robot || robot.ownerId !== payload.sub) {
        client.close(4003, 'Not authorized for this robot');
        return;
      }
    } catch {
      client.close(4001, 'Invalid or expired token');
      return;
    }

    client.robotId = robotId;
    const existing = this.clientsByRobot.get(robotId) ?? new Set<RobotSocket>();
    existing.add(client);
    this.clientsByRobot.set(robotId, existing);
    this.logger.log(`App client connected for robot ${robotId}`);
  }

  handleDisconnect(client: RobotSocket): void {
    if (!client.robotId) return;
    this.clientsByRobot.get(client.robotId)?.delete(client);
  }

  onModuleDestroy(): void {
    this.bridgeSubscription?.unsubscribe();
  }

  private fanOut(frame: RobotFrame): void {
    const clients = this.clientsByRobot.get(frame.robotId);
    if (!clients?.size) return;

    const message = JSON.stringify({ type: frame.type, payload: frame.payload });
    for (const client of clients) {
      if (client.readyState === client.OPEN) {
        client.send(message);
      }
    }
  }
}
