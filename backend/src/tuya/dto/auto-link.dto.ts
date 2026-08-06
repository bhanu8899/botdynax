import { IsString } from 'class-validator';

export class AutoLinkDto {
  @IsString()
  productId!: string;
}
