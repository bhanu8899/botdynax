import { Body, Controller, Delete, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { AuthenticatedUser } from '../auth/jwt-payload.interface';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { UpsertScheduleDto } from './dto/upsert-schedule.dto';
import { SchedulesService } from './schedules.service';

@UseGuards(JwtAuthGuard)
@Controller('robots/:robotId/schedules')
export class SchedulesController {
  constructor(private readonly schedulesService: SchedulesService) {}

  @Get()
  findAll(@CurrentUser() user: AuthenticatedUser, @Param('robotId') robotId: string) {
    return this.schedulesService.findAll(user.id, robotId);
  }

  @Post()
  create(
    @CurrentUser() user: AuthenticatedUser,
    @Param('robotId') robotId: string,
    @Body() dto: UpsertScheduleDto,
  ) {
    return this.schedulesService.create(user.id, robotId, dto);
  }

  @Patch(':scheduleId')
  update(
    @CurrentUser() user: AuthenticatedUser,
    @Param('robotId') robotId: string,
    @Param('scheduleId') scheduleId: string,
    @Body() dto: UpsertScheduleDto,
  ) {
    return this.schedulesService.update(user.id, robotId, scheduleId, dto);
  }

  @Delete(':scheduleId')
  remove(
    @CurrentUser() user: AuthenticatedUser,
    @Param('robotId') robotId: string,
    @Param('scheduleId') scheduleId: string,
  ) {
    return this.schedulesService.remove(user.id, robotId, scheduleId);
  }
}
