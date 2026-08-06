import { Body, Controller, Delete, Get, Param, Post, UseGuards } from '@nestjs/common';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { AuthenticatedUser } from '../auth/jwt-payload.interface';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { RobotsService } from '../robots/robots.service';
import { AutoLinkDto } from './dto/auto-link.dto';
import { LinkAccountDto } from './dto/link-account.dto';
import { SendCommandsDto } from './dto/send-commands.dto';
import { TuyaService } from './tuya.service';

@UseGuards(JwtAuthGuard)
@Controller('tuya')
export class TuyaController {
  constructor(
    private readonly tuyaService: TuyaService,
    private readonly robotsService: RobotsService,
  ) {}

  /// The app opens this URL in an in-app WebView; once the user
  /// authorizes, Tuya redirects to `redirectUri` with a `code` query
  /// param, which the app then posts to [link]. Only needed for a user
  /// connecting their own pre-existing Tuya-ecosystem device — devices
  /// OEM'd directly into this project (see robots/:id/tuya-link) skip
  /// this entirely.
  @Get('auth-url')
  getAuthUrl() {
    const state = this.tuyaService.generateState();
    return { url: this.tuyaService.getAuthUrl(state), state };
  }

  @Post('link')
  async link(@CurrentUser() user: AuthenticatedUser, @Body() dto: LinkAccountDto) {
    await this.tuyaService.linkAccount(user.id, dto.code);
    return { linked: true };
  }

  @Delete('link')
  async unlink(@CurrentUser() user: AuthenticatedUser) {
    await this.tuyaService.unlinkAccount(user.id);
    return { linked: false };
  }

  @Get('devices')
  listDevices(@CurrentUser() user: AuthenticatedUser) {
    return this.tuyaService.listDevices(user.id);
  }

  /// Looks up this product's CURRENT Tuya device id (project-scoped, no
  /// per-user OAuth needed) and links it to `robotId` -- called instead
  /// of the client trusting a possibly-stale id it already has. Devices
  /// that re-provision (observed on this robot after what looked like a
  /// routine reboot) get a brand new id from Tuya each time; calling this
  /// on every app launch, the way `pairDefaultRobot()` does, makes that
  /// self-healing instead of needing a manual fix every time it happens.
  @Post('robots/:robotId/link-auto')
  async linkAuto(
    @CurrentUser() user: AuthenticatedUser,
    @Param('robotId') robotId: string,
    @Body() dto: AutoLinkDto,
  ) {
    const deviceId = await this.tuyaService.discoverDeviceIdByProduct(dto.productId);
    return this.robotsService.linkTuyaDevice(user.id, robotId, deviceId);
  }

  /// Every device-level route below takes a *backend robot id*, not a raw
  /// Tuya device id — `RobotsService.requireTuyaDeviceId` both resolves it
  /// and enforces that the caller owns that robot.
  @Get('robots/:robotId/status')
  async getStatus(@CurrentUser() user: AuthenticatedUser, @Param('robotId') robotId: string) {
    const deviceId = await this.robotsService.requireTuyaDeviceId(user.id, robotId);
    return this.tuyaService.getDeviceStatus(deviceId);
  }

  @Get('robots/:robotId/functions')
  async getFunctions(@CurrentUser() user: AuthenticatedUser, @Param('robotId') robotId: string) {
    const deviceId = await this.robotsService.requireTuyaDeviceId(user.id, robotId);
    return this.tuyaService.getDeviceFunctions(deviceId);
  }

  @Post('robots/:robotId/commands')
  async sendCommands(
    @CurrentUser() user: AuthenticatedUser,
    @Param('robotId') robotId: string,
    @Body() dto: SendCommandsDto,
  ) {
    const deviceId = await this.robotsService.requireTuyaDeviceId(user.id, robotId);
    return this.tuyaService.sendCommands(deviceId, dto.commands);
  }

  @Get('robots/:robotId/map')
  async getMap(@CurrentUser() user: AuthenticatedUser, @Param('robotId') robotId: string) {
    const deviceId = await this.robotsService.requireTuyaDeviceId(user.id, robotId);
    return this.tuyaService.getLatestMap(deviceId);
  }
}
