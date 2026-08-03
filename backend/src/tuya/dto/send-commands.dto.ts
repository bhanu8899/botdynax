import { Type } from 'class-transformer';
import { ArrayMinSize, IsArray, IsDefined, IsString, ValidateNested } from 'class-validator';

export class TuyaCommandDto {
  @IsString()
  code!: string;

  // A Tuya DP value can be a bool, string, or number depending on the
  // code — @IsDefined() just requires it be present (false/0/'' are all
  // valid DP values). Without ANY decorator here, the global
  // ValidationPipe's `forbidNonWhitelisted` rejects this field outright.
  @IsDefined()
  value!: unknown;
}

export class SendCommandsDto {
  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => TuyaCommandDto)
  commands!: TuyaCommandDto[];
}
