import { IsOptional, IsString, MinLength } from 'class-validator';

export class UpdateRobotDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  name?: string;
}
