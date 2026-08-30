// Controller = the "routes" layer. Same role as the @app.post/@app.get
// decorators in Project 1's main.py, just NestJS's class-based style.
import {
  Controller,
  Post,
  Get,
  Body,
  Param,
  Res,
  HttpStatus,
} from '@nestjs/common';
import { Response } from 'express';
import { LinksService } from './links.service';
import { CreateLinkDto } from './dto/create-link.dto';
import { linksCreatedTotal, redirectsTotal } from '../metrics/metrics';

@Controller()
export class LinksController {
  constructor(private readonly linksService: LinksService) {}

  @Post('api/shorten')
  async shorten(@Body() dto: CreateLinkDto) {
    const link = await this.linksService.createLink(dto.url);
    linksCreatedTotal.inc();
    const baseUrl = process.env.BASE_URL || 'http://localhost:4000';
    return {
      shortCode: link.shortCode,
      shortUrl: `${baseUrl}/${link.shortCode}`,
      originalUrl: link.originalUrl,
    };
  }

  @Get('api/stats/:code')
  async stats(@Param('code') code: string) {
    const link = await this.linksService.getStats(code);
    return {
      shortCode: link.shortCode,
      originalUrl: link.originalUrl,
      clickCount: link.clickCount,
      createdAt: (link as any).createdAt,
    };
  }

  @Get(':code')
  async redirect(@Param('code') code: string, @Res() res: Response) {
    const originalUrl = await this.linksService.resolveAndTrackClick(code);
    redirectsTotal.inc();
    return res.redirect(HttpStatus.TEMPORARY_REDIRECT, originalUrl);
  }
}
