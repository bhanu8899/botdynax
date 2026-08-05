import { Body, Controller, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { AuthenticatedUser } from '../auth/jwt-payload.interface';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { CreateNotificationDto } from './dto/create-notification.dto';
import { NotificationsService } from './notifications.service';

@UseGuards(JwtAuthGuard)
@Controller('notifications')
export class NotificationsController {
  constructor(private readonly notificationsService: NotificationsService) {}

  @Get()
  findAll(@CurrentUser() user: AuthenticatedUser) {
    return this.notificationsService.findAll(user.id);
  }

  /// The app has no server-side connection to the real Tuya device (all
  /// polling happens client-side, see TuyaTransport) — so unlike a
  /// firmware that pushes events to the backend over MQTT, the client is
  /// the one detecting cleaning-started/completed/error events and
  /// reports them here to persist as a real notification record.
  @Post()
  create(@CurrentUser() user: AuthenticatedUser, @Body() dto: CreateNotificationDto) {
    return this.notificationsService.create(user.id, dto.type, dto.message, dto.robotId);
  }

  @Patch(':id/read')
  markRead(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string) {
    return this.notificationsService.markRead(user.id, id);
  }
}
