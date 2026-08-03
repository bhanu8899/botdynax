import { Module } from '@nestjs/common';

import { RobotsModule } from '../robots/robots.module';
import { AccessoriesController } from './accessories.controller';
import { AccessoriesService } from './accessories.service';

@Module({
  imports: [RobotsModule],
  controllers: [AccessoriesController],
  providers: [AccessoriesService],
})
export class AccessoriesModule {}
