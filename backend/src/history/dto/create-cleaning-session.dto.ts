import { IsArray, IsInt, IsNumber, IsOptional, IsString, Min } from 'class-validator';

export class CreateCleaningSessionDto {
  @IsNumber()
  @Min(0)
  areaCleanedSqm!: number;

  @IsInt()
  @Min(0)
  durationSeconds!: number;

  @IsNumber()
  @Min(0)
  batteryUsedPercent!: number;

  @IsOptional()
  @IsArray()
  errors?: string[];

  @IsOptional()
  @IsString()
  mapSnapshotUrl?: string;

  @IsOptional()
  @IsInt()
  cleaningScore?: number;
}
