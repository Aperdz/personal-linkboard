// DTO = Data Transfer Object. This is NestJS's equivalent of the
// Pydantic schema in Project 1 — it validates incoming request bodies
// BEFORE any business logic runs.
import { IsUrl, IsNotEmpty } from 'class-validator';

export class CreateLinkDto {
  @IsUrl({ require_protocol: true }, { message: 'url must be a valid http(s) URL' })
  @IsNotEmpty()
  url: string;
}
