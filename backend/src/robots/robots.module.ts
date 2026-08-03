import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';

import { RobotsController } from './robots.controller';
import { RobotsGateway } from './robots.gateway';
import { RobotsService } from './robots.service';

@Module({
  imports: [JwtModule.register({})],
  controllers: [RobotsController],
  providers: [RobotsService, RobotsGateway],
  exports: [RobotsService],
})
export class RobotsModule {}
