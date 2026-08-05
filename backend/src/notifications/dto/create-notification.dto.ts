import { NotificationType } from '@prisma/client';
import { IsEnum, IsOptional, IsString, MaxLength } from 'class-validator';

export class CreateNotificationDto {
  @IsEnum(NotificationType)
  type!: NotificationType;

  @IsString()
  @MaxLength(500)
  message!: string;

  @IsOptional()
  @IsString()
  robotId?: string;
}
