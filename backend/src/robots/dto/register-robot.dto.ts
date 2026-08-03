import { IsString, MinLength } from 'class-validator';

export class RegisterRobotDto {
  @IsString()
  @MinLength(1)
  serialNumber!: string;

  @IsString()
  @MinLength(1)
  name!: string;

  @IsString()
  @MinLength(1)
  model!: string;
}
