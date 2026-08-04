import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { APP_GUARD } from '@nestjs/core';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';

import { AccessoriesModule } from './accessories/accessories.module';
import { AppController } from './app.controller';
import { DiagnosticsController } from './diagnostics/diagnostics.controller';
import configuration from './config/configuration';
import { HistoryModule } from './history/history.module';
import { MqttModule } from './mqtt/mqtt.module';
import { NotificationsModule } from './notifications/notifications.module';
import { PrismaModule } from './prisma/prisma.module';
import { RobotsModule } from './robots/robots.module';
import { SchedulesModule } from './schedules/schedules.module';
import { AuthModule } from './auth/auth.module';
import { TuyaModule } from './tuya/tuya.module';
import { UsersModule } from './users/users.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true, load: [configuration] }),
    ThrottlerModule.forRoot([{ ttl: 60_000, limit: 120 }]),
    PrismaModule,
    MqttModule,
    AuthModule,
    UsersModule,
    RobotsModule,
    SchedulesModule,
    HistoryModule,
    AccessoriesModule,
    NotificationsModule,
    TuyaModule,
  ],
  controllers: [AppController, DiagnosticsController],
  providers: [{ provide: APP_GUARD, useClass: ThrottlerGuard }],
})
export class AppModule {}
