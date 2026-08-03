import { Body, Controller, Get, Param, Post, Put, UseGuards } from '@nestjs/common';
import { AccessoryType } from '@prisma/client';
import { IsEnum } from 'class-validator';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { AuthenticatedUser } from '../auth/jwt-payload.interface';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { AccessoriesService } from './accessories.service';
import { UpsertAccessoryDto } from './dto/upsert-accessory.dto';

class ReplaceByTypeDto {
  @IsEnum(AccessoryType)
  type!: AccessoryType;
}

@UseGuards(JwtAuthGuard)
@Controller('robots/:robotId/accessories')
export class AccessoriesController {
  constructor(private readonly accessoriesService: AccessoriesService) {}

  @Get()
  findAll(@CurrentUser() user: AuthenticatedUser, @Param('robotId') robotId: string) {
    return this.accessoriesService.findAll(user.id, robotId);
  }

  @Put()
  upsert(
    @CurrentUser() user: AuthenticatedUser,
    @Param('robotId') robotId: string,
    @Body() dto: UpsertAccessoryDto,
  ) {
    return this.accessoriesService.upsert(user.id, robotId, dto);
  }

  @Post(':accessoryId/replace')
  markReplaced(
    @CurrentUser() user: AuthenticatedUser,
    @Param('robotId') robotId: string,
    @Param('accessoryId') accessoryId: string,
  ) {
    return this.accessoriesService.markReplaced(user.id, robotId, accessoryId);
  }

  @Post('replace-by-type')
  markReplacedByType(
    @CurrentUser() user: AuthenticatedUser,
    @Param('robotId') robotId: string,
    @Body() dto: ReplaceByTypeDto,
  ) {
    return this.accessoriesService.markReplacedByType(user.id, robotId, dto.type);
  }
}
