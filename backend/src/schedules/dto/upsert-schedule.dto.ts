import { IsArray, IsBoolean, IsOptional, IsString, Matches, MinLength } from 'class-validator';

export class UpsertScheduleDto {
  @IsString()
  @MinLength(1)
  label!: string;

  @IsString()
  daysOfWeek!: string;

  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/, { message: 'time must be in HH:mm 24h format' })
  time!: string;

  @IsString()
  mode!: string;

  @IsArray()
  roomIds!: string[];

  @IsString()
  vacuumPower!: string;

  @IsString()
  waterLevel!: string;

  @IsOptional()
  @IsBoolean()
  enabled?: boolean;

  @IsOptional()
  @IsBoolean()
  notify?: boolean;
}
