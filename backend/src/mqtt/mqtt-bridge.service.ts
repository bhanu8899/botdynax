import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { connect, MqttClient } from 'mqtt';
import { Subject } from 'rxjs';

/// One inbound frame relayed from the MQTT broker, destined for whichever
/// app WebSocket connections are watching this robot.
export interface RobotFrame {
  robotId: string;
  type: 'status' | 'map' | 'event';
  payload: unknown;
}

/// Bridges the Mosquitto MQTT broker (where real robot firmware and the
/// app's own MQTTTransport publish/subscribe) into the rest of the backend.
/// `robotFrames$` is what RobotsGateway fans out to connected app clients.
@Injectable()
export class MqttBridgeService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(MqttBridgeService.name);
  private client: MqttClient | undefined;
  private readonly frames = new Subject<RobotFrame>();

  readonly robotFrames$ = this.frames.asObservable();

  constructor(private readonly config: ConfigService) {}

  onModuleInit(): void {
    // Only the direct-firmware BLE/WiFi/MQTT transport path needs a
    // broker — Tuya Cloud devices don't touch MQTT at all. No `MQTT_URL`
    // (e.g. no broker deployed alongside this backend, as on a plain
    // Render/Railway web service) just means that path is inert, not
    // broken; skip connecting rather than endlessly retrying against
    // `localhost`, which won't exist off of this dev machine.
    const url = this.config.get<string>('mqtt.url');
    if (!url) {
      this.logger.warn('MQTT_URL not set — skipping broker connection (Tuya-based robots are unaffected).');
      return;
    }
    this.client = connect(url, { clientId: `botdynax-backend-${Math.random().toString(16).slice(2)}` });

    this.client.on('connect', () => {
      this.logger.log(`Connected to MQTT broker at ${url}`);
      this.client?.subscribe('botdynax/+/status');
      this.client?.subscribe('botdynax/+/map');
      this.client?.subscribe('botdynax/+/events');
    });

    this.client.on('error', (error) => this.logger.error(`MQTT error: ${error.message}`));

    this.client.on('message', (topic, payload) => {
      const [, robotId, kind] = topic.split('/');
      if (!robotId || !kind) return;

      const type = kind === 'status' ? 'status' : kind === 'map' ? 'map' : kind === 'events' ? 'event' : null;
      if (!type) return;

      try {
        const parsed: unknown = JSON.parse(payload.toString('utf8'));
        this.frames.next({ robotId, type, payload: parsed });
      } catch {
        this.logger.warn(`Received non-JSON payload on ${topic}`);
      }
    });
  }

  onModuleDestroy(): void {
    this.client?.end(true);
  }

  publishCommand(robotId: string, command: Record<string, unknown>): void {
    this.client?.publish(`botdynax/${robotId}/commands`, JSON.stringify(command), { qos: 1 });
  }
}
