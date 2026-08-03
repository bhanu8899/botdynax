import { IsString, MinLength } from 'class-validator';

export class LinkTuyaDeviceDto {
  @IsString()
  @MinLength(1)
  tuyaDeviceId!: string;
}
