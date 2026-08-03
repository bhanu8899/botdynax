import { Module } from '@nestjs/common';

import { RobotsModule } from '../robots/robots.module';
import { TuyaClientService } from './tuya-client.service';
import { TuyaController } from './tuya.controller';
import { TuyaService } from './tuya.service';

@Module({
  imports: [RobotsModule],
  controllers: [TuyaController],
  providers: [TuyaClientService, TuyaService],
  exports: [TuyaService],
})
export class TuyaModule {}
