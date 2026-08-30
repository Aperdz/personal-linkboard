// Health + /metrics endpoints — separated from LinksController since
// these aren't "business" routes, same separation of concerns Project 1
// has between /health, /metrics, and the actual URL endpoints.
import { Controller, Get, Res } from '@nestjs/common';
import { Response } from 'express';
import { LinksService } from '../links/links.service';
import { register } from '../metrics/metrics';

@Controller()
export class HealthController {
  constructor(private readonly linksService: LinksService) {}

  @Get('health')
  async health() {
    await this.linksService.pingDependencies();
    return { status: 'ok' };
  }

  @Get('metrics')
  async metrics(@Res() res: Response) {
    res.set('Content-Type', register.contentType);
    res.send(await register.metrics());
  }
}
