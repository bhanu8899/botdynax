import { Body, Controller, Get, Param, Post, UseGuards } from '@nestjs/common';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { AuthenticatedUser } from '../auth/jwt-payload.interface';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { CreateCleaningSessionDto } from './dto/create-cleaning-session.dto';
import { HistoryService } from './history.service';

@UseGuards(JwtAuthGuard)
@Controller('robots/:robotId/history')
export class HistoryController {
  constructor(private readonly historyService: HistoryService) {}

  @Get()
  findAll(@CurrentUser() user: AuthenticatedUser, @Param('robotId') robotId: string) {
    return this.historyService.findAll(user.id, robotId);
  }

  @Post()
  create(
    @CurrentUser() user: AuthenticatedUser,
    @Param('robotId') robotId: string,
    @Body() dto: CreateCleaningSessionDto,
  ) {
    return this.historyService.create(user.id, robotId, dto);
  }
}
