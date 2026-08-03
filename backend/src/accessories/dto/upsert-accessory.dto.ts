import { AccessoryType } from '@prisma/client';
import { IsEnum, IsInt, IsNumber, Max, Min } from 'class-validator';

export class UpsertAccessoryDto {
  @IsEnum(AccessoryType)
  type!: AccessoryType;

  @IsNumber()
  @Min(0)
  @Max(1)
  remainingPercent!: number;

  @IsInt()
  @Min(1)
  ratedLifetimeMinutes!: number;

  @IsInt()
  @Min(0)
  usedMinutes!: number;
}
