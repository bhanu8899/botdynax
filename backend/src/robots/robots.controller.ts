import { Body, Controller, Delete, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { AuthenticatedUser } from '../auth/jwt-payload.interface';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { LinkTuyaDeviceDto } from './dto/link-tuya-device.dto';
import { RegisterRobotDto } from './dto/register-robot.dto';
import { UpdateRobotDto } from './dto/update-robot.dto';
import { RobotsService } from './robots.service';

@UseGuards(JwtAuthGuard)
@Controller('robots')
export class RobotsController {
  constructor(private readonly robotsService: RobotsService) {}

  @Get()
  findAll(@CurrentUser() user: AuthenticatedUser) {
    return this.robotsService.findAllForUser(user.id);
  }

  /// Robots already linked to this account and reachable for (re)connection.
  /// True proximity discovery for first-time setup happens over BLE, not
  /// REST — see the app's BLETransport.scan().
  @Get('nearby')
  nearby(@CurrentUser() user: AuthenticatedUser) {
    return this.robotsService.findAllForUser(user.id);
  }

  @Get(':id')
  findOne(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string) {
    return this.robotsService.findOneForUser(user.id, id);
  }

  @Post()
  register(@CurrentUser() user: AuthenticatedUser, @Body() dto: RegisterRobotDto) {
    return this.robotsService.register(user.id, dto);
  }

  @Patch(':id')
  update(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string, @Body() dto: UpdateRobotDto) {
    return this.robotsService.update(user.id, id, dto);
  }

  @Delete(':id')
  unpair(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string) {
    return this.robotsService.unpair(user.id, id);
  }

  @Post(':id/commands')
  sendCommand(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') id: string,
    @Body() command: Record<string, unknown>,
  ) {
    return this.robotsService.sendCommand(user.id, id, command);
  }

  @Post(':id/tuya-link')
  linkTuyaDevice(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: LinkTuyaDeviceDto,
  ) {
    return this.robotsService.linkTuyaDevice(user.id, id, dto.tuyaDeviceId);
  }
}
