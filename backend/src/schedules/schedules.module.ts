import { Module } from '@nestjs/common';

import { RobotsModule } from '../robots/robots.module';
import { TuyaModule } from '../tuya/tuya.module';
import { SchedulesController } from './schedules.controller';
import { SchedulesService } from './schedules.service';

@Module({
  imports: [RobotsModule, TuyaModule],
  controllers: [SchedulesController],
  providers: [SchedulesService],
})
export class SchedulesModule {}
